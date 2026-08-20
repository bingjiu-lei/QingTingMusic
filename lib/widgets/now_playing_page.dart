import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../controllers/playback_quality_controller.dart';
import '../controllers/player_controller.dart';
import '../models/lyric.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';
import 'album_art.dart';
import 'app_icon_button.dart';
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
    this.onOpenArtist,
    required this.desktopLyricsVisible,
    required this.onDesktopLyricsChanged,
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
  final ValueChanged<Song>? onOpenArtist;
  final bool desktopLyricsVisible;
  final ValueChanged<bool> onDesktopLyricsChanged;
  final bool showTranslation;
  final bool showTransliteration;
  final ValueChanged<bool> onTranslationChanged;
  final ValueChanged<bool> onTransliterationChanged;
  final Future<List<String>> Function(Song song) loadArtistPortraits;

  @override
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage> {
  static bool _portraitModePreference = false;
  static final Map<String, List<String>> _portraitCache =
      <String, List<String>>{};

  List<String> _portraits = const [];
  bool _portraitMode = _portraitModePreference;
  bool _portraitLoading = true;
  String? _portraitSongKey;
  int _portraitRequestToken = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleSongChanged);
    widget.controller.progress.addListener(_handleProgressChanged);
    _handleSongChanged();
  }

  @override
  void didUpdateWidget(covariant NowPlayingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleSongChanged);
      oldWidget.controller.progress.removeListener(_handleProgressChanged);
      widget.controller.addListener(_handleSongChanged);
      widget.controller.progress.addListener(_handleProgressChanged);
      _portraitSongKey = null;
      _handleSongChanged();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleSongChanged);
    widget.controller.progress.removeListener(_handleProgressChanged);
    super.dispose();
  }

  void _handleProgressChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleSongChanged() {
    final song = widget.controller.currentSong;
    final key = song == null ? null : '${song.id}|${song.hash ?? ''}';
    if (key == _portraitSongKey) return;
    _portraitSongKey = key;
    final token = ++_portraitRequestToken;
    if (song == null) {
      setState(() {
        _portraits = const [];
        _portraitLoading = false;
      });
      return;
    }
    final cached = _portraitCache[key];
    if (cached != null) {
      setState(() {
        _portraits = cached;
        _portraitLoading = false;
      });
      return;
    }
    setState(() => _portraitLoading = true);
    _loadPortraits(song, key!, token);
  }

  Future<void> _loadPortraits(Song song, String key, int token) async {
    try {
      final portraits = await widget.loadArtistPortraits(song);
      if (!mounted ||
          token != _portraitRequestToken ||
          _portraitSongKey != key) {
        return;
      }
      final decoded = <String>[];
      for (final url in portraits) {
        final cleanUrl = url.trim();
        if (cleanUrl.isEmpty) continue;
        try {
          await precacheImage(
            ResizeImage(NetworkImage(cleanUrl), width: 1920),
            context,
          );
          decoded.add(cleanUrl);
          break;
        } catch (_) {
          // Try the next upstream portrait before using the local fallback.
        }
      }
      if (!mounted ||
          token != _portraitRequestToken ||
          _portraitSongKey != key) {
        return;
      }
      final resolved = List<String>.unmodifiable(decoded);
      _portraitCache[key] = resolved;
      setState(() {
        _portraits = resolved;
        _portraitLoading = false;
      });
    } catch (_) {
      if (mounted &&
          token == _portraitRequestToken &&
          _portraitSongKey == key) {
        setState(() {
          _portraits = const [];
          _portraitLoading = false;
        });
      }
    }
  }

  void _togglePortraitMode() {
    if (_portraitMode) {
      _portraitModePreference = false;
      setState(() => _portraitMode = false);
      return;
    }
    _portraitModePreference = true;
    setState(() => _portraitMode = true);
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
            portraitLoading: _portraitLoading,
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
                            portraitMode: _portraitMode,
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
                            portraitMode: _portraitMode,
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
                      portraitSelected: _portraitMode,
                      portraitAvailable: true,
                      onTogglePortrait: _togglePortraitMode,
                      desktopLyricsVisible: widget.desktopLyricsVisible,
                      onDesktopLyricsChanged: widget.onDesktopLyricsChanged,
                    ),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            left: compact ? 12 : 22,
            bottom: 17,
            child: _SubtleCollapseButton(onClose: widget.onClose),
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
    required this.portraitLoading,
  });

  final Song? song;
  final String? portraitUrl;
  final bool portraitMode;
  final bool portraitLoading;

  @override
  Widget build(BuildContext context) {
    final coverUrl = (song?.coverUrl ?? '').trim();
    final portrait = (portraitUrl ?? '').trim();
    // While discovery is still running, keep the current artwork (or album
    // backdrop on first open). The bundled wallpaper is only shown after the
    // API has definitively returned no usable portrait.
    final showPortrait =
        portraitMode && (!portraitLoading || portrait.isNotEmpty);
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
                    ? _PortraitTransitionArtwork(
                        key: const ValueKey('portrait-mode'),
                        portraitUrl: portrait,
                        fallbackAsset: dark
                            ? 'assets/images/artist_wallpaper_dark.png'
                            : 'assets/images/artist_wallpaper_light.png',
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
            if (!showPortrait) ...[
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
            ],
            if (!showPortrait) ...[
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
          ],
        ),
      ),
    );
  }
}

