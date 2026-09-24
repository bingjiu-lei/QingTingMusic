import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/export.dart' hide State;

import '../models/kugou_session.dart';

class KugouOfficialException implements Exception {
  const KugouOfficialException(this.message);
  final String message;

  @override
  String toString() => message;
}

class KugouOfficialClient {
  KugouOfficialClient({Dio? dio}) : _dio = dio ?? _createDio();

  static const appid = 1005;
  static const clientver = 20489;
  static const liteAppid = 3116;
  static const liteClientver = 11440;
  static const srcappid = 2919;
  static const _androidSalt = 'LnT6xpN3khm36zse0QzvmgTZ3waWdRSA';
  static const _webSalt = 'NVPh5oo715z5DIWAeQlhMDsWXXQV4hwt';
  static const _liteSignKeySalt = '185672dd44712f60bb1736df5a377e82';
  static const _standardSignKeySalt = '57ae12eb6890223e355ccfcb74edf70d';
  static const _cloudKeySalt = 'ebd1ac3134c880bda6a2194537843caa0162e2e7';
  static const _standardParamKeySalt = 'OIlwieks28dk2k092lksi2UIkp';
  static const _liteLoginT2Key = 'fd14b35e3f81af3817a20ae7adae7020';
  static const _liteLoginT2Iv = '17a20ae7adae7020';
  static const _liteLoginT1Key = '5e4ef500e9597fe004bd09a46d8add98';
  static const _liteLoginT1Iv = '04bd09a46d8add98';
  static const _publicLiteRsaKey = '''
-----BEGIN PUBLIC KEY-----
MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDECi0Np2UR87scwrvTr72L6oO01rBbbBPriSDFPxr3Z5syug0O24QyQO8bg27+0+4kBzTBTBOZ/WWU0WryL1JSXRTXLgFVxtzIY41Pe7lPOgsfTCn5kZcvKhYKJesKnnJDNr5/abvTGf+rHG3YRwsCHcQ08/q6ifSioBszvb3QiwIDAQAB
-----END PUBLIC KEY-----
''';
  // ignore: unused_field
  static const _publicRsaKey = '''
-----BEGIN PUBLIC KEY-----
MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDIAG7QOELSYoIJvTFJhMpe1s/gbjDJX51HBNnEl5HXqTW6lQ7LC8jr9fWZTwusknp+sVGzwd40MwP6U5yDE27M/X1+UR4tvOGOqp94TJtQ1EPnWGWXngpeIW5GxoQGao1rmYWAu6oi1z9XkChrsUdC6DJE5E221wf/4WLFxwAtRQIDAQAB
-----END PUBLIC KEY-----
''';

  final Dio _dio;
  static final _random = Random.secure();

  static String randomGuid() => _md5Static(_guid());

  static String randomMid() => _calculateMid(randomGuid());

  static String midFromGuid(String guid) => _calculateMid(guid);

  static String randomDeviceId() => _randomString(24);

