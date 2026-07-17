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

class NowPlayingPage extends StatefulWidget {
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
    required this.showTranslation,
    required this.showTransliteration,
    required this.onTranslationChanged,
    required this.onTransliterationChanged,
    required this.loadArtistPortraits,
  });

  final PlayerController controller;
  final PlaybackQualityController playbackQualityController;
  final VoidCallback onClose;
  final Future<List<LyricLine>> Function(Song song) loadLyrics;
  final ValueChanged<Song>? onLike;
  final ValueChanged<Song>? onAddToPlaylist;
  final ValueChanged<Song>? onOpenAlbum;
  final ValueChanged<Song>? onOpenArtist;
  final bool showTranslation;
  final bool showTransliteration;
  final ValueChanged<bool> onTranslationChanged;
  final ValueChanged<bool> onTransliterationChanged;
  final Future<List<String>> Function(Song song) loadArtistPortraits;

  @override
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage> {
  List<String> _portraits = const [];
  bool _portraitMode = false;
  bool _portraitLoading = false;
  String? _portraitSongKey;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleSongChanged);
    _handleSongChanged();
  }

  @override
  void didUpdateWidget(covariant NowPlayingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleSongChanged);
      widget.controller.addListener(_handleSongChanged);
      _portraitSongKey = null;
      _handleSongChanged();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleSongChanged);
    super.dispose();
  }

  void _handleSongChanged() {
    final song = widget.controller.currentSong;
    final key = song == null ? null : '${song.id}|${song.hash ?? ''}';
    if (key == _portraitSongKey) return;
    _portraitSongKey = key;
    setState(() {
      _portraitMode = false;
      _portraits = const [];
    });
    if (song != null) _loadPortraits(song);
  }

  Future<void> _loadPortraits(Song song) async {
    setState(() => _portraitLoading = true);
    try {
      final portraits = await widget.loadArtistPortraits(song);
      if (!mounted || widget.controller.currentSong?.id != song.id) return;
      setState(() {
        _portraits = portraits;
        _portraitLoading = false;
      });
    } catch (_) {
      if (mounted && widget.controller.currentSong?.id == song.id) {
        setState(() => _portraitLoading = false);
      }
    }
  }

  void _togglePortraitMode() {
    setState(() => _portraitMode = !_portraitMode);
    if (_portraitMode && _portraits.isEmpty && !_portraitLoading) {
      final song = widget.controller.currentSong;
      if (song != null) _loadPortraits(song);
    }
  }

  @override
  Widget build(BuildContext context) {
    final song = widget.controller.currentSong;
    final compact = MediaQuery.sizeOf(context).width < 980;
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          _BlurredCoverBackground(
            song: song,
            portraitUrl: _portraits.firstOrNull,
            portraitMode: _portraitMode,
          ),
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
                            controller: widget.controller,
                            loadLyrics: widget.loadLyrics,
                            onOpenArtist: widget.onOpenArtist,
                            showTranslation: widget.showTranslation,
                            showTransliteration: widget.showTransliteration,
                            onTranslationChanged: widget.onTranslationChanged,
                            onTransliterationChanged:
                                widget.onTransliterationChanged,
                          )
                        : _WideContent(
                            song: song,
                            controller: widget.controller,
                            loadLyrics: widget.loadLyrics,
                            onOpenArtist: widget.onOpenArtist,
                            showTranslation: widget.showTranslation,
                            showTransliteration: widget.showTransliteration,
                            onTranslationChanged: widget.onTranslationChanged,
                            onTransliterationChanged:
                                widget.onTransliterationChanged,
                          ),
                  ),
                  if (song != null) ...[
                    const SizedBox(height: 12),
                    _PlaybackControls(
                      controller: widget.controller,
                      playbackQualityController:
                          widget.playbackQualityController,
                      song: song,
                      onLike: widget.onLike,
                      onAddToPlaylist: widget.onAddToPlaylist,
                      onOpenAlbum: widget.onOpenAlbum,
                    ),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            left: compact ? 12 : 22,
            bottom: 17,
            child: Row(
              children: [
                _SubtleCollapseButton(onClose: widget.onClose),
                const SizedBox(width: 8),
                _PortraitModeButton(
                  loading: _portraitLoading,
                  selected: _portraitMode,
                  onPressed: _togglePortraitMode,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BlurredCoverBackground extends StatelessWidget {
  const _BlurredCoverBackground({
    required this.song,
    required this.portraitUrl,
    required this.portraitMode,
  });

  final Song? song;
  final String? portraitUrl;
  final bool portraitMode;

  @override
  Widget build(BuildContext context) {
    final coverUrl = (song?.coverUrl ?? '').trim();
    final portrait = (portraitUrl ?? '').trim();
    final showPortrait = portraitMode && portrait.isNotEmpty;
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
                child: showPortrait
                    ? Image.network(
                        portrait,
                        key: ValueKey('portrait-$portrait'),
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        gaplessPlayback: true,
                        filterQuality: FilterQuality.medium,
                        cacheWidth: 1600,
                      )
                    : Opacity(
                        key: ValueKey(
                          hasCover ? coverUrl : 'album-placeholder-bg',
                        ),
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
                                      ),
                                    )
                                  : Image.asset(
                                      'assets/images/album_placeholder.png',
                                      fit: BoxFit.cover,
                                    ),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: overlay.withValues(
                  alpha: showPortrait
                      ? (dark ? 0.32 : 0.48)
                      : (dark ? 0.54 : 0.68),
                ),
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

class _PortraitModeButton extends StatelessWidget {
  const _PortraitModeButton({
    required this.loading,
    required this.selected,
    required this.onPressed,
  });

  final bool loading;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 58,
      child: IconButton(
        tooltip: selected ? '切换到专辑封面' : '切换到歌手写真',
        onPressed: onPressed,
        mouseCursor: SystemMouseCursors.click,
        style: IconButton.styleFrom(
          foregroundColor: selected ? AppColors.primary : AppColors.muted,
          backgroundColor: selected
              ? AppColors.selected.withValues(alpha: 0.78)
              : AppColors.surfaceMuted.withValues(
                  alpha: AppColors.isDark ? 0.22 : 0.28,
                ),
          hoverColor: AppColors.primary.withValues(alpha: 0.10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        icon: loading && selected
            ? const SizedBox(
                width: 17,
                height: 17,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                selected ? Icons.person_rounded : Icons.person_outline_rounded,
                size: 22,
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
    required this.showTranslation,
    required this.showTransliteration,
    required this.onTranslationChanged,
    required this.onTransliterationChanged,
  });

  final Song song;
  final PlayerController controller;
  final Future<List<LyricLine>> Function(Song song) loadLyrics;
  final ValueChanged<Song>? onOpenArtist;
  final bool showTranslation;
  final bool showTransliteration;
  final ValueChanged<bool> onTranslationChanged;
  final ValueChanged<bool> onTransliterationChanged;

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
              showTranslation: showTranslation,
              showTransliteration: showTransliteration,
              onTranslationChanged: onTranslationChanged,
              onTransliterationChanged: onTransliterationChanged,
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
    required this.showTranslation,
    required this.showTransliteration,
    required this.onTranslationChanged,
    required this.onTransliterationChanged,
  });

  final Song song;
  final PlayerController controller;
  final Future<List<LyricLine>> Function(Song song) loadLyrics;
  final ValueChanged<Song>? onOpenArtist;
  final bool showTranslation;
  final bool showTransliteration;
  final ValueChanged<bool> onTranslationChanged;
  final ValueChanged<bool> onTransliterationChanged;

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
            showTranslation: showTranslation,
            showTransliteration: showTransliteration,
            onTranslationChanged: onTranslationChanged,
            onTransliterationChanged: onTransliterationChanged,
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
    required this.showTranslation,
    required this.showTransliteration,
    required this.onTranslationChanged,
    required this.onTransliterationChanged,
  });

  final Song song;
  final PlayerController controller;
  final Future<List<LyricLine>> Function(Song song) loadLyrics;
  final bool showTranslation;
  final bool showTransliteration;
  final ValueChanged<bool> onTranslationChanged;
  final ValueChanged<bool> onTransliterationChanged;

  @override
  State<_LyricsPanel> createState() => _LyricsPanelState();
}

class _LyricsPanelState extends State<_LyricsPanel> {
  static const double _lyricViewportHeight = 304;
  static const double _lyricRowExtent = 72;

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
    if (nextIndex == _activeIndex && !forceScroll) {
      if (nextIndex >= 0 && _lines[nextIndex].hasExactTiming && mounted) {
        setState(() {});
      }
      return;
    }
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
    final hasTranslation = _lines.any(
      (line) => (line.translation ?? '').trim().isNotEmpty,
    );
    final hasTransliteration = _lines.any(
      (line) => (line.transliteration ?? '').trim().isNotEmpty,
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 430),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasTranslation || hasTransliteration) ...[
            Row(
              children: [
                if (hasTranslation)
                  _LyricLayerToggle(
                    label: '译',
                    tooltip: '外语翻译',
                    selected: widget.showTranslation,
                    onTap: () =>
                        widget.onTranslationChanged(!widget.showTranslation),
                  ),
                if (hasTranslation && hasTransliteration)
                  const SizedBox(width: 6),
                if (hasTransliteration)
                  _LyricLayerToggle(
                    label: '音',
                    tooltip: '音译',
                    selected: widget.showTransliteration,
                    onTap: () => widget.onTransliterationChanged(
                      !widget.showTransliteration,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
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
        final secondary = <String>[
          if (widget.showTranslation &&
              (line.translation ?? '').trim().isNotEmpty)
            line.translation!.trim(),
          if (widget.showTransliteration &&
              (line.transliteration ?? '').trim().isNotEmpty)
            line.transliteration!.trim(),
        ].join('  ·  ');
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: () async {
            await widget.controller.seek(line.time);
            if (!mounted) return;
            _syncActiveLine(forceScroll: true);
          },
          child: SizedBox(
            height: _lyricRowExtent,
            child: Align(
              alignment: Alignment.centerLeft,
              child: AnimatedScale(
                scale: active ? 1 : 0.97,
                alignment: Alignment.centerLeft,
                duration: AppMotion.fast,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _KaraokeLine(
                      line: line,
                      position: widget.controller.position,
                      active: active,
                    ),
                    if (secondary.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        secondary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: active
                              ? AppColors.primary.withValues(alpha: 0.82)
                              : AppColors.faint,
                          fontSize: active ? 12 : 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
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

class _LyricLayerToggle extends StatelessWidget {
  const _LyricLayerToggle({
    required this.label,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: selected
          ? AppColors.selected
          : AppColors.surfaceMuted.withValues(alpha: 0.36),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          width: 30,
          height: 24,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.primary : AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _KaraokeLine extends StatelessWidget {
  const _KaraokeLine({
    required this.line,
    required this.position,
    required this.active,
  });

  final LyricLine line;
  final Duration position;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: 'NotoSansSC',
      color: active ? AppColors.text : AppColors.muted.withValues(alpha: 0.82),
      fontSize: active ? 22 : 17,
      fontWeight: active ? FontWeight.w800 : FontWeight.w500,
      height: 1.24,
    );
    if (!active || !line.hasExactTiming) {
      return Text(
        line.text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    final progress = _wordProgress(line, position);
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          Text(
            line.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style.copyWith(
              color: AppColors.muted.withValues(alpha: 0.5),
            ),
          ),
          ClipRect(
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: SizedBox(
                width: constraints.maxWidth,
                child: Text(
                  line.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style.copyWith(color: AppColors.text),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _wordProgress(LyricLine line, Duration position) {
    final elapsed = position - line.time;
    if (elapsed <= Duration.zero) return 0;
    var completedCharacters = 0.0;
    final totalCharacters = line.words.fold<int>(
      0,
      (total, word) => total + word.text.runes.length,
    );
    if (totalCharacters == 0) return 0;
    for (final word in line.words) {
      final count = word.text.runes.length;
      if (elapsed >= word.offset + word.duration) {
        completedCharacters += count;
        continue;
      }
      if (elapsed > word.offset && word.duration > Duration.zero) {
        final local =
            (elapsed - word.offset).inMicroseconds /
            word.duration.inMicroseconds;
        completedCharacters += count * local.clamp(0.0, 1.0);
      }
      break;
    }
    return (completedCharacters / totalCharacters).clamp(0.0, 1.0);
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
    required this.song,
    this.onLike,
    this.onAddToPlaylist,
    this.onOpenAlbum,
  });

  final PlayerController controller;
  final PlaybackQualityController playbackQualityController;
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
      constraints: const BoxConstraints(maxWidth: 680),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 384,
            height: 48,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(
                  alpha: AppColors.isDark ? 0.42 : 0.54,
                ),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.34),
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    right: 220,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _NowPlayingActions(
                          song: song,
                          onLike: onLike,
                          onAddToPlaylist: onAddToPlaylist,
                          onOpenAlbum: onOpenAlbum,
                          compact: true,
                        ),
                        const SizedBox(width: 4),
                        _GlassControlButton(
                          tooltip: '上一首',
                          icon: Icons.skip_previous_rounded,
                          onPressed: controller.playPrevious,
                        ),
                      ],
                    ),
                  ),
                  _PlayControlButton(
                    isPlaying: controller.isPlaying,
                    disabled: controller.isPreparing,
                    onPressed: controller.togglePlay,
                  ),
                  Positioned(
                    left: 220,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _GlassControlButton(
                          tooltip: '下一首',
                          icon: Icons.skip_next_rounded,
                          onPressed: () => controller.playNext(),
                        ),
                        const SizedBox(width: 16),
                        PlaybackQualityMenu(
                          controller: playbackQualityController,
                          compact: true,
                        ),
                        const SizedBox(width: 16),
                        _GlassControlButton(
                          tooltip: controller.playbackMode.label,
                          icon: _modeIcon(controller.playbackMode),
                          onPressed: controller.cyclePlaybackMode,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
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