class _PortraitSource {
  const _PortraitSource({
    required this.key,
    required this.provider,
    required this.isFallback,
  });

  final String key;
  final ImageProvider<Object> provider;
  final bool isFallback;
}

class _PortraitTransitionArtwork extends StatefulWidget {
  const _PortraitTransitionArtwork({
    super.key,
    required this.portraitUrl,
    required this.fallbackAsset,
  });

  final String portraitUrl;
  final String fallbackAsset;

  @override
  State<_PortraitTransitionArtwork> createState() =>
      _PortraitTransitionArtworkState();
}

class _PortraitTransitionArtworkState extends State<_PortraitTransitionArtwork>
    with SingleTickerProviderStateMixin {
  static final Set<String> _decodedPortraits = <String>{};

  late final AnimationController _controller;
  late final Animation<double> _fade;
  _PortraitSource? _current;
  _PortraitSource? _previous;
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _current ??= _initialSource();
    unawaited(_prepareTarget());
  }

  @override
  void didUpdateWidget(covariant _PortraitTransitionArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.portraitUrl != widget.portraitUrl ||
        oldWidget.fallbackAsset != widget.fallbackAsset) {
      unawaited(_prepareTarget());
    }
  }

  @override
  void dispose() {
    _loadToken++;
    _controller.dispose();
    super.dispose();
  }

  _PortraitSource _fallbackSource() => _PortraitSource(
    key: 'asset:${widget.fallbackAsset}',
    provider: AssetImage(widget.fallbackAsset),
    isFallback: true,
  );

  _PortraitSource _targetSource() {
    final url = widget.portraitUrl.trim();
    if (url.isEmpty) return _fallbackSource();
    return _PortraitSource(
      key: 'network:$url',
      provider: ResizeImage(NetworkImage(url), width: 1920),
      isFallback: false,
    );
  }

  _PortraitSource _initialSource() {
    // Network portraits are decoded before this widget is revealed, so using
    // the target immediately avoids a one-frame fallback wallpaper flash.
    return _targetSource();
  }

  Future<void> _prepareTarget() async {
    final token = ++_loadToken;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    var target = _targetSource();
    if (_current?.key == target.key && _previous == null) return;
    try {
      await precacheImage(target.provider, context);
      if (!target.isFallback) _decodedPortraits.add(target.key);
    } catch (_) {
      target = _fallbackSource();
      if (_current?.key == target.key && _previous == null) return;
      if (!mounted) return;
      try {
        await precacheImage(target.provider, context);
      } catch (_) {
        return;
      }
    }
    if (!mounted || token != _loadToken || _current?.key == target.key) return;
    final targetKey = target.key;
    setState(() {
      _previous = _current;
      _current = target;
    });
    _controller.duration = Duration(milliseconds: reduceMotion ? 90 : 280);
    await _controller.forward(from: 0);
    if (!mounted || token != _loadToken || _current?.key != targetKey) return;
    setState(() => _previous = null);
  }

  @override
  Widget build(BuildContext context) {
    final current = _current ?? _fallbackSource();
    final previous = _previous;
    if (previous == null) return _PortraitArtwork(source: current);
    return AnimatedBuilder(
      animation: _fade,
      builder: (context, _) {
        final progress = _fade.value;
        if (progress >= 0.999) return _PortraitArtwork(source: current);
        return Stack(
          fit: StackFit.expand,
          children: [
            _PortraitArtwork(source: previous),
            Opacity(
              opacity: progress,
              child: _PortraitArtwork(source: current),
            ),
          ],
        );
      },
    );
  }
}