  static String randomMac() {
    return List.generate(
      6,
      (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join(':');
  }

  Future<Map<String, Object?>> request(
    String path, {
    Map<String, Object?> queryParameters = const {},
    String method = 'GET',
    KugouSession session = const KugouSession(),
    bool bypassCache = false,
    Object? data,
  }) async {
    final request = _buildRequest(path, queryParameters, method, session, data);
    final response = await _dio.request<Object?>(
      request.path,
      data: request.data,
      queryParameters: request.params,
      options: Options(
        method: request.method,
        headers: {
          ...request.headers,
          if (bypassCache) 'Cache-Control': 'no-cache, no-store',
          if (bypassCache) 'Pragma': 'no-cache',
        },
        responseType: request.responseType,
        extra: {'baseUrl': request.baseUrl},
      ),
    );
    final decoded = _decodeBody(response.data, decryptKey: request.decryptKey);
    return {
      'statusCode': response.statusCode,
      'data': _decodeLoginBody(decoded, request.loginDecryptKey),
      'setCookie': response.headers.map['set-cookie'] ?? const <String>[],
    };
  }

  Object? _decodeLoginBody(Object? data, String? loginDecryptKey) {
    if (loginDecryptKey == null || data is! Map) return data;
    final body = Map<String, Object?>.from(data.cast<String, Object?>());
    final rawData = body['data'];
    if (rawData is! Map) return body;
    final loginData = Map<String, Object?>.from(
      rawData.cast<String, Object?>(),
    );
    final secuParams = loginData['secu_params']?.toString() ?? '';
    if (secuParams.isEmpty) return body;
    final decrypted = _loginAesDecrypt(secuParams, loginDecryptKey);
    if (decrypted is Map) {
      loginData.addAll(decrypted.cast<String, Object?>());
    } else if (decrypted is String && decrypted.isNotEmpty) {
      loginData['token'] = decrypted;
    }
    body['data'] = loginData;
    return body;
  }

  Object? _decodeBody(Object? data, {String? decryptKey}) {
    if (decryptKey != null && data is List<int>) {
      try {
        return _playlistAesDecrypt(base64Encode(data), decryptKey);
      } catch (_) {
        final text = utf8.decode(data, allowMalformed: true).trim();
        if (text.startsWith('{') || text.startsWith('[')) {
          try {
            return jsonDecode(text);
          } catch (_) {
            return text;
          }
        }
        return text;
      }
    }
    if (data is String) {
      final text = data.trim();
      if (text.startsWith('{') || text.startsWith('[')) {
        try {
          return jsonDecode(text);
        } catch (_) {
          return data;
        }
      }
    }
    return data;
  }

  _OfficialRequest _buildRequest(
    String path,
    Map<String, Object?> input,
    String method,
    KugouSession session,
    Object? data,
  ) {
    final params = Map<String, Object?>.from(input);
    final cookie = _cookie(session);
    final fmClienttime = DateTime.now().millisecondsSinceEpoch;
    final body = data is Map
        ? Map<String, Object?>.from(data.cast<Object?, Object?>())
        : const <String, Object?>{};

    return switch (path) {
      '/login/qr/key' => _web('https://login-user.kugou.com', '/v2/qrcode', {
        'appid': 1001,
        'type': 1,
        'plat': 4,
        'qrcode_txt':
            'https://h5.kugou.com/apps/loginQRCode/html/index.html?appid=$liteAppid&',
        'srcappid': srcappid,
      }, cookie),
      '/login/qr/check' => _web(
        'https://login-user.kugou.com',
        '/v2/get_userinfo_qrcode',
        {
          'plat': 4,
          'appid': liteAppid,
          'srcappid': srcappid,
          'qrcode': params['key'] ?? '',
        },
        cookie,
      ),
      '/captcha/sent' => _sendSmsCode(params, cookie),
      '/login/cellphone' => _loginByCellphone(params, cookie),
      '/register/dev' => _registerDevice(params, cookie),
      '/search/suggest' => _android(
        '/v2/getSearchTip',
        {
          'keyword': params['keywords'] ?? '',
          'AlbumTipCount': 10,
          'CorrectTipCount': 10,
          'MVTipCount': 10,
          'MusicTipCount': 10,
          'radiotip': 1,
        },
        cookie,
        headers: {'x-router': 'searchtip.kugou.com'},
      ),
      '/search' => _search(params, cookie),
      '/search/lyric' => _android(
        '/search',
        {
          'ver': 1,
          'client': 'pc',
          'duration': params['duration'] ?? 0,
          'hash': params['hash'] ?? '',
          'keyword': params['keywords'] ?? params['keyword'] ?? '',
          'man': params['man'] ?? 'no',
        },
        cookie,
        baseUrl: 'http://lyrics.kugou.com',
        clearDefaultParams: true,
        notSignature: true,
      ),
      '/lyric' => _android(
        '/download',
        {
          'ver': 1,
          'client': 'android',
          'id': params['id'] ?? '',
          'accesskey': params['accesskey'] ?? '',
          'fmt': params['fmt'] ?? 'lrc',
          'charset': 'utf8',
        },
        cookie,
        baseUrl: 'https://lyrics.kugou.com',
      ),
      '/images/audio' => _android(
        '/v2/author_image/audio',
        {
          'appid': liteAppid,
          'clientver': liteClientver,
          'count': params['count'] ?? 5,
          'data': jsonEncode([
            {
              'audio_id': params['audio_id'] ?? 0,
              'hash': params['hash'] ?? '',
              'album_audio_id': params['album_audio_id'] ?? 0,
              'filename': params['filename'] ?? '',
            },
          ]),
          'isCdn': 1,
          'publish_time': 1,
          'show_authors': 1,
        },
        cookie,
        baseUrl: 'https://expendablekmr.kugou.com',
        clearDefaultParams: true,
      ),
      '/song/url' => _songUrl(params, cookie),
      '/privilege/lite' => _privilegeLite(params, cookie),
      '/playlist/tracks/add' => _playlistTracksAdd(params, cookie),
      '/playlist/tracks/del' => _playlistTracksDel(params, cookie),
      '/playlist/add' => _playlistAdd(params, cookie),
      '/playlist/del' => _playlistDel(params, cookie),
      '/artist/follow' => _artistFollow(params, cookie, follow: true),
      '/artist/unfollow' => _artistFollow(params, cookie, follow: false),
      '/mv/collect' => _mvCollect(params, cookie, collect: true),
      '/mv/collect/del' => _mvCollect(params, cookie, collect: false),
      '/user/cloud' => _cloudSongs(params, cookie),
      '/user/cloud/del' => _cloudSongsDel(params, cookie),
      '/user/cloud/url' => _cloudSongUrl(params, cookie),
      '/user/video/collect' => _userVideoCollect(params, cookie),
      '/user/follow' => _userFollow(cookie),
      '/recommend/daily' => _android(
        '/everyday_song_recommend',
        {},
        cookie,
        method: 'POST',
        data: {
          'platform': 'android',
          'userid': session.userId.isEmpty ? 0 : session.userId,
        },
        headers: {'x-router': 'everydayrec.service.kugou.com'},
      ),
      '/recommend/fm' => _android(
        '/v2/personal_recommend',
        {},
        cookie,
        method: 'POST',
        data: {
          'appid': liteAppid,
          'clientver': liteClientver,
          'clienttime': fmClienttime,
          'mid': cookie['KUGOU_API_MID'] ?? session.mid,
          'action': body['action'] ?? 'play',
          'recommend_source_locked': 0,
          'is_overplay': body['is_overplay'] ?? 0,
          'remain_songcnt': body['remain_songcnt'] ?? 0,
          'mode': body['mode'] ?? 'normal',
          'song_pool_id': body['song_pool_id'] ?? 0,
          'callerid': 0,
          'm_type': 1,
          'platform': 'android',
          'area_code': 1,
          'fakem': 'ca981cfc583a4c37f28d2d49000013c16a0a',
          'key': _signParamsKey(
            fmClienttime.toString(),
            appId: liteAppid,
            clientVersion: liteClientver,
          ),
          if (session.userId.isNotEmpty) 'userid': session.userId,
          if (session.userId.isNotEmpty) 'kguid': session.userId,
          if (session.token.isNotEmpty) 'token': session.token,
          'vip_type': 0,
          if ((body['hash']?.toString() ?? '').isNotEmpty) 'hash': body['hash'],
          if ((body['songid']?.toString() ?? '').isNotEmpty)
            'songid': body['songid'],
          if ((body['playtime'] as int? ?? 0) > 0) 'playtime': body['playtime'],
        },
        headers: {'x-router': 'persnfm.service.kugou.com'},
      ),
      '/playlist/public/track/all' =>
        _android('/pubsongs/v2/get_other_list_file_nofilt', {
          'area_code': 1,
          'begin_idx':
              (_toInt(params['page'], fallback: 1) - 1) *
              _toInt(params['pagesize'], fallback: 100),
          'plat': 1,
          'type': 1,
          'mode': 1,
          'personal_switch': 1,
          'extend_fields': 'abtags,hot_cmt,popularization',
          'pagesize': params['pagesize'] ?? 100,
          'global_collection_id': params['id'] ?? params['listid'] ?? '',
        }, cookie),
      '/playlist/track/all' => _android(
        '/v4/get_list_all_file',
        {},
        cookie,
        method: 'POST',
        data: {
          'listid': params['listid'] ?? params['id'] ?? '',
          'userid': cookie['userid'] ?? params['userid'] ?? '0',
          'area_code': 1,
          'show_relate_goods': 0,
          'pagesize': params['pagesize'] ?? 200,
          'allplatform': 1,
          'show_cover': 1,
          'type': 0,
          'token': cookie['token'] ?? params['token'] ?? '',
          'page': params['page'] ?? 1,
        },
        headers: {'x-router': 'cloudlist.service.kugou.com'},
      ),
      '/album/songs' => _android(
        '/v1/album_audio/lite',
        {},
        cookie,
        method: 'POST',
        data: {
          'album_id': params['id'] ?? '',
          'is_buy': params['is_buy'] ?? '',
          'page': params['page'] ?? 1,
          'pagesize': params['pagesize'] ?? 100,
        },
        headers: {'x-router': 'openapi.kugou.com', 'kg-tid': '255'},
      ),
      '/album/detail' => _android(
        '/kmr/v2/albums',
        {},
        cookie,
        method: 'POST',
        data: {
          'data': [
            {'album_id': params['id'] ?? ''},
          ],
          'is_buy': 0,
          'fields':
              'album_id,album_name,publish_date,sizable_cover,intro,language,is_publish,heat,type,quality,authors,exclusive,author_name,trans_param',
        },
        headers: {'x-router': 'openapi.kugou.com', 'kg-tid': '255'},
      ),
      '/song/climax' => _android(
        '/v1/audio_climax/audio',
        {
          'data': jsonEncode([
            {'hash': params['hash'] ?? ''},
          ]),
        },
        cookie,
        baseUrl: 'https://expendablekmrcdn.kugou.com',
      ),
      '/artist/audios' => _public('/api/v3/singer/song', {
        'singerid': params['id'] ?? '',
        'page': params['page'] ?? 1,
        'pagesize': params['pagesize'] ?? 100,
      }),
      '/artist/albums' => _public('/api/v3/singer/album', {
        'singerid': params['id'] ?? '',
        'page': params['page'] ?? 1,
        'pagesize': params['pagesize'] ?? 100,
        'sort': params['sort'] ?? 'new',
      }),
      '/artist/videos' => _android(
        '/kmr/v1/author/videos',
        {
          'author_id': params['id'] ?? params['author_id'] ?? '',
          'is_fanmade': '',
          'tag_idx': params['tag_idx'] ?? '',
          'page': params['page'] ?? 1,
          'pagesize': params['pagesize'] ?? 30,
        },
        cookie,
        baseUrl: 'https://openapicdn.kugou.com',
      ),
      '/audio/mv' => _android(
        '/kmr/v1/audio/mv',
        {},
        cookie,
        method: 'POST',
        data: {
          'data': [
            {'album_audio_id': params['album_audio_id'] ?? ''},
          ],
          'fields': params['fields'] ?? '',
        },
        headers: {'x-router': 'openapi.kugou.com', 'kg-tid': '38'},
      ),
      '/artist/similar' => _similarArtists(body, cookie),
      '/user/playlist' => _android(
        '/v7/get_all_list',
        {
          'plat': 1,
          'userid': session.userId.isEmpty ? 0 : session.userId,
          'token': session.token,
        },
        cookie,
        method: 'POST',
        data: {
          'userid': session.userId.isEmpty ? 0 : session.userId,
          'token': session.token,
          'total_ver': 979,
          'type': 2,
          'page': params['page'] ?? 1,
          'pagesize': params['pagesize'] ?? 100,
        },
        headers: {'x-router': 'cloudlist.service.kugou.com'},
      ),
      '/youth/day/vip' => _android(
        '/youth/v1/recharge/receive_vip_listen_song',
        {'source_id': 90139, 'receive_day': params['receive_day'] ?? ''},
        cookie,
        method: 'POST',
        headers: {'content-type': 'application/x-www-form-urlencoded'},
      ),
      '/youth/day/vip/upgrade' => _android(
        '/youth/v1/listen_song/upgrade_vip_reward',
        {'kugouid': _toInt(cookie['userid'] ?? params['userid']), 'ad_type': 1},
        cookie,
        method: 'POST',
      ),
      '/youth/month/vip/record' => _android(
        '/youth/v1/activity/get_month_vip_record',
        {'latest_limit': 100},
        cookie,
      ),
      '/video/url' => _android(
        '/v2/interface/index',
        {
          'backupdomain': 1,
          'cmd': 123,
          'ext': params['ext'] ?? 'mp4',
          'ismp3': params['ismp3'] ?? 0,
          'hash': params['hash'] ?? '',
          'pid': 1,
          'type': 1,
        },
        cookie,
        encryptKey: true,
        headers: {'x-router': 'trackermv.kugou.com'},
      ),
      '/video/detail' => _videoDetail(params, cookie),
      _ => _android(path, params, cookie, method: method),
    };
  }

  _OfficialRequest _registerDevice(
    Map<String, Object?> params,
    Map<String, String> cookie,
  ) {
    final aes = _playlistAesEncrypt({
      'availableRamSize': 4983533568,
      'availableRomSize': 48114719,
      'availableSDSize': 48114717,
      'basebandVer': '',
      'batteryLevel': 100,
      'batteryStatus': 3,
      'brand': 'Redmi',
      'buildSerial': 'unknown',
      'device': 'marble',
      'imei': cookie['KUGOU_API_GUID'] ?? randomGuid(),
      'imsi': '',
      'manufacturer': 'Xiaomi',
      'uuid': cookie['KUGOU_API_GUID'] ?? randomGuid(),
      'accelerometer': false,
      'accelerometerValue': '',
      'gravity': false,
      'gravityValue': '',
      'gyroscope': false,
      'gyroscopeValue': '',
      'light': false,
      'lightValue': '',
      'magnetic': false,
      'magneticValue': '',
      'orientation': false,
      'orientationValue': '',
      'pressure': false,
      'pressureValue': '',
      'step_counter': false,
      'step_counterValue': '',
      'temperature': false,
      'temperatureValue': '',
    });
    final p = _rsaEncrypt2({
      'aes': aes.key,
      'uid': params['userid'] ?? cookie['userid'] ?? 0,
      'token': params['token'] ?? cookie['token'] ?? '',
    });
    return _android(
      '/risk/v2/r_register_dev',
      {'part': 1, 'platid': 1, 'p': p},
      cookie,
      baseUrl: 'https://userservice.kugou.com',
      method: 'POST',
      data: aes.data,
      appId: liteAppid,
      clientVersion: liteClientver,
      responseType: ResponseType.bytes,
      decryptKey: aes.key,
    );
  }

  _OfficialRequest _sendSmsCode(
    Map<String, Object?> params,
    Map<String, String> cookie,
  ) {
    return _android(
      '/v7/send_mobile_code',
      {},
      cookie,
      baseUrl: 'http://login.user.kugou.com',
      method: 'POST',
      data: {'businessid': 5, 'mobile': params['mobile'] ?? '', 'plat': 3},
    );
  }

  _OfficialRequest _loginByCellphone(
    Map<String, Object?> params,
    Map<String, String> cookie,
  ) {
    final dateTime = DateTime.now().millisecondsSinceEpoch;
    final encrypt = _loginAesEncrypt({
      'mobile': params['mobile'] ?? '',
      'code': params['code'] ?? '',
    });
    final mobile = params['mobile']?.toString() ?? '';
    final maskedMobile = mobile.length == 11
        ? '${mobile.substring(0, 2)}*****${mobile.substring(10, 11)}'
        : mobile;
    final guid = cookie['KUGOU_API_GUID'] ?? randomGuid();
    final mac = cookie['KUGOU_API_MAC'] ?? randomMac();
    final dev = cookie['KUGOU_API_DEV'] ?? randomDeviceId();
    final dfid = cookie['dfid'] ?? _randomString(24);
    final t2 = _aesCbcEncryptHex(
      '$guid|0f607264fc6318a92b9e13c65db7cd3c|$mac|$dev|$dateTime',
      key: _liteLoginT2Key,
      iv: _liteLoginT2Iv,
    );
    final t1 = _aesCbcEncryptHex(
      '|$dateTime',
      key: _liteLoginT1Key,
      iv: _liteLoginT1Iv,
    );
    return _android(
      '/v7/login_by_verifycode',
      {},
      {
        ...cookie,
        'dfid': dfid,
        'KUGOU_API_GUID': guid,
        'KUGOU_API_MAC': mac,
        'KUGOU_API_DEV': dev,
      },
      baseUrl: 'https://loginserviceretry.kugou.com',
      method: 'POST',
      data: {
        'plat': 1,
        'support_multi': 1,
        't1': t1,
        't2': t2,
        'clienttime_ms': dateTime,
        'mobile': maskedMobile,
        'key': _signParamsKey(dateTime.toString()),
        'pk': _rsaEncrypt({
          'clienttime_ms': dateTime,
          'key': encrypt.key,
        }, _publicLiteRsaKey).toUpperCase(),
        'params': encrypt.data,
        'dfid': dfid,
        'dev': dev,
        'gitversion': '5f0b7c4',
      },
      headers: {
        'support-calm': '1',
        'User-Agent': 'Android16-1070-11440-130-0-LOGIN-wifi',
      },
      loginDecryptKey: encrypt.key,
    );
  }

  _OfficialRequest _userVideoCollect(
    Map<String, Object?> params,
    Map<String, String> cookie,
  ) {
    return _android(
      '/collectservice/v2/collect_list_mixvideo',
      {'plat': 1},
      cookie,
      method: 'POST',
      data: {
        'userid': cookie['userid'] ?? '0',
        'token': cookie['token'] ?? '',
        'page': params['page'] ?? 1,
        'pagesize': params['pagesize'] ?? 30,
      },
    );
  }

  _OfficialRequest _mvCollect(
    Map<String, Object?> params,
    Map<String, String> cookie, {
    required bool collect,
  }) {
    // The app logs in through the concept-version client. Keep the MV
    // collection request on the same appid/clientver/RSA key as that session.
    const requestAppid = liteAppid;
    const requestClientver = liteClientver;
    final clienttime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final aes = _playlistAesEncrypt({
      'ctype': 2,
      'data': [
        {'obj_id': _toInt(params['id'])},
      ],
    });
    final p = _rsaEncrypt2({
      'aes': aes.key,
      'uid': cookie['userid'] ?? 0,
      'token': cookie['token'] ?? '',
    }).toUpperCase();
    return _android(
      collect ? '/v1/collect' : '/v1/cancel_collect',
      {
        'clienttime': clienttime,
        'mid': cookie['KUGOU_API_MID'] ?? randomMid(),
        'dfid': cookie['dfid'] ?? '-',
        'key': _signParamsKey(
          clienttime.toString(),
          appId: requestAppid,
          clientVersion: requestClientver,
        ),
        'clientver': requestClientver,
        'appid': requestAppid,
        'p': p,
      },
      cookie,
      baseUrl: 'https://collectservice.kugou.com',
      method: 'POST',
      data: base64Decode(aes.data),
      responseType: ResponseType.bytes,
      decryptKey: aes.key,
      notSignature: true,
      headers: {
        'User-Agent':
            'Android9-1070-$requestClientver-18-0-MV/${collect ? 'Care' : 'UnCare'}-wifi',
        'KG-THash': _random.nextInt(0xfffffff).toString(),
        'Content-Type': 'application/json',
      },
    );
  }

  _OfficialRequest _videoDetail(
    Map<String, Object?> params,
    Map<String, String> cookie,
  ) {
    const requestAppid = liteAppid;
    const requestClientver = liteClientver;
    final clienttime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final dfid = cookie['dfid']?.isNotEmpty == true ? cookie['dfid']! : '-';
    final mid = cookie['KUGOU_API_MID']?.isNotEmpty == true
        ? cookie['KUGOU_API_MID']!
        : randomMid();
    return _android(
      '/v1/video',
      const {},
      cookie,
      method: 'POST',
      clearDefaultParams: true,
      notSignature: true,
      headers: {'x-router': 'kmr.service.kugou.com'},
      data: {
        'appid': requestAppid,
        'clientver': requestClientver,
        'clienttime': clienttime,
        'mid': mid,
        'uuid': _md5('$dfid$mid'),
        'dfid': dfid,
        'token': cookie['token'] ?? '',
        'key': _signParamsKey(
          clienttime.toString(),
          appId: requestAppid,
          clientVersion: requestClientver,
        ),
        'show_resolution': 1,
        'data': [
          {'video_id': params['id'] ?? ''},
        ],
      },
    );
  }

  _OfficialRequest _cloudSongs(
    Map<String, Object?> params,
    Map<String, String> cookie,
  ) {
    final clienttime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final aes = _playlistAesEncrypt({
      'page': params['page'] ?? 1,
      'pagesize': params['pagesize'] ?? 100,
      'getkmr': 1,
    });
    final p = _rsaEncrypt2({
      'aes': aes.key,
      'uid': cookie['userid'] ?? params['userid'] ?? 0,
      'token': cookie['token'] ?? params['token'] ?? '',
    }).toUpperCase();
    return _android(
      '/v1/get_list',
      {
        'clienttime': clienttime,
        'mid': cookie['KUGOU_API_MID'] ?? randomMid(),
        'key': _signParamsKey(
          clienttime.toString(),
          appId: liteAppid,
          clientVersion: liteClientver,
        ),
        'clientver': liteClientver,
        'appid': liteAppid,
        'p': p,
      },
      cookie,
      baseUrl: 'https://mcloudservice.kugou.com',
      method: 'POST',
      data: base64Decode(aes.data),
      responseType: ResponseType.bytes,
      decryptKey: aes.key,
      clearDefaultParams: true,
      notSignature: true,
    );
  }

  _OfficialRequest _cloudSongsDel(
    Map<String, Object?> params,
    Map<String, String> cookie,
  ) {
    final clienttime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final fileids = _splitIds(
      params['fileids'] ??
          params['fileid'] ??
          params['kv_ids'] ??
          params['kv_id'],
    );
    final albumAudioIds = _splitIds(
      params['album_audio_ids'] ?? params['album_audio_id'],
    );
    final aes = _playlistAesEncrypt({
      'data': [
        for (var i = 0; i < fileids.length; i++)
          {
            'kv_id': _toInt(fileids[i]),
            'album_audio_id': _toInt(
              i < albumAudioIds.length
                  ? albumAudioIds[i]
                  : (albumAudioIds.isNotEmpty ? albumAudioIds.first : 0),
            ),
          },
      ],
    });
    final p = _rsaEncrypt2({
      'aes': aes.key,
      'uid': cookie['userid'] ?? params['userid'] ?? 0,
      'token': cookie['token'] ?? params['token'] ?? '',
    }).toUpperCase();
    return _android(
      '/v1/del_files',
      {
        'clienttime': clienttime,
        'mid': cookie['KUGOU_API_MID'] ?? randomMid(),
        'key': _signParamsKey(
          clienttime.toString(),
          appId: liteAppid,
          clientVersion: liteClientver,
        ),
        'clientver': liteClientver,
        'appid': liteAppid,
        'p': p,
      },
      cookie,
      baseUrl: 'https://mcloudservice.kugou.com',
      method: 'POST',
      data: base64Decode(aes.data),
      responseType: ResponseType.bytes,
      decryptKey: aes.key,
      clearDefaultParams: true,
      notSignature: true,
    );
  }

  _OfficialRequest _cloudSongUrl(
    Map<String, Object?> params,
    Map<String, String> cookie,
  ) {
    final hash = (params['hash'] ?? '').toString().toLowerCase();
    return _android('/bsstrackercdngz/v2/query_musicclound_url', {
      'hash': hash,
      'ssa_flag': 'is_fromtrack',
      'version': '20102',
      'ssl': 0,
      'album_audio_id': params['album_audio_id'] ?? 0,
      'pid': 20026,
      'audio_id': params['audio_id'] ?? 0,
      'kv_id': 2,
      'key': _signCloudKey(hash, 20026),
      'bucket': 'musicclound',
      'name': params['name'] ?? '',
      'with_res_tag': 0,
    }, cookie);
  }

  Future<Map<String, Object?>> uploadCloudSong({
    required Uint8List fileBytes,
    required String name,
    required String extendname,
    required String authorName,
    required int audioId,
    required int albumAudioId,
    required String hashStd,
    required KugouSession session,
    int durationSeconds = 0,
    CancelToken? cancelToken,
    void Function(double progress)? onProgress,
  }) async {
    final fileHash = md5.convert(fileBytes).toString().toLowerCase();
    final cookie = _cookie(session);
    final userid = (cookie['userid'] ?? session.userId).trim();
    final token = (cookie['token'] ?? session.token).trim();
    final mid = (cookie['KUGOU_API_MID'] ?? session.mid).trim();
    final dfid = (cookie['dfid'] ?? session.dfid).trim().isEmpty
        ? '-'
        : (cookie['dfid'] ?? session.dfid).trim();
    final uuid = (cookie['KUGOU_API_GUID'] ?? session.guid).trim().isEmpty
        ? '-'
        : (cookie['KUGOU_API_GUID'] ?? session.guid).trim();
    int requestAppid = liteAppid;
    int requestClientver = liteClientver;
    final clienttime = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final bssHeaders = {
      'User-Agent': 'Android15-1070-$requestClientver-201-0-wifi',
      'KG-RC': '1',
      'KG-Rec': '1',
      'KG-THash': _random.nextInt(0xfffffff).toRadixString(16).padLeft(7, '0'),
    };

    // 1. 获取上传授权（优先使用概念版 3116/11440 凭证，若失败降级至标准版 1005/20489）
    String authorization = '';
    for (final candidate in [(liteAppid, liteClientver), (1005, 20489)]) {
      try {
        final authRes = await _dio.get<Object?>(
          'http://bssulbig.kugou.com/v2/authorization',
          queryParameters: {
            'version': candidate.$2,
            'userid': userid,
            'filename': fileHash,
            'token': token,
            'appid': candidate.$1,
            'method': 'POST',
            'bucket': 'musicclound',
          },
          cancelToken: cancelToken,
          options: Options(
            headers: bssHeaders,
            responseType: ResponseType.plain,
          ),
        );
        final authBody = _parseBssMap(authRes.data);
        final data = authBody['data'];
        if (data is Map &&
            (data['authorization'] ?? '').toString().isNotEmpty) {
          authorization = data['authorization'].toString();
          requestAppid = candidate.$1;
          requestClientver = candidate.$2;
          break;
        }
      } catch (e) {
        if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      }
    }

    if (authorization.isEmpty) {
      // 备用鉴权途径：bsstrackercdngz/v1/upload/auth（extranet 必须为 0，标准 salt）
      final buVerifyCode = md5
          .convert(
            utf8.encode(
              '$requestAppid'
              'musicclound'
              '8ae10344e9738dcb',
            ),
          )
          .toString();

      Map<String, Object?> signBss(Map<String, Object?> params) {
        final keys = params.keys.toList()..sort();
        final paramStr = keys.map((k) => '$k=${params[k]}').join();
        final sig = md5
            .convert(
              utf8.encode(
                '$_standardParamKeySalt$paramStr$_standardParamKeySalt',
              ),
            )
            .toString();
        return {...params, 'signature': sig};
      }

      final authParams = signBss({
        'bucket': 'musicclound',
        'filename': fileHash,
        'method': 'POST',
        'loginType': token.isNotEmpty && userid != '0' ? 1 : 0,
        'buVerifyCode': buVerifyCode,
        'extranet': 0,
        'userid': userid,
        'token': token,
        'version': requestClientver,
        'dfid': dfid,
        'mid': mid,
        'uuid': uuid,
        'appid': requestAppid,
        'clientver': requestClientver,
        'clienttime': clienttime,
      });

      try {
        final authRes = await _dio.get<Object?>(
          'https://gateway.kugou.com/bsstrackercdngz/v1/upload/auth',
          queryParameters: authParams,
          cancelToken: cancelToken,
          options: Options(
            headers: bssHeaders,
            responseType: ResponseType.plain,
          ),
        );

        final authBody = _parseBssMap(authRes.data);
        final Map<String, Object?>? authData = authBody['data'] is Map
            ? (authBody['data'] as Map).cast<String, Object?>()
            : null;
        authorization = authData?['authorization']?.toString() ?? '';
        if (authorization.isEmpty) {
          final msg =
              authBody['msg']?.toString() ??
              authBody['message']?.toString() ??
              authBody['error_msg']?.toString() ??
              '获取云盘上传授权失败';
          throw KugouOfficialException(msg);
        }
      } on DioException catch (e) {
        throw KugouOfficialException(
          '获取云盘授权网络异常: ${e.message ?? e.toString()}',
        );
      }
    }

    onProgress?.call(0.15);

    // 2. 初始化分片上传
    Map<String, Object?>? initBody;
    try {
      final initRes = await _dio.post<Object?>(
        'http://bssulbig.kugou.com/multipart/initiate/music',
        queryParameters: {
          'version': requestClientver,
          'extendname': extendname.replaceAll('.', ''),
          'userid': userid,
          'filename': fileHash,
          'appid': requestAppid,
          'bucket': 'musicclound',
        },
        cancelToken: cancelToken,
        options: Options(
          headers: {...bssHeaders, 'Authorization': authorization},
          responseType: ResponseType.plain,
        ),
      );
      initBody = _parseBssMap(initRes.data);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      throw KugouOfficialException('初始化云盘上传失败: ${e.message ?? e.toString()}');
    }

    final Map<String, Object?>? initData = initBody['data'] is Map
        ? (initBody['data'] as Map).cast<String, Object?>()
        : null;
    final externalHost = initData?['external_host']?.toString() ?? '';
    final uploadId = initData?['upload_id']?.toString() ?? '';
    var bssFileHash = initData?['x-bss-filename']?.toString() ?? fileHash;

    // 3 & 4. 上传分片并完成（秒传分支 upload_id 为空，直接跳过）
    if (uploadId.isNotEmpty && externalHost.isNotEmpty) {
      final hostWithProto = externalHost.startsWith('http')
          ? externalHost
          : 'http://$externalHost';
      const partSize = 1024 * 1024 * 4; // 4MB 分片
      final partCount = max(1, (fileBytes.length / partSize).ceil());

      for (var i = 0; i < partCount; i++) {
        final start = i * partSize;
        final end = min(start + partSize, fileBytes.length);
        final partData = fileBytes.sublist(start, end);

        try {
          final uploadRes = await _dio.post<Object?>(
            '$hostWithProto/multipart/upload',
            queryParameters: {
              'version': requestClientver,
              'userid': userid,
              'filename': fileHash,
              'appid': requestAppid,
              'upload_id': uploadId,
              'partnumber': i + 1,
              'bucket': 'musicclound',
            },
            cancelToken: cancelToken,
            data: Stream.fromIterable([partData]),
            options: Options(
              headers: {
                ...bssHeaders,
                'Authorization': authorization,
                'Content-Type': 'application/octet-stream',
                'Content-Length': partData.length,
              },
              responseType: ResponseType.plain,
            ),
          );
          final uploadData = _parseBssMap(uploadRes.data);
          if (uploadData['status'] != 1) {
            throw KugouOfficialException(
              uploadData['msg']?.toString() ?? '云盘分片上传失败',
            );
          }
        } on DioException catch (e) {
          if (e.type == DioExceptionType.cancel) rethrow;
          throw KugouOfficialException(
            '分片上传网络异常 (${i + 1}/$partCount): ${e.message ?? e.toString()}',
          );
        }
        onProgress?.call(0.15 + 0.55 * ((i + 1) / partCount));
      }

      Map<String, Object?>? compBody;
      try {
        final completeRes = await _dio.post<Object?>(
          '$hostWithProto/multipart/complete',
          queryParameters: {
            'filename': fileHash,
            'bucket': 'musicclound',
            'if_id3': 1,
            'upload_id': uploadId,
            'userid': userid,
            'md5': fileHash,
            'version': requestClientver,
            'appid': requestAppid,
            'partnumber': partCount,
          },
          cancelToken: cancelToken,
          options: Options(
            headers: {...bssHeaders, 'Authorization': authorization},
            responseType: ResponseType.plain,
          ),
        );
        compBody = _parseBssMap(completeRes.data);
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) rethrow;
        throw KugouOfficialException(
          '完成云盘分片上传网络异常: ${e.message ?? e.toString()}',
        );
      }
      if (compBody['status'] != 1) {
        throw KugouOfficialException(
          compBody['msg']?.toString() ?? '完成云盘分片上传失败',
        );
      }
      final Map<String, Object?>? compData = compBody['data'] is Map
          ? (compBody['data'] as Map).cast<String, Object?>()
          : null;
      bssFileHash = compData?['x-bss-filename']?.toString() ?? bssFileHash;
    } else {
      // 秒传命中
      onProgress?.call(0.7);
    }

    onProgress?.call(0.75);

    // 5. 添加文件到酷狗云盘（AES 加密 payload + RSA 加密密钥）
    final cleanExt = extendname.replaceAll('.', '').trim();
    final cleanName = name
        .replaceFirst(
          RegExp(
            r'\.(mp3|m4a|flac|wav|aac|mp4|m4v|mkv|ogg)$',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    final aes = _playlistAesEncrypt({
      'data': [
        {
          'name': cleanName.isNotEmpty ? cleanName : name,
          'ext': cleanExt,
          'author_name': authorName,
          'hash': bssFileHash,
          'hash_std': hashStd.isNotEmpty ? hashStd : fileHash,
          'audio_id': audioId,
          'bitrate': 4,
          'album_audio_id': albumAudioId,
          'size': fileBytes.length,
          'timelen': durationSeconds > 0 ? durationSeconds : 0,
        },
      ],
      'list_ver': 0,
    });
    final p = _rsaEncrypt2({
      'aes': aes.key,
      'uid': userid,
      'token': token,
    }).toUpperCase();

    final addClienttime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    Response<List<int>> addRes;
    try {
      addRes = await _dio.post<List<int>>(
        'https://mcloudservice.kugou.com/v1/add_files',
        queryParameters: {
          'clienttime': addClienttime,
          'mid': mid.isNotEmpty ? mid : randomMid(),
          'key': _signParamsKey(
            addClienttime.toString(),
            appId: requestAppid,
            clientVersion: requestClientver,
          ),
          'clientver': requestClientver,
          'appid': requestAppid,
          'p': p,
        },
        cancelToken: cancelToken,
        data: base64Decode(aes.data),
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'KG-RC': '1',
            'KG-Rec': '1',
            if (cookie.isNotEmpty)
              'Cookie': cookie.entries
                  .map((e) => '${e.key}=${e.value}')
                  .join('; '),
          },
        ),
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      throw KugouOfficialException('同步云盘列表网络异常: ${e.message}');
    }

    Object? decoded;
    if (addRes.data != null) {
      decoded = _decodeBody(addRes.data, decryptKey: aes.key);
    }

    if (decoded is Map) {
      final status = _toInt(decoded['status'] ?? 1);
      final errorCode = _toInt(decoded['error_code'] ?? decoded['code']);
      if (status != 1 || errorCode != 0) {
        final errorMsg =
            decoded['msg']?.toString() ??
            decoded['message']?.toString() ??
            '添加到云盘失败 (error_code=$errorCode)';
        throw KugouOfficialException(errorMsg);
      }
    }

    onProgress?.call(1.0);
    return {
      'status': 1,
      'data': decoded,
      'hash': bssFileHash,
      'is_second_upload': uploadId.isEmpty,
    };
  }

  _OfficialRequest _userFollow(Map<String, String> cookie) {
    final clienttime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return _android(
      '/v4/follow_list',
      {'plat': 1},
      cookie,
      method: 'POST',
      data: {
        'merge': 2,
        'need_iden_type': 1,
        'ext_params': 'k_pic,jumptype,singerid,score',
        'userid': cookie['userid'] ?? '0',
        'type': 0,
        'id_type': 0,
        'p': _rsaEncrypt({
          'clienttime': clienttime,
          'token': cookie['token'] ?? '',
        }, _publicLiteRsaKey).toUpperCase(),
      },
      headers: {'x-router': 'relationuser.kugou.com'},
    );
  }

  _OfficialRequest _playlistTracksAdd(
    Map<String, Object?> params,
    Map<String, String> cookie,
  ) {
    final clienttime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return _android(
      '/cloudlist.service/v6/add_song',
      {
        'last_time': clienttime,
        'last_area': 'gztx',
        'userid': cookie['userid'] ?? '0',
        'token': cookie['token'] ?? '',
      },
      cookie,
      method: 'POST',
      data: {
        'userid': cookie['userid'] ?? '0',
        'token': cookie['token'] ?? '',
        'listid': params['listid'] ?? '',
        'list_ver': 0,
        'type': 0,
        'slow_upload': 1,
        'scene': 'false;null',
        'data': _playlistAddResources(params['data']),
      },
    );
  }

  _OfficialRequest _playlistTracksDel(
    Map<String, Object?> params,
    Map<String, String> cookie,
  ) {
    return _android(
      '/v4/delete_songs',
      {},
      cookie,
      method: 'POST',
      data: {
        'userid': cookie['userid'] ?? '0',
        'token': cookie['token'] ?? '',
        'listid': params['listid'] ?? '',
        'list_ver': 0,
        'type': 0,
        'data': [
          for (final fileId in _splitIds(params['fileids']))
            {'fileid': _toInt(fileId)},
        ],
      },
      headers: {'x-router': 'cloudlist.service.kugou.com'},
    );
  }

  _OfficialRequest _playlistAdd(
    Map<String, Object?> params,
    Map<String, String> cookie,
  ) {
    final clienttime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return _android(
      '/cloudlist.service/v5/add_list',
      {
        'last_time': clienttime,
        'last_area': 'gztx',
        'userid': cookie['userid'] ?? '0',
        'token': cookie['token'] ?? '',
      },
      cookie,
      method: 'POST',
      data: {
        'userid': cookie['userid'] ?? '0',
        'token': cookie['token'] ?? '',
        'total_ver': 0,
        'name': params['name'] ?? '',
        'type': params['type'] ?? 0,
        'source': params['source'] ?? 1,
        'is_pri': params['is_pri'] ?? 0,
        'list_create_userid': params['list_create_userid'] ?? '',
        'list_create_listid': params['list_create_listid'] ?? '',
        'list_create_gid': params['list_create_gid'] ?? '',
        'from_shupinmv': 0,
      },
    );
  }

  _OfficialRequest _playlistDel(
    Map<String, Object?> params,
    Map<String, String> cookie,
  ) {
    final clienttime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final aes = _playlistAesEncrypt({
      'listid': _toInt(params['listid']),
      'total_ver': 0,
      'type': 1,
    });
    final p = _rsaEncrypt2({
      'aes': aes.key,
      'uid': cookie['userid'] ?? 0,
      'token': cookie['token'] ?? '',
    }).toUpperCase();
    return _android(
      '/v2/delete_list',
      {
        'clienttime': clienttime,
        'key': _signParamsKey(clienttime.toString()),
        'last_area': 'gztx',
        'clientver': liteClientver,
        'appid': liteAppid,
        'last_time': clienttime,
        'p': p,
      },
      cookie,
      method: 'POST',
      data: aes.data,
      responseType: ResponseType.bytes,
      decryptKey: aes.key,
      headers: {'x-router': 'cloudlist.service.kugou.com'},
    );
  }

  _OfficialRequest _artistFollow(
    Map<String, Object?> params,
    Map<String, String> cookie, {
    required bool follow,
  }) {
    final clienttime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final encrypt = _loginAesEncrypt({
      'singerid': _toInt(params['id']),
      'token': cookie['token'] ?? '',
    });
    return _android(
      follow
          ? '/followservice/v3/follow_singer'
          : '/followservice/v3/unfollow_singer',
      {'clienttime': clienttime},
      cookie,
      method: 'POST',
      data: {
        'plat': 0,
        'userid': _toInt(cookie['userid']),
        'singerid': _toInt(params['id']),
        'source': 7,
        'p': _rsaEncrypt2({'clienttime': clienttime, 'key': encrypt.key}),
        'params': encrypt.data,
      },
    );
  }

  List<Map<String, Object?>> _playlistAddResources(Object? value) {
    return [
      for (final raw in (value?.toString() ?? '').split(','))
        if (raw.trim().isNotEmpty) _playlistAddResource(raw),
    ];
  }

  Map<String, Object?> _playlistAddResource(String value) {
    final parts = value.split('|');
    return {
      'number': 1,
      'name': parts.isNotEmpty ? parts[0].trim() : '',
      'hash': parts.length > 1 ? parts[1].trim() : '',
      'size': 0,
      'sort': 0,
      'timelen': 0,
      'bitrate': 0,
      'album_id': parts.length > 2 ? _toInt(parts[2]) : 0,
      'mixsongid': parts.length > 3 ? _toInt(parts[3]) : 0,
    };
  }

  List<String> _splitIds(Object? value) => (value?.toString() ?? '')
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();

  _OfficialRequest _search(
    Map<String, Object?> params,
    Map<String, String> cookie,
  ) {
    final type = params['type']?.toString() ?? 'song';
    final normalizedType =
        ['special', 'lyric', 'song', 'album', 'author', 'mv'].contains(type)
        ? type
        : 'song';
    return _android(
      '/${normalizedType == 'song' ? 'v3' : 'v1'}/search/$normalizedType',
      {
        'albumhide': 0,
        'iscorrection': 1,
        'keyword': params['keywords'] ?? '',
        'nocollect': 0,
        'page': params['page'] ?? 1,
        'pagesize': params['pagesize'] ?? 30,
        'platform': 'AndroidFilter',
      },
      cookie,
      headers: {'x-router': 'complexsearch.kugou.com'},
    );
  }

  _OfficialRequest _public(String path, Map<String, Object?> params) {
    return _OfficialRequest(
      baseUrl: 'http://mobilecdn.kugou.com',
      path: path,
      params: params,
      method: 'GET',
      headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
    );
  }

  _OfficialRequest _similarArtists(
    Map<String, Object?> body,
    Map<String, String> cookie,
  ) {
    const clientVersion = 9108;
    final clienttime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return _OfficialRequest(
      baseUrl: 'http://kmr.service.kugou.com',
      path: '/v1/author/similar',
      params: const {},
      method: 'POST',
      data: {
        'clientver': clientVersion,
        'mid': cookie['KUGOU_API_MID'] ?? randomMid(),
        'clienttime': clienttime,
        'key': _signParamsKey(
          clienttime.toString(),
          appId: appid,
          clientVersion: clientVersion,
        ),
        'appid': appid,
        'data': body['data'] ?? const [],
      },
      headers: const {
        'Content-Type': 'application/json',
        'User-Agent': 'Android15-1070-11083-46-0-DiscoveryDRADProtocol-wifi',
      },
    );
  }

  _OfficialRequest _songUrl(
    Map<String, Object?> params,
    Map<String, String> cookie,
  ) {
    final hash = (params['hash'] ?? '').toString().toLowerCase();
    final base = {
      'album_id': _toInt(params['album_id']),
      'area_code': 1,
      'hash': hash,
      'ssa_flag': 'is_fromtrack',
      'version': 11430,
      'page_id': 967177915,
      'quality': params['quality'] ?? 128,
      'album_audio_id': _toInt(params['album_audio_id']),
      'behavior': 'play',
      'pid': 411,
      'cmd': 26,
      'pidversion': 3001,
      'IsFreePart': 0,
      'ppage_id': params['ppage_id'] ?? '356753938,823673182,967485191',
      'cdnBackup': 1,
      'module': '',
      'clientver': 11430,
    };
    return _android(
      '/v5/url',
      base,
      {
        ...cookie,
        if ((cookie['dfid'] ?? '').isEmpty) 'dfid': _randomString(24),
      },
      headers: {'x-router': 'trackercdn.kugou.com'},
      encryptKey: true,
    );
  }

  _OfficialRequest _privilegeLite(
    Map<String, Object?> params,
    Map<String, String> cookie,
  ) {
    return _android(
      '/v2/get_res_privilege/lite',
      {},
      cookie,
      method: 'POST',
      data: {
        'appid': appid,
        'area_code': 1,
        'behavior': 'play',
        'clientver': clientver,
        'need_hash_offset': 1,
        'relate': 1,
        'support_verify': 1,
        'resource': [
          {
            'type': 'audio',
            'page_id': 0,
            'hash': params['hash'] ?? '',
            'album_id': _toInt(params['album_id']),
          },
        ],
        'qualities': [
          '128',
          '320',
          'flac',
          'high',
          'viper_atmos',
          'viper_tape',
          'viper_clear',
          'super',
          'multitrack',
        ],
      },
      headers: {
        'x-router': 'media.store.kugou.com',
        'Content-Type': 'application/json',
      },
    );
  }

  _OfficialRequest _android(
    String path,
    Map<String, Object?> params,
    Map<String, String> cookie, {
    String baseUrl = 'https://gateway.kugou.com',
    Map<String, String> headers = const {},
    String method = 'GET',
    Object? data,
    bool encryptKey = false,
    bool notSignature = false,
    bool clearDefaultParams = false,
    int appId = liteAppid,
    int clientVersion = liteClientver,
    ResponseType? responseType,
    String? decryptKey,
    String? loginDecryptKey,
  }) {
    final dfid = cookie['dfid']?.isNotEmpty == true ? cookie['dfid']! : '-';
    final mid = cookie['KUGOU_API_MID']?.isNotEmpty == true
        ? cookie['KUGOU_API_MID']!
        : randomMid();
    final clienttime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final defaultParams = <String, Object?>{
      'dfid': dfid,
      'mid': mid,
      'uuid': '-',
      'appid': appId,
      'clientver': clientVersion,
      'clienttime': clienttime,
      if ((cookie['token'] ?? '').isNotEmpty) 'token': cookie['token'],
      if ((cookie['userid'] ?? '').isNotEmpty) 'userid': cookie['userid'],
    };
    final merged = <String, Object?>{
      if (!clearDefaultParams) ...defaultParams,
      ...params,
    };
    if (encryptKey) {
      final keySalt = _toInt(merged['appid']) == liteAppid
          ? _liteSignKeySalt
          : _standardSignKeySalt;
      merged['key'] = _md5(
        '${merged['hash']}$keySalt${merged['appid']}${merged['mid']}${merged['userid'] ?? 0}',
      );
    }
    if (!notSignature) {
      merged['signature'] = _androidSignature(merged, data);
    }
    return _OfficialRequest(
      baseUrl: baseUrl,
      path: path,
      params: merged,
      data: data,
      method: method,
      responseType: responseType,
      decryptKey: decryptKey,
      loginDecryptKey: loginDecryptKey,
      headers: {
        'User-Agent': 'Android15-1070-11083-46-0-DiscoveryDRADProtocol-wifi',
        'dfid': dfid,
        'mid': mid,
        'clienttime': clienttime.toString(),
        if (cookie.isNotEmpty)
          HttpHeaders.cookieHeader: cookie.entries
              .map((entry) => '${entry.key}=${entry.value}')
              .join('; '),
        'kg-rc': '1',
        'kg-thash': '5d816a0',
        'kg-rec': '1',
        'kg-rf': 'B9EDA08A64250DEFFBCADDEE00F8F25F',
        ...headers,
      },
    );
  }

  _OfficialRequest _web(
    String baseUrl,
    String path,
    Map<String, Object?> params,
    Map<String, String> cookie,
  ) {
    final dfid = cookie['dfid']?.isNotEmpty == true ? cookie['dfid']! : '-';
    final mid = cookie['KUGOU_API_MID']?.isNotEmpty == true
        ? cookie['KUGOU_API_MID']!
        : randomMid();
    final clienttime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final merged = <String, Object?>{
      'dfid': dfid,
      'mid': mid,
      'uuid': '-',
      'appid': liteAppid,
      'clientver': liteClientver,
      'clienttime': clienttime,
      if ((cookie['token'] ?? '').isNotEmpty) 'token': cookie['token'],
      if ((cookie['userid'] ?? '').isNotEmpty) 'userid': cookie['userid'],
      ...params,
    };
    merged['signature'] = _webSignature(merged);
    return _OfficialRequest(
      baseUrl: baseUrl,
      path: path,
      params: merged,
      method: 'GET',
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
        'dfid': dfid,
        'mid': mid,
        'clienttime': clienttime.toString(),
        if (cookie.isNotEmpty)
          HttpHeaders.cookieHeader: cookie.entries
              .map((entry) => '${entry.key}=${entry.value}')
              .join('; '),
      },
    );
  }

  Map<String, String> _cookie(KugouSession session) => {
    if (session.token.isNotEmpty) 'token': session.token,
    if (session.userId.isNotEmpty) 'userid': session.userId,
    if (session.dfid.isNotEmpty) 'dfid': session.dfid,
    if (session.mid.isNotEmpty) 'KUGOU_API_MID': session.mid,
    if (session.guid.isNotEmpty) 'KUGOU_API_GUID': session.guid,
    if (session.device.isNotEmpty) 'KUGOU_API_DEV': session.device,
    if (session.mac.isNotEmpty) 'KUGOU_API_MAC': session.mac,
  };

  String _androidSignature(Map<String, Object?> params, Object? data) {
    final values = params.keys.toList()..sort();
    final paramsString = values
        .map((key) => '$key=${_stringify(params[key])}')
        .join();
    return _md5('$_androidSalt$paramsString${_stringify(data)}$_androidSalt');
  }

  String _webSignature(Map<String, Object?> params) {
    final values = params.keys.toList()..sort();
    final paramsString = values.map((key) => '$key=${params[key]}').join();
    return _md5('$_webSalt$paramsString$_webSalt');
  }

  String _stringify(Object? value) => value is Map || value is List
      ? jsonEncode(value)
      : value?.toString() ?? '';

  String _md5(String input) => md5.convert(utf8.encode(input)).toString();

  String _signCloudKey(String hash, int pid) {
    return _md5('musicclound$hash$pid$_cloudKeySalt');
  }

  String _signParamsKey(
    String data, {
    int appId = liteAppid,
    int clientVersion = liteClientver,
  }) {
    final salt = appId == liteAppid ? _androidSalt : _standardParamKeySalt;
    return _md5('$appId$salt$clientVersion$data');
  }

  static String _md5Static(String input) =>
      md5.convert(utf8.encode(input)).toString();

  static String _calculateMid(String guid) =>
      BigInt.parse(_md5Static(guid), radix: 16).toString();

  static String _randomString(int length) {
    const chars = '1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    return List.generate(
      length,
      (_) => chars[_random.nextInt(chars.length)],
    ).join();
  }

