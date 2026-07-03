import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/app_update.dart';
import 'app_storage_service.dart';

class AppUpdateService {
  AppUpdateService({Dio? dio}) : _dio = dio ?? _createDio();

  static const owner = 'bingjiu-lei';
  static const repo = 'QingTingMusic';
  static const releasesUrl = 'https://github.com/$owner/$repo/releases';
  static const latestReleaseApi =
      'https://api.github.com/repos/$owner/$repo/releases/latest';
  static const _fallbackGithubProxyUrls = [
    'https://gh-proxy.com',
    'https://ghproxy.net',
  ];

  final Dio _dio;

  Future<String> currentVersion({bool useFallback = false}) async {
    if (useFallback) return fallbackVersion;
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (_) {
      return fallbackVersion;
    }
  }

  static const fallbackVersion = String.fromEnvironment(
    'FLUTTER_BUILD_NAME',
    defaultValue: '0.4.0',
  );

  Future<UpdateCheckResult> checkForUpdates({
    String githubProxyUrl = '',
  }) async {
    final current = await currentVersion();
    try {
      final response = await _dio.get<Object?>(
        latestReleaseApi,
        options: Options(headers: const {'Accept': 'application/json'}),
      );
      final data = response.data;
      if (data is! Map) {
        return UpdateCheckResult.error(
          currentVersion: current,
          message: '返回的更新信息无效',
        );
      }
      final tagName = data['tag_name']?.toString() ?? '';
      final latest = _normalizeVersion(tagName);
      if (latest.isEmpty) {
        return UpdateCheckResult.error(
          currentVersion: current,
          message: '没有找到可用版本',
        );
      }
      if (!_isNewer(latest, current)) {
        return UpdateCheckResult.latest(currentVersion: current);
      }
      final asset = _findInstallerAsset(data['assets']);
      if (asset == null) {
        return UpdateCheckResult.error(
          currentVersion: current,
          message: '新版本没有可用安装包',
        );
      }
      final rawDownloadUrl = asset['browser_download_url']?.toString() ?? '';
      if (rawDownloadUrl.isEmpty) {
        return UpdateCheckResult.error(
          currentVersion: current,
          message: '安装包下载地址为空',
        );
      }
      final body = data['body']?.toString() ?? '';
      final sha256 =
          _extractSha256(body, assetName: asset['name']?.toString()) ??
          await _loadSha256FromAsset(
            data['assets'],
            assetName: asset['name']?.toString(),
            githubProxyUrl: githubProxyUrl,
          );
      final releaseUrl =
          data['html_url']?.toString() ?? '$releasesUrl/tag/$tagName';
      return UpdateCheckResult.available(
        AppUpdateInfo(
          currentVersion: current,
          latestVersion: latest,
          releaseName: data['name']?.toString().trim().isNotEmpty == true
              ? data['name'].toString()
              : tagName,
          releaseUrl: releaseUrl,
          downloadUrl: rawDownloadUrl,
          downloadUrls: _downloadCandidates(rawDownloadUrl, githubProxyUrl),
          sha256: sha256 ?? '',
          body: body,
        ),
      );
    } catch (error) {
      return UpdateCheckResult.error(
        currentVersion: current,
        message: '检查更新失败，请稍后重试',
      );
    }
  }

  Future<File> downloadInstaller(
    AppUpdateInfo update, {
    required void Function(int received, int total) onProgress,
  }) async {
    final directory = AppStorageService.directory('updates');
    await directory.create(recursive: true);
    await AppStorageService.ensureCurrentUserAccess(directory);
    final file = File(
      '${directory.path}\\QingTingMusic-Setup-v${update.latestVersion}-x64.exe',
    );
    final partial = File('${file.path}.download');
    Object? lastError;
    for (final url in _effectiveDownloadUrls(update)) {
      try {
        if (await partial.exists()) await partial.delete();
        onProgress(0, 1);
        await _dio.download(
          url,
          partial.path,
          onReceiveProgress: onProgress,
          options: Options(
            followRedirects: true,
            receiveTimeout: const Duration(minutes: 10),
            headers: const {'Accept': 'application/octet-stream'},
          ),
        );
        await _validateInstaller(partial, update.sha256);
        if (await file.exists()) await file.delete();
        final completed = await partial.rename(file.path);
        await AppStorageService.ensureCurrentUserAccess(completed);
        return completed;
      } catch (error) {
        lastError = error;
        if (await partial.exists()) {
          try {
            await partial.delete();
          } catch (_) {}
        }
      }
    }
    throw StateError(_downloadFailureMessage(lastError));
  }

  Future<void> install(File installer) async {
    if (!await installer.exists()) {
      throw const FileSystemException('安装包不存在');
    }
    await Process.start(installer.path, const []);
  }

  Future<void> openReleasePage(String url) {
    if (Platform.isWindows) {
      return Process.start('cmd', ['/c', 'start', '', url]).then((_) {});
    }
    return Process.start('open', [url]).then((_) {});
  }

  Map<String, Object?>? _findInstallerAsset(Object? assets) {
    if (assets is! List) return null;
    for (final value in assets) {
      if (value is! Map) continue;
      final name = value['name']?.toString() ?? '';
      if (name.endsWith('.exe') &&
          name.contains('QingTingMusic-Setup') &&
          name.contains('x64')) {
        return value.cast<String, Object?>();
      }
    }
    return null;
  }

