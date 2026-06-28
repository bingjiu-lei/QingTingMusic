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
  static const _publicLiteRsaKey = '''
-----BEGIN PUBLIC KEY-----
MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDECi0Np2UR87scwrvTr72L6oO01rBbbBPriSDFPxr3Z5syug0O24QyQO8bg27+0+4kBzTBTBOZ/WWU0WryL1JSXRTXLgFVxtzIY41Pe7lPOgsfTCn5kZcvKhYKJesKnnJDNr5/abvTGf+rHG3YRwsCHcQ08/q6ifSioBszvb3QiwIDAQAB
-----END PUBLIC KEY-----
''';
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
    return {
      'statusCode': response.statusCode,
      'data': _decodeBody(response.data, decryptKey: request.decryptKey),
      'setCookie': response.headers.map['set-cookie'] ?? const <String>[],
    };
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
      '/song/url' => _songUrl(params, cookie),
      '/privilege/lite' => _privilegeLite(params, cookie),
      '/user/cloud' => _cloudSongs(params, cookie),
      '/user/cloud/url' => _cloudSongUrl(params, cookie),
      '/user/follow' => _userFollow(cookie),
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
      '/album/songs' => _public('/api/v3/album/song', {
        'albumid': params['id'] ?? '',
        'page': params['page'] ?? 1,
        'pagesize': params['pagesize'] ?? 100,
      }),
      '/artist/audios' => _public('/api/v3/singer/song', {
        'singerid': params['id'] ?? '',
        'page': params['page'] ?? 1,
        'pagesize': params['pagesize'] ?? 100,
      }),
      '/artist/albums' => _public('/api/v3/singer/album', {
        'singerid': params['id'] ?? '',
        'page': params['page'] ?? 1,
        'pagesize': params['pagesize'] ?? 100,
      }),
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
  });

  final String baseUrl;
  final String path;
  final Map<String, Object?> params;
  final String method;
  final Map<String, String> headers;
  final Object? data;
  final ResponseType? responseType;
  final String? decryptKey;
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