  static String _guid() {
    String part() => _random.nextInt(0x10000).toRadixString(16).padLeft(4, '0');
    return '${part()}${part()}-${part()}-${part()}-${part()}-${part()}${part()}${part()}';
  }

  _PlaylistAesPayload _playlistAesEncrypt(Object data) {
    final useData = data is String ? data : jsonEncode(data);
    final key = _randomString(6).toLowerCase();
    final keyMd5 = _md5(key);
    final encryptKey = utf8.encode(keyMd5.substring(0, 16));
    final iv = utf8.encode(keyMd5.substring(16, 32));
    final cipher =
        PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
          ..init(
            true,
            PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, Null>(
              ParametersWithIV<KeyParameter>(
                KeyParameter(Uint8List.fromList(encryptKey)),
                Uint8List.fromList(iv),
              ),
              null,
            ),
          );
    final encrypted = cipher.process(Uint8List.fromList(utf8.encode(useData)));
    return _PlaylistAesPayload(base64Encode(encrypted), key);
  }

  Object? _playlistAesDecrypt(String data, String key) {
    final keyMd5 = _md5(key);
    final decryptKey = utf8.encode(keyMd5.substring(0, 16));
    final iv = utf8.encode(keyMd5.substring(16, 32));
    final cipher =
        PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
          ..init(
            false,
            PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, Null>(
              ParametersWithIV<KeyParameter>(
                KeyParameter(Uint8List.fromList(decryptKey)),
                Uint8List.fromList(iv),
              ),
              null,
            ),
          );
    final decrypted = cipher.process(base64Decode(data));
    final text = utf8.decode(decrypted);
    try {
      return jsonDecode(text);
    } catch (_) {
      return text;
    }
  }

