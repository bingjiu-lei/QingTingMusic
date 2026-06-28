import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../models/kugou_session.dart';
import '../models/music_playlist.dart';
import '../models/search_catalog_item.dart';
import '../models/song.dart';
import 'api_endpoint_service.dart';
import 'kugou_official_client.dart';
import 'secure_session_storage.dart';

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

class KugouApiClient {
  KugouApiClient({
    Dio? dio,
    SecureSessionStorage? storage,
    ApiEndpointService? endpointService,
  }) : _dio = dio ?? _createDio(''),
       _storage = storage ?? SecureSessionStorage(),
       _endpointService = endpointService ?? ApiEndpointService(),
       _officialClient = KugouOfficialClient();

  final Dio _dio;
  final SecureSessionStorage _storage;
  final ApiEndpointService _endpointService;
  final KugouOfficialClient _officialClient;

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
      throw const KugouApiException('登录成功，但未获得有效凭证');
    }

    session = _mergeCookies(
      session.copyWith(
        token: token,
        userId: userId,
        nickname: (data['nickname'] ?? data['username'] ?? '').toString(),
      ),
      response.headers.map['set-cookie'] ?? const [],
    );
    if (await _usesOfficialApi()) {
      await registerDevice();
    }
    await _storage.save(session);
    return KugouQrCheckResult(status: status, session: session);
  }

  Future<void> logout() async {
    session = session.loggedOut();
    await _storage.save(session);
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
    final path = switch (item.category) {
      SearchCategory.album => '/album/songs',
      SearchCategory.artist => '/artist/audios',
      SearchCategory.song => throw const KugouApiException('不支持的详情类型'),
    };
    final response = await _get(
      path,
      authenticated: true,
      queryParameters: {'id': item.id, 'page': 1, 'pagesize': 100},
    );
    return _parseSongCollection(response.data);
  }

  Future<List<SearchCatalogItem>> getArtistAlbums(
    SearchCatalogItem artist,
  ) async {
    final response = await _get(
      '/artist/albums',
      authenticated: true,
      queryParameters: {'id': artist.id, 'page': 1, 'pagesize': 100},
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
    return playlists.values.toList();
  }

  MusicPlaylist? _playlistFromJson(Object? value) {
    final json = _map(value);
    final image = _read(json, ['pic', 'img', 'sizable_cover']);
    final source = _toInt(json['source']);
    final ownerId = _read(json, ['list_create_userid', 'userid', 'user_id']);
    final isMine =
        ownerId.isNotEmpty && ownerId == session.userId ||
        _toInt(json['is_mine']) == 1;
    final isDefault = _toInt(json['is_def'] ?? json['is_default']) > 0;
    final playlist = MusicPlaylist(
      id: _read(json, [
        'global_collection_id',
        'list_create_gid',
        'gid',
        'specialid',
      ]),
      listId: _read(json, ['listid', 'list_create_listid', 'specialid']),
      name: _read(json, ['name'], fallback: '未命名歌单'),
      songCount: _toInt(json['m_count'] ?? json['song_count']),
      coverUrl: image.isEmpty ? null : image.replaceAll('{size}', '240'),
      isDefault: isDefault,
      isMine: isMine,
      kind: isDefault
          ? MusicPlaylistKind.favoriteSongs
          : source == 2
          ? MusicPlaylistKind.album
          : isMine
          ? MusicPlaylistKind.createdPlaylist
          : MusicPlaylistKind.collectedPlaylist,
    );
    if (playlist.id.isEmpty && playlist.listId.isEmpty) return null;
    return playlist;
  }

  Future<List<Song>> getPlaylistSongs(MusicPlaylist playlist) async {
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
              liked: playlist.isDefault,
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

    final directUrl = await _resolveSongUrl(song);
    if (directUrl != null) return song.copyWith(audioUrl: directUrl);

    if (!song.isCloud) {
      final candidates = await _resolvePrivilegeCandidates(song);
      for (final candidate in candidates) {
        if (candidate.hash.toLowerCase() == song.hash!.toLowerCase()) continue;
        final candidateUrl = await _resolveSongUrl(
          song,
          hash: candidate.hash,
          quality: candidate.quality,
        );
        if (candidateUrl != null) {
          return song.copyWith(audioUrl: candidateUrl);
        }
      }

      final cloudMatch = await _findMatchingCloudSong(song);
      if (cloudMatch != null) {
        final cloudUrl = await _resolveSongUrl(cloudMatch);
        if (cloudUrl != null) {
          return song.copyWith(audioUrl: cloudUrl, playbackNotice: '已切换云盘版本');
        }
      }
    }

    throw const KugouApiException('该歌曲无版权或需付费');
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
      return _findRelateGoods(response.data);
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
      if (authenticated && errorCode == 152) {
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
  }) async {
    final result = await _officialClient.request(
      path,
      queryParameters: queryParameters ?? const {},
      method: method,
      session: session,
      bypassCache: bypassCache,
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
    if (errorCode == 152 || errorCode == 20017) {
      throw const AuthenticationRequiredException();
    }
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

  Song? _songFromCollection(
    Object? value, {
    required bool liked,
    required bool cloud,
  }) {
    final json = _map(value);
    final base = _map(json['base']);
    final audio = _map(json['audio_info']);
    final albumInfo = _map(json['album_info'] ?? json['albuminfo']);
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
          json['duration'] ??
          audio['duration'] ??
          audio['duration_128'],
    );
    if (duration > 10000) duration ~/= 1000;

    return Song(
      id: identity,
      title: title,
      artist: artist,
      album: _read(json, [
        'album_name',
        'AlbumName',
      ], fallback: _read(albumInfo, ['album_name', 'name'], fallback: '未知专辑')),
      duration: Duration(seconds: duration),
      audioUrl: '',
      hash: hash.isEmpty ? null : hash,
      albumId: _nullableInt(
        json['album_id'] ??
            json['albumid'] ??
            json['albumId'] ??
            base['album_id'] ??
            albumInfo['album_id'] ??
            albumInfo['id'],
      ),
      albumAudioId: _nullableInt(
        json['mixsongid'] ?? json['album_audio_id'] ?? base['album_audio_id'],
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
      ),
      SearchCategory.artist => (
        id: _read(json, ['AuthorId', 'authorid', 'singerid']),
        title: _read(json, ['AuthorName', 'authorname', 'singername']),
        subtitle: '${_toInt(json['AudioCount'] ?? json['songcount'])} 首歌曲',
        image: _read(json, ['Avatar', 'avatar', 'img']),
      ),
      SearchCategory.song => (id: '', title: '', subtitle: '', image: ''),
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
    );
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

String _coverFromTransParam(Object? value) {
  final text = value?.toString() ?? '';
  if (text.isEmpty) return '';
  final match = RegExp(r'union_cover=([^;}\s]+)').firstMatch(text);
  return match?.group(1) ?? '';
}

String? _findAudioUrl(Object? value) {
  if (value is Map) {
    const preferredKeys = [
      'play_url',
      'playUrl',
      'url',
      'backup_url',
      'backupUrl',
    ];
    for (final key in preferredKeys) {
      final found = _findAudioUrl(value[key]);
      if (found != null) return found;
    }
    for (final entry in value.entries) {
      if (preferredKeys.contains(entry.key)) continue;
      final found = _findAudioUrl(entry.value);
      if (found != null) return found;
    }
  } else if (value is List) {
    for (final item in value) {
      final found = _findAudioUrl(item);
      if (found != null) return found;
    }
  } else if (value is String &&
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
          quality: json['quality'] ?? json['level'],
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

String _normalizeSongText(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'\.(mp3|m4a|flac|wav|aac)$'), '')
      .replaceAll(RegExp(r'[\s《》〈〉「」『』【】\[\]（）()_-]+'), '')
      .trim();
}

String _normalizeArtistText(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll(RegExp(r'(、|,|，|/|&|feat\.?|ft\.?).*'), '')
      .trim();
}
