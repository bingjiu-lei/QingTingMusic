import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../controllers/music_library_controller.dart';
import '../models/song.dart';
import '../services/cloud_upload_service.dart';
import '../services/kugou_api_client.dart';
import '../theme/app_theme.dart';
import 'app_dialog.dart';

class CloudUploadDialog extends StatefulWidget {
  const CloudUploadDialog({
    super.key,
    required this.song,
    required this.apiClient,
    this.libraryController,
    this.barrierDismissible = false,
  });

  final Song song;
  final KugouApiClient apiClient;
  final MusicLibraryController? libraryController;
  final bool barrierDismissible;

  static Future<bool?> show(
    BuildContext context, {
    required Song song,
    required KugouApiClient apiClient,
    MusicLibraryController? libraryController,
    bool barrierDismissible = false,
  }) {
    return showDialog<bool>(
      context: context,
      // 保持底层的 route barrier 为 true，避免 Flutter 在 Windows 上点击遮罩时触发系统警报提示音（SystemSound.play(SystemSoundType.alert)）
      // 实际是否允许点击外部关闭由 CloudUploadDialog 内部的 PopScope 及 widget.barrierDismissible 严格控制
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (context) => CloudUploadDialog(
        song: song,
        apiClient: apiClient,
        libraryController: libraryController,
        barrierDismissible: barrierDismissible,
      ),
    );
  }

  @override
  State<CloudUploadDialog> createState() => _CloudUploadDialogState();
}

