import 'package:flutter/material.dart';

import '../controllers/update_controller.dart';
import '../models/app_update.dart';
import '../theme/app_theme.dart';
import 'app_dialog.dart';

class UpdateDialog extends StatelessWidget {
  const UpdateDialog({super.key, required this.controller});

  final UpdateController controller;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final result = controller.lastResult;
        final update = result?.update;
        final title = switch (result?.status) {
          UpdateCheckStatus.available =>
            '发现新版本 ${update?.releaseName ?? update?.latestVersion ?? ''}',
          UpdateCheckStatus.latest => '已是最新版本',
          UpdateCheckStatus.error => '检查更新失败',
          _ => '检查更新',
        };
        final description = switch (result?.status) {
          UpdateCheckStatus.available =>
            '当前版本 v${update?.currentVersion ?? controller.currentVersion}，可升级到 v${update?.latestVersion ?? ''}。',
          UpdateCheckStatus.latest =>
            '当前版本 v${result?.currentVersion ?? controller.currentVersion} 已是最新版本。',
          UpdateCheckStatus.error =>
            result?.message.isNotEmpty == true
                ? result!.message
                : '暂时无法获取更新信息，请稍后再试。',
          _ => '正在检查是否有可用版本。',
        };
        return AppDialog(
          maxWidth: 500,
          icon: Icons.system_update_alt_rounded,
          title: title,
          subtitle: description,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((update?.body ?? '').trim().isNotEmpty) ...[
                Container(
                  constraints: const BoxConstraints(maxHeight: 220),
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1C222B)
                        : const Color(0xFFF3F6FA),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: _ReleaseNotesText(body: update!.body),
                  ),
                ),
              ],
              if (controller.downloadStatus ==
                      UpdateDownloadStatus.downloading ||
                  controller.downloadStatus ==
                      UpdateDownloadStatus.downloaded) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      controller.downloadStatus ==
                              UpdateDownloadStatus.downloaded
                          ? '下载完成'
                          : '${(controller.downloadProgress * 100).round()}%',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: controller.downloadStatus ==
                                  UpdateDownloadStatus.downloaded
                              ? 1
                              : controller.downloadProgress,
                          minHeight: 5,
                          backgroundColor: isDark
                              ? const Color(0xFF28303A)
                              : const Color(0xFFE2E8F0),
                          valueColor: AlwaysStoppedAnimation(AppColors.primary),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (controller.downloadStatus == UpdateDownloadStatus.error)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    controller.errorMessage.isEmpty
                        ? '下载失败，请稍后重试'
                        : controller.errorMessage,
                    style: TextStyle(color: AppColors.danger, fontSize: 12),
                  ),
                ),
            ],
          ),
          actions: [
            AppDialogButton.ghost(
              label: '稍后',
              onPressed: () => Navigator.of(context).pop(),
            ),
            if (result?.status == UpdateCheckStatus.available) ...[
              const SizedBox(width: 8),
              AppDialogButton.ghost(
                label: '前往下载',
                icon: Icons.open_in_new_rounded,
                onPressed: controller.openReleasePage,
              ),
              const SizedBox(width: 8),
              AppDialogButton.primary(
                label: switch (controller.downloadStatus) {
                  UpdateDownloadStatus.downloading => '下载中',
                  UpdateDownloadStatus.downloaded => '立即安装',
                  _ => '立即下载',
                },
                onPressed: controller.downloadStatus ==
                        UpdateDownloadStatus.downloading
                    ? null
                    : controller.downloadStatus ==
                            UpdateDownloadStatus.downloaded
                        ? controller.install
                        : controller.download,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ReleaseNotesText extends StatelessWidget {
  const _ReleaseNotesText({required this.body});

  final String body;

  @override
  Widget build(BuildContext context) {
    final lines = _cleanLines(body);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          Padding(
            padding: EdgeInsets.only(bottom: line.isHeading ? 8 : 6),
            child: Text(
              line.text,
              style: TextStyle(
                color: line.isHeading ? AppColors.text : AppColors.muted,
                fontSize: line.isHeading ? 14 : 13,
                height: 1.52,
                fontWeight: line.isHeading ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  List<_ReleaseNoteLine> _cleanLines(String raw) {
    final result = <_ReleaseNoteLine>[];
    var inFence = false;
    for (final source in raw.trim().split(RegExp(r'\r?\n'))) {
      var line = source.trim();
      if (line.startsWith('```')) {
        inFence = !inFence;
        continue;
      }
      if (inFence || line.isEmpty) continue;
      final heading = line.startsWith('#');
      line = line
          .replaceFirst(RegExp(r'^#{1,6}\s*'), '')
          .replaceFirst(RegExp(r'^[-*]\s+'), '')
          .replaceAllMapped(
            RegExp(r'\[([^\]]+)\]\([^)]+\)'),
            (match) => match.group(1) ?? '',
          )
          .replaceAll(RegExp(r'[`*_]'), '')
          .trim();
      if (line.isEmpty) continue;
      result.add(_ReleaseNoteLine(heading ? line : '• $line', heading));
    }
    return result;
  }
}

class _ReleaseNoteLine {
  const _ReleaseNoteLine(this.text, this.isHeading);

  final String text;
  final bool isHeading;
}