class _PortraitArtwork extends StatelessWidget {
  const _PortraitArtwork({required this.source});

  final _PortraitSource source;

  @override
  Widget build(BuildContext context) {
    if (source.isFallback) {
      return SizedBox.expand(
        child: Image(
          image: source.provider,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
        ),
      );
    }
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Transform.scale(
            scale: 1.16,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Image(
                image: source.provider,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                filterQuality: FilterQuality.low,
              ),
            ),
          ),
          // Many upstream portraits contain baked-in black bars. A small crop
          // removes those bars while the softened copy behind it extends the
          // composition for very tall or very wide source images.
          Transform.scale(
            scale: 1.10,
            child: Image(
              image: source.provider,
              fit: BoxFit.contain,
              alignment: Alignment.center,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ],
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
    final isDark = AppColors.isDark;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: '收起播放页',
        child: GestureDetector(
          onTap: widget.onClose,
          child: AnimatedScale(
            scale: _hovered ? 1.06 : 1.0,
            duration: AppMotion.fast,
            curve: AppMotion.curve,
            child: AnimatedContainer(
              duration: AppMotion.normal,
              curve: AppMotion.curve,
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _hovered
                    ? (isDark
                          ? Colors.white.withValues(alpha: 0.18)
                          : Colors.white.withValues(alpha: 0.85))
                    : (isDark
                          ? Colors.white.withValues(alpha: 0.10)
                          : Colors.white.withValues(alpha: 0.50)),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: _hovered ? 0.25 : 0.14)
                      : Colors.white.withValues(alpha: _hovered ? 0.90 : 0.70),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow.withValues(
                      alpha: isDark ? 0.25 : 0.10,
                    ),
                    blurRadius: _hovered ? 14 : 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 26,
                  color: _hovered ? AppColors.text : AppColors.muted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PortraitModeButton extends StatelessWidget {
  const _PortraitModeButton({
    required this.selected,
    required this.available,
    required this.onPressed,
  });

  final bool selected;
  final bool available;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AppIconButton.ghost(
      tooltip: selected ? '切换到专辑封面' : '切换到歌手写真',
      icon: selected ? Icons.person_rounded : Icons.person_outline_rounded,
      onPressed: available ? onPressed : null,
      size: 42,
      iconSize: 22,
      selected: selected,
      selectedColor: AppColors.primary,
      selectedBackgroundColor: AppColors.primary.withValues(
        alpha: AppColors.isDark ? 0.18 : 0.10,
      ),
      iconColor: AppColors.muted,
      hoverIconColor: AppColors.primary,
      shadowColor: AppColors.primary,
    );
  }
}

// ignore: unused_element
class _CollapseButton extends StatelessWidget {
  const _CollapseButton({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return AppIconButton.filled(
      tooltip: '收起播放页',
      icon: Icons.keyboard_arrow_down_rounded,
      onPressed: onClose,
      size: 46,
      iconSize: 26,
      backgroundColor: AppColors.surfaceMuted.withValues(
        alpha: AppColors.isDark ? 0.72 : 0.82,
      ),
      hoverBackgroundColor: AppColors.primary.withValues(alpha: 0.16),
      iconColor: AppColors.muted,
      hoverIconColor: AppColors.primary,
      shadowColor: AppColors.primary,
    );
  }
}

class _NowPlayingActions extends StatelessWidget {
  const _NowPlayingActions({
    required this.song,
    required this.controller,
    this.onLike,
    this.onAddToPlaylist,
    this.compact = false,
  });

  final Song song;
  final PlayerController controller;
  final ValueChanged<Song>? onLike;
  final ValueChanged<Song>? onAddToPlaylist;
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
          tooltip: controller.playbackMode.label,
          icon: _playbackModeIcon(controller.playbackMode),
          size: size,
          onPressed: controller.cyclePlaybackMode,
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
    return AppIconButton.ghost(
      tooltip: tooltip,
      icon: icon,
      onPressed: onPressed,
      size: size,
      iconSize: size < 36 ? 18 : 20,
      selected: selected,
      selectedColor: AppColors.favorite,
      selectedBackgroundColor: Colors.transparent,
      iconColor: AppColors.muted,
      hoverIconColor: selected ? AppColors.favorite : AppColors.primary,
      shadowColor: selected ? AppColors.favorite : AppColors.primary,
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
    required this.portraitMode,
  });

  final Song song;
  final PlayerController controller;
  final Future<List<LyricLine>> Function(Song song) loadLyrics;
  final ValueChanged<Song>? onOpenArtist;
  final bool showTranslation;
  final bool showTransliteration;
  final ValueChanged<bool> onTranslationChanged;
  final ValueChanged<bool> onTransliterationChanged;
  final bool portraitMode;

  @override
  Widget build(BuildContext context) {
    if (portraitMode) {
      return Center(
        child: _LyricsPanel(
          song: song,
          controller: controller,
          loadLyrics: loadLyrics,
          showTranslation: showTranslation,
          showTransliteration: showTransliteration,
          onTranslationChanged: onTranslationChanged,
          onTransliterationChanged: onTransliterationChanged,
          centered: true,
        ),
      );
    }
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
    required this.portraitMode,
  });

  final Song song;
  final PlayerController controller;
  final Future<List<LyricLine>> Function(Song song) loadLyrics;
  final ValueChanged<Song>? onOpenArtist;
  final bool showTranslation;
  final bool showTransliteration;
  final ValueChanged<bool> onTranslationChanged;
  final ValueChanged<bool> onTransliterationChanged;
  final bool portraitMode;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          if (!portraitMode) ...[
            _SongIdentity(song: song, onOpenArtist: onOpenArtist),
            const SizedBox(height: 30),
          ],
          _LyricsPanel(
            song: song,
            controller: controller,
            loadLyrics: loadLyrics,
            showTranslation: showTranslation,
            showTransliteration: showTransliteration,
            onTranslationChanged: onTranslationChanged,
            onTransliterationChanged: onTransliterationChanged,
            centered: portraitMode,
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
    this.centered = false,
  });

  final Song song;
  final PlayerController controller;
  final Future<List<LyricLine>> Function(Song song) loadLyrics;
  final bool showTranslation;
  final bool showTransliteration;
  final ValueChanged<bool> onTranslationChanged;
  final ValueChanged<bool> onTransliterationChanged;
  final bool centered;

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
  Timer? _layerControlsTimer;
  bool _showLayerControls = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
    widget.controller.progress.addListener(_handleProgressChanged);
    _load();
  }