  _LoginAesPayload _loginAesEncrypt(Object data) {
    final useData = data is String ? data : jsonEncode(data);
    final key = _randomString(16).toLowerCase();
    return _LoginAesPayload(_aesCbcEncryptHex(useData, key: key), key);
  }

  Object? _loginAesDecrypt(String data, String key) {
    final keyMd5 = _md5(key).substring(0, 32);
    final iv = keyMd5.substring(keyMd5.length - 16);
    final cipher =
        PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
          ..init(
            false,
            PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, Null>(
              ParametersWithIV<KeyParameter>(
                KeyParameter(Uint8List.fromList(utf8.encode(keyMd5))),
                Uint8List.fromList(utf8.encode(iv)),
              ),
              null,
            ),
          );
    final decrypted = cipher.process(_hexToBytes(data));
    final text = utf8.decode(decrypted, allowMalformed: true);
    try {
      return jsonDecode(text);
    } catch (_) {
      return text;
    }
  }

  String _aesCbcEncryptHex(String data, {required String key, String? iv}) {
    final useKey = iv == null ? _md5(key).substring(0, 32) : key;
    final useIv = iv ?? useKey.substring(useKey.length - 16);
    final cipher =
        PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
          ..init(
            true,
            PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, Null>(
              ParametersWithIV<KeyParameter>(
                KeyParameter(Uint8List.fromList(utf8.encode(useKey))),
                Uint8List.fromList(utf8.encode(useIv)),
              ),
              null,
            ),
          );
    final encrypted = cipher.process(Uint8List.fromList(utf8.encode(data)));
    return encrypted
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  Uint8List _hexToBytes(String value) {
    final clean = value.length.isOdd ? '0$value' : value;
    return Uint8List.fromList([
      for (var i = 0; i < clean.length; i += 2)
        int.parse(clean.substring(i, i + 2), radix: 16),
    ]);
  }

  String _rsaEncrypt2(Object data) {
    return _rsaEncrypt(data, _publicLiteRsaKey);
  }

  String _rsaEncrypt(Object data, String pem) {
    final publicKey = _parsePublicKey(pem);
    final engine = PKCS1Encoding(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));
    final encrypted = engine.process(
      Uint8List.fromList(utf8.encode(jsonEncode(data))),
    );
    return encrypted
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  RSAPublicKey _parsePublicKey(String pem) {
    final rows = pem
        .split('\n')
        .where((line) => !line.startsWith('-----') && line.trim().isNotEmpty)
        .join();
    final bytes = base64Decode(rows);
    final topLevel = ASN1Parser(bytes).nextObject() as ASN1Sequence;
    final bitString = topLevel.elements![1] as ASN1BitString;
    final publicKeySeq =
        ASN1Parser(bitString.stringValues as Uint8List).nextObject()
            as ASN1Sequence;
    final modulus = publicKeySeq.elements![0] as ASN1Integer;
    final exponent = publicKeySeq.elements![1] as ASN1Integer;
    return RSAPublicKey(modulus.integer!, exponent.integer!);
  }
}

class _PlaylistAesPayload {
  const _PlaylistAesPayload(this.data, this.key);

