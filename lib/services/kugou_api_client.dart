import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../models/kugou_session.dart';
import '../models/lyric.dart';
import '../models/music_playlist.dart';
import '../models/search_catalog_item.dart';
import '../models/song.dart';
import '../controllers/playback_quality_controller.dart';
import 'api_endpoint_service.dart';
import 'kugou_official_client.dart';
import 'krc_lyric_parser.dart';
import 'secure_session_storage.dart';
import 'session_expired_service.dart';

class AuthenticationRequiredException implements Exception {
  const AuthenticationRequiredException();
}

class KugouApiException implements Exception {
  const KugouApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _PlaybackCandidate {
  const _PlaybackCandidate({required this.hash, this.quality});

  final String hash;
  final Object? quality;
}

class KugouQrCode {
  const KugouQrCode({
    required this.key,
    required this.imageDataUrl,
    this.qrText,
  });

  final String key;
  final String imageDataUrl;
  final String? qrText;
}

class KugouQrCheckResult {
  const KugouQrCheckResult({required this.status, this.session});

  final int status;
  final KugouSession? session;
}

class KugouWxLoginCode {
  const KugouWxLoginCode({
    required this.uuid,
    required this.imageDataUrl,
    this.qrText,
  });

  final String uuid;
  final String imageDataUrl;
  final String? qrText;
}

class KugouWxCheckResult {
  const KugouWxCheckResult({required this.status, this.openCode, this.session});

  final int status;
  final String? openCode;
  final KugouSession? session;
}

class DailyVipClaimResult {
  const DailyVipClaimResult({required this.claimed, required this.already});

  final bool claimed;
  final bool already;
}

class KugouApiClient {
  KugouApiClient({
    Dio? dio,
    SecureSessionStorage? storage,
    ApiEndpointService? endpointService,
    this.playbackQualityController,
  }) : _dio = dio ?? _createDio(''),
       _storage = storage ?? SecureSessionStorage(),
       _endpointService = endpointService ?? ApiEndpointService(),
       _officialClient = KugouOfficialClient();

  final Dio _dio;
  final SecureSessionStorage _storage;
  final ApiEndpointService _endpointService;
  final PlaybackQualityController? playbackQualityController;
  final KugouOfficialClient _officialClient;
  final Map<String, ({DateTime expiresAt, List<String> urls})> _portraitCache =
      {};
  final Map<String, Future<List<String>>> _portraitRequests = {};

  KugouSession session = const KugouSession();

  Future<void> initialize() async {
    session = await _storage.load();
    if (!session.hasDevice || await _needsOfficialDeviceRefresh()) {
      await registerDevice();
    }
  }

  Future<bool> _needsOfficialDeviceRefresh() async {
    if (!await _usesOfficialApi()) return false;
    final guidLooksValid = RegExp(r'^[0-9a-f]{32}$').hasMatch(session.guid);
    final dfidLooksSynthetic = RegExp(r'^[0-9A-Z]{24}$').hasMatch(session.dfid);
    return !guidLooksValid || dfidLooksSynthetic;
  }