  @override
  void didUpdateWidget(covariant _LyricsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      oldWidget.controller.progress.removeListener(_handleProgressChanged);
      widget.controller.addListener(_handleControllerChanged);
      widget.controller.progress.addListener(_handleProgressChanged);
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
    widget.controller.progress.removeListener(_handleProgressChanged);
    _layerControlsTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _revealLayerControls({bool leaving = false}) {
    _layerControlsTimer?.cancel();
    if (!_showLayerControls) setState(() => _showLayerControls = true);
    _layerControlsTimer = Timer(
      Duration(milliseconds: leaving ? 700 : 2600),
      () {
        if (mounted) setState(() => _showLayerControls = false);
      },
    );
  }

  void _handleControllerChanged() {
    _syncActiveLine();
  }

  void _handleProgressChanged() {
    if (mounted) _syncActiveLine();
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
    return MouseRegion(
      onEnter: (_) => _revealLayerControls(),
      onHover: (_) => _revealLayerControls(),
      onExit: (_) => _revealLayerControls(leaving: true),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: widget.centered
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            if (hasTranslation || hasTransliteration) ...[
              SizedBox(
                height: 26,
                child: IgnorePointer(
                  ignoring: !_showLayerControls,
                  child: AnimatedOpacity(
                    opacity: _showLayerControls ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    child: Row(
                      mainAxisAlignment: widget.centered
                          ? MainAxisAlignment.center
                          : MainAxisAlignment.start,
                      children: [
                        if (hasTranslation)
                          _LyricLayerToggle(
                            label: '译',
                            tooltip: '外语翻译',
                            selected: widget.showTranslation,
                            onTap: () => widget.onTranslationChanged(
                              !widget.showTranslation,
                            ),
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
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(height: _lyricViewportHeight, child: _lyricsContent()),
          ],
        ),
      ),
    );
  }

  Widget _lyricsContent() {
    if (_loading) {
      return Align(
        alignment: widget.centered ? Alignment.center : Alignment.centerLeft,
        child: const _LyricLoadingIndicator(),
      );
    }
    if (_errorText != null) {
      return _LyricEmptyText(text: _errorText!, centered: widget.centered);
    }
    if (_lines.isEmpty) {
      return _LyricEmptyText(text: '暂无歌词', centered: widget.centered);
    }

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
            if (!widget.controller.isPlaying) {
              await widget.controller.togglePlay();
            }
            if (!mounted) return;
            _syncActiveLine(forceScroll: true);
          },
          child: SizedBox(
            height: _lyricRowExtent,
            child: Align(
              alignment: widget.centered
                  ? Alignment.center
                  : Alignment.centerLeft,
              child: AnimatedScale(
                scale: active ? 1 : 0.97,
                alignment: widget.centered
                    ? Alignment.center
                    : Alignment.centerLeft,
                duration: AppMotion.fast,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: widget.centered
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
                  children: [
                    _KaraokeLine(
                      line: line,
                      position: widget.controller.position,
                      active: active,
                      centered: widget.centered,
                    ),
                    if (secondary.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        secondary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: widget.centered
                            ? TextAlign.center
                            : TextAlign.start,
                        style: TextStyle(
                          color: widget.centered
                              ? Colors.white.withValues(
                                  alpha: active ? 0.88 : 0.58,
                                )
                              : active
                              ? AppColors.primary.withValues(alpha: 0.85)
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

class _LyricLoadingIndicator extends StatefulWidget {
  const _LyricLoadingIndicator();

  @override
  State<_LyricLoadingIndicator> createState() => _LyricLoadingIndicatorState();
}

class _LyricLoadingIndicatorState extends State<_LyricLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          final phase = (_controller.value - index * 0.16) % 1.0;
          final opacity = reduceMotion
              ? 0.52
              : (0.26 + (1 - (phase * 2 - 1).abs()) * 0.54);
          return Container(
            width: 4,
            height: 4,
            margin: EdgeInsets.only(right: index == 2 ? 0 : 5),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: opacity),
              shape: BoxShape.circle,
            ),
          );
        }),
      ),
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
    this.centered = false,
  });

  final LyricLine line;
  final Duration position;
  final bool active;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: 'NotoSansSC',
      color: centered
          ? Colors.white.withValues(alpha: active ? 0.98 : 0.66)
          : active
          ? AppColors.text
          : AppColors.muted.withValues(alpha: 0.82),
      fontSize: active ? 22 : 17,
      fontWeight: active ? FontWeight.w800 : FontWeight.w500,
      height: 1.24,
    );

    final progress = resolveLyricProgress(line, position).progress;

    return LayoutBuilder(
      builder: (context, constraints) {
        final hasBoundedWidth =
            constraints.hasBoundedWidth && constraints.maxWidth.isFinite;
        final maxWidth = hasBoundedWidth
            ? constraints.maxWidth
            : double.infinity;
        var resolvedStyle = style;
        var tp = TextPainter(
          text: TextSpan(text: line.text, style: resolvedStyle),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout();

        // The active line uses a larger font. For long English lyrics that
        // small size change can push only the final word outside the lyric
        // column. Scale that line down just enough to keep the full sentence
        // visible instead of clipping a word while it is being sung.
        if (active && hasBoundedWidth && tp.width > maxWidth && maxWidth > 0) {
          // Only make a small correction for a single trailing word. Truly
          // long lines remain wider than the viewport and continue through
          // the marquee path below.
          final scale = ((maxWidth - 8) / tp.width).clamp(0.88, 1.0);
          resolvedStyle = style.copyWith(
            fontSize: (style.fontSize ?? 22) * scale,
          );
          tp = TextPainter(
            text: TextSpan(text: line.text, style: resolvedStyle),
            maxLines: 1,
            textDirection: TextDirection.ltr,
          )..layout();
        }

        final textWidth = tp.width;
        final textHeight = tp.height;
        final effectiveMaxWidth = hasBoundedWidth ? maxWidth : textWidth;
        final isOverflow = hasBoundedWidth && textWidth > effectiveMaxWidth;

        final baseText = Text(
          line.text,
          maxLines: 1,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: resolvedStyle,
        );

        Widget child;
        if (!active || !line.hasExactTiming) {
          child = baseText;
        } else {
          child = Stack(
            children: [
              Text(
                line.text,
                maxLines: 1,
                textAlign: centered ? TextAlign.center : TextAlign.start,
                style: resolvedStyle.copyWith(
                  color: AppColors.muted.withValues(alpha: 0.5),
                ),
              ),
              ClipRect(
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Text(
                    line.text,
                    maxLines: 1,
                    textAlign: centered ? TextAlign.center : TextAlign.start,
                    style: resolvedStyle.copyWith(color: AppColors.text),
                  ),
                ),
              ),
            ],
          );
        }

        if (!isOverflow) {
          return child;
        }

        // Long lyric line auto-scroll (marquee) to left
        final overflowWidth = (textWidth - effectiveMaxWidth + 18.0).clamp(
          0.0,
          double.infinity,
        );
        final scrollOffset = active
            ? -overflowWidth * progress.clamp(0.0, 1.0)
            : 0.0;

        return SizedBox(
          height: textHeight,
          child: ClipRect(
            child: OverflowBox(
              minWidth: 0,
              maxWidth: double.infinity,
              minHeight: textHeight,
              maxHeight: textHeight,
              alignment: centered ? Alignment.center : Alignment.centerLeft,
              child: Transform.translate(
                offset: Offset(scrollOffset, 0),
                child: SizedBox(
                  width: textWidth + 60.0,
                  height: textHeight,
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LyricEmptyText extends StatelessWidget {
  const _LyricEmptyText({required this.text, this.centered = false});

  final String text;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: centered ? Alignment.center : Alignment.centerLeft,
      child: Text(
        text,
        textAlign: centered ? TextAlign.center : TextAlign.start,
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
    required this.portraitSelected,
    required this.portraitAvailable,
    required this.onTogglePortrait,
    required this.desktopLyricsVisible,
    required this.onDesktopLyricsChanged,
  });

  final PlayerController controller;
  final PlaybackQualityController playbackQualityController;
  final Song song;
  final ValueChanged<Song>? onLike;
  final ValueChanged<Song>? onAddToPlaylist;
  final bool portraitSelected;
  final bool portraitAvailable;
  final VoidCallback onTogglePortrait;
  final bool desktopLyricsVisible;
  final ValueChanged<bool> onDesktopLyricsChanged;

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
            width: 430,
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
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _NowPlayingActions(
                        song: song,
                        controller: controller,
                        onLike: onLike,
                        onAddToPlaylist: onAddToPlaylist,
                        compact: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _GlassControlButton(
                        tooltip: '上一首',
                        icon: Icons.skip_previous_rounded,
                        onPressed: controller.playPrevious,
                      ),
                      _PlayControlButton(
                        isPlaying: controller.isPlaying,
                        preparing: controller.isPreparing,
                        onPressed: controller.togglePlay,
                      ),
                      _GlassControlButton(
                        tooltip: '下一首',
                        icon: Icons.skip_next_rounded,
                        onPressed: () => controller.playNext(),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PlaybackQualityMenu(
                            controller: playbackQualityController,
                            compact: true,
                          ),
                          _DesktopLyricControlButton(
                            tooltip: desktopLyricsVisible ? '关闭桌面歌词' : '打开桌面歌词',
                            selected: desktopLyricsVisible,
                            onPressed: () =>
                                onDesktopLyricsChanged(!desktopLyricsVisible),
                          ),
                          _PortraitModeButton(
                            selected: portraitSelected,
                            available: portraitAvailable,
                            onPressed: onTogglePortrait,
                          ),
                        ],
                      ),
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
            climaxSegments: song.climaxSegments,
            onSeek: controller.seekByRatio,
            showTimes: true,
          ),
        ],
      ),
    );
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
    return AppIconButton.ghost(
      tooltip: tooltip,
      icon: icon,
      onPressed: onPressed,
      size: 42,
      iconSize: 22,
      iconColor: AppColors.muted,
      hoverIconColor: AppColors.primary,
      shadowColor: AppColors.primary,
    );
  }
}

class _DesktopLyricControlButton extends StatelessWidget {
  const _DesktopLyricControlButton({
    required this.tooltip,
    required this.onPressed,
    required this.selected,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AppIconButton.ghost(
      tooltip: tooltip,
      onPressed: onPressed,
      selected: selected,
      size: 42,
      selectedColor: AppColors.primary,
      selectedBackgroundColor: AppColors.primary.withValues(
        alpha: AppColors.isDark ? 0.18 : 0.10,
      ),
      hoverIconColor: AppColors.primary,
      shadowColor: AppColors.primary,
      child: Text(
        '词',
        style: TextStyle(
          color: selected ? AppColors.primary : AppColors.muted,
          fontSize: 15,
          height: 1,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PlayControlButton extends StatelessWidget {
  const _PlayControlButton({
    required this.isPlaying,
    required this.preparing,
    required this.onPressed,
  });

  final bool isPlaying;
  final bool preparing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: AppIconButton.filled(
        tooltip: preparing
            ? '正在准备'
            : isPlaying
            ? '暂停'
            : '播放',
        icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
        onPressed: preparing ? null : onPressed,
        size: 44,
        iconSize: 26,
        iconColor: AppColors.primary,
        hoverIconColor: AppColors.primary,
        backgroundColor: AppColors.surfaceMuted.withValues(
          alpha: isDark ? 0.40 : 0.60,
        ),
        hoverBackgroundColor: AppColors.primary.withValues(
          alpha: isDark ? 0.18 : 0.10,
        ),
        shadowColor: AppColors.primary,
        alwaysGlow: true,
        scaleFactor: 1.08,
        child: preparing ? const _PreparingDots() : null,
      ),
    );
  }
}

class _PreparingDots extends StatefulWidget {
  const _PreparingDots();

  @override
  State<_PreparingDots> createState() => _PreparingDotsState();
}

class _PreparingDotsState extends State<_PreparingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) {
      final phase = _controller.value;
      return SizedBox(
        width: 20,
        height: 20,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            final offset = (phase + index / 3) % 1;
            final opacity = (0.32 + (offset < 0.5 ? offset : 1 - offset) * 1.36)
                .clamp(0.0, 1.0);
            return Container(
              width: 3.5,
              height: 3.5,
              margin: const EdgeInsets.symmetric(horizontal: 1.2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: opacity),
                shape: BoxShape.circle,
              ),
            );
          }),
        ),
      );
    },
  );
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

IconData _playbackModeIcon(PlaybackMode mode) {
  return switch (mode) {
    PlaybackMode.sequence => Icons.format_list_numbered_rounded,
    PlaybackMode.repeatAll => Icons.repeat_rounded,
    PlaybackMode.repeatOne => Icons.repeat_one_rounded,
    PlaybackMode.shuffle => Icons.shuffle_rounded,
  };
}
