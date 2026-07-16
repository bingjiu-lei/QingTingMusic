import 'dart:ui';

import 'package:flutter/material.dart';

import '../controllers/playback_quality_controller.dart';
import '../controllers/player_controller.dart';
import '../models/lyric.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';
import 'album_art.dart';
import 'playback_progress.dart';
import 'playback_quality_menu.dart';
import 'song_row.dart';

class NowPlayingPage extends StatelessWidget {
  const NowPlayingPage({
    super.key,
    required this.controller,
    required this.playbackQualityController,
    required this.onClose,
    required this.loadLyrics,
    this.onLike,
    this.onAddToPlaylist,
    this.onOpenAlbum,
    this.onOpenArtist,
  });

  final PlayerController controller;
  final PlaybackQualityController playbackQualityController;
  final VoidCallback onClose;
  final Future<List<LyricLine>> Function(Song song) loadLyrics;
  final ValueChanged<Song>? onLike;
  final ValueChanged<Song>? onAddToPlaylist;
  final ValueChanged<Song>? onOpenAlbum;
  final ValueChanged<Song>? onOpenArtist;

  @override
  Widget build(BuildContext context) {
    final song = controller.currentSong;
    final compact = MediaQuery.sizeOf(context).width < 980;
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          _BlurredCoverBackground(song: song),
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
                            onOpenArtist: onOpenArtist,
                          )
                        : _WideContent(
                            song: song,
                            controller: controller,
                            loadLyrics: loadLyrics,
                            onOpenArtist: onOpenArtist,
                          ),
                  ),
                  if (song != null) ...[
                    const SizedBox(height: 12),
                    _PlaybackControls(
                      controller: controller,
                      playbackQualityController: playbackQualityController,
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
            child: _SubtleCollapseButton(onClose: onClose),
          ),
        ],
      ),
    );
  }
}

class _BlurredCoverBackground extends StatelessWidget {
  const _BlurredCoverBackground({required this.song});

  final Song? song;