  final String data;
  final String key;
}

class _LoginAesPayload {
  const _LoginAesPayload(this.data, this.key);

  final String data;
  final String key;
}

class _OfficialRequest {
  const _OfficialRequest({
    required this.baseUrl,
    required this.path,
    required this.params,
    required this.method,
    this.headers = const {},
    this.data,
    this.responseType,
    this.decryptKey,
    this.loginDecryptKey,
  });

  final String baseUrl;
  final String path;
  final Map<String, Object?> params;
  final String method;
  final Map<String, String> headers;
  final Object? data;
  final ResponseType? responseType;
  final String? decryptKey;
  final String? loginDecryptKey;
}

Dio _createDio() {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 15),
    ),
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.extra['baseUrl'] is String) {
          options.baseUrl = options.extra['baseUrl'] as String;
        }
        handler.next(options);
      },
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

int _toInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

Map<String, Object?> _parseBssMap(Object? value) {
  if (value == null) return const {};
  if (value is Map<String, Object?>) return value;
  if (value is Map) return value.cast<String, Object?>();
  try {
    String text;
    if (value is List<int>) {
      text = utf8.decode(value);
    } else {
      text = value.toString();
    }
    final decoded = jsonDecode(text);
    if (decoded is Map) {
      return decoded.cast<String, Object?>();
    }
  } catch (_) {}
  return const {};
}
