import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../controllers/playback_quality_controller.dart';
import '../controllers/player_controller.dart';
import '../models/lyric.dart';
import '../models/song.dart';
import '../services/cover_palette_service.dart';
import '../theme/app_theme.dart';
import 'album_art.dart';
import 'app_icon_button.dart';
import 'heart_off_icon.dart';
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
    this.isAddedToPlaylist = false,
    this.onOpenArtist,
    required this.desktopLyricsVisible,
    required this.onDesktopLyricsChanged,
    required this.showTranslation,
    required this.showTransliteration,
    required this.onTranslationChanged,
    required this.onTransliterationChanged,
    required this.loadArtistPortraits,
    this.isFm = false,
    this.onDislikeFm,
  });

  final PlayerController controller;
  final PlaybackQualityController playbackQualityController;
  final VoidCallback onClose;
  final Future<List<LyricLine>> Function(Song song) loadLyrics;
  final ValueChanged<Song>? onLike;
  final ValueChanged<Song>? onAddToPlaylist;
  final bool isAddedToPlaylist;
  final ValueChanged<Song>? onOpenArtist;
  final bool desktopLyricsVisible;
  final ValueChanged<bool> onDesktopLyricsChanged;
  final bool showTranslation;
  final bool showTransliteration;
  final ValueChanged<bool> onTranslationChanged;
  final ValueChanged<bool> onTransliterationChanged;
  final Future<List<String>> Function(Song song) loadArtistPortraits;
  final bool isFm;
  final VoidCallback? onDislikeFm;

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
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = screenWidth < 600;
    final isNarrow = screenWidth < 1000;
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          _FluidAmbientBackground(
            song: song,
            portraitUrl: _portraits.firstOrNull,
            portraitMode: _portraitMode,
            portraitLoading: _portraitLoading,
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 16 : (isNarrow ? 24 : 48),
                compact ? 12 : 52,
                compact ? 16 : (isNarrow ? 24 : 48),
                compact ? 12 : 18,
              ),
              child: Column(
                children: [
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
                    const SizedBox(height: 14),
                    RepaintBoundary(
                      child: _PlaybackControls(
                        controller: widget.controller,
                        playbackQualityController:
                            widget.playbackQualityController,
                        song: song,
                        onLike: widget.onLike,
                        onAddToPlaylist: widget.onAddToPlaylist,
                        isAddedToPlaylist: widget.isAddedToPlaylist,
                        portraitSelected: _portraitMode,
                        portraitAvailable: true,
                        onTogglePortrait: _togglePortraitMode,
                        desktopLyricsVisible: widget.desktopLyricsVisible,
                        onDesktopLyricsChanged: widget.onDesktopLyricsChanged,
                        isFm: widget.isFm,
                        onDislikeFm: widget.onDislikeFm,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            left: compact ? 12 : (isNarrow ? 16 : 22),
            bottom: 17,
            child: _SubtleCollapseButton(onClose: widget.onClose),
          ),
        ],
      ),
    );
  }
}

