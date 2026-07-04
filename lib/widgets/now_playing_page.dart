import 'package:flutter/material.dart';

import '../controllers/player_controller.dart';
import '../models/lyric.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';
import 'album_art.dart';
import 'song_row.dart';

class NowPlayingPage extends StatelessWidget {
  const NowPlayingPage({
    super.key,
    required this.controller,
    required this.onClose,
    required this.loadLyrics,
    this.onLike,
    this.onAddToPlaylist,
    this.onOpenAlbum,
  });

  final PlayerController controller;
  final VoidCallback onClose;
  final Future<List<LyricLine>> Function(Song song) loadLyrics;
  final ValueChanged<Song>? onLike;
  final ValueChanged<Song>? onAddToPlaylist;
  final ValueChanged<Song>? onOpenAlbum;

  @override
  Widget build(BuildContext context) {
    final song = controller.currentSong;
    final compact = MediaQuery.sizeOf(context).width < 980;
    return Material(
      color: AppColors.page,
      child: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 24 : 52,
                24,
                compact ? 24 : 52,
                28,
              ),
              child: Column(
                children: [
                  const SizedBox(height: 58),
                  Expanded(
                    child: song == null
                        ? const _EmptyState()
                        : compact
                        ? _CompactContent(
                            song: song,
                            controller: controller,
                            loadLyrics: loadLyrics,
                          )
                        : _WideContent(
                            song: song,
                            controller: controller,
                            loadLyrics: loadLyrics,
                          ),
                  ),
                  if (song != null) ...[
                    const SizedBox(height: 12),
                    _PlaybackControls(
                      controller: controller,
                      compact: compact,
                      song: song,
                      onLike: onLike,
                      onAddToPlaylist: onAddToPlaylist,
                      onOpenAlbum: onOpenAlbum,
                    ),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            left: compact ? 12 : 22,
            bottom: 17,
            child: _CollapseButton(onClose: onClose),
          ),
        ],
      ),
    );
  }
}

class _CollapseButton extends StatelessWidget {
  const _CollapseButton({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: '收起播放页',
        child: SizedBox(
          width: 58,
          height: 58,
          child: IconButton.filledTonal(
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surfaceMuted,
              foregroundColor: AppColors.muted,
              hoverColor: AppColors.primary.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            tooltip: '收起播放页',
            onPressed: onClose,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 25),
          ),
        ),
      ),
    );
  }
}

class _NowPlayingActions extends StatelessWidget {
  const _NowPlayingActions({
    required this.song,
    this.onLike,
    this.onAddToPlaylist,
    this.onOpenAlbum,
    this.compact = false,
  });

  final Song song;
  final ValueChanged<Song>? onLike;
  final ValueChanged<Song>? onAddToPlaylist;
  final ValueChanged<Song>? onOpenAlbum;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 34.0 : 38.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _NowPlayingActionButton(
          tooltip: song.liked ? '取消收藏' : '收藏',
          icon: song.liked
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          selected: song.liked,
          size: size,
          onPressed: onLike == null ? null : () => onLike!(song),
        ),
        SizedBox(width: compact ? 4 : 6),
        _NowPlayingActionButton(
          tooltip: '添加到歌单',
          icon: Icons.playlist_add_rounded,
          size: size,
          onPressed: onAddToPlaylist == null
              ? null
              : () => onAddToPlaylist!(song),
        ),
        SizedBox(width: compact ? 4 : 6),
        _NowPlayingActionButton(
          tooltip: '打开专辑',
          icon: Icons.album_rounded,
          size: size,
          onPressed: _hasAlbum(song) && onOpenAlbum != null
              ? () => onOpenAlbum!(song)
              : null,
        ),
      ],
    );
  }
}

class _NowPlayingActionButton extends StatelessWidget {
  const _NowPlayingActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    required this.size,
    this.selected = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        minimumSize: Size(size, size),
        fixedSize: Size(size, size),
        padding: EdgeInsets.zero,
        iconSize: size < 36 ? 18 : 20,
        foregroundColor: selected ? AppColors.primary : AppColors.muted,
        disabledForegroundColor: AppColors.faint.withValues(alpha: 0.45),
        backgroundColor: AppColors.surfaceMuted,
        disabledBackgroundColor: AppColors.surfaceMuted.withValues(alpha: 0.5),
        hoverColor: AppColors.primary.withValues(alpha: 0.08),
        shape: const CircleBorder(),
      ),
    );
  }
}