class _CloudUploadDialogState extends State<CloudUploadDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _artistController;
  late final TextEditingController _searchController;

  int? _matchedAudioId;
  int? _matchedAlbumAudioId;
  String? _matchedHashStd;
  String _matchedDisplay = '';

  bool _showSearchPicker = false;
  bool _isSearching = false;
  List<Song> _searchResults = const [];

  bool _isUploading = false;
  CancelToken? _cancelToken;
  double _progress = 0.0;
  String _statusMessage = '';
  String _detailsMessage = '';
  String? _errorMessage;
  bool _isDone = false;
  bool _canPop = false;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.song.title);
    _artistController = TextEditingController(text: widget.song.artist);
    _searchController = TextEditingController(
      text: '${widget.song.title} ${widget.song.artist}'.trim(),
    );

    _matchedAudioId = widget.song.fileId ?? 0;
    _matchedAlbumAudioId = widget.song.albumAudioId ?? 0;
    _matchedHashStd = widget.song.catalogHash ?? widget.song.hash ?? '';
    _matchedDisplay = '${widget.song.artist} - ${widget.song.title}';
  }

  void _cancel() {
    if (_isClosing) return;
    _isClosing = true;

    if (_isUploading) {
      _cancelToken?.cancel('用户取消了转存');
      _cancelToken = null;
    }
    if (!mounted) return;
    setState(() {
      _isUploading = false;
      _canPop = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pop(false);
      }
    });
  }

  void _finish() {
    if (_isClosing) return;
    _isClosing = true;

    if (!mounted) return;
    setState(() {
      _canPop = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    });
  }

  @override
  void dispose() {
    _cancelToken?.cancel('弹窗关闭');
    _titleController.dispose();
    _artistController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String get _sourceBadgeText {
    if (widget.song.isMv || widget.song.playbackQuality == 'MV') {
      return 'MV 音频提取';
    }
    return '特殊解析音源';
  }

  void _clearMatch() {
    setState(() {
      _matchedAudioId = 0;
      _matchedAlbumAudioId = 0;
      _matchedHashStd = '';
      _matchedDisplay = '';
      _showSearchPicker = false;
    });
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchResults = const [];
    });

    try {
      final results = await widget.apiClient.searchSongs(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  void _selectMatch(Song candidate) {
    setState(() {
      _matchedAudioId = candidate.fileId ?? 0;
      _matchedAlbumAudioId = candidate.albumAudioId ?? 0;
      _matchedHashStd = candidate.catalogHash ?? candidate.hash ?? '';
      _matchedDisplay = '${candidate.artist} - ${candidate.title}';
      _showSearchPicker = false;
    });
  }

  Future<void> _startUpload() async {
    if (_isUploading) return;

    final cancelToken = CancelToken();
    _cancelToken = cancelToken;

    setState(() {
      _isUploading = true;
      _errorMessage = null;
      _progress = 0.05;
      _statusMessage = '正在准备转存...';
      _detailsMessage = '';
    });

    try {
      final service = CloudUploadService(apiClient: widget.apiClient);
      final result = await service.uploadSpecialSongToCloud(
        song: widget.song,
        customTitle: _titleController.text.trim(),
        customArtist: _artistController.text.trim(),
        matchedAudioId: _matchedAudioId,
        matchedAlbumAudioId: _matchedAlbumAudioId,
        matchedHashStd: _matchedHashStd,
        cancelToken: cancelToken,
        onProgress: (prog) {
          if (mounted && !cancelToken.isCancelled) {
            setState(() {
              _progress = prog.progress;
              _statusMessage = prog.message;
              if (prog.details.isNotEmpty) {
                _detailsMessage = prog.details;
              }
            });
          }
        },
      );

      if (mounted && !cancelToken.isCancelled) {
        setState(() {
          _isUploading = false;
          _isDone = true;
          _progress = 1.0;
          _statusMessage = result.message;
        });
        unawaited(
          widget.libraryController?.ensureLoaded(
            LibrarySection.cloud,
            refresh: true,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        if (cancelToken.isCancelled) {
          _errorMessage = null;
        } else {
          _errorMessage = e
              .toString()
              .replaceFirst('Exception: ', '')
              .replaceFirst('KugouApiException: ', '');
        }
      });
    } finally {
      if (identical(_cancelToken, cancelToken)) {
        _cancelToken = null;
      }
      if (mounted && _isUploading) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;
    final isMv = widget.song.isMv || widget.song.playbackQuality == 'MV';
    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (widget.barrierDismissible) {
          _cancel();
        }
      },
      child: AppDialog(
        maxWidth: 480,
        showCloseButton: true,
        onClose: _cancel,
        icon: Icons.cloud_upload_rounded,
        iconColor: AppColors.primary,
        iconBackgroundColor: AppColors.primary.withValues(alpha: 0.12),
        title: '转存到个人云盘',
        subtitle: '将当前解析的特殊音源保存至个人酷狗云盘。',
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 来源标签指示
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(
                  alpha: isDark ? 0.12 : 0.08,
                ),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isMv ? Icons.video_library_rounded : Icons.auto_awesome,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '当前音源：$_sourceBadgeText',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 歌曲名称与歌手输入
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '歌曲名称',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AppDialogTextField(
                        controller: _titleController,
                        hintText: '请输入歌曲名',
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '歌手',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AppDialogTextField(
                        controller: _artistController,
                        hintText: '请输入歌手',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 曲库关联信息卡片
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.link_rounded,
                        size: 15,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '关联酷狗官方曲库原曲',
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      if (!_isUploading && !_isDone) ...[
                        if (_matchedDisplay.isNotEmpty) ...[
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _clearMatch,
                            child: Text(
                              '去除关联',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            setState(() {
                              _showSearchPicker = !_showSearchPicker;
                              if (_showSearchPicker && _searchResults.isEmpty) {
                                _performSearch();
                              }
                            });
                          },
                          child: Text(
                            _showSearchPicker
                                ? '收起搜索'
                                : (_matchedDisplay.isNotEmpty ? '重新匹配' : '关联原曲'),
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _matchedDisplay.isNotEmpty
                        ? '已关联：$_matchedDisplay'
                        : '未关联官方曲库（作为独立纯云盘音频保存）',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _matchedDisplay.isNotEmpty
                          ? AppColors.text
                          : AppColors.muted,
                      fontSize: 12,
                      fontWeight: _matchedDisplay.isNotEmpty
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),

                  // 搜索选择列表展开面板
                  if (_showSearchPicker) ...[
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: AppDialogTextField(
                            controller: _searchController,
                            hintText: '搜索曲库原曲...',
                            onSubmitted: (_) => _performSearch(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        AppDialogButton(
                          label: '搜索',
                          onPressed: _isSearching ? null : _performSearch,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_isSearching)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    else if (_searchResults.isNotEmpty)
                      Container(
                        constraints: const BoxConstraints(maxHeight: 160),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _searchResults.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = _searchResults[index];
                            return ListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              title: Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                              subtitle: Text(
                                '${item.artist} - ${item.album}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.muted,
                                ),
                              ),
                              trailing: AppDialogButton(
                                label: '匹配',
                                isPrimary: true,
                                onPressed: () => _selectMatch(item),
                              ),
                            );
                          },
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          '未搜索到匹配结果',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),

            // 错误提示
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 16,
                      color: AppColors.danger,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: AppColors.danger, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 上传进度展示
            if (_isUploading || _isDone) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 6,
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _isDone ? const Color(0xFF10B981) : AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: TextStyle(
                        color: _isDone
                            ? const Color(0xFF10B981)
                            : AppColors.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '${(_progress * 100).toInt()}%',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (_detailsMessage.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  _detailsMessage,
                  style: TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        if (!_isDone) ...[
          AppDialogButton(
            label: '取消',
            onPressed: _cancel,
          ),
          const SizedBox(width: 10),
        ],
        AppDialogButton(
          label: _isDone
              ? '完成'
              : (_isUploading
                    ? '转存中...'
                    : (_errorMessage != null ? '重试转存' : '开始转存')),
          isPrimary: true,
          icon: _isDone ? Icons.check_rounded : Icons.cloud_upload_outlined,
          onPressed: _isDone
              ? _finish
              : (_isUploading ? null : _startUpload),
        ),
      ],
    ),
  );
  }
}
