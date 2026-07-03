import 'dart:io';

import 'package:dio/dio.dart';
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
          downloadUrl: _withGithubProxy(rawDownloadUrl, githubProxyUrl),
          body: data['body']?.toString() ?? '',
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
    if (await partial.exists()) await partial.delete();
    await _dio.download(
      update.downloadUrl,
      partial.path,
      onReceiveProgress: onProgress,
      options: Options(
        followRedirects: true,
        receiveTimeout: const Duration(minutes: 10),
      ),
    );
    if (await file.exists()) await file.delete();
    final completed = await partial.rename(file.path);
    await AppStorageService.ensureCurrentUserAccess(completed);
    return completed;
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

  String _withGithubProxy(String url, String githubProxyUrl) {
    final proxy = githubProxyUrl.trim();
    if (proxy.isEmpty || !url.startsWith('https://github.com/')) return url;
    final normalized = proxy.endsWith('/')
        ? proxy.substring(0, proxy.length - 1)
        : proxy;
    return '$normalized/$url';
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
    return Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 15),
        headers: const {'User-Agent': 'QingTingMusic-Updater'},
      ),
    );
  }
}