  Future<void> registerDevice() async {
    if (await _usesOfficialApi()) {
      final guid = !RegExp(r'^[0-9a-f]{32}$').hasMatch(session.guid)
          ? KugouOfficialClient.randomGuid()
          : session.guid;
      session = session.copyWith(
        mid: session.mid.isEmpty
            ? KugouOfficialClient.midFromGuid(guid)
            : session.mid,
        guid: guid,
        device: session.device.isEmpty
            ? KugouOfficialClient.randomDeviceId()
            : session.device,
        mac: session.mac.isEmpty
            ? KugouOfficialClient.randomMac()
            : session.mac,
      );
      final response = await _officialRequest(
        '/register/dev',
        queryParameters: {
          'userid': session.userId,
          'token': session.token,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
        bypassCache: true,
      );
      final body = _map(response.data);
      final data = _map(body['data']);
      final dfid = _read(data, ['dfid'], fallback: _read(body, ['dfid']));
      if (dfid.isEmpty) {
        throw const KugouApiException('设备初始化失败，请稍后重试');
      }
      session = _mergeCookies(
        session.copyWith(dfid: dfid),
        response.headers.map['set-cookie'] ?? const [],
      );
      await _storage.save(session);
      return;
    }

    final response = await _get(
      '/register/dev',
      queryParameters: {'timestamp': DateTime.now().millisecondsSinceEpoch},
    );
    final data = _map(response.data)['data'];
    final body = _map(data);
    session = _mergeCookies(
      session.copyWith(dfid: body['dfid']?.toString()),
      response.headers.map['set-cookie'] ?? const [],
    );
    if (!session.hasDevice) {
      throw const KugouApiException('设备初始化失败，请稍后重试');
    }
    await _storage.save(session);
  }

  Future<KugouQrCode> createLoginQr() async {
    final response = await _get(
      '/login/qr/key',
      queryParameters: {'timestamp': DateTime.now().millisecondsSinceEpoch},
      bypassCache: true,
    );
    final data = _map(_map(response.data)['data']);
    final key = (data['qrcode'] ?? data['key'] ?? '').toString();
    var qrText = (data['qrcode_txt'] ?? data['qrText'] ?? '').toString();
    var image = (data['qrcode_img'] ?? data['base64'] ?? '').toString();

    if (key.isEmpty) {
      throw const KugouApiException('二维码生成失败');
    }
    if (image.isEmpty && qrText.isEmpty && await _usesOfficialApi()) {
      qrText =
          'https://h5.kugou.com/apps/loginQRCode/html/index.html?qrcode=$key';
    }
    if (image.isEmpty && qrText.isEmpty) {
      final create = await _get(
        '/login/qr/create',
        queryParameters: {
          'key': key,
          'qrimg': true,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
        bypassCache: true,
      );
      final createData = _map(_map(create.data)['data']);
      image = (createData['base64'] ?? createData['qrcode_img'] ?? '')
          .toString();
    }
    if (image.isEmpty && qrText.isEmpty) {
      throw const KugouApiException('二维码图片生成失败');
    }
    return KugouQrCode(key: key, imageDataUrl: image, qrText: qrText);
  }

  Future<KugouQrCheckResult> checkLoginQr(String key) async {
    final response = await _get(
      '/login/qr/check',
      queryParameters: {
        'key': key,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
      bypassCache: true,
    );
    final data = _map(_map(response.data)['data']);
    final status = _toInt(data['status']);
    if (status != 4) return KugouQrCheckResult(status: status);

    final token = (data['token'] ?? '').toString();
    final userId = (data['userid'] ?? data['user_id'] ?? '').toString();
    if (token.isEmpty || userId.isEmpty) {
      throw const KugouApiException('该账号未注册或未获得有效登录凭证');
    }

    session = _mergeCookies(
      session.copyWith(
        token: token,
        userId: userId,
        nickname: (data['nickname'] ?? data['username'] ?? '').toString(),
        avatarUrl: _read(data, ['pic', 'avatar', 'img', 'avatar_url']),
      ),
      response.headers.map['set-cookie'] ?? const [],
    );
    if (await _usesOfficialApi()) {
      await registerDevice();
    }
    await _storage.save(session);
    return KugouQrCheckResult(status: status, session: session);
  }

  Future<void> sendSmsCode(String mobile) async {
    final normalized = mobile.trim();
    if (!RegExp(r'^1\d{10}$').hasMatch(normalized)) {
      throw const KugouApiException('请输入正确的手机号');
    }
    final response = await _get(
      '/captcha/sent',
      queryParameters: {
        'mobile': normalized,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
      bypassCache: true,
    );
    final body = _map(response.data);
    final status = _toInt(body['status'] ?? body['code']);
    final errorCode = _toInt(body['error_code'] ?? body['errcode']);
    final ok =
        status == 1 ||
        status == 200 ||
        errorCode == 0 ||
        body['data'] == true ||
        _toInt(_map(body['data'])['status']) == 1;
    if (!ok) {
      throw KugouApiException(
        _read(body, ['error', 'message', 'msg'], fallback: '验证码发送失败，请稍后重试'),
      );
    }
  }

  Future<KugouSession> loginBySms(String mobile, String code) async {
    final normalized = mobile.trim();
    final smsCode = code.trim();
    if (!RegExp(r'^1\d{10}$').hasMatch(normalized)) {
      throw const KugouApiException('请输入正确的手机号');
    }
    if (smsCode.isEmpty) {
      throw const KugouApiException('请输入验证码');
    }
    if (!session.hasDevice) await registerDevice();
    final response = await _get(
      '/login/cellphone',
      queryParameters: {
        'mobile': normalized,
        'code': smsCode,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
      bypassCache: true,
    );
    session = await _applyLoginResponse(response);
    return session;
  }

  Future<KugouWxLoginCode> createWxLogin() async {
    if (await _usesOfficialApi()) {
      throw const KugouApiException('微信登录需要后端 API 支持，请先在设置中填写支持微信登录的接口地址');
    }
    final response = await _get('/login/wx/create', bypassCache: true);
    final body = _map(response.data);
    final data = _map(body['data'] ?? body);
    final uuid = _read(data, ['uuid'], fallback: _read(body, ['uuid']));
    final qrcode = _map(data['qrcode'] ?? body['qrcode']);
    var image = _read(qrcode, [
      'qrcodebase64',
    ], fallback: _read(data, ['qrcodebase64', 'base64', 'qrcode_img']));
    final qrText = _read(qrcode, [
      'qrcodeurl',
    ], fallback: _read(data, ['qrcodeurl', 'qrText']));
    if (image.isNotEmpty && !image.startsWith('data:')) {
      image = 'data:image/jpeg;base64,$image';
    }
    if (uuid.isEmpty || (image.isEmpty && qrText.isEmpty)) {
      throw const KugouApiException('微信二维码生成失败');
    }
    return KugouWxLoginCode(uuid: uuid, imageDataUrl: image, qrText: qrText);
  }

  Future<KugouWxCheckResult> checkWxLogin(String uuid) async {
    if (await _usesOfficialApi()) {
      throw const KugouApiException('微信登录需要后端 API 支持');
    }
    final response = await _get(
      '/login/wx/check',
      queryParameters: {
        'uuid': uuid,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
      bypassCache: true,
    );
    final body = _map(response.data);
    final data = _map(body['data'] ?? body);
    final status = _toInt(
      data['wx_errcode'] ??
          data['status'] ??
          body['wx_errcode'] ??
          body['status'],
    );
    final openCode = _read(data, [
      'wx_code',
      'code',
    ], fallback: _read(body, ['wx_code', 'code']));
    return KugouWxCheckResult(status: status, openCode: openCode);
  }

  Future<KugouSession> loginByOpenPlat(String code) async {
    if (await _usesOfficialApi()) {
      throw const KugouApiException('微信登录需要后端 API 支持');
    }
    final response = await _get(
      '/login/openplat',
      queryParameters: {'code': code, 'plat': 2},
      bypassCache: true,
    );
    session = await _applyLoginResponse(response);
    return session;
  }

  Future<void> logout() async {
    session = session.loggedOut();
    await _storage.save(session);
  }

  Future<DailyVipClaimResult> ensureDailyVip() async {
    if (!session.isLoggedIn) throw const AuthenticationRequiredException();
    final today = _todayString();
    final recordResponse = await _get(
      '/youth/month/vip/record',
      authenticated: true,
      bypassCache: true,
    );
    final records = _findRecords(recordResponse.data);
    final already = records.any((item) {
      final json = _map(item);
      final day = _read(json, ['day', 'date', 'receive_day']);
      return day == today;
    });
    if (already) return const DailyVipClaimResult(claimed: true, already: true);

    final claimResponse = await _get(
      '/youth/day/vip',
      authenticated: true,
      queryParameters: {'receive_day': today},
      bypassCache: true,
    );
    final claimBody = _map(claimResponse.data);
    final claimStatus = _toInt(claimBody['status'] ?? claimBody['code']);
    final claimError = _toInt(claimBody['error_code'] ?? claimBody['errcode']);
    if (claimStatus != 1 && claimStatus != 200 && claimError != 0) {
      throw KugouApiException(
        _read(claimBody, ['message', 'msg', 'error'], fallback: 'VIP 领取失败'),
      );
    }

    try {
      await _get(
        '/youth/day/vip/upgrade',
        authenticated: true,
        bypassCache: true,
      );
    } catch (_) {
      // 升级权益失败不影响每日畅听会员的领取状态。
    }
    return const DailyVipClaimResult(claimed: true, already: false);
  }

  Future<KugouSession> _applyLoginResponse(Response<Object?> response) async {
    final body = _map(response.data);
    final data = _map(body['data'] ?? body);
    final status = _toInt(body['status'] ?? body['code'] ?? data['status']);
    if (status != 0 && status != 1 && status != 200) {
      throw KugouApiException(
        _read(body, ['error', 'message', 'msg'], fallback: '登录失败，请稍后重试'),
      );
    }
    final token = _read(data, ['token'], fallback: _read(body, ['token']));
    final userId = _read(data, [
      'userid',
      'user_id',
    ], fallback: _read(body, ['userid', 'user_id']));
    if (token.isEmpty || userId.isEmpty || userId == '0') {
      throw KugouApiException(
        _read(body, ['error', 'message', 'msg'], fallback: '该账号未注册或未获得有效登录凭证'),
      );
    }
    session = _mergeCookies(
      session.copyWith(
        token: token,
        userId: userId,
        nickname: _read(data, [
          'nickname',
          'username',
          'nick_name',
        ], fallback: _read(body, ['nickname', 'username', 'nick_name'])),
        avatarUrl: _read(data, [
          'pic',
          'avatar',
          'img',
          'avatar_url',
        ], fallback: _read(body, ['pic', 'avatar', 'img', 'avatar_url'])),
      ),
      response.headers.map['set-cookie'] ?? const [],
    );
    if (await _usesOfficialApi()) {
      await registerDevice();
    } else {
      await _storage.save(session);
    }
    return session;
  }

  Future<List<String>> searchSuggestions(String keyword) async {
    final response = await _get(
      '/search/suggest',
      queryParameters: {'keywords': keyword},
    );
    final body = _map(response.data);
    final groups = _list(body['data']);
    final values = <String>[];
    for (final group in groups) {
      for (final record in _list(_map(group)['RecordDatas'])) {
        final value = (_map(record)['HintInfo'] ?? '').toString().trim();
        if (value.isNotEmpty && !values.contains(value)) values.add(value);
        if (values.length == 8) return values;
      }
    }
    return values;
  }

  Future<List<Song>> searchSongs(String keyword) async {
    if (!await _usesOfficialApi() && !session.isLoggedIn) {
      throw const AuthenticationRequiredException();
    }

    final response = await _get(
      '/search',
      authenticated: true,
      queryParameters: {
        'keywords': keyword,
        'type': 'song',
        'page': 1,
        'pagesize': 30,
      },
    );
    final body = _map(response.data);
    final errorCode = _toInt(body['error_code'] ?? body['ErrorCode']);
    if (errorCode == 152) {
      await logout();
      throw const AuthenticationRequiredException();
    }

    final data = _map(body['data']);
    final records = _list(
      data['lists'] ??
          data['list'] ??
          data['songs'] ??
          data['info'] ??
          body['lists'],
    );
    return records.map(_songFromSearch).whereType<Song>().toList();
  }

  Future<List<SearchCatalogItem>> searchCatalog(
    String keyword,
    SearchCategory category,
  ) async {
    if (!await _usesOfficialApi() && !session.isLoggedIn) {
      throw const AuthenticationRequiredException();
    }

    final type = switch (category) {
      SearchCategory.album => 'album',
      SearchCategory.artist => 'author',
      SearchCategory.playlist => 'special',
      SearchCategory.song => 'song',
    };
    final response = await _get(
      '/search',
      authenticated: true,
      queryParameters: {
        'keywords': keyword,
        'type': type,
        'page': 1,
        'pagesize': 30,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
      bypassCache: true,
    );
    final body = _map(response.data);
    final errorCode = _toInt(body['error_code'] ?? body['ErrorCode']);
    if (errorCode == 152) {
      await logout();
      throw const AuthenticationRequiredException();
    }

    final data = _map(body['data']);
    final records = _list(data['lists'] ?? data['info'] ?? body['data']);
    return records
        .map((value) => _catalogItem(value, category))
        .whereType<SearchCatalogItem>()
        .toList();
  }

  Future<List<Song>> getCatalogSongs(SearchCatalogItem item) async {
    if (item.category == SearchCategory.album) {
      return _getAlbumSongs(item.id);
    }
    final path = switch (item.category) {
      SearchCategory.artist => '/artist/audios',
      SearchCategory.playlist => '/playlist/public/track/all',
      SearchCategory.album => throw const KugouApiException('不支持的详情类型'),
      SearchCategory.song => throw const KugouApiException('不支持的详情类型'),
    };
    final response = await _get(
      path,
      authenticated: true,
      bypassCache: true,
      queryParameters: {
        'id': item.id,
        'listid': item.listId ?? item.id,
        'page': 1,
        'pagesize': 100,
      },
    );
    return _parseSongCollection(response.data);
  }

  Future<List<Song>> getDailyRecommendations() async {
    if (!session.isLoggedIn) throw const AuthenticationRequiredException();
    final response = await _officialRequest(
      '/recommend/daily',
      method: 'POST',
      bypassCache: true,
    );
    _throwIfAuthFailed(response.data);
    final body = _map(response.data);
    final data = _map(body['data']);
    return _deduplicateSongs(
      _list(data['song_list'])
          .map(
            (value) => _songFromCollection(value, liked: false, cloud: false),
          )
          .whereType<Song>(),
    );
  }

  Future<List<Song>> getPersonalFmSongs({
    String action = 'play',
    Song? contextSong,
    int playtimeSeconds = 0,
    bool isOverplay = false,
    String mode = 'normal',
    int songPoolId = 0,
    int remainSongCount = 0,
  }) async {
    if (!session.isLoggedIn) throw const AuthenticationRequiredException();
    final response = await _officialRequest(
      '/recommend/fm',
      method: 'POST',
      bypassCache: true,
      data: {
        'action': action,
        'hash': contextSong?.hash ?? '',
        'songid': contextSong?.albumAudioId ?? '',
        'playtime': playtimeSeconds,
        'is_overplay': isOverplay ? 1 : 0,
        'mode': mode,
        'song_pool_id': songPoolId,
        'remain_songcnt': remainSongCount,
      },
    );
    _throwIfAuthFailed(response.data);
    final body = _map(response.data);
    if (_toInt(body['error_code'] ?? body['ErrorCode']) != 0) {
      throw const KugouApiException('私人 FM 暂时不可用，请稍后重试');
    }
    final data = _map(body['data']);
    return _deduplicateSongs(
      _list(data['song_list'])
          .map(
            (value) => _songFromCollection(value, liked: false, cloud: false),
          )
          .whereType<Song>(),
    );
  }

  Future<List<SearchCatalogItem>> getArtistAlbums(
    SearchCatalogItem artist,
  ) async {
    return getArtistAlbumsPage(artist, page: 1);
  }

  Future<List<SearchCatalogItem>> getArtistAlbumsPage(
    SearchCatalogItem artist, {
    required int page,
    int pageSize = 50,
  }) async {
    final response = await _get(
      '/artist/albums',
      authenticated: true,
      queryParameters: {
        'id': artist.id,
        'page': page,
        'pagesize': pageSize,
        'sort': 'new',
      },
    );
    return _findRecords(response.data)
        .map((value) => _catalogItem(value, SearchCategory.album))
        .whereType<SearchCatalogItem>()
        .toList();
  }

  Future<List<MusicPlaylist>> getUserPlaylists() async {
    if (!session.isLoggedIn) throw const AuthenticationRequiredException();
    const pageSize = 100;
    final playlists = <String, MusicPlaylist>{};
    for (var page = 1; page <= 20; page++) {
      final response = await _get(
        '/user/playlist',
        authenticated: true,
        bypassCache: true,
        queryParameters: {'page': page, 'pagesize': pageSize},
      );
      final data = _map(_map(response.data)['data']);
      _throwIfAuthFailed(response.data);
      final records = _findRecords(data);
      if (records.isEmpty) break;

      var added = 0;
      for (final value in records) {
        final playlist = _playlistFromJson(value);
        if (playlist == null) continue;
        final key = playlist.listId.isNotEmpty ? playlist.listId : playlist.id;
        if (!playlists.containsKey(key)) added++;
        playlists[key] = playlist;
      }
      if (records.length < pageSize || added == 0) break;
    }
    return _withResolvedCollectionCounts(playlists.values.toList());
  }

  Future<List<MusicPlaylist>> _withResolvedCollectionCounts(
    List<MusicPlaylist> playlists,
  ) async {
    final result = <MusicPlaylist>[];
    for (final playlist in playlists) {
      if (playlist.kind == MusicPlaylistKind.collectedPlaylist &&
          playlist.songCount == 0 &&
          (playlist.sourceId ?? '').isNotEmpty) {
        final count = await _getPublicPlaylistCount(playlist.sourceId!);
        result.add(
          count > 0 ? _playlistWithSongCount(playlist, count) : playlist,
        );
      } else if (playlist.kind == MusicPlaylistKind.album &&
          playlist.songCount == 0) {
        final albumId = _albumIdFromPlaylist(playlist);
        if (albumId.isEmpty) {
          result.add(playlist);
          continue;
        }
        final songs = await _getAlbumSongs(albumId);
        result.add(
          songs.isNotEmpty
              ? _playlistWithSongCount(playlist, songs.length)
              : playlist,
        );
      } else {
        result.add(playlist);
      }
    }
    return result;
  }

  MusicPlaylist _playlistWithSongCount(MusicPlaylist playlist, int songCount) {
    return MusicPlaylist(
      id: playlist.id,
      listId: playlist.listId,
      name: playlist.name,
      songCount: songCount,
      coverUrl: playlist.coverUrl,
      sourceId: playlist.sourceId,
      sourceListId: playlist.sourceListId,
      isDefault: playlist.isDefault,
      isMine: playlist.isMine,
      kind: playlist.kind,
    );
  }

  MusicPlaylist? _playlistFromJson(Object? value) {
    final json = _map(value);
    final image = _read(json, ['pic', 'img', 'sizable_cover']);
    final source = _toInt(json['source']);
    final ownerId = _read(json, ['list_create_userid', 'userid', 'user_id']);
    final isDefault = _toInt(json['is_def'] ?? json['is_default']) > 0;
    final name = _read(json, ['name'], fallback: '未命名歌单');
    final collectionType = _toInt(json['type']);
    final mineFlag =
        (ownerId.isNotEmpty && ownerId == session.userId) ||
        _toInt(json['is_mine']) == 1;
    final localId = _read(json, ['global_collection_id', 'gid', 'specialid']);
    final sourceId = _read(json, ['list_create_gid']);
    final localListId = _read(json, ['listid']);
    final sourceListId = source == 2
        ? _read(json, ['musiclib_id', 'list_create_listid', 'specialid'])
        : _read(json, ['list_create_listid', 'specialid']);
    final isFavoriteSongs = isDefault && _isFavoriteSongsPlaylistName(name);
    final kind = isFavoriteSongs
        ? MusicPlaylistKind.favoriteSongs
        : source == 2
        ? MusicPlaylistKind.album
        : collectionType != 0
        ? MusicPlaylistKind.collectedPlaylist
        : mineFlag
        ? MusicPlaylistKind.createdPlaylist
        : isDefault
        ? MusicPlaylistKind.createdPlaylist
        : sourceId.isNotEmpty
        ? MusicPlaylistKind.collectedPlaylist
        : MusicPlaylistKind.collectedPlaylist;
    final playlist = MusicPlaylist(
      id: localId.isNotEmpty ? localId : sourceId,
      listId: localListId.isNotEmpty ? localListId : sourceListId,
      name: name,
      songCount: _toInt(json['m_count'] ?? json['song_count'] ?? json['count']),
      coverUrl: image.isEmpty ? null : image.replaceAll('{size}', '240'),
      sourceId: sourceId.isEmpty ? null : sourceId,
      sourceListId: sourceListId.isEmpty ? null : sourceListId,
      isDefault: isDefault,
      isMine: kind == MusicPlaylistKind.createdPlaylist,
      kind: kind,
    );
    if (playlist.id.isEmpty && playlist.listId.isEmpty) return null;
    return playlist;
  }

  Future<List<Song>> getPlaylistSongs(MusicPlaylist playlist) async {
    if (playlist.kind == MusicPlaylistKind.album) {
      final albumId = _albumIdFromPlaylist(playlist);
      if (albumId.isNotEmpty) {
        return _getAlbumSongs(albumId);
      }
    }
    if (playlist.kind == MusicPlaylistKind.collectedPlaylist &&
        (playlist.sourceId ?? '').isNotEmpty) {
      return _getPublicPlaylistSongs(playlist.sourceId!);
    }
    const pageSize = 200;
    final songs = <String, Song>{};
    for (var page = 1; page <= 30; page++) {
      final response = await _get(
        '/playlist/track/all',
        authenticated: true,
        bypassCache: true,
        queryParameters: {
          'id': playlist.id,
          'listid': playlist.listId,
          'page': page,
          'pagesize': pageSize,
        },
      );
      final records = _findRecords(response.data);
      if (records.isEmpty) break;
      final pageSongs = records
          .map(
            (value) => _songFromCollection(
              value,
              liked: playlist.kind == MusicPlaylistKind.favoriteSongs,
              cloud: false,
            ),
          )
          .whereType<Song>();
      var added = 0;
      for (final song in pageSongs) {
        final hash = song.hash ?? '';
        final key = hash.isNotEmpty ? hash : song.id;
        if (!songs.containsKey(key)) added++;
        songs[key] = song;
      }
      if (playlist.songCount > 0 && songs.length >= playlist.songCount) break;
      if (records.length < pageSize || added == 0) break;
    }
    final result = songs.values.toList();
    final newestFirst = playlist.kind == MusicPlaylistKind.createdPlaylist;
    return newestFirst ? result.reversed.toList() : result;
  }

  Future<List<Song>> _getPublicPlaylistSongs(String collectionId) async {
    const pageSize = 100;
    final songs = <String, Song>{};
    for (var page = 1; page <= 30; page++) {
      final response = await _get(
        '/playlist/public/track/all',
        authenticated: true,
        bypassCache: true,
        queryParameters: {
          'id': collectionId,
          'page': page,
          'pagesize': pageSize,
        },
      );
      final records = _findRecords(response.data);
      if (records.isEmpty) break;
      var added = 0;
      for (final value in records) {
        final song = _songFromCollection(value, liked: false, cloud: false);
        if (song == null) continue;
        final hash = song.hash ?? '';
        final key = hash.isNotEmpty ? hash : song.id;
        if (!songs.containsKey(key)) added++;
        songs[key] = song;
      }
      if (records.length < pageSize || added == 0) break;
    }
    return songs.values.toList();
  }

  Future<int> _getPublicPlaylistCount(String collectionId) async {
    try {
      final response = await _get(
        '/playlist/public/track/all',
        authenticated: true,
        bypassCache: true,
        queryParameters: {'id': collectionId, 'page': 1, 'pagesize': 1},
      );
      final body = _map(response.data);
      final data = _map(body['data']);
      return _toInt(
        body['count'] ??
            body['total'] ??
            data['count'] ??
            data['total'] ??
            data['total_count'],
      );
    } catch (_) {
      return 0;
    }
  }

  Future<List<Song>> _getAlbumSongs(String albumId) async {
    if (albumId.isEmpty) return const [];
    const pageSize = 30;
    final songs = <String, Song>{};
    var total = 0;
    for (var page = 1; page <= 20; page++) {
      final response = await _get(
        '/album/songs',
        authenticated: true,
        bypassCache: true,
        queryParameters: {'id': albumId, 'page': page, 'pagesize': pageSize},
      );
      final data = _map(_map(response.data)['data']);
      final records = _list(data['songs']);
      if (records.isEmpty) break;
      total = _toInt(data['total']);
      var added = 0;
      for (final value in records) {
        final song = _songFromCollection(value, liked: false, cloud: false);
        if (song == null) continue;
        final hash = song.hash ?? '';
        final key = hash.isNotEmpty ? hash : song.id;
        if (!songs.containsKey(key)) added++;
        songs[key] = song;
      }
      if (total > 0 && songs.length >= total) break;
      if (records.length < pageSize || added == 0) break;
    }
    return songs.values.toList();
  }

  Future<List<Song>> getCloudSongs() async {
    if (!session.isLoggedIn) throw const AuthenticationRequiredException();
    const pageSize = 100;
    final songs = <String, Song>{};
    for (var page = 1; page <= 30; page++) {
      final response = await _get(
        '/user/cloud',
        authenticated: true,
        bypassCache: true,
        queryParameters: {'page': page, 'pagesize': pageSize},
      );
      _throwIfAuthFailed(response.data);
      final records = _findRecords(response.data);
      if (records.isEmpty) break;
      final pageSongs = records
          .map((value) => _songFromCollection(value, liked: false, cloud: true))
          .whereType<Song>();
      var added = 0;
      for (final song in pageSongs) {
        final hash = song.hash ?? '';
        final key =
            song.cloudAudioId?.toString() ?? (hash.isNotEmpty ? hash : song.id);
        if (!songs.containsKey(key)) added++;
        songs[key] = song;
      }
      if (records.length < pageSize) break;
      if (added == 0 && songs.isNotEmpty) break;
    }
    return songs.values.toList();
  }

  Future<List<SearchCatalogItem>> getFollowedArtists() async {
    final response = await _get(
      '/user/follow',
      authenticated: true,
      bypassCache: true,
    );
    _throwIfAuthFailed(response.data);
    final records = _findRecords(response.data);
    return records
        .map((value) {
          final json = _map(value);
          final idenType = _toInt(json['iden_type']);
          final jumpType = _toInt(json['jumptype']);
          if ((idenType > 0 && idenType != 1) ||
              (jumpType > 0 && jumpType != 1)) {
            return null;
          }
          final directSingerId = _read(json, [
            'singerid',
            'author_id',
            'authorid',
          ]);
          final singerId = directSingerId.isNotEmpty
              ? directSingerId
              : (idenType == 1 || jumpType == 1)
              ? _read(json, ['id', 'userid'])
              : '';
          final name = _read(json, [
            'nickname',
            'singername',
            'name',
            'author_name',
            'username',
          ]);
          if (singerId.isEmpty || name.isEmpty) {
            return null;
          }
          return SearchCatalogItem(
            id: singerId,
            title: name,
            subtitle: '歌手',
            category: SearchCategory.artist,
            imageUrl: _read(json, ['pic', 'k_pic', 'avatar', 'img']),
          );
        })
        .whereType<SearchCatalogItem>()
        .toList();
  }

  Future<void> collectCatalog(SearchCatalogItem item) async {
    switch (item.category) {
      case SearchCategory.playlist:
        if (item.id.isEmpty) {
          throw const KugouApiException('歌单缺少收藏信息');
        }
        final response = await _post(
          '/playlist/add',
          authenticated: true,
          queryParameters: {
            'name': item.title,
            'source': 1,
            'type': 1,
            'list_create_userid': session.userId,
            'list_create_listid': '1',
            'list_create_gid': item.id,
          },
        );
        _ensureOperationSucceeded(response.data);
      case SearchCategory.artist:
        final response = await _post(
          '/artist/follow',
          authenticated: true,
          queryParameters: {'id': item.id},
        );
        _ensureOperationSucceeded(response.data);
      case SearchCategory.album:
        final albumId = item.listId ?? item.id;
        if (albumId.isEmpty) {
          throw const KugouApiException('专辑缺少收藏信息');
        }
        final response = await _post(
          '/playlist/add',
          authenticated: true,
          queryParameters: {
            'name': item.title,
            'source': 2,
            'type': 1,
            'is_pri': 0,
            'list_create_userid': item.ownerId ?? '0',
            'list_create_listid': albumId,
            'list_create_gid': '',
          },
        );
        _ensureOperationSucceeded(response.data);
      case SearchCategory.song:
        throw const KugouApiException('不支持收藏该类型');
    }
  }

  Future<void> uncollectCatalog(SearchCatalogItem item) async {
    switch (item.category) {
      case SearchCategory.playlist:
        final response = await _post(
          '/playlist/del',
          authenticated: true,
          queryParameters: {'listid': item.listId ?? item.id},
        );
        _ensureOperationSucceeded(response.data);
      case SearchCategory.album:
        final listId = item.listId ?? '';
        if (listId.isEmpty) {
          throw const KugouApiException('专辑缺少取消收藏信息');
        }
        final response = await _post(
          '/playlist/del',
          authenticated: true,
          queryParameters: {'listid': listId},
        );
        _ensureOperationSucceeded(response.data);
      case SearchCategory.artist:
        final response = await _post(
          '/artist/unfollow',
          authenticated: true,
          queryParameters: {'id': item.id},
        );
        _ensureOperationSucceeded(response.data);
      case SearchCategory.song:
        throw const KugouApiException('不支持取消收藏该类型');
    }
  }

  Future<void> addSongToPlaylist(MusicPlaylist playlist, Song song) async {
    if (song.hash == null || song.hash!.isEmpty) {
      throw const KugouApiException('歌曲缺少收藏信息');
    }
    await _post(
      '/playlist/tracks/add',
      authenticated: true,
      queryParameters: {
        'listid': playlist.listId,
        'data':
            '${song.artist} - ${song.title}|${song.hash}|${song.albumId ?? 0}|${song.albumAudioId ?? 0}',
      },
    );
  }

  Future<void> removeSongFromPlaylist(MusicPlaylist playlist, Song song) async {
    if (song.fileId == null) {
      throw const KugouApiException('请刷新收藏列表后再取消收藏');
    }
    await _post(
      '/playlist/tracks/del',
      authenticated: true,
      queryParameters: {'listid': playlist.listId, 'fileids': song.fileId},
    );
  }

  Future<Song> resolvePlayback(Song song) async {
    if (song.audioUrl.isNotEmpty) return song;
    if (!await _usesOfficialApi() && !session.isLoggedIn) {
      throw const AuthenticationRequiredException();
    }
    if (song.hash == null || song.hash!.isEmpty) {
      throw const KugouApiException('歌曲缺少播放信息');
    }

    if (!song.isCloud) {
      final candidates = await _resolvePrivilegeCandidates(song);
      for (final candidate in candidates) {
        final candidateUrl = await _resolveSongUrl(
          song,
          hash: candidate.hash,
          quality: candidate.quality,
        );
        if (candidateUrl != null) {
          return song.copyWith(audioUrl: candidateUrl);
        }
      }
    }

    final directUrl = await _resolvePreferredSongUrl(song);
    if (directUrl != null) return song.copyWith(audioUrl: directUrl);

    if (!song.isCloud) {
      final cloudMatch = await _findMatchingCloudSong(song);
      if (cloudMatch != null) {
        final cloudUrl = await _resolvePreferredSongUrl(cloudMatch);
        if (cloudUrl != null) {
          return song.copyWith(audioUrl: cloudUrl, playbackNotice: '已切换云盘版本');
        }
      }

      final searchableMatch = await _findPlayableSearchReplacement(song);
      if (searchableMatch != null) return searchableMatch;
    }

    throw const KugouApiException('该歌曲无版权或需付费');
  }

  Future<List<LyricLine>> getLyrics(Song song) async {
    final hash = song.hash?.trim() ?? '';
    if (hash.isEmpty) return const [];
    final searchResponse = await _get(
      '/search/lyric',
      queryParameters: {
        'hash': hash,
        'keywords': '${song.artist} - ${song.title}',
        'duration': song.duration.inMilliseconds,
        if (song.albumAudioId != null) 'album_audio_id': song.albumAudioId,
        'man': 'no',
      },
      bypassCache: true,
    );
    final candidate = _lyricCandidate(searchResponse.data);
    if (candidate == null) return const [];

    final lyricResponse = await _get(
      '/lyric',
      queryParameters: {
        'id': candidate.id,
        'accesskey': candidate.accessKey,
        'decode': 'true',
        'fmt': 'krc',
      },
      bypassCache: true,
    );
    final content = _lyricContent(lyricResponse.data);
    if (content.isEmpty) return const [];
    final parsed = const KrcLyricParser().parse(content);
    if (parsed.isNotEmpty) return parsed;
    final fallbackResponse = await _get(
      '/lyric',
      queryParameters: {
        'id': candidate.id,
        'accesskey': candidate.accessKey,
        'decode': 'true',
        'fmt': 'lrc',
      },
      bypassCache: true,
    );
    final fallback = _lyricContent(fallbackResponse.data);
    return fallback.isEmpty ? const [] : const KrcLyricParser().parse(fallback);
  }

  Future<List<String>> getArtistPortraits(Song song) async {
    final hash = song.hash?.trim() ?? '';
    if (hash.isEmpty) return const [];
    final cached = _portraitCache[hash];
    if (cached != null && cached.expiresAt.isAfter(DateTime.now())) {
      return cached.urls;
    }
    final pending = _portraitRequests[hash];
    if (pending != null) return pending;
    final request = _loadArtistPortraits(song);
    _portraitRequests[hash] = request;
    try {
      return await request;
    } finally {
      _portraitRequests.remove(hash);
    }
  }

  Future<List<String>> _loadArtistPortraits(Song song) async {
    final response = await _get(
      '/images/audio',
      queryParameters: {
        'hash': song.hash ?? '',
        'audio_id': song.fileId ?? 0,
        'album_audio_id': song.albumAudioId ?? 0,
        'filename': song.title,
        'count': 5,
      },
      bypassCache: true,
    );
    final urls = _findPortraitUrls(
      response.data,
    ).take(5).toList(growable: false);
    _portraitCache[song.hash!] = (
      expiresAt: DateTime.now().add(
        urls.isEmpty ? const Duration(minutes: 5) : const Duration(minutes: 30),
      ),
      urls: urls,
    );
    while (_portraitCache.length > 50) {
      _portraitCache.remove(_portraitCache.keys.first);
    }
    return urls;
  }

  Future<String?> _resolveSongUrl(
    Song song, {
    String? hash,
    Object? quality,
  }) async {
    final targetHash = hash ?? song.hash;
    if (targetHash == null || targetHash.isEmpty) return null;
    try {
      final response = await _get(
        song.isCloud ? '/user/cloud/url' : '/song/url',
        authenticated: true,
        queryParameters: {
          'hash': targetHash,
          'album_id': song.albumId ?? 0,
          'album_audio_id': song.albumAudioId ?? 0,
          if (song.isCloud) 'audio_id': song.cloudAudioId ?? 0,
          if (song.isCloud) 'name': '${song.artist} - ${song.title}',
          if (!song.isCloud) 'ppage_id': 356753938,
          'quality': quality ?? 128,
        },
      );
      return _findAudioUrl(response.data);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _resolvePreferredSongUrl(Song song) async {
    final qualities =
        playbackQualityController?.requestCandidates ?? const <Object>[128];
    for (final quality in qualities) {
      final url = await _resolveSongUrl(song, quality: quality);
      if (url != null) return url;
    }
    return null;
  }

  Future<List<_PlaybackCandidate>> _resolvePrivilegeCandidates(
    Song song,
  ) async {
    final hash = song.hash;
    if (hash == null || hash.isEmpty || song.isCloud) return const [];
    try {
      final response = await _get(
        '/privilege/lite',
        authenticated: true,
        queryParameters: {'hash': hash, 'album_id': song.albumId ?? 0},
      );
      final goods = _findRelateGoods(response.data);
      final preferred =
          playbackQualityController?.requestCandidates ?? const <Object>[128];
      final ranks = <String, int>{
        for (var index = 0; index < preferred.length; index++)
          _normalizedQuality(preferred[index]): index,
      };
      goods.sort((left, right) {
        final leftRank = ranks[_normalizedQuality(left.quality)] ?? 999;
        final rightRank = ranks[_normalizedQuality(right.quality)] ?? 999;
        return leftRank.compareTo(rightRank);
      });
      return goods;
    } catch (_) {
      return const [];
    }
  }

  Future<Song?> _findMatchingCloudSong(Song song) async {
    if (song.isCloud || !session.isLoggedIn) return null;
    try {
      final cloudSongs = await getCloudSongs();
      for (final cloudSong in cloudSongs) {
        if (_isSameSong(song, cloudSong)) return cloudSong;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<Song?> _findPlayableSearchReplacement(Song song) async {
    try {
      final candidates = await searchSongs('${song.title} ${song.artist}');
      for (final candidate in candidates) {
        if (!_isReplacementCandidate(song, candidate)) continue;
        final candidateUrl = await _resolvePreferredSongUrl(candidate);
        if (candidateUrl == null) continue;
        return song.copyWith(
          audioUrl: candidateUrl,
          playbackNotice: '已切换可播放版本',
        );
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<Response<Object?>> _get(
    String path, {
    Map<String, Object?>? queryParameters,
    bool authenticated = false,
    bool bypassCache = false,
  }) async {
    try {
      final officialMode = await _usesOfficialApi();
      if (officialMode) {
        return await _officialRequest(
          path,
          queryParameters: queryParameters,
          bypassCache: bypassCache,
        );
      }
      await _configureEndpoint();
      return await _dio.get<Object?>(
        path,
        queryParameters: queryParameters,
        options: Options(
          headers: {
            if (authenticated && session.authorization.isNotEmpty)
              'Authorization': session.authorization,
            if (bypassCache) 'Cache-Control': 'no-cache, no-store',
            if (bypassCache) 'Pragma': 'no-cache',
          },
        ),
      );
    } on DioException catch (error) {
      final data = error.response?.data;
      final errorCode = _toInt(
        _map(data)['error_code'] ?? _map(data)['ErrorCode'],
      );
      final authMessage =
          _map(data)['message']?.toString() ??
          _map(data)['msg']?.toString() ??
          '';
      if (authenticated && _isAuthenticationExpired(errorCode, authMessage)) {
        SessionExpiredService.notify();
        await logout();
        throw const AuthenticationRequiredException();
      }
      final message =
          _map(data)['message']?.toString() ??
          _map(data)['msg']?.toString() ??
          '网络请求失败，请稍后重试';
      throw KugouApiException(message);
    }
  }

  Future<Response<Object?>> _post(
    String path, {
    Map<String, Object?>? queryParameters,
    bool authenticated = false,
  }) async {
    try {
      final officialMode = await _usesOfficialApi();
      if (officialMode) {
        return await _officialRequest(
          path,
          queryParameters: queryParameters,
          method: 'POST',
          bypassCache: true,
        );
      }
      await _configureEndpoint();
      return await _dio.post<Object?>(
        path,
        queryParameters: queryParameters,
        options: Options(
          headers: {
            if (authenticated && session.authorization.isNotEmpty)
              'Authorization': session.authorization,
            'Cache-Control': 'no-cache, no-store',
          },
        ),
      );
    } on DioException catch (error) {
      final data = error.response?.data;
      throw KugouApiException(
        _map(data)['message']?.toString() ??
            _map(data)['msg']?.toString() ??
            '操作失败，请稍后重试',
      );
    }
  }

  Future<void> _configureEndpoint() async {
    final endpoint = await _endpointService.load();
    if (endpoint.isEmpty) {
      throw const KugouApiException('请先在设置中填写后端 API 地址');
    }
    final uri = Uri.tryParse(endpoint);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const KugouApiException('后端 API 地址格式不正确');
    }
    _dio.options.baseUrl = endpoint;
  }

  Future<bool> _usesOfficialApi() async =>
      (await _endpointService.load()).isEmpty;

  Future<Response<Object?>> _officialRequest(
    String path, {
    Map<String, Object?>? queryParameters,
    String method = 'GET',
    bool bypassCache = false,
    Object? data,
  }) async {
    final result = await _officialClient.request(
      path,
      queryParameters: queryParameters ?? const {},
      method: method,
      session: session,
      bypassCache: bypassCache,
      data: data,
    );
    return Response<Object?>(
      data: result['data'],
      statusCode: _toInt(result['statusCode']),
      headers: Headers.fromMap({
        'set-cookie': (result['setCookie'] as List<Object?>? ?? const [])
            .map((value) => value.toString())
            .toList(),
      }),
      requestOptions: RequestOptions(path: path),
    );
  }

  void _throwIfAuthFailed(Object? response) {
    final body = _map(response);
    final errorCode = _toInt(body['error_code'] ?? body['ErrorCode']);
    final message =
        body['message']?.toString() ??
        body['msg']?.toString() ??
        body['errmsg']?.toString() ??
        '';
    if (_isAuthenticationExpired(errorCode, message)) {
      SessionExpiredService.notify();
      throw const AuthenticationRequiredException();
    }
  }

  bool _isAuthenticationExpired(int errorCode, String message) {
    final normalized = message.trim();
    return errorCode == 152 ||
        errorCode == 20017 ||
        errorCode == 20018 ||
        normalized.contains('登录已过期') ||
        normalized.contains('登录过期') ||
        normalized.contains('请重新登录') ||
        normalized.toLowerCase().contains('login expired');
  }

  void _ensureOperationSucceeded(Object? response) {
    final body = _map(response);
    if (body.isEmpty) return;
    _throwIfAuthFailed(body);
    final data = _map(body['data']);
    final errorCode = _toInt(
      body['error_code'] ??
          body['ErrorCode'] ??
          body['errcode'] ??
          data['error_code'] ??
          data['errcode'],
    );
    final status = _toInt(
      body['status'] ??
          body['Status'] ??
          body['code'] ??
          data['status'] ??
          data['code'],
    );
    final success =
        errorCode == 0 && (status == 0 || status == 1 || status == 200);
    if (success) return;
    final message =
        body['message']?.toString() ??
        body['msg']?.toString() ??
        data['message']?.toString() ??
        data['msg']?.toString() ??
        '操作失败，请稍后重试';
    throw KugouApiException(message);
  }

  Song? _songFromSearch(Object? value) {
    final json = _map(value);
    final hash = _read(json, ['FileHash', 'filehash', 'hash', 'Hash']);
    var title = _read(json, [
      'SongName',
      'songname',
      'song_name',
      'title',
      'FileName',
      'filename',
    ]);
    var artist = _read(json, [
      'SingerName',
      'singername',
      'singer_name',
      'author_name',
    ], fallback: '未知歌手');
    final prefix = '$artist - ';
    if (title.startsWith(prefix)) title = title.substring(prefix.length);
    if (artist == '未知歌手' && title.contains(' - ')) {
      final parts = title.split(' - ');
      artist = parts.first.trim();
      title = parts.skip(1).join(' - ').trim();
    }
    final extractedArtists = _extractArtists(json, fallbackName: artist);
    final normalized = _normalizeTitleAndArtist(
      title,
      artist,
      extractedArtists,
    );
    title = normalized.title;
    artist = normalized.artist;
    if (hash.isEmpty || title.isEmpty) return null;

    final image = _read(json, [
      'Image',
      'image',
      'img',
      'imgurl',
    ], fallback: _coverFromTransParam(json['trans_param']));
    return Song(
      id: hash,
      title: title,
      artist: artist,
      album: _read(json, [
        'AlbumName',
        'album_name',
        'albumname',
      ], fallback: '未知专辑'),
      duration: Duration(
        seconds: _toInt(
          json['Duration'] ?? json['duration'] ?? json['timelen'],
        ),
      ),
      audioUrl: '',
      hash: hash,
      albumId: _toInt(json['AlbumID'] ?? json['album_id']),
      albumAudioId: _toInt(
        json['MixSongID'] ?? json['mixsongid'] ?? json['album_audio_id'],
      ),
      coverUrl: image.isEmpty ? null : image.replaceAll('{size}', '240'),
      fileId: _nullableInt(json['fileid']),
      artistId: _nullableInt(
        json['SingerId'] ?? json['singerid'] ?? json['author_id'],
      ),
      artists: _displayArtists(artist, extractedArtists),
    );
  }

  List<Song> _parseSongCollection(
    Object? response, {
    bool liked = false,
    bool cloud = false,
  }) {
    return _findRecords(response)
        .map((value) => _songFromCollection(value, liked: liked, cloud: cloud))
        .whereType<Song>()
        .toList();
  }

  List<Song> _deduplicateSongs(Iterable<Song> songs) {
    final result = <Song>[];
    final seen = <String>{};
    for (final song in songs) {
      final key = song.hash?.isNotEmpty == true ? song.hash! : song.id;
      if (key.isEmpty || !seen.add(key)) continue;
      result.add(song);
    }
    return result;
  }

  Song? _songFromCollection(
    Object? value, {
    required bool liked,
    required bool cloud,
  }) {
    final json = _map(value);
    final base = _map(json['base']);
    final audio = _map(json['audio_info']);
    final albumInfo = _map(json['album_info'] ?? json['albuminfo']);
    final relateGoodsList = _list(json['relate_goods']);
    final relateGoods = relateGoodsList.isEmpty
        ? const <String, Object?>{}
        : _map(relateGoodsList.first);
    final relateInfo = _map(relateGoods['info']);
    final transParam = _map(json['trans_param']);
    final singerInfoValue = json['singerinfo'];
    final singerInfo = singerInfoValue is List && singerInfoValue.isNotEmpty
        ? _map(singerInfoValue.first)
        : _map(singerInfoValue);
    final hash = _read(json, [
      'hash',
      'FileHash',
      'file_hash',
      'filehash',
    ], fallback: _read(audio, ['hash', 'hash_128', 'file_hash']));
    var artist = _read(
      json,
      ['singername', 'SingerName', 'author_name', 'singer_name', 'singer'],
      fallback: _read(base, [
        'author_name',
      ], fallback: _read(singerInfo, ['name'], fallback: '未知歌手')),
    );
    final authors = _list(json['authors'] ?? base['authors']);
    final firstAuthor = authors.isEmpty
        ? const <String, Object?>{}
        : _map(authors.first);
    final artistList = _extractArtists(json, fallbackName: artist);
    var title = _read(json, [
      'name',
      'audio_name',
      'songname',
      'song_name',
      'FileName',
      'filename',
      'file_name',
    ], fallback: _read(base, ['audio_name']));
    if (artist == '未知歌手' && title.contains(' - ')) {
      final parts = title.split(' - ');
      artist = parts.first.trim();
      title = parts.skip(1).join(' - ').trim();
    }
    final prefix = '$artist - ';
    if (title.startsWith(prefix)) title = title.substring(prefix.length);
    final normalized = _normalizeTitleAndArtist(title, artist, artistList);
    title = normalized.title;
    artist = normalized.artist;
    title = title.replaceFirst(
      RegExp(r'\.(mp3|m4a|flac|wav|aac)$', caseSensitive: false),
      '',
    );
    final cloudIdentity = _read(json, [
      'audio_id',
      'audioid',
      'mixsongid',
      'album_audio_id',
    ], fallback: _read(audio, ['audio_id']));
    final identity = hash.isNotEmpty ? hash : cloudIdentity;
    if (identity.isEmpty || title.isEmpty) return null;

    final cover = _read(
      json,
      ['cover', 'img', 'image', 'imgurl', 'sizable_cover'],
      fallback: _read(
        albumInfo,
        ['cover', 'sizable_cover'],
        fallback: _read(transParam, [
          'union_cover',
        ], fallback: _coverFromTransParam(json['trans_param'])),
      ),
    );
    var duration = _toInt(
      json['timelen'] ??
          json['timelength'] ??
          json['time_length'] ??
          json['timelength_320'] ??
          json['duration_320'] ??
          json['duration'] ??
          audio['duration'] ??
          audio['duration_128'] ??
          audio['duration_320'] ??
          relateGoods['duration'] ??
          relateGoods['timelength'] ??
          relateInfo['duration'] ??
          relateInfo['timelength'],
    );
    if (duration > 10000) duration ~/= 1000;

    return Song(
      id: identity,
      title: title,
      artist: artist,
      album: _read(
        json,
        ['album_name', 'AlbumName', 'albumname', 'album_title'],
        fallback: _read(
          albumInfo,
          ['album_name', 'albumname', 'name'],
          fallback: _read(
            relateGoods,
            ['album_name', 'albumname', 'name'],
            fallback: _read(
              base,
              ['album_name', 'albumname'],
              fallback: _read(audio, [
                'album_name',
                'albumname',
              ], fallback: '未知专辑'),
            ),
          ),
        ),
      ),
      duration: Duration(seconds: duration),
      audioUrl: '',
      hash: hash.isEmpty ? null : hash,
      albumId: _nullableInt(
        json['album_id'] ??
            json['albumid'] ??
            json['albumId'] ??
            base['album_id'] ??
            albumInfo['album_id'] ??
            albumInfo['albumid'] ??
            albumInfo['id'] ??
            relateGoods['album_id'] ??
            relateGoods['albumid'] ??
            relateGoods['recommend_album_id'] ??
            audio['album_id'] ??
            audio['albumid'],
      ),
      albumAudioId: _nullableInt(
        json['mixsongid'] ??
            json['album_audio_id'] ??
            base['album_audio_id'] ??
            relateGoods['album_audio_id'],
      ),
      coverUrl: cover.isEmpty ? null : cover.replaceAll('{size}', '240'),
      fileId: _nullableInt(json['fileid'] ?? json['file_id']),
      artistId: _nullableInt(
        json['singerid'] ??
            json['author_id'] ??
            base['author_id'] ??
            singerInfo['id'] ??
            firstAuthor['author_id'],
      ),
      artists: _displayArtists(artist, artistList),
      isCloud: cloud,
      cloudAudioId: _nullableInt(
        json['audio_id'] ??
            json['audioid'] ??
            json['mixsongid'] ??
            json['album_audio_id'] ??
            base['audio_id'],
      ),
      liked: liked,
    );
  }

  SearchCatalogItem? _catalogItem(Object? value, SearchCategory category) {
    final json = _map(value);
    final fields = switch (category) {
      SearchCategory.album => (
        id: _read(json, ['albumid', 'album_id']),
        title: _read(json, ['albumname', 'album_name']),
        subtitle: _read(json, [
          'singer',
          'author_name',
          'singername',
        ], fallback: '未知歌手'),
        image: _read(json, ['img', 'imgurl']),
        listId: _read(json, [
          'listid',
          'list_create_listid',
          'albumid',
          'album_id',
        ]),
        ownerId: _read(json, [
          'list_create_userid',
          'userid',
          'user_id',
          'singerid',
          'author_id',
          'authorid',
        ], fallback: '0'),
      ),
      SearchCategory.artist => (
        id: _read(json, ['AuthorId', 'authorid', 'singerid']),
        title: _read(json, ['AuthorName', 'authorname', 'singername']),
        subtitle: '${_toInt(json['AudioCount'] ?? json['songcount'])} 首歌曲',
        image: _read(json, ['Avatar', 'avatar', 'img']),
        listId: '',
        ownerId: '',
      ),
      SearchCategory.playlist => (
        id: _read(json, [
          'global_collection_id',
          'list_create_gid',
          'gid',
          'specialid',
        ]),
        title: _read(json, ['specialname', 'name', 'title']),
        subtitle: _read(json, [
          'nickname',
          'username',
          'intro',
        ], fallback: '${_toInt(json['songcount'] ?? json['song_count'])} 首歌曲'),
        image: _read(json, ['img', 'imgurl', 'sizable_cover', 'pic']),
        listId: _read(json, ['listid', 'list_create_listid', 'specialid']),
        ownerId: _read(
          json,
          ['list_create_userid', 'userid', 'user_id'],
          fallback: _ownerIdFromCollectionId(
            _read(json, [
              'global_collection_id',
              'list_create_gid',
              'gid',
              'specialid',
            ]),
          ),
        ),
      ),
      SearchCategory.song => (
        id: '',
        title: '',
        subtitle: '',
        image: '',
        listId: '',
        ownerId: '',
      ),
    };
    if (fields.id.isEmpty || fields.title.isEmpty) return null;
    return SearchCatalogItem(
      id: fields.id,
      title: fields.title,
      subtitle: fields.subtitle,
      category: category,
      imageUrl: fields.image.isEmpty
          ? null
          : fields.image.replaceAll('{size}', '240'),
      listId: fields.listId.isEmpty ? null : fields.listId,
      ownerId: fields.ownerId.isEmpty ? null : fields.ownerId,
    );
  }

  LyricCandidate? _lyricCandidate(Object? response) {
    final body = _map(response);
    final data = _map(body['data']);
    final candidates = <Object?>[
      ..._list(body['candidates']),
      ..._list(body['info']),
      ..._list(data['candidates']),
      ..._list(data['info']),
      if (body['id'] != null || body['accesskey'] != null) body,
      if (data['id'] != null || data['accesskey'] != null) data,
    ];
    for (final value in candidates) {
      final json = _map(value);
      final id = _read(json, ['id', 'download_id']);
      final accessKey = _read(json, ['accesskey', 'access_key']);
      if (id.isNotEmpty && accessKey.isNotEmpty) {
        return LyricCandidate(id: id, accessKey: accessKey);
      }
    }
    return null;
  }

  String _lyricContent(Object? response) {
    final body = _map(response);
    final data = _map(body['data']);
    final content = _read(body, [
      'decodeContent',
      'lyric',
    ], fallback: _read(data, ['decodeContent', 'lyric']));
    if (content.isNotEmpty) return _cleanLyricText(content);

    final encoded = _read(body, [
      'content',
    ], fallback: _read(data, ['content']));
    if (encoded.isEmpty) return '';
    try {
      final bytes = base64Decode(encoded);
      final contentType = _toInt(body['contenttype'] ?? data['contenttype']);
      return _cleanLyricText(
        contentType == 0 ? decodeKrcBytes(bytes) : utf8.decode(bytes),
      );
    } catch (_) {
      return '';
    }
  }

  KugouSession _mergeCookies(KugouSession current, List<String> setCookies) {
    final values = <String, String>{};
    for (final header in setCookies) {
      final first = header.split(';').first;
      final index = first.indexOf('=');
      if (index > 0) {
        values[first.substring(0, index)] = first.substring(index + 1);
      }
    }
    return current.copyWith(
      token: values['token'],
      userId: values['userid'],
      dfid: values['dfid'],
      mid: values['KUGOU_API_MID'],
      guid: values['KUGOU_API_GUID'],
      device: values['KUGOU_API_DEV'],
      mac: values['KUGOU_API_MAC'],
    );
  }
}

Dio _createDio(String _) {
  final dio = Dio(
    BaseOptions(
      baseUrl: '',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 15),
    ),
  );
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient();
      client.findProxy = (uri) {
        final value =
            Platform.environment['HTTPS_PROXY'] ??
            Platform.environment['https_proxy'] ??
            Platform.environment['HTTP_PROXY'] ??
            Platform.environment['http_proxy'] ??
            Platform.environment['ALL_PROXY'] ??
            Platform.environment['all_proxy'];
        if (value == null || value.isEmpty) return 'DIRECT';

        final proxy = Uri.tryParse(value);
        if (proxy?.host.isEmpty ?? true) return 'DIRECT';
        return 'PROXY ${proxy!.host}:${proxy.hasPort ? proxy.port : 80}';
      };
      return client;
    },
  );
  return dio;
}

Map<String, Object?> _map(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const {};
}

List<Object?> _list(Object? value) => value is List ? value : const [];

List<Object?> _findRecords(Object? value) {
  if (value is List) return value;
  if (value is Map) {
    for (final key in [
      'songs',
      'lists',
      'list',
      'info',
      'records',
      'items',
      'data',
    ]) {
      final nested = value[key];
      if (nested is List) return nested;
      final found = _findRecords(nested);
      if (found.isNotEmpty) return found;
    }
  }
  return const [];
}

int _toInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _nullableInt(Object? value) {
  final parsed = _toInt(value);
  return parsed == 0 ? null : parsed;
}

String _read(
  Map<String, Object?> json,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = json[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return fallback;
}

String _cleanLyricText(String value) {
  return value
      .replaceFirst('\uFEFF', '')
      .replaceAll('&apos;', "'")
      .replaceAll('&quot;', '"')
      .replaceAll('&amp;', '&')
      .trim();
}

String _todayString() {
  final now = DateTime.now();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${now.year}-${two(now.month)}-${two(now.day)}';
}

({String title, String artist}) _normalizeTitleAndArtist(
  String title,
  String artist,
  List<SongArtist> artists,
) {
  var normalizedTitle = title.trim();
  var normalizedArtist = artist.trim();
  final prefix = '$normalizedArtist - ';
  if (normalizedTitle.startsWith(prefix)) {
    normalizedTitle = normalizedTitle.substring(prefix.length).trim();
  }

  final dashIndex = normalizedTitle.indexOf(' - ');
  if (dashIndex > 0) {
    final possibleArtists = normalizedTitle.substring(0, dashIndex).trim();
    final pureTitle = normalizedTitle.substring(dashIndex + 3).trim();
    final names = _splitArtists(possibleArtists);
    final currentNames = artists.isEmpty
        ? _splitArtists(normalizedArtist)
        : artists;
    final containsKnown = currentNames.any(
      (item) => possibleArtists.contains(item.name),
    );
    if (names.length > 1 || containsKnown || normalizedArtist.isEmpty) {
      normalizedArtist = _artistJoin(names);
      normalizedTitle = pureTitle;
    }
  }

  if (artists.length > 1) normalizedArtist = _artistJoin(artists);
  return (title: normalizedTitle, artist: normalizedArtist);
}

List<SongArtist> _extractArtists(
  Map<String, Object?> json, {
  required String fallbackName,
}) {
  final result = <SongArtist>[];

  void add(String name, Object? id) {
    final cleanName = _cleanArtistName(name);
    if (!_isUsefulArtistName(cleanName)) return;
    if (result.any((item) => item.name == cleanName)) return;
    result.add(SongArtist(name: cleanName, id: _nullableInt(id)));
  }

  for (final source in [
    json['authors'],
    json['author'],
    json['singers'],
    json['singerinfo'],
    _map(json['base'])['authors'],
  ]) {
    if (source is List) {
      for (final item in source) {
        final map = _map(item);
        add(
          _read(map, [
            'name',
            'author_name',
            'authorname',
            'AuthorName',
            'singername',
            'SingerName',
          ]),
          map['author_id'] ?? map['authorid'] ?? map['singerid'] ?? map['id'],
        );
      }
    } else if (source is Map) {
      final map = _map(source);
      add(
        _read(map, [
          'name',
          'author_name',
          'authorname',
          'AuthorName',
          'singername',
          'SingerName',
        ]),
        map['author_id'] ?? map['authorid'] ?? map['singerid'] ?? map['id'],
      );
    }
  }

  if (result.isEmpty) return _splitArtists(fallbackName);
  return result;
}

List<SongArtist> _splitArtists(String value) {
  final normalized = value
      .replaceAll('、', '/')
      .replaceAll('，', '/')
      .replaceAll(',', '/')
      .replaceAll('&', '/')
      .replaceAll(RegExp(r'\s+feat\.?\s+', caseSensitive: false), '/')
      .replaceAll(RegExp(r'\s+ft\.?\s+', caseSensitive: false), '/');
  final seen = <String>{};
  return [
    for (final part in normalized.split('/'))
      if (_isUsefulArtistName(part) && seen.add(part.trim()))
        SongArtist(name: part.trim()),
  ];
}

bool _isUsefulArtistName(String value) {
  final text = _cleanArtistName(value);
  if (text.isEmpty) return false;
  if (!RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(text)) return false;
  final lower = text.toLowerCase();
  return lower != '未知歌手' &&
      lower != 'unknown' &&
      lower != 'unknown artist' &&
      lower != 'null';
}

String _cleanArtistName(String value) {
  return value.replaceAll(RegExp(r'^[\s/\\|,，、]+|[\s/\\|,，、]+$'), '').trim();
}

List<SongArtist> _displayArtists(String artist, List<SongArtist> extracted) {
  final display = _splitArtists(artist);
  if (display.length <= extracted.length && extracted.isNotEmpty) {
    return extracted;
  }
  return [
    for (final item in display)
      SongArtist(
        name: item.name,
        id: extracted
            .cast<SongArtist?>()
            .firstWhere(
              (candidate) => candidate?.name == item.name,
              orElse: () => null,
            )
            ?.id,
      ),
  ];
}

String _artistJoin(List<SongArtist> artists) => artists
    .map((item) => item.name)
    .where((name) => name.isNotEmpty)
    .join(' / ');

String _coverFromTransParam(Object? value) {
  final text = value?.toString() ?? '';
  if (text.isEmpty) return '';
  final match = RegExp(r'union_cover=([^;}\s]+)').firstMatch(text);
  return match?.group(1) ?? '';
}

String? _findAudioUrl(Object? value, {bool allowString = false}) {
  if (value is Map) {
    const preferredKeys = [
      'play_url',
      'playUrl',
      'url',
      'backup_url',
      'backupUrl',
    ];
    for (final key in preferredKeys) {
      final found = _findAudioUrl(value[key], allowString: true);
      if (found != null) return found;
    }
    for (final entry in value.entries) {
      if (preferredKeys.contains(entry.key)) continue;
      final found = _findAudioUrl(entry.value);
      if (found != null) return found;
    }
  } else if (value is List) {
    for (final item in value) {
      final found = _findAudioUrl(item, allowString: allowString);
      if (found != null) return found;
    }
  } else if (allowString &&
      value is String &&
      value.startsWith('http') &&
      !RegExp(
        r'\.(jpg|jpeg|png|webp)(\?|$)',
        caseSensitive: false,
      ).hasMatch(value)) {
    return value;
  }
  return null;
}

List<_PlaybackCandidate> _findRelateGoods(Object? value) {
  final goods = <_PlaybackCandidate>[];

  void visit(Object? item) {
    if (item is List) {
      for (final child in item) {
        visit(child);
      }
      return;
    }
    if (item is! Map) return;
    final json = _map(item);
    final hash = _read(json, ['hash', 'Hash', 'file_hash']);
    if (hash.isNotEmpty) {
      goods.add(
        _PlaybackCandidate(
          hash: hash,
          quality: _normalizedQuality(json['quality'] ?? json['level']),
        ),
      );
    }
    final relateGoods = json['relate_goods'] ?? json['relateGoods'];
    if (relateGoods != null) visit(relateGoods);
  }

  visit(value);
  final seen = <String>{};
  return goods.where((item) => seen.add(item.hash.toLowerCase())).toList();
}

List<String> _findPortraitUrls(Object? value) {
  final body = _map(value);
  final groups = _list(body['data']);
  const priorities = ['3', '4', '2'];
  for (final priority in priorities) {
    final urls = <String>{};
    void visit(Object? node) {
      if (node is List) {
        for (final child in node) {
          visit(child);
        }
        return;
      }
      if (node is! Map) return;
      final json = _map(node);
      final imgs = _map(json['imgs']);
      final portraits = _list(imgs[priority]);
      for (final portrait in portraits) {
        final url = _read(_map(portrait), [
          'sizable_portrait',
          'portrait',
          'url',
        ]).replaceFirst('http://', 'https://');
        if (url.isNotEmpty) urls.add(url);
      }
      for (final child in json.values) {
        visit(child);
      }
    }

    visit(groups);
    if (urls.isNotEmpty) return urls.toList(growable: false);
  }
  return const [];
}

String _normalizedQuality(Object? value) {
  final raw = value?.toString().trim().toLowerCase() ?? '';
  return switch (raw) {
    '0' || '1' || '128' || 'standard' => '128',
    '2' || '320' || 'highquality' => '320',
    '3' || 'flac' || 'lossless' || 'sq' => 'flac',
    '6' || 'hires' || 'hi-res' || 'high' || 'hr' => 'high',
    '7' || 'super' || 'dsd' || 'premium' => 'super',
    _ => raw,
  };
}

bool _isSameSong(Song source, Song target) {
  final sourceHash = source.hash?.toLowerCase() ?? '';
  final targetHash = target.hash?.toLowerCase() ?? '';
  if (sourceHash.isNotEmpty && sourceHash == targetHash) return true;

  final sourceTitle = _normalizeSongText(source.title);
  final targetTitle = _normalizeSongText(target.title);
  if (sourceTitle.isEmpty || sourceTitle != targetTitle) return false;

  final sourceArtist = _normalizeArtistText(source.artist);
  final targetArtist = _normalizeArtistText(target.artist);
  if (sourceArtist.isNotEmpty && targetArtist.isNotEmpty) {
    return sourceArtist == targetArtist ||
        sourceArtist.contains(targetArtist) ||
        targetArtist.contains(sourceArtist);
  }

  final sourceAlbum = _normalizeSongText(source.album);
  final targetAlbum = _normalizeSongText(target.album);
  return sourceAlbum.isNotEmpty && sourceAlbum == targetAlbum;
}

bool _isReplacementCandidate(Song source, Song target) {
  final sourceHash = source.hash?.toLowerCase() ?? '';
  final targetHash = target.hash?.toLowerCase() ?? '';
  if (targetHash.isEmpty || sourceHash == targetHash) return false;

  final sourceTitle = _normalizeSongText(source.title);
  final targetTitle = _normalizeSongText(target.title);
  if (sourceTitle.isEmpty || sourceTitle != targetTitle) return false;

  final sourceArtists = _normalizedArtistSet(source);
  final targetArtists = _normalizedArtistSet(target);
  if (sourceArtists.isEmpty || targetArtists.isEmpty) return false;
  return sourceArtists.intersection(targetArtists).isNotEmpty ||
      sourceArtists.any((sourceArtist) {
        return targetArtists.any(
          (targetArtist) =>
              sourceArtist.contains(targetArtist) ||
              targetArtist.contains(sourceArtist),
        );
      });
}

String _normalizeSongText(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'\.(mp3|m4a|flac|wav|aac)$'), '')
      .replaceAll(RegExp(r'[\s《》〈〉「」『』【】\[\]（）()_-]+'), '')
      .trim();
}

Set<String> _normalizedArtistSet(Song song) {
  final values = <String>[
    song.artist,
    for (final artist in song.artists) artist.name,
  ];
  final result = <String>{};
  for (final value in values) {
    for (final part in value.split(RegExp(r'(、|,|，|/|&|;|；)'))) {
      final normalized = _normalizeArtistText(part);
      if (normalized.isNotEmpty) result.add(normalized);
    }
  }
  return result;
}

String _normalizeArtistText(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll(RegExp(r'(、|,|，|/|&|feat\.?|ft\.?).*'), '')
      .trim();
}

String _ownerIdFromCollectionId(String value) {
  final parts = value.split('_');
  if (parts.length >= 4 && parts.first == 'collection') return parts[2];
  return '';
}

bool _isFavoriteSongsPlaylistName(String value) {
  final name = value.replaceAll(RegExp(r'\s+'), '').trim();
  return name == '我喜欢' || name == '我喜欢的音乐';
}

String _albumIdFromPlaylist(MusicPlaylist playlist) {
  final sourceList = playlist.sourceListId ?? '';
  final directSourceList = int.tryParse(sourceList);
  if (directSourceList != null && directSourceList > 0) return sourceList;
  final source = playlist.sourceId ?? '';
  final directSource = int.tryParse(source);
  if (directSource != null && directSource > 0) return source;
  final sourceParts = source.split('_');
  if (sourceParts.length >= 4 && sourceParts.first == 'collection') {
    return sourceParts[3];
  }
  final direct = int.tryParse(playlist.id);
  if (direct != null && direct > 0) return playlist.id;
  final list = int.tryParse(playlist.listId);
  if (list != null && list > 0) return playlist.listId;
  final parts = playlist.id.split('_');
  if (parts.length >= 4 && parts.first == 'collection') return parts[3];
  return '';
}