  List<String> _downloadCandidates(String url, String githubProxyUrl) {
    final candidates = <String>[url];
    final configured = _withGithubProxy(url, githubProxyUrl);
    if (configured != url) candidates.add(configured);
    for (final proxy in _fallbackGithubProxyUrls) {
      candidates.add(_withGithubProxy(url, proxy));
    }
    return candidates.toSet().toList();
  }

  List<String> _effectiveDownloadUrls(AppUpdateInfo update) {
    final urls = update.downloadUrls.isEmpty
        ? <String>[update.downloadUrl]
        : update.downloadUrls;
    return urls.where((url) => url.trim().isNotEmpty).toSet().toList();
  }

  String _withGithubProxy(String url, String githubProxyUrl) {
    final proxy = githubProxyUrl.trim();
    if (proxy.isEmpty || !url.startsWith('https://github.com/')) return url;
    final normalized = proxy.endsWith('/')
        ? proxy.substring(0, proxy.length - 1)
        : proxy;
    return '$normalized/$url';
  }

  Future<void> _validateInstaller(File file, String expectedSha256) async {
    if (!await file.exists() || await file.length() <= 1024 * 1024) {
      throw const FileSystemException('安装包内容为空或不完整');
    }
    final expected = expectedSha256.trim().toUpperCase();
    if (expected.isEmpty) return;
    final actual = await _sha256(file);
    if (actual != expected) {
      throw const FileSystemException('安装包校验失败');
    }
  }

  Future<String> _sha256(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString().toUpperCase();
  }

  Future<String?> _loadSha256FromAsset(
    Object? assets, {
    required String? assetName,
    required String githubProxyUrl,
  }) async {
    final name = assetName?.trim();
    if (assets is! List || name == null || name.isEmpty) return null;
    final shaAssetName = '$name.sha256';
    for (final value in assets) {
      if (value is! Map) continue;
      if (value['name']?.toString() != shaAssetName) continue;
      final rawUrl = value['browser_download_url']?.toString() ?? '';
      if (rawUrl.isEmpty) return null;
      for (final url in _downloadCandidates(rawUrl, githubProxyUrl)) {
        try {
          final response = await _dio.get<String>(
            url,
            options: Options(responseType: ResponseType.plain),
          );
          final hash = _extractSha256(response.data ?? '', assetName: name);
          if (hash != null) return hash;
        } catch (_) {}
      }
      return null;
    }
    return null;
  }

  String? _extractSha256(String body, {String? assetName}) {
    final normalizedBody = body.trim();
    if (normalizedBody.isEmpty) return null;
    final normalizedAsset = assetName?.trim();
    if (normalizedAsset != null && normalizedAsset.isNotEmpty) {
      final escaped = RegExp.escape(normalizedAsset);
      final assetPattern = RegExp(
        r'([A-Fa-f0-9]{64})\s+.*?' + escaped,
        caseSensitive: false,
      );
      final match = assetPattern.firstMatch(normalizedBody);
      if (match != null) return match.group(1)!.toUpperCase();
    }
    final labeledPattern = RegExp(
      r'SHA256\s*[:：]\s*`?([A-Fa-f0-9]{64})`?',
      caseSensitive: false,
    );
    final labeled = labeledPattern.firstMatch(normalizedBody);
    if (labeled != null) return labeled.group(1)!.toUpperCase();
    final plain = RegExp(r'\b[A-Fa-f0-9]{64}\b').firstMatch(normalizedBody);
    return plain?.group(0)?.toUpperCase();
  }

  String _downloadFailureMessage(Object? error) {
    final value = error?.toString() ?? '';
    if (value.contains('校验失败')) {
      return '安装包校验失败，请使用浏览器下载或稍后重试';
    }
    return '下载失败，请使用浏览器下载或稍后重试';
  }

  String _normalizeVersion(String value) {
    return value.trim().replaceFirst(RegExp(r'^[vV]'), '').split('+').first;
  }

  bool _isNewer(String latest, String current) {
    final left = _versionParts(latest);
    final right = _versionParts(current);
    for (var index = 0; index < 3; index++) {
      if (left[index] > right[index]) return true;
      if (left[index] < right[index]) return false;
    }
    return false;
  }

  List<int> _versionParts(String value) {
    final normalized = _normalizeVersion(value).split('-').first;
    final parts = normalized.split('.');
    return List<int>.generate(
      3,
      (index) => index < parts.length ? int.tryParse(parts[index]) ?? 0 : 0,
    );
  }

  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 15),
        headers: const {'User-Agent': 'QingTingMusic-Updater'},
      ),
    );
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.findProxy = (uri) {
          final raw =
              Platform.environment['HTTPS_PROXY'] ??
              Platform.environment['HTTP_PROXY'] ??
              Platform.environment['ALL_PROXY'];
          final proxy = raw == null ? null : Uri.tryParse(raw);
          return proxy == null ? 'DIRECT' : 'PROXY ${proxy.host}:${proxy.port}';
        };
        return client;
      },
    );
    return dio;
  }
}
