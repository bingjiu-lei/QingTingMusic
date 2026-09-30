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

  /// 清理 MV 标题及多余标签词，提取纯净的歌名与歌手
  static ({String title, String artist}) cleanMvMetadata({
    required String rawTitle,
    required String rawArtist,
  }) {
    var title = rawTitle.trim();
    var artist = rawArtist.trim();

    // 1. 清理首部括号视频标签，如 【4K 60帧】、[MV]、(MV)、【官方MV】等
    final prefixBracketRegex = RegExp(
      r'^(?:[\(\[\{【（][^\)\]\}】）]*(?:4k|1080p|720p|超清|高清|无损|完整版|纯享版|60帧|official|music\s*video|dance\s*practice|performance\s*video|mv|现场版|live|官方|首播|预告|修复|自制|杜比)[^\)\]\}】）]*[\)\]\}】）]\s*)+',
      caseSensitive: false,
    );
    title = title.replaceAll(prefixBracketRegex, '').trim();
    artist = artist.replaceAll(prefixBracketRegex, '').trim();

    // 2. 清理尾部括号标签或以空格分隔的独立后缀标签，如 (Official Music Video)、【MV】、 MV、 1080P
    final suffixBracketRegex = RegExp(
      r'(?:[\(\[\{【（][^\)\]\}】）]*(?:4k|1080p|720p|超清|高清|无损|完整版|纯享版|原画|杜比|dolby|hdr|60帧|official\s*(?:music\s*video|mv|audio)?|music\s*video|dance\s*practice|performance\s*video|mv|现场版|live版?|官方mv|官方视频|首播|预告|修复)[^\)\]\}】）]*[\)\]\}】）]\s*)+$',
      caseSensitive: false,
    );
    title = title.replaceAll(suffixBracketRegex, '').trim();

    final suffixStandaloneRegex = RegExp(
      r'(?:(?:\s+|(?<=[\)\]\}】）》]))[\-–—_]?\s*(?:4k|1080p|720p|超清|高清|无损|完整版|纯享版|原画|杜比|dolby|hdr|60帧|official\s*(?:music\s*video|mv|audio)?|music\s*video|dance\s*practice|performance\s*video|mv|现场版|live版?|官方mv|官方视频|首播|预告|修复))+\s*$',
      caseSensitive: false,
    );
    title = title.replaceAll(suffixStandaloneRegex, '').trim();

    // 3. 如果包含常见的 "歌手 - 歌名" 或 "歌手 _ 歌名" 结构
    final dashSplit = title.split(RegExp(r'\s*[-–—_]\s*'));
    if (dashSplit.length == 2) {
      var part0 = dashSplit[0].trim();
      var part1 = dashSplit[1].trim();
      part0 = part0
          .replaceAll(prefixBracketRegex, '')
          .replaceAll(suffixBracketRegex, '')
          .replaceAll(suffixStandaloneRegex, '')
          .trim();
      part1 = part1
          .replaceAll(prefixBracketRegex, '')
          .replaceAll(suffixBracketRegex, '')
          .replaceAll(suffixStandaloneRegex, '')
          .trim();
      if (artist.isEmpty || artist == '未知歌手') {
        artist = part0;
        title = part1;
      } else if (artist.toLowerCase() == part0.toLowerCase() ||
          part0.toLowerCase().startsWith(artist.toLowerCase())) {
        title = part1;
      }
    }

    // 4. 检查是否有包含在单双引号/书名号中的歌名（例如: IVE ‘BANG BANG’ 或 aespa 《Whiplash》）
    final quoteMatch =
        RegExp(r'''^(.+?)\s*['‘“"『「《](.+?)['’”"』」》]''').firstMatch(title);
    if (quoteMatch != null) {
      final potentialArtist = quoteMatch.group(1)!.trim();
      final potentialTitle = quoteMatch.group(2)!.trim();
      if (potentialTitle.isNotEmpty) {
        if (artist.isEmpty || artist == '未知歌手') {
          artist = potentialArtist;
          title = potentialTitle;
        } else if (artist.toLowerCase() == potentialArtist.toLowerCase() ||
            potentialArtist.toLowerCase().startsWith(artist.toLowerCase())) {
          title = potentialTitle;
        }
      }
    }

    // 5. 如果歌名以歌手名开头（例如 "IVE BANG BANG"）
    if (artist.isNotEmpty &&
        title.toLowerCase().startsWith(artist.toLowerCase())) {
      title = title.substring(artist.length).trim();
    }

    // 6. 清理整体被书名号包裹的情况（如《七里香》或【七里香】）
    if ((title.startsWith('《') && title.endsWith('》')) ||
        (title.startsWith('【') && title.endsWith('】')) ||
        (title.startsWith('『') && title.endsWith('』')) ||
        (title.startsWith('「') && title.endsWith('」'))) {
      title = title.substring(1, title.length - 1).trim();
    }

    // 7. 清理首尾可能残留的单双引号、空格或连接符（保留标题中合法的副标题圆括号）
    title = title
        .replaceAll(RegExp(r'''^[\s\-–—:_：'‘"“]+'''), '')
        .replaceAll(RegExp(r'''[\s\-–—:_：'’"”]+$'''), '')
        .trim();

    // 兜底：如果清理后标题变空，回退到原始值
    if (title.isEmpty) {
      title = rawTitle.trim();
    }
    if (artist.isEmpty) {
      artist = rawArtist.trim();
    }

    return (title: title, artist: artist);
  }

  /// 高置信度曲库匹配算法
  /// 只有当歌曲包含真实的音频ID或标准hash，且标题与歌手高度吻合时才自动建立关联
  static Song? findHighConfidenceMatch({
    required List<Song> results,
    required String targetTitle,
    required String targetArtist,
  }) {
    if (results.isEmpty) return null;

    final normTargetTitle = _normalizeMatchString(targetTitle);
    final normTargetArtist = _normalizeMatchString(targetArtist);

    // 如果标题或歌手为空，无法确保高置信度，不自动关联，交由用户手动关联
    if (normTargetTitle.isEmpty || normTargetArtist.isEmpty) {
      return null;
    }

    Song? fallbackMatch;

    for (final candidate in results) {
      final hasValidId = ((candidate.fileId ?? 0) > 0) ||
          ((candidate.albumAudioId ?? 0) > 0) ||
          (candidate.catalogHash != null && candidate.catalogHash!.isNotEmpty) ||
          (candidate.hash != null && candidate.hash!.isNotEmpty);
      if (!hasValidId) continue;

      final candTitleLower = candidate.title.toLowerCase();
      // 避免误匹配为伴奏/伴唱
      final isInstrumental = candTitleLower.contains('伴奏') ||
          candTitleLower.contains('instrumental') ||
          candTitleLower.contains('karaoke');

      final normCandTitle = _normalizeMatchString(candidate.title);
      final normCandArtist = _normalizeMatchString(candidate.artist);

      // 标题匹配校验：完全一致，或长标题包含短标题且长度差异不大
      final isExactTitle = normCandTitle == normTargetTitle;
      final isFuzzyTitle = !isExactTitle &&
          (normCandTitle.contains(normTargetTitle) ||
              normTargetTitle.contains(normCandTitle)) &&
          (normCandTitle.length - normTargetTitle.length).abs() <= 6;

      if (!isExactTitle && !isFuzzyTitle) continue;

      // 歌手匹配校验：必须相互包含（支持中英文/韩文别名等）
      final isArtistMatch = normCandArtist == normTargetArtist ||
          normCandArtist.contains(normTargetArtist) ||
          normTargetArtist.contains(normCandArtist);

      if (!isArtistMatch) continue;

      // 优先选择非伴奏的标准原曲
      if (!isInstrumental) {
        if (isExactTitle) {
          return candidate;
        }
        fallbackMatch ??= candidate;
      } else {
        fallbackMatch ??= candidate;
      }
    }

    return fallbackMatch;
  }

  static String _normalizeMatchString(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[\s\p{P}\p{S}]', unicode: true), '');
  }

  /// 检查当前匹配的歌曲是否已存在于个人云盘列表中
  static bool isMatchedSongInCloud({
    required List<Song> cloudSongs,
    int? matchedAudioId,
    int? matchedAlbumAudioId,
    String? matchedHashStd,
    required String matchedTitle,
    required String matchedArtist,
  }) {
    if (cloudSongs.isEmpty) return false;

    final normTargetTitle = _normalizeMatchString(matchedTitle);
    final normTargetArtist = _normalizeMatchString(matchedArtist);
    final normHash = matchedHashStd?.trim().toLowerCase() ?? '';

    for (final cloudSong in cloudSongs) {
      // 1. 比对音频 ID (audio_id / mixsongid / fileId)
      if (matchedAudioId != null && matchedAudioId > 0) {
        if (cloudSong.cloudAudioId == matchedAudioId ||
            cloudSong.fileId == matchedAudioId ||
            cloudSong.albumAudioId == matchedAudioId) {
          return true;
        }
      }
      if (matchedAlbumAudioId != null && matchedAlbumAudioId > 0) {
        if (cloudSong.albumAudioId == matchedAlbumAudioId ||
            cloudSong.cloudAudioId == matchedAlbumAudioId ||
            cloudSong.fileId == matchedAlbumAudioId) {
          return true;
        }
      }

      // 2. 比对标准 Hash / 哈希特征
      if (normHash.isNotEmpty) {
        final cHash = cloudSong.hash?.trim().toLowerCase() ?? '';
        final cCatHash = cloudSong.catalogHash?.trim().toLowerCase() ?? '';
        if ((cHash.isNotEmpty && cHash == normHash) ||
            (cCatHash.isNotEmpty && cCatHash == normHash)) {
          return true;
        }
      }

      // 3. 比对歌名与歌手（规范化去空格标点匹配）
      if (normTargetTitle.isNotEmpty && normTargetArtist.isNotEmpty) {
        final cTitle = _normalizeMatchString(cloudSong.title);
        final cArtist = _normalizeMatchString(cloudSong.artist);
        if (cTitle == normTargetTitle) {
          if (cArtist == normTargetArtist ||
              cArtist.contains(normTargetArtist) ||
              normTargetArtist.contains(cArtist)) {
            return true;
          }
        }
      }
    }

    return false;
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
  bool _isAutoMatching = false;
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

  bool get _isMatchedSongAlreadyInCloud {
    if (_matchedDisplay.isEmpty) return false;
    final cloudSongs = widget.libraryController?.cloudSongs;
    if (cloudSongs == null || cloudSongs.isEmpty) return false;
    return CloudUploadDialog.isMatchedSongInCloud(
      cloudSongs: cloudSongs,
      matchedAudioId: _matchedAudioId,
      matchedAlbumAudioId: _matchedAlbumAudioId,
      matchedHashStd: _matchedHashStd,
      matchedTitle: _titleController.text,
      matchedArtist: _artistController.text,
    );
  }

  void _onLibraryChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    widget.libraryController?.addListener(_onLibraryChanged);
    if (widget.libraryController != null &&
        widget.libraryController!.cloudSongs.isEmpty) {
      widget.libraryController!.ensureLoaded(LibrarySection.cloud);
    }
    final isMv = widget.song.isMv || widget.song.playbackQuality == 'MV';
    final cleaned = isMv
        ? CloudUploadDialog.cleanMvMetadata(
            rawTitle: widget.song.title,
            rawArtist: widget.song.artist,
          )
        : (title: widget.song.title, artist: widget.song.artist);

    _titleController = TextEditingController(text: cleaned.title);
    _artistController = TextEditingController(text: cleaned.artist);
    _searchController = TextEditingController(
      text: '${cleaned.title} ${cleaned.artist}'.trim(),
    );

    final hasOfficialId = ((widget.song.fileId ?? 0) > 0) ||
        ((widget.song.albumAudioId ?? 0) > 0);

    if (!isMv && hasOfficialId) {
      _matchedAudioId = widget.song.fileId ?? 0;
      _matchedAlbumAudioId = widget.song.albumAudioId ?? 0;
      _matchedHashStd = widget.song.catalogHash ?? widget.song.hash ?? '';
      _matchedDisplay = '${widget.song.artist} - ${widget.song.title}';
    } else {
      _matchedAudioId = 0;
      _matchedAlbumAudioId = 0;
      _matchedHashStd = '';
      _matchedDisplay = '';
      _autoMatchOfficialSong(cleaned.title, cleaned.artist);
    }
  }

  Future<void> _autoMatchOfficialSong(String title, String artist) async {
    final query = '$title $artist'.trim();
    if (query.isEmpty) return;

    setState(() {
      _isAutoMatching = true;
    });

    try {
      final results = await widget.apiClient.searchSongs(query);
      if (!mounted) return;

      if (_searchResults.isEmpty) {
        _searchResults = results;
      }

      final matched = CloudUploadDialog.findHighConfidenceMatch(
        results: results,
        targetTitle: title,
        targetArtist: artist,
      );

      if (mounted) {
        setState(() {
          _isAutoMatching = false;
          // 仅在当前尚未手动选择关联且未被清除时赋予自动匹配结果
          if (_matchedDisplay.isEmpty && matched != null) {
            _selectMatch(matched);
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isAutoMatching = false;
        });
      }
    }
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
    widget.libraryController?.removeListener(_onLibraryChanged);
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
    var query = _searchController.text.trim();
    if (query.isEmpty) {
      query =
          '${_titleController.text.trim()} ${_artistController.text.trim()}'
              .trim();
      _searchController.text = query;
    }
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
      _titleController.text = candidate.title;
      _artistController.text = candidate.artist;
      _showSearchPicker = false;
    });
  }

  Future<void> _startUpload() async {
    if (_isUploading || _isMatchedSongAlreadyInCloud) return;

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
    final isMatched = _matchedDisplay.isNotEmpty;
    final isAlreadyInCloud = _isMatchedSongAlreadyInCloud;
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
                        enabled: !isMatched,
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
                        enabled: !isMatched,
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
                        '曲库关联',
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
                              if (_showSearchPicker &&
                                  _searchResults.isEmpty &&
                                  !_isSearching) {
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
                  if (_isAutoMatching)
                    Row(
                      children: [
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.5),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '正在识别原曲...',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      _matchedDisplay.isNotEmpty
                          ? (isAlreadyInCloud
                              ? '已关联：$_matchedDisplay (云盘已存在)'
                              : '已关联：$_matchedDisplay')
                          : '未关联',
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
                    : (isAlreadyInCloud
                          ? '云盘已存在'
                          : (_errorMessage != null ? '重试转存' : '开始转存'))),
          isPrimary: !isAlreadyInCloud && !_isDone,
          icon: _isDone
              ? Icons.check_rounded
              : (isAlreadyInCloud
                    ? Icons.cloud_done_outlined
                    : Icons.cloud_upload_outlined),
          onPressed: _isDone
              ? _finish
              : (_isUploading || isAlreadyInCloud ? null : _startUpload),
        ),
      ],
    ),
  );
  }
}
