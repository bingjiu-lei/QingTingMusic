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
          maxWidth: 540,
          icon: Icons.system_update_alt_rounded,
          title: title,
          subtitle: description,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((update?.body ?? '').trim().isNotEmpty) ...[
                Container(
                  constraints: const BoxConstraints(maxHeight: 340),
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF161B22)
                        : const Color(0xFFF6F8FA),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF30363D)
                          : const Color(0xFFD0D7DE),
                    ),
                  ),
                  child: _ReleaseNotesView(body: update!.body),
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
                          value:
                              controller.downloadStatus ==
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
                onPressed:
                    controller.downloadStatus ==
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

class _ReleaseNotesView extends StatefulWidget {
  const _ReleaseNotesView({required this.body});

  final String body;

  @override
  State<_ReleaseNotesView> createState() => _ReleaseNotesViewState();
}

class _ReleaseNotesViewState extends State<_ReleaseNotesView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _scrollController,
        child: Padding(
          padding: const EdgeInsets.only(right: 6),
          child: _ReleaseNotesMarkdown(body: widget.body),
        ),
      ),
    );
  }
}

class _ReleaseNotesMarkdown extends StatelessWidget {
  const _ReleaseNotesMarkdown({required this.body});

  final String body;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;
    final elements = _parseMarkdown(body);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final element in elements) _buildElement(element, isDark),
      ],
    );
  }

  Widget _buildElement(_MarkdownElement element, bool isDark) {
    return switch (element) {
      _HeadingElement heading => _buildHeading(heading, isDark),
      _ListItemElement item => _buildListItem(item, isDark),
      _CodeBlockElement codeBlock => _buildCodeBlock(codeBlock, isDark),
      _BlockquoteElement quote => _buildBlockquote(quote, isDark),
      _DividerElement _ => _buildDivider(isDark),
      _ParagraphElement paragraph => _buildParagraph(paragraph, isDark),
    };
  }

  Widget _buildHeading(_HeadingElement heading, bool isDark) {
    final textColor = isDark
        ? const Color(0xFFF0F6FC)
        : const Color(0xFF1F2328);

    if (heading.level == 1) {
      return Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 12),
        child: Text(
          heading.text,
          style: TextStyle(
            color: textColor,
            fontSize: 18.5,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
      );
    } else if (heading.level == 2) {
      // GitHub-style H2 with bottom border divider
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 6),
            child: Text(
              heading.text,
              style: TextStyle(
                color: textColor,
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
          Container(
            height: 1,
            width: double.infinity,
            color: isDark ? const Color(0xFF21262D) : const Color(0xFFD8DEE4),
          ),
          const SizedBox(height: 8),
        ],
      );
    } else {
      return Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 5),
        child: Text(
          heading.text,
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
      );
    }
  }

  Widget _buildListItem(_ListItemElement item, bool isDark) {
    return Padding(
      padding: EdgeInsets.only(
        left: item.level * 20.0,
        bottom: item.level == 0 ? 6.0 : 4.0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBullet(item.level, isDark, item.orderNumber),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: _parseInlineMarkdown(
                  item.text,
                  isDark: isDark,
                  baseStyle: TextStyle(
                    color: item.level == 0
                        ? (isDark
                              ? const Color(0xFFE6EDF3)
                              : const Color(0xFF1F2328))
                        : (isDark
                              ? const Color(0xFFC9D1D9)
                              : const Color(0xFF24292F)),
                    fontSize: item.level == 0 ? 13.5 : 13.0,
                    height: 1.55,
                    fontWeight: item.level == 0
                        ? FontWeight.w500
                        : FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBullet(int level, bool isDark, int? orderNumber) {
    if (orderNumber != null) {
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Text(
          '$orderNumber.',
          style: TextStyle(
            color: isDark ? const Color(0xFF8B949E) : const Color(0xFF57606A),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.55,
          ),
        ),
      );
    }

    if (level == 0) {
      // Solid filled circle for top-level list items
      return Container(
        width: 5,
        height: 5,
        margin: const EdgeInsets.only(top: 7.5, right: 9),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF8B949E) : const Color(0xFF57606A),
          shape: BoxShape.circle,
        ),
      );
    } else if (level == 1) {
      // Hollow / open circle for second-level nested list items (GitHub style)
      return Container(
        width: 5,
        height: 5,
        margin: const EdgeInsets.only(top: 7.5, right: 9),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? const Color(0xFF8B949E) : const Color(0xFF57606A),
            width: 1.2,
          ),
        ),
      );
    } else {
      // Small square for deeply nested list items
      return Container(
        width: 4.5,
        height: 4.5,
        margin: const EdgeInsets.only(top: 7.5, right: 9),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF8B949E) : const Color(0xFF57606A),
          borderRadius: BorderRadius.circular(1),
        ),
      );
    }
  }

  Widget _buildCodeBlock(_CodeBlockElement codeBlock, bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : const Color(0xFFEAEFF5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE),
          width: 0.8,
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Text(
          codeBlock.code,
          style: TextStyle(
            fontFamily: 'Consolas',
            fontSize: 12,
            height: 1.45,
            color: isDark ? const Color(0xFFE6EDF3) : const Color(0xFF1F2328),
          ),
        ),
      ),
    );
  }

  Widget _buildBlockquote(_BlockquoteElement quote, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE),
            width: 3.5,
          ),
        ),
      ),
      child: Text.rich(
        TextSpan(
          children: _parseInlineMarkdown(
            quote.text,
            isDark: isDark,
            baseStyle: TextStyle(
              color: isDark ? const Color(0xFF8B949E) : const Color(0xFF57606A),
              fontSize: 13,
              height: 1.5,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        height: 1,
        width: double.infinity,
        color: isDark ? const Color(0xFF21262D) : const Color(0xFFD8DEE4),
      ),
    );
  }

  Widget _buildParagraph(_ParagraphElement paragraph, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(
          children: _parseInlineMarkdown(
            paragraph.text,
            isDark: isDark,
            baseStyle: TextStyle(
              color: isDark ? const Color(0xFFE6EDF3) : const Color(0xFF1F2328),
              fontSize: 13.5,
              height: 1.55,
            ),
          ),
        ),
      ),
    );
  }

  static List<_MarkdownElement> _parseMarkdown(String raw) {
    final elements = <_MarkdownElement>[];
    final lines = raw.split(RegExp(r'\r?\n'));
    bool inCodeBlock = false;
    final codeBuffer = StringBuffer();
    String? codeLang;

    for (int i = 0; i < lines.length; i++) {
      final rawLine = lines[i];

      if (rawLine.trim().startsWith('```')) {
        if (inCodeBlock) {
          elements.add(
            _CodeBlockElement(
              code: codeBuffer.toString().trimRight(),
              language: codeLang,
            ),
          );
          codeBuffer.clear();
          codeLang = null;
          inCodeBlock = false;
        } else {
          inCodeBlock = true;
          codeLang = rawLine.trim().substring(3).trim();
        }
        continue;
      }

      if (inCodeBlock) {
        codeBuffer.writeln(rawLine);
        continue;
      }

      final trimmed = rawLine.trim();
      if (trimmed.isEmpty) {
        continue;
      }

      // Horizontal rule
      if (RegExp(r'^(-{3,}|\*{3,}|_{3,})$').hasMatch(trimmed)) {
        elements.add(_DividerElement());
        continue;
      }

      // Heading (# to ######)
      final headingMatch = RegExp(
        r'^(#{1,6})\s+(.*?)(?:\s+#+)?$',
      ).firstMatch(trimmed);
      if (headingMatch != null) {
        final level = headingMatch.group(1)!.length;
        final text = headingMatch.group(2)!.trim();
        elements.add(_HeadingElement(level: level, text: text));
        continue;
      }

      // Blockquote
      if (trimmed.startsWith('>')) {
        final text = trimmed.substring(1).trim();
        elements.add(_BlockquoteElement(text: text));
        continue;
      }

      // Unordered list item
      final listMatch = RegExp(r'^(\s*)([-*+])\s+(.*)$').firstMatch(rawLine);
      if (listMatch != null) {
        final indentStr = listMatch.group(1)!;
        final content = listMatch.group(3)!.trim();
        final spaces = indentStr.replaceAll('\t', '  ').length;
        final level = (spaces / 2).floor().clamp(0, 3);
        elements.add(_ListItemElement(level: level, text: content));
        continue;
      }

      // Ordered list item
      final orderedMatch = RegExp(r'^(\s*)(\d+)\.\s+(.*)$').firstMatch(rawLine);
      if (orderedMatch != null) {
        final indentStr = orderedMatch.group(1)!;
        final num = int.tryParse(orderedMatch.group(2)!);
        final content = orderedMatch.group(3)!.trim();
        final spaces = indentStr.replaceAll('\t', '  ').length;
        final level = (spaces / 2).floor().clamp(0, 3);
        elements.add(
          _ListItemElement(level: level, text: content, orderNumber: num),
        );
        continue;
      }

      // Regular paragraph
      elements.add(_ParagraphElement(text: trimmed));
    }

    if (inCodeBlock && codeBuffer.isNotEmpty) {
      elements.add(
        _CodeBlockElement(
          code: codeBuffer.toString().trimRight(),
          language: codeLang,
        ),
      );
    }

    return elements;
  }

  static List<InlineSpan> _parseInlineMarkdown(
    String text, {
    required bool isDark,
    required TextStyle baseStyle,
  }) {
    final spans = <InlineSpan>[];
    final regex = RegExp(
      r'(\*\*(.+?)\*\*)|(`(.+?)`)|(\*(.+?)\*)|(\[([^\]]+)\]\(([^)]+)\))',
    );
    int lastIndex = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, match.start),
            style: baseStyle,
          ),
        );
      }

      if (match.group(2) != null) {
        // **bold**
        spans.add(
          TextSpan(
            text: match.group(2),
            style: baseStyle.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFFF0F6FC) : const Color(0xFF1F2328),
            ),
          ),
        );
      } else if (match.group(4) != null) {
        // `code`
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF262C36)
                    : const Color(0xFFEAEEF2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.08),
                  width: 0.8,
                ),
              ),
              child: Text(
                match.group(4)!,
                style: TextStyle(
                  fontSize: (baseStyle.fontSize ?? 13) * 0.9,
                  fontFamily: 'Consolas',
                  color: isDark
                      ? const Color(0xFFE6EDF3)
                      : const Color(0xFF1F2328),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      } else if (match.group(6) != null) {
        // *italic*
        spans.add(
          TextSpan(
            text: match.group(6),
            style: baseStyle.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      } else if (match.group(8) != null) {
        // [text](url)
        spans.add(
          TextSpan(
            text: match.group(8),
            style: baseStyle.copyWith(
              color: AppColors.primary,
              decoration: TextDecoration.underline,
            ),
          ),
        );
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex), style: baseStyle));
    }

    return spans;
  }
}

sealed class _MarkdownElement {}

class _HeadingElement extends _MarkdownElement {
  _HeadingElement({required this.level, required this.text});
  final int level;
  final String text;
}

class _ListItemElement extends _MarkdownElement {
  _ListItemElement({required this.level, required this.text, this.orderNumber});
  final int level;
  final String text;
  final int? orderNumber;
}

class _BlockquoteElement extends _MarkdownElement {
  _BlockquoteElement({required this.text});
  final String text;
}

class _CodeBlockElement extends _MarkdownElement {
  _CodeBlockElement({required this.code, this.language});
  final String code;
  final String? language;
}

class _DividerElement extends _MarkdownElement {}

class _ParagraphElement extends _MarkdownElement {
  _ParagraphElement({required this.text});
  final String text;
}
