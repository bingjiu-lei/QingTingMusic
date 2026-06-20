import 'dart:io';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ApiEndpointService {
  ApiEndpointService({this.verifier});

  static const storageKey = 'music_api_endpoint';
  static const defaultEndpoint = 'https://kugou.bingjiu.cc.cd';
  final Future<void> Function(String endpoint)? verifier;

  Future<String> load() async {
    if (Platform.isWindows && await _settingsFile.exists()) {
      try {
        final json =
            jsonDecode(await _settingsFile.readAsString())
                as Map<String, Object?>;
        return json[storageKey]?.toString() ?? '';
      } catch (_) {}
    }
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(storageKey) ?? defaultEndpoint;
  }

  Future<void> save(String value) async {
    final endpoint = normalize(value);
    if (endpoint.isNotEmpty) await (verifier ?? verify)(endpoint);
    if (Platform.isWindows) {
      await _settingsFile.parent.create(recursive: true);
      await _settingsFile.writeAsString(
        jsonEncode({storageKey: endpoint}),
        flush: true,
      );
      if (await load() != endpoint) {
        throw StateError('后端 API 地址未能持久化');
      }
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(storageKey, endpoint);
    if (!saved) throw StateError('后端 API 地址保存失败');
    await preferences.reload();
    if (preferences.getString(storageKey) != endpoint) {
      throw StateError('后端 API 地址未能持久化');
    }
  }

  File get _settingsFile {
    final root =
        Platform.environment['LOCALAPPDATA'] ??
        Platform.environment['APPDATA'] ??
        Directory.current.path;
    return File('$root\\QingTingMusic\\settings.json');
  }

  String normalize(String value) =>
      value.trim().replaceFirst(RegExp(r'/+$'), '');

  Future<void> verify(String endpoint) async {
    final uri = Uri.tryParse(endpoint);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const FormatException('请输入完整的 http 或 https 地址');
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12);
    client.findProxy = (_) {
      final value =
          Platform.environment['HTTPS_PROXY'] ??
          Platform.environment['HTTP_PROXY'] ??
          Platform.environment['ALL_PROXY'];
      final proxy = value == null ? null : Uri.tryParse(value);
      return proxy == null ? 'DIRECT' : 'PROXY ${proxy.host}:${proxy.port}';
    };
    try {
      final request = await client.getUrl(uri);
      request.headers.set('Cache-Control', 'no-cache');
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      await response.drain<void>();
      if (response.statusCode < 200 || response.statusCode >= 400) {
        throw HttpException('接口返回 ${response.statusCode}');
      }
    } finally {
      client.close(force: true);
    }
  }
}