  @override
  Widget build(BuildContext context) {
    final coverUrl = (song?.coverUrl ?? '').trim();
    final hasCover = coverUrl.isNotEmpty;
    final dark = AppColors.isDark;
    final overlay = dark ? Colors.black : Colors.white;
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF070A0F) : const Color(0xFFF8FAFD),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 420),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: Opacity(
                  key: ValueKey(hasCover ? coverUrl : 'album-placeholder-bg'),
                  opacity: hasCover ? 0.92 : 0.42,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
                    child: Transform.scale(
                      scale: 1.76,
                      child: SizedBox.expand(
                        child: hasCover
                            ? Image.network(
                                coverUrl,
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                                filterQuality: FilterQuality.low,
                                cacheWidth: 720,
                                errorBuilder: (_, _, _) => Image.asset(
                                  'assets/images/album_placeholder.png',
                                  fit: BoxFit.cover,
                                  filterQuality: FilterQuality.low,
                                ),
                              )
                            : Image.asset(
                                'assets/images/album_placeholder.png',
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.low,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: overlay.withValues(alpha: dark ? 0.54 : 0.68),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: dark
                      ? [
                          Colors.black.withValues(alpha: 0.40),
                          Colors.black.withValues(alpha: 0.10),
                          Colors.black.withValues(alpha: 0.48),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.62),
                          Colors.white.withValues(alpha: 0.22),
                          Colors.white.withValues(alpha: 0.70),
                        ],
                  stops: const [0, 0.48, 1],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.45, -0.12),
                  radius: 0.66,
                  colors: [
                    AppColors.primary.withValues(alpha: dark ? 0.18 : 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.35, 0.50),
                  radius: 0.62,
                  colors: [
                    (dark ? const Color(0xFFB5677B) : const Color(0xFFFFB4C8))
                        .withValues(alpha: dark ? 0.16 : 0.14),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubtleCollapseButton extends StatefulWidget {
  const _SubtleCollapseButton({required this.onClose});

  final VoidCallback onClose;

  @override
  State<_SubtleCollapseButton> createState() => _SubtleCollapseButtonState();
}

class _SubtleCollapseButtonState extends State<_SubtleCollapseButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: '收起播放页',
        child: AnimatedContainer(
          duration: AppMotion.normal,
          curve: AppMotion.curve,
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.surfaceMuted.withValues(
                    alpha: AppColors.isDark ? 0.72 : 0.78,
                  )
                : AppColors.surfaceMuted.withValues(
                    alpha: AppColors.isDark ? 0.16 : 0.20,
                  ),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: _hovered
                  ? AppColors.border.withValues(alpha: 0.48)
                  : Colors.transparent,
            ),
          ),
          child: IconButton(
            mouseCursor: SystemMouseCursors.click,
            style: IconButton.styleFrom(
              foregroundColor: (_hovered ? AppColors.muted : AppColors.faint)
                  .withValues(
                    alpha: _hovered ? 1 : (AppColors.isDark ? 0.74 : 0.62),
                  ),
              hoverColor: Colors.transparent,
              highlightColor: AppColors.primary.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            tooltip: '收起播放页',
            onPressed: widget.onClose,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 24),
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
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
              backgroundColor: AppColors.surfaceMuted.withValues(
                alpha: AppColors.isDark ? 0.72 : 0.82,
              ),
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
      mouseCursor: onPressed == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        minimumSize: Size(size, size),
        fixedSize: Size(size, size),
        padding: EdgeInsets.zero,
        iconSize: size < 36 ? 18 : 20,
        foregroundColor: selected ? AppColors.favorite : AppColors.muted,
        disabledForegroundColor: AppColors.faint.withValues(alpha: 0.45),
        backgroundColor: selected
            ? Colors.transparent
            : AppColors.surfaceMuted.withValues(
                alpha: AppColors.isDark ? 0.34 : 0.46,
              ),
        disabledBackgroundColor: AppColors.surfaceMuted.withValues(alpha: 0.22),
        hoverColor: AppColors.primary.withValues(alpha: 0.10),
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
    this.onOpenArtist,
  });

  final Song song;
  final PlayerController controller;
  final Future<List<LyricLine>> Function(Song song) loadLyrics;
  final ValueChanged<Song>? onOpenArtist;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Align(
            alignment: Alignment.center,
            child: _SongIdentity(song: song, onOpenArtist: onOpenArtist),
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
    this.onOpenArtist,
  });

  final Song song;
  final PlayerController controller;
  final Future<List<LyricLine>> Function(Song song) loadLyrics;
  final ValueChanged<Song>? onOpenArtist;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _SongIdentity(song: song, onOpenArtist: onOpenArtist),
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
  const _SongIdentity({required this.song, this.onOpenArtist});

  final Song song;
  final ValueChanged<Song>? onOpenArtist;

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
          Center(
            child: SongArtistLine(
              song: song,
              fontSize: 14,
              onArtistLink: onOpenArtist == null
                  ? null
                  : (artist) => onOpenArtist!(
                      song.copyWith(
                        artist: artist.name,
                        artistId: artist.id,
                        artists: [artist],
                      ),
                    ),
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
    required this.playbackQualityController,
    required this.compact,
    required this.song,
    this.onLike,
    this.onAddToPlaylist,
    this.onOpenAlbum,
  });

  final PlayerController controller;
  final PlaybackQualityController playbackQualityController;
  final bool compact;
  final Song song;
  final ValueChanged<Song>? onLike;
  final ValueChanged<Song>? onAddToPlaylist;
  final ValueChanged<Song>? onOpenAlbum;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => _buildControls(context),
  );

  Widget _buildControls(BuildContext context) {
    final currentSong = controller.currentSong;
    final duration = controller.duration == Duration.zero && currentSong != null
        ? currentSong.duration
        : controller.duration;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(
                    alpha: AppColors.isDark ? 0.62 : 0.70,
                  ),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.36),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 3,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _NowPlayingActions(
                        song: song,
                        onLike: onLike,
                        onAddToPlaylist: onAddToPlaylist,
                        onOpenAlbum: onOpenAlbum,
                        compact: compact,
                      ),
                      SizedBox(width: compact ? 8 : 12),
                      PlaybackQualityMenu(
                        controller: playbackQualityController,
                        compact: true,
                      ),
                      SizedBox(width: compact ? 6 : 8),
                      _GlassControlButton(
                        tooltip: controller.playbackMode.label,
                        icon: _modeIcon(controller.playbackMode),
                        onPressed: controller.cyclePlaybackMode,
                      ),
                      _GlassControlButton(
                        tooltip: '上一首',
                        icon: Icons.skip_previous_rounded,
                        onPressed: controller.playPrevious,
                      ),
                      _PlayControlButton(
                        isPlaying: controller.isPlaying,
                        disabled: controller.isPreparing,
                        onPressed: controller.togglePlay,
                      ),
                      _GlassControlButton(
                        tooltip: '下一首',
                        icon: Icons.skip_next_rounded,
                        onPressed: () => controller.playNext(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 13),
          PlaybackProgress(
            position: controller.position,
            duration: duration,
            onSeek: controller.seekByRatio,
            showTimes: true,
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
}

class _GlassControlButton extends StatelessWidget {
  const _GlassControlButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      mouseCursor: onPressed == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        minimumSize: const Size(42, 42),
        fixedSize: const Size(42, 42),
        iconSize: 22,
        foregroundColor: AppColors.muted,
        disabledForegroundColor: AppColors.faint.withValues(alpha: 0.45),
        hoverColor: AppColors.primary.withValues(alpha: 0.10),
        highlightColor: AppColors.primary.withValues(alpha: 0.14),
        shape: const CircleBorder(),
      ),
    );
  }
}

class _PlayControlButton extends StatelessWidget {
  const _PlayControlButton({
    required this.isPlaying,
    required this.disabled,
    required this.onPressed,
  });

  final bool isPlaying;
  final bool disabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: SizedBox(
        width: 44,
        height: 44,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: disabled ? AppColors.surfaceMuted : AppColors.selected,
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: disabled ? null : onPressed,
              customBorder: const CircleBorder(),
              child: Center(
                child: Icon(
                  isPlaying || disabled
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: disabled ? AppColors.faint : AppColors.primary,
                  size: 26,
                ),
              ),
            ),
          ),
        ),
      ),
    );
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

bool _hasAlbum(Song song) {
  final album = song.album.trim();
  return album.isNotEmpty && album != '未知专辑';
}
