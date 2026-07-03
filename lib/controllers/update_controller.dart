import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/app_update.dart';
import '../services/app_preferences_service.dart';
import '../services/app_update_service.dart';

class UpdateController extends ChangeNotifier {
  UpdateController({
    AppUpdateService? updateService,
    AppPreferencesService? preferences,
  }) : _updateService = updateService ?? AppUpdateService(),
       _preferences = preferences ?? AppPreferencesService();

  static const _autoCheckKey = 'updates.autoCheck';
  static const _githubProxyKey = 'updates.githubProxyUrl';

  final AppUpdateService _updateService;
  final AppPreferencesService _preferences;

  UpdateCheckStatus checkStatus = UpdateCheckStatus.idle;
  UpdateDownloadStatus downloadStatus = UpdateDownloadStatus.idle;
  UpdateCheckResult? lastResult;
  File? downloadedInstaller;
  String currentVersion = '';
  String errorMessage = '';
  double downloadProgress = 0;
  bool autoCheck = true;
  String githubProxyUrl = '';

  bool get hasUpdate => lastResult?.status == UpdateCheckStatus.available;
  AppUpdateInfo? get update => lastResult?.update;

  Future<void> initialize({bool useFallbackVersion = false}) async {
    currentVersion = await _updateService.currentVersion(
      useFallback: useFallbackVersion,
    );
    final storedAutoCheck = await _preferences.read(_autoCheckKey);
    autoCheck = storedAutoCheck is bool ? storedAutoCheck : true;
    githubProxyUrl =
        (await _preferences.read(_githubProxyKey))?.toString() ?? '';
    notifyListeners();
  }

  Future<void> setAutoCheck(bool value) async {
    autoCheck = value;
    notifyListeners();
    await _preferences.write(_autoCheckKey, value);
  }

  Future<void> setGithubProxyUrl(String value) async {
    githubProxyUrl = value.trim();
    notifyListeners();
    await _preferences.write(_githubProxyKey, githubProxyUrl);
  }

  Future<UpdateCheckResult> check({bool silent = false}) async {
    if (checkStatus == UpdateCheckStatus.checking) {
      return lastResult ??
          UpdateCheckResult.latest(currentVersion: currentVersion);
    }
    checkStatus = UpdateCheckStatus.checking;
    errorMessage = '';
    if (!silent) {
      lastResult = null;
      downloadStatus = UpdateDownloadStatus.idle;
      downloadProgress = 0;
      downloadedInstaller = null;
    }
    notifyListeners();
    final result = await _updateService.checkForUpdates(
      githubProxyUrl: githubProxyUrl,
    );
    lastResult = result;
    checkStatus = result.status;
    currentVersion = result.currentVersion;
    errorMessage = result.message;
    notifyListeners();
    return result;
  }

  Future<void> download() async {
    final next = update;
    if (next == null || downloadStatus == UpdateDownloadStatus.downloading) {
      return;
    }
    downloadStatus = UpdateDownloadStatus.downloading;
    downloadProgress = 0;
    errorMessage = '';
    downloadedInstaller = null;
    notifyListeners();
    try {
      downloadedInstaller = await _updateService.downloadInstaller(
        next,
        onProgress: (received, total) {
          if (total <= 0) return;
          downloadProgress = (received / total).clamp(0, 1);
          notifyListeners();
        },
      );
      downloadProgress = 1;
      downloadStatus = UpdateDownloadStatus.downloaded;
    } catch (error) {
      downloadStatus = UpdateDownloadStatus.error;
      errorMessage = error.toString().replaceFirst(
        RegExp(r'^(Bad state|StateError):\s*'),
        '',
      );
    }
    notifyListeners();
  }

  Future<void> install() async {
    final installer = downloadedInstaller;
    if (installer == null) return;
    await _updateService.install(installer);
    Timer(const Duration(milliseconds: 500), () => exit(0));
  }

  Future<void> openReleasePage() async {
    final url = update?.releaseUrl ?? AppUpdateService.releasesUrl;
    await _updateService.openReleasePage(url);
  }
}