class _WideContent extends StatelessWidget {
  const _WideContent({
    required this.song,
    required this.controller,
    required this.loadLyrics,
  });

  final Song song;
  final PlayerController controller;
  final Future<List<LyricLine>> Function(Song song) loadLyrics;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Align(
            alignment: Alignment.center,
            child: _SongIdentity(song: song),
          ),
        ),
        const SizedBox(width: 48),
        Expanded(
          flex: 4,
          child: Align(
            alignment: Alignment.centerLeft,
            child: _LyricsPanel(
              song: song,
              controller: controller,
              loadLyrics: loadLyrics,
            ),
          ),
        ),
      ],
    );
  }
}

class _CompactContent extends StatelessWidget {
  const _CompactContent({
    required this.song,
    required this.controller,
    required this.loadLyrics,
  });

  final Song song;
  final PlayerController controller;
  final Future<List<LyricLine>> Function(Song song) loadLyrics;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _SongIdentity(song: song),
          const SizedBox(height: 30),
          _LyricsPanel(
            song: song,
            controller: controller,
            loadLyrics: loadLyrics,
          ),
        ],
      ),
    );
  }
}

class _SongIdentity extends StatelessWidget {
  const _SongIdentity({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: AppShadows.popover,
            ),
            child: AlbumArt(
              size: 276,
              emphasized: true,
              imageUrl: song.coverUrl,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            song.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.text,
              fontSize: 25,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            _artistLabel(song),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LyricsPanel extends StatefulWidget {
  const _LyricsPanel({
    required this.song,
    required this.controller,
    required this.loadLyrics,
  });

  final Song song;
  final PlayerController controller;
  final Future<List<LyricLine>> Function(Song song) loadLyrics;

  @override
  State<_LyricsPanel> createState() => _LyricsPanelState();
}

class _LyricsPanelState extends State<_LyricsPanel> {
  static const double _lyricViewportHeight = 310;
  static const double _lyricRowExtent = 62;

  final _scrollController = ScrollController();
  List<LyricLine> _lines = const [];
  bool _loading = true;
  String? _errorText;
  int _activeIndex = -1;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
    _load();
  }

  @override
  void didUpdateWidget(covariant _LyricsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
    }
    if (oldWidget.song.id != widget.song.id ||
        oldWidget.song.hash != widget.song.hash) {
      _load();
      return;
    }
    _syncActiveLine();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    _syncActiveLine();
  }

  Future<void> _load() async {
    final song = widget.song;
    setState(() {
      _loading = true;
      _errorText = null;
      _lines = const [];
      _activeIndex = -1;
    });
    try {
      final lines = await widget.loadLyrics(song);
      if (!mounted ||
          widget.song.id != song.id ||
          widget.song.hash != song.hash) {
        return;
      }
      setState(() {
        _lines = lines;
        _loading = false;
      });
      _syncActiveLine(forceScroll: true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorText = '歌词加载失败';
      });
    }
  }

  void _syncActiveLine({bool forceScroll = false}) {
    if (_lines.isEmpty) return;
    final position = widget.controller.position;
    var nextIndex = -1;
    for (var index = 0; index < _lines.length; index++) {
      if (_lines[index].time <= position) {
        nextIndex = index;
      } else {
        break;
      }
    }
    if (nextIndex == _activeIndex && !forceScroll) return;
    setState(() => _activeIndex = nextIndex);
    _scrollToActiveLine(nextIndex, forceScroll: forceScroll);
  }

  void _scrollToActiveLine(int index, {bool forceScroll = false}) {
    if (index < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_scrollController.hasClients) return;
      final target = index * _lyricRowExtent;
      final safeTarget = target.clamp(
        _scrollController.position.minScrollExtent,
        _scrollController.position.maxScrollExtent,
      );
      await _scrollController.animateTo(
        safeTarget,
        duration: Duration(milliseconds: forceScroll ? 280 : 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 430),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: _lyricViewportHeight, child: _lyricsContent()),
        ],
      ),
    );
  }

  Widget _lyricsContent() {
    if (_loading) {
      return Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: AppColors.primary,
          ),
        ),
      );
    }
    if (_errorText != null) return _LyricEmptyText(text: _errorText!);
    if (_lines.isEmpty) return const _LyricEmptyText(text: '暂无歌词');

    final listView = ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        vertical: (_lyricViewportHeight - _lyricRowExtent) / 2,
      ),
      itemCount: _lines.length,
      itemBuilder: (context, index) {
        final line = _lines[index];
        final active = index == _activeIndex;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: () async {
            await widget.controller.seek(line.time);
            if (!mounted) return;
            _syncActiveLine(forceScroll: true);
          },
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            style: TextStyle(
              fontFamily: 'NotoSansSC',
              color: active
                  ? AppColors.text
                  : AppColors.muted.withValues(alpha: 0.82),
              fontSize: active ? 22 : 17,
              fontWeight: active ? FontWeight.w800 : FontWeight.w500,
              height: 1.48,
              letterSpacing: 0,
            ),
            child: Padding(
              padding: EdgeInsets.zero,
              child: SizedBox(
                height: _lyricRowExtent,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    line.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: listView,
    );
  }
}

