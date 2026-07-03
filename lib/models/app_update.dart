enum UpdateCheckStatus { idle, checking, latest, available, error }

enum UpdateDownloadStatus { idle, downloading, downloaded, error }

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseName,
    required this.releaseUrl,
    required this.downloadUrl,
    this.downloadUrls = const [],
    this.sha256 = '',
    this.body = '',
  });

  final String currentVersion;
  final String latestVersion;
  final String releaseName;
  final String releaseUrl;
  final String downloadUrl;
  final List<String> downloadUrls;
  final String sha256;
  final String body;
}

class UpdateCheckResult {
  const UpdateCheckResult.latest({required this.currentVersion})
    : status = UpdateCheckStatus.latest,
      update = null,
      message = '';

  UpdateCheckResult.available(AppUpdateInfo updateInfo)
    : status = UpdateCheckStatus.available,
      currentVersion = updateInfo.currentVersion,
      update = updateInfo,
      message = '';

  const UpdateCheckResult.error({
    required this.currentVersion,
    required this.message,
  }) : status = UpdateCheckStatus.error,
       update = null;

  final UpdateCheckStatus status;
  final String currentVersion;
  final AppUpdateInfo? update;
  final String message;
}