class _FluidAmbientBackground extends StatefulWidget {
  const _FluidAmbientBackground({
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
  State<_FluidAmbientBackground> createState() =>
      _FluidAmbientBackgroundState();
}

class _FluidAmbientBackgroundState extends State<_FluidAmbientBackground> {
  Color? _extractedColor;
  String? _lastCoverUrl;

  @override
  void initState() {
    super.initState();
    _resolveColor();
  }

  @override
  void didUpdateWidget(covariant _FluidAmbientBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song?.coverUrl != widget.song?.coverUrl) {
      _resolveColor();
    }
  }

  void _resolveColor() {
    final coverUrl = (widget.song?.coverUrl ?? '').trim();
    if (coverUrl == _lastCoverUrl) return;
    _lastCoverUrl = coverUrl;
    if (coverUrl.isEmpty) {
      if (mounted) setState(() => _extractedColor = null);
      return;
    }
    CoverPaletteService.colorFor(coverUrl).then((color) {
      if (!mounted || _lastCoverUrl != coverUrl) return;
      setState(() => _extractedColor = color);
    });
  }

  @override
  Widget build(BuildContext context) {
    final portrait = (widget.portraitUrl ?? '').trim();
    final showPortrait =
        widget.portraitMode && (!widget.portraitLoading || portrait.isNotEmpty);
    final dark = AppColors.isDark;

    if (showPortrait) {
      return Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF070A0F) : const Color(0xFFF8FAFD),
          ),
          child: RepaintBoundary(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 420),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: _PortraitTransitionArtwork(
                key: const ValueKey('portrait-mode'),
                portraitUrl: portrait,
                fallbackAsset: dark
                    ? 'assets/images/artist_wallpaper_dark.webp'
                    : 'assets/images/artist_wallpaper_light.webp',
              ),
            ),
          ),
        ),
      );
    }

    final baseAccent = _extractedColor ?? AppColors.primary;
    final hsv = HSVColor.fromColor(baseAccent);

    // Harmonious fluid palette derived from cover palette with lively vibrancy
    final c1 = hsv
        .withSaturation((hsv.saturation * 1.15).clamp(0.46, 0.90))
        .withValue((hsv.value * 1.00).clamp(0.48, 0.88))
        .toColor();
    final c2 = hsv
        .withHue((hsv.hue + 44) % 360)
        .withSaturation((hsv.saturation * 0.95).clamp(0.38, 0.82))
        .withValue((hsv.value * 1.05).clamp(0.50, 0.92))
        .toColor();
    final c3 = hsv
        .withHue((hsv.hue - 38 + 360) % 360)
        .withSaturation((hsv.saturation * 0.88).clamp(0.32, 0.78))
        .withValue((hsv.value * 0.95).clamp(0.44, 0.85))
        .toColor();

    return Positioned.fill(
      child: RepaintBoundary(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF080A10) : const Color(0xFFF5F7FB),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: CustomPaint(
                    key: ValueKey('aurora-${baseAccent.toARGB32()}-$dark'),
                    size: Size.infinite,
                    painter: _FluidAuroraPainter(
                      isDark: dark,
                      c1: c1,
                      c2: c2,
                      c3: c3,
                    ),
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: (dark ? const Color(0xFF080A10) : Colors.white)
                      .withValues(alpha: dark ? 0.24 : 0.50),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: dark
                        ? [
                            Colors.black.withValues(alpha: 0.28),
                            Colors.black.withValues(alpha: 0.08),
                            Colors.black.withValues(alpha: 0.38),
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.55),
                            Colors.white.withValues(alpha: 0.18),
                            Colors.white.withValues(alpha: 0.62),
                          ],
                    stops: const [0.0, 0.48, 1.0],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FluidAuroraPainter extends CustomPainter {
  const _FluidAuroraPainter({
    required this.isDark,
    required this.c1,
    required this.c2,
    required this.c3,
  });

  final bool isDark;
  final Color c1;
  final Color c2;
  final Color c3;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final w = size.width;
    final h = size.height;
    final radius = math.max(w, h) * 0.55;

    // Multi-stop radial gradients provide ultra-smooth, native GPU hardware falloff
    // with zero offscreen blur buffer overhead and zero banding.
    // Blob 1: upper-left ambient halo behind cover
    final p1 = Offset(w * 0.36, h * 0.32);
    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [
          c1.withValues(alpha: isDark ? 0.38 : 0.28),
          c1.withValues(alpha: isDark ? 0.20 : 0.15),
          c1.withValues(alpha: isDark ? 0.06 : 0.04),
          c1.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.35, 0.70, 1.0],
      ).createShader(Rect.fromCircle(center: p1, radius: radius));
    canvas.drawCircle(p1, radius, paint1);

    // Blob 2: upper-right gentle light behind lyrics
    final p2 = Offset(w * 0.74, h * 0.36);
    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          c2.withValues(alpha: isDark ? 0.34 : 0.24),
          c2.withValues(alpha: isDark ? 0.18 : 0.12),
          c2.withValues(alpha: isDark ? 0.05 : 0.03),
          c2.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.35, 0.70, 1.0],
      ).createShader(Rect.fromCircle(center: p2, radius: radius * 0.95));
    canvas.drawCircle(p2, radius * 0.95, paint2);

    // Blob 3: bottom-center subtle foundation behind controls
    final p3 = Offset(w * 0.54, h * 0.72);
    final paint3 = Paint()
      ..shader = RadialGradient(
        colors: [
          c3.withValues(alpha: isDark ? 0.30 : 0.20),
          c3.withValues(alpha: isDark ? 0.15 : 0.10),
          c3.withValues(alpha: isDark ? 0.04 : 0.02),
          c3.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.35, 0.70, 1.0],
      ).createShader(Rect.fromCircle(center: p3, radius: radius * 1.05));
    canvas.drawCircle(p3, radius * 1.05, paint3);
  }

  @override
  bool shouldRepaint(covariant _FluidAuroraPainter oldDelegate) {
    return oldDelegate.isDark != isDark ||
        oldDelegate.c1 != c1 ||
        oldDelegate.c2 != c2 ||
        oldDelegate.c3 != c3;
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
    this.isAddedToPlaylist = false,
    this.compact = false,
  });

  final Song song;
  final PlayerController controller;
  final ValueChanged<Song>? onLike;
  final ValueChanged<Song>? onAddToPlaylist;
  final bool isAddedToPlaylist;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 34.0 : 38.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _NowPlayingActionButton(
          tooltip: song.isMv
              ? (song.liked ? '取消收藏MV' : '收藏MV')
              : (song.liked ? '取消收藏' : '收藏'),
          icon: song.liked
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          selected: song.liked,
          size: size,
          onPressed: onLike == null ? null : () => onLike!(song),
        ),
        SizedBox(width: compact ? 4 : 6),
        _NowPlayingActionButton(
          tooltip: song.isMv
              ? 'MV音源暂不支持加入自建歌单'
              : (isAddedToPlaylist ? '歌单管理 (已收录)' : '添加到歌单'),
          icon: isAddedToPlaylist
              ? Icons.playlist_add_check_rounded
              : Icons.playlist_add_rounded,
          selected: isAddedToPlaylist && !song.isMv,
          selectedColor: AppColors.primary,
          size: size,
          onPressed: (song.isMv || onAddToPlaylist == null)
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
    this.selectedColor,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final bool selected;
  final Color? selectedColor;

  @override
  Widget build(BuildContext context) {
    final activeColor = selectedColor ?? AppColors.favorite;
    return AppIconButton.ghost(
      tooltip: tooltip,
      icon: icon,
      onPressed: onPressed,
      size: size,
      iconSize: size < 36 ? 18 : 20,
      selected: selected,
      selectedColor: activeColor,
      selectedBackgroundColor: Colors.transparent,
      iconColor: AppColors.muted,
      hoverIconColor: selected ? activeColor : AppColors.primary,
      shadowColor: selected ? activeColor : AppColors.primary,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final totalHeight = constraints.maxHeight;
        final isHuge = totalWidth >= 1600 && totalHeight >= 720;
        final isLarge = isHuge || (totalWidth >= 1350 && totalHeight >= 620);
        final isNarrow = totalWidth < 1000;

        if (portraitMode) {
          final portraitLyricsMaxWidth = isHuge
              ? 820.0
              : (isLarge ? 740.0 : 640.0);
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: portraitLyricsMaxWidth),
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
            ),
          );
        }

        final maxStageWidth = isHuge
            ? 1580.0
            : (isLarge ? 1380.0 : (isNarrow ? double.infinity : 1180.0));
        final columnGap = isHuge
            ? 96.0
            : (isLarge ? 76.0 : (isNarrow ? 36.0 : 52.0));
        final shiftRight = isLarge ? 24.0 : (isNarrow ? 12.0 : 36.0);

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxStageWidth),
            child: Padding(
              padding: EdgeInsets.only(left: shiftRight),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 1,
                    child: Align(
                      alignment: isLarge
                          ? const Alignment(0.08, 0.0)
                          : const Alignment(0.28, 0.0),
                      child: RepaintBoundary(
                        child: _SongIdentity(
                          song: song,
                          onOpenArtist: onOpenArtist,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: columnGap),
                  Expanded(
                    flex: 1,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: RepaintBoundary(
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
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
    return Column(
      children: [
        if (!portraitMode) ...[
          _SongIdentity(song: song, onOpenArtist: onOpenArtist),
          const SizedBox(height: 12),
        ],
        Expanded(
          child: _LyricsPanel(
            song: song,
            controller: controller,
            loadLyrics: loadLyrics,
            showTranslation: showTranslation,
            showTransliteration: showTransliteration,
            onTranslationChanged: onTranslationChanged,
            onTransliterationChanged: onTransliterationChanged,
            centered: portraitMode,
          ),
        ),
      ],
    );
  }
}

class _SongIdentity extends StatefulWidget {
  const _SongIdentity({required this.song, this.onOpenArtist});

  final Song song;
  final ValueChanged<Song>? onOpenArtist;

  @override
  State<_SongIdentity> createState() => _SongIdentityState();
}

class _SongIdentityState extends State<_SongIdentity> {
  Color? _paletteColor;
  String? _lastCover;

  @override
  void initState() {
    super.initState();
    _fetchColor();
  }

  @override
  void didUpdateWidget(covariant _SongIdentity oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.coverUrl != widget.song.coverUrl) {
      _fetchColor();
    }
  }

  void _fetchColor() {
    final cover = (widget.song.coverUrl ?? '').trim();
    if (cover == _lastCover) return;
    _lastCover = cover;
    if (cover.isEmpty) {
      if (mounted) setState(() => _paletteColor = null);
      return;
    }
    CoverPaletteService.colorFor(cover).then((color) {
      if (mounted && _lastCover == cover) {
        setState(() => _paletteColor = color);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final song = widget.song;
    final isDark = AppColors.isDark;
    final glowColor = _paletteColor ?? AppColors.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 520.0;
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 400.0;
        final isHuge = availableWidth >= 500 && availableHeight >= 700;
        final isLarge =
            isHuge || (availableWidth >= 400 && availableHeight >= 560);
        final maxCover = isHuge ? 380.0 : (isLarge ? 340.0 : 290.0);
        final factor = isHuge ? 0.54 : (isLarge ? 0.50 : 0.48);
        final paddingH = isLarge ? 48.0 : 32.0;
        final rawSize = math.min(
          availableWidth - paddingH,
          availableHeight * factor,
        );
        final coverSize = rawSize.clamp(170.0, maxCover);

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: math.min(
              availableWidth,
              math.max(260.0, coverSize + (isLarge ? 48 : 28)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pure album cover with ambient glow drop shadow (NO vinyl)
              RepaintBoundary(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 380),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      coverSize >= 340 ? 24 : 20,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: glowColor.withValues(
                          alpha: isDark ? 0.34 : 0.20,
                        ),
                        blurRadius: coverSize >= 340 ? 38 : 30,
                        offset: Offset(0, coverSize >= 340 ? 12 : 10),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.30 : 0.08,
                        ),
                        blurRadius: 18,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      coverSize >= 340 ? 24 : 20,
                    ),
                    child: AlbumArt(
                      size: coverSize,
                      emphasized: false,
                      imageUrl: song.coverUrl,
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: coverSize >= 340
                    ? 20
                    : (availableHeight < 420 ? 12 : 18),
              ),
              Tooltip(
                message: song.title,
                waitDuration: const Duration(milliseconds: 500),
                child: Text(
                  song.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'NotoSansSC',
                    color: AppColors.text,
                    fontSize: coverSize >= 340
                        ? 26.0
                        : (availableWidth < 340 ? 19.5 : 22.5),
                    fontWeight: FontWeight.w800,
                    height: 1.22,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: SongArtistLine(
                        song: song,
                        fontSize: coverSize >= 340
                            ? 15.5
                            : (availableWidth < 340 ? 13.0 : 14.0),
                        onArtistLink: widget.onOpenArtist == null
                            ? null
                            : (artist) => widget.onOpenArtist!(
                                song.copyWith(
                                  artist: artist.name,
                                  artistId: artist.id,
                                  artists: [artist],
                                ),
                              ),
                      ),
                    ),
                    if (song.album.trim().isNotEmpty) ...[
                      Flexible(
                        child: Text(
                          '  ·  ${song.album.trim()}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'NotoSansSC',
                            color: AppColors.muted,
                            fontSize: coverSize >= 340 ? 15.0 : 13.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
  final _scrollController = ScrollController();
  List<LyricLine> _lines = const [];
  bool _loading = true;
  String? _errorText;
  int _activeIndex = -1;
  Timer? _layerControlsTimer;
  bool _showLayerControls = false;

  double _getRowExtent(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (size.width >= 1600 && size.height >= 720) {
      return 78.0;
    } else if (size.width >= 1350 && size.height >= 620) {
      return 72.0;
    }
    return 60.0;
  }

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
      if (nextIndex >= 0 && mounted) {
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
      final rowExtent = _getRowExtent(context);
      final target = index * rowExtent;
      final safeTarget = target.clamp(
        _scrollController.position.minScrollExtent,
        _scrollController.position.maxScrollExtent,
      );
      await _scrollController.animateTo(
        safeTarget,
        duration: Duration(milliseconds: forceScroll ? 280 : 320),
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxH = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : 380.0;
          final layerHeight = (hasTranslation || hasTransliteration)
              ? 34.0
              : 0.0;
          final viewportHeight = math.max(120.0, maxH - layerHeight);

          final body = _lyricsContent(viewportHeight);

          final size = MediaQuery.sizeOf(context);
          final isHuge = size.width >= 1600;
          final isLarge = isHuge || size.width >= 1350;
          final panelMaxWidth = widget.centered
              ? (isHuge ? 820.0 : (isLarge ? 740.0 : 680.0))
              : (isHuge ? 780.0 : (isLarge ? 700.0 : 640.0));

          return ConstrainedBox(
            constraints: BoxConstraints(maxWidth: panelMaxWidth),
            child: Column(
              mainAxisSize: MainAxisSize.max,
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
                constraints.maxHeight.isFinite
                    ? Expanded(child: body)
                    : SizedBox(height: viewportHeight, child: body),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _lyricsContent(double viewportHeight) {
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

    final size = MediaQuery.sizeOf(context);
    final isHuge = size.width >= 1600 && size.height >= 720;
    final isLarge = isHuge || (size.width >= 1350 && size.height >= 620);
    final rowExtent = isHuge ? 78.0 : (isLarge ? 72.0 : 60.0);
    final activeFontSize = isHuge ? 29.0 : (isLarge ? 26.5 : 21.5);
    final inactiveFontSize = isHuge ? 19.0 : (isLarge ? 17.5 : 15.5);
    final activeSecondaryFontSize = isHuge ? 15.0 : (isLarge ? 14.0 : 12.0);
    final inactiveSecondaryFontSize = isHuge ? 13.5 : (isLarge ? 12.5 : 11.0);

    final focalOffset = viewportHeight * 0.42;
    final bottomPadding = math.max(
      0.0,
      viewportHeight - focalOffset - rowExtent,
    );

    final listView = ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(top: focalOffset, bottom: bottomPadding),
      itemCount: _lines.length,
      itemBuilder: (context, index) {
        final line = _lines[index];
        final active = index == _activeIndex;
        return _LyricRow(
          key: ValueKey('lyric-$index-${line.time.inMilliseconds}'),
          line: line,
          active: active,
          position: widget.controller.position,
          centered: widget.centered,
          showTranslation: widget.showTranslation,
          showTransliteration: widget.showTransliteration,
          rowExtent: rowExtent,
          activeFontSize: activeFontSize,
          inactiveFontSize: inactiveFontSize,
          activeSecondaryFontSize: activeSecondaryFontSize,
          inactiveSecondaryFontSize: inactiveSecondaryFontSize,
          onDoubleTap: () async {
            await widget.controller.seek(line.time);
            if (!widget.controller.isPlaying) {
              await widget.controller.togglePlay();
            }
            if (!mounted) return;
            _syncActiveLine(forceScroll: true);
          },
        );
      },
    );

    return ShaderMask(
      shaderCallback: (rect) {
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black,
            Colors.black,
            Colors.transparent,
          ],
          stops: [0.0, 0.18, 0.82, 1.0],
        ).createShader(rect);
      },
      blendMode: BlendMode.dstIn,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: listView,
      ),
    );
  }
}

class _LyricRow extends StatefulWidget {
  const _LyricRow({
    super.key,
    required this.line,
    required this.active,
    required this.position,
    required this.centered,
    required this.showTranslation,
    required this.showTransliteration,
    required this.onDoubleTap,
    this.rowExtent = 60.0,
    this.activeFontSize = 21.5,
    this.inactiveFontSize = 15.5,
    this.activeSecondaryFontSize = 12.0,
    this.inactiveSecondaryFontSize = 11.0,
  });

  final LyricLine line;
  final bool active;
  final Duration position;
  final bool centered;
  final bool showTranslation;
  final bool showTransliteration;
  final VoidCallback onDoubleTap;
  final double rowExtent;
  final double activeFontSize;
  final double inactiveFontSize;
  final double activeSecondaryFontSize;
  final double inactiveSecondaryFontSize;

  @override
  State<_LyricRow> createState() => _LyricRowState();
}

class _LyricRowState extends State<_LyricRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final centered = widget.centered;
    final isDark = AppColors.isDark;

    final secondary = <String>[
      if (widget.showTranslation &&
          (widget.line.translation ?? '').trim().isNotEmpty)
        widget.line.translation!.trim(),
      if (widget.showTransliteration &&
          (widget.line.transliteration ?? '').trim().isNotEmpty)
        widget.line.transliteration!.trim(),
    ].join('  ·  ');

    return MouseRegion(
      cursor: active ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: widget.onDoubleTap,
        child: SizedBox(
          height: widget.rowExtent,
          child: Align(
            alignment: centered ? Alignment.center : Alignment.centerLeft,
            child: AnimatedScale(
              scale: active ? 1.0 : (_hovered ? 1.01 : 0.98),
              alignment: centered ? Alignment.center : Alignment.centerLeft,
              duration: AppMotion.fast,
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: active
                    ? 1.0
                    : (_hovered
                          ? (isDark ? 0.88 : 0.84)
                          : (isDark ? 0.45 : 0.48)),
                duration: AppMotion.fast,
                curve: Curves.easeOutCubic,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: centered
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
                  children: [
                    _KaraokeLine(
                      line: widget.line,
                      position: widget.position,
                      active: active,
                      centered: centered,
                      activeFontSize: widget.activeFontSize,
                      inactiveFontSize: widget.inactiveFontSize,
                    ),
                    if (secondary.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        secondary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: centered
                            ? TextAlign.center
                            : TextAlign.start,
                        style: TextStyle(
                          fontFamily: 'NotoSansSC',
                          color: centered
                              ? Colors.white.withValues(
                                  alpha: active ? 0.88 : 0.60,
                                )
                              : active
                              ? AppColors.primary.withValues(alpha: 0.90)
                              : AppColors.muted,
                          fontSize: active
                              ? widget.activeSecondaryFontSize
                              : widget.inactiveSecondaryFontSize,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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
    this.activeFontSize = 21.5,
    this.inactiveFontSize = 15.5,
  });

  final LyricLine line;
  final Duration position;
  final bool active;
  final bool centered;
  final double activeFontSize;
  final double inactiveFontSize;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: 'NotoSansSC',
      color: centered
          ? Colors.white.withValues(alpha: active ? 0.98 : 0.66)
          : AppColors.text,
      fontSize: active ? activeFontSize : inactiveFontSize,
      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
      height: 1.28,
      letterSpacing: active ? -0.1 : 0.0,
    );

    final progress = resolveLyricProgress(line, position).progress;

    return LayoutBuilder(
      builder: (context, constraints) {
        final hasBoundedWidth =
            constraints.hasBoundedWidth && constraints.maxWidth.isFinite;
        final maxWidth = hasBoundedWidth
            ? constraints.maxWidth
            : double.infinity;

        final tp = TextPainter(
          text: TextSpan(text: line.text, style: style),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout();

        final textWidth = tp.width;
        final textHeight = tp.height;
        final effectiveMaxWidth = hasBoundedWidth ? maxWidth : textWidth;
        final isOverflow = hasBoundedWidth && textWidth > effectiveMaxWidth;

        final baseText = Text(
          line.text,
          maxLines: 1,
          overflow: isOverflow && !active ? TextOverflow.ellipsis : null,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: style,
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
                overflow: isOverflow && !active ? TextOverflow.ellipsis : null,
                textAlign: centered ? TextAlign.center : TextAlign.start,
                style: style.copyWith(
                  color: (centered ? Colors.white : AppColors.text).withValues(
                    alpha: centered ? 0.40 : 0.35,
                  ),
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
                    style: style.copyWith(
                      color: centered ? Colors.white : AppColors.text,
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        if (!isOverflow) {
          return child;
        }

        if (!active) {
          return baseText;
        }

        // 长歌词自动平滑跑马灯滑动 (marquee)
        final overflowWidth = (textWidth - effectiveMaxWidth + 28.0).clamp(
          0.0,
          double.infinity,
        );

        // 跑马灯推进曲线：
        // 0.0 ~ 0.12：保持开头静止，确保开头歌词清晰可读
        // 0.12 ~ 0.88：平滑滑动至末尾
        // 0.88 ~ 1.0：在末尾平稳停顿，确保结尾歌词清晰可读
        double marqueeCurve(double p) {
          if (p <= 0.12) return 0.0;
          if (p >= 0.88) return 1.0;
          final t = (p - 0.12) / (0.88 - 0.12);
          return Curves.easeInOutCubic.transform(t);
        }

        final scrollOffset =
            -overflowWidth * marqueeCurve(progress.clamp(0.0, 1.0));

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
    this.isAddedToPlaylist = false,
    required this.portraitSelected,
    required this.portraitAvailable,
    required this.onTogglePortrait,
    required this.desktopLyricsVisible,
    required this.onDesktopLyricsChanged,
    this.isFm = false,
    this.onDislikeFm,
  });

  final PlayerController controller;
  final PlaybackQualityController playbackQualityController;
  final Song song;
  final ValueChanged<Song>? onLike;
  final ValueChanged<Song>? onAddToPlaylist;
  final bool isAddedToPlaylist;
  final bool portraitSelected;
  final bool portraitAvailable;
  final VoidCallback onTogglePortrait;
  final bool desktopLyricsVisible;
  final ValueChanged<bool> onDesktopLyricsChanged;
  final bool isFm;
  final VoidCallback? onDislikeFm;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([controller, controller.progress]),
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
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: PlaybackProgress(
              position: controller.position,
              duration: duration,
              climaxSegments: song.climaxSegments,
              onSeek: controller.seekByRatio,
              showTimes: true,
            ),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SizedBox(
              height: 50,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(
                    alpha: AppColors.isDark ? 0.42 : 0.58,
                  ),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.border.withValues(
                      alpha: AppColors.isDark ? 0.32 : 0.45,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadow.withValues(
                        alpha: AppColors.isDark ? 0.25 : 0.08,
                      ),
                      blurRadius: 18,
                      offset: const Offset(0, 5),
                    ),
                  ],
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
                          isAddedToPlaylist: isAddedToPlaylist,
                          compact: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isFm)
                          _GlassControlButton(
                            tooltip: '不喜欢',
                            onPressed: onDislikeFm,
                            child: const HeartOffIcon(
                              size: 20,
                              strokeWidth: 1.7,
                            ),
                          )
                        else
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
                              playerController: controller,
                              compact: true,
                            ),
                            _DesktopLyricControlButton(
                              tooltip: desktopLyricsVisible
                                  ? '关闭桌面歌词'
                                  : '打开桌面歌词',
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
          ),
        ],
      ),
    );
  }
}

class _GlassControlButton extends StatelessWidget {
  const _GlassControlButton({
    required this.tooltip,
    this.icon,
    this.child,
    required this.onPressed,
  });

  final String tooltip;
  final IconData? icon;
  final Widget? child;
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
      child: child,
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