class _LyricEmptyText extends StatelessWidget {
  const _LyricEmptyText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.muted,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PlaybackControls extends StatelessWidget {
  const _PlaybackControls({
    required this.controller,
    required this.compact,
    required this.song,
    this.onLike,
    this.onAddToPlaylist,
    this.onOpenAlbum,
  });

  final PlayerController controller;
  final bool compact;
  final Song song;
  final ValueChanged<Song>? onLike;
  final ValueChanged<Song>? onAddToPlaylist;
  final ValueChanged<Song>? onOpenAlbum;

  @override
  Widget build(BuildContext context) {
    final currentSong = controller.currentSong;
    final duration = controller.duration == Duration.zero && currentSong != null
        ? currentSong.duration
        : controller.duration;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _NowPlayingActions(
                song: song,
                onLike: onLike,
                onAddToPlaylist: onAddToPlaylist,
                onOpenAlbum: onOpenAlbum,
                compact: compact,
              ),
              SizedBox(width: compact ? 6 : 10),
              IconButton(
                tooltip: controller.playbackMode.label,
                onPressed: controller.cyclePlaybackMode,
                icon: Icon(_modeIcon(controller.playbackMode)),
              ),
              const SizedBox(width: 10),
              IconButton(
                tooltip: '上一首',
                onPressed: controller.playPrevious,
                icon: const Icon(Icons.skip_previous_rounded),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: controller.isPreparing
                    ? null
                    : controller.togglePlay,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(15),
                  elevation: 0,
                ),
                child: Icon(
                  controller.isPlaying || controller.isPreparing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 28,
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                tooltip: '下一首',
                onPressed: () => controller.playNext(),
                icon: const Icon(Icons.skip_next_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                formatDuration(controller.position),
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: AppColors.divider,
                    thumbColor: AppColors.primary,
                    overlayColor: AppColors.primary.withValues(alpha: 0.12),
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 5,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 13,
                    ),
                    trackShape: const _EdgeToEdgeSliderTrackShape(),
                  ),
                  child: Slider(
                    value: _ratio(controller.position, duration),
                    onChanged: controller.seekByRatio,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                formatDuration(duration),
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _modeIcon(PlaybackMode mode) {
    return switch (mode) {
      PlaybackMode.sequence => Icons.format_list_numbered_rounded,
      PlaybackMode.repeatAll => Icons.repeat_rounded,
      PlaybackMode.repeatOne => Icons.repeat_one_rounded,
      PlaybackMode.shuffle => Icons.shuffle_rounded,
    };
  }

  double _ratio(Duration position, Duration duration) {
    if (duration.inMilliseconds <= 0) return 0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '选择一首歌开始播放',
        style: TextStyle(color: AppColors.muted, fontSize: 14),
      ),
    );
  }
}

class _EdgeToEdgeSliderTrackShape extends RoundedRectSliderTrackShape {
  const _EdgeToEdgeSliderTrackShape();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 0;
    final top = offset.dy + (parentBox.size.height - trackHeight) / 2;
    return Rect.fromLTWH(offset.dx, top, parentBox.size.width, trackHeight);
  }
}

String _artistLabel(Song song) {
  final names = song.artists
      .map((artist) => artist.name.trim())
      .where((name) => name.isNotEmpty && name != '未知歌手')
      .toSet()
      .toList();
  if (names.isNotEmpty) return names.join(' / ');
  final fallback = song.artist.trim();
  return fallback.isEmpty || fallback == '未知歌手' ? '群星' : fallback;
}

bool _hasAlbum(Song song) {
  final album = song.album.trim();
  return album.isNotEmpty && album != '未知专辑';
}
