import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/recommendation_controller.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';
import '../widgets/album_art.dart';
import '../widgets/glass.dart';
import '../widgets/song_panel.dart';

const double _heroHeight = 210;

class RecommendationPage extends StatelessWidget {
  const RecommendationPage({
    super.key,
    required this.controller,
    required this.currentSong,
    required this.onPlay,
    required this.onPlayFm,
    required this.onOpenDaily,
  });

  final RecommendationController controller;
  final Song? currentSong;
  final SongPlayRequest onPlay;
  final SongPlayRequest onPlayFm;
  final VoidCallback onOpenDaily;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 8, 18, 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('推荐', style: AppTypography.pageTitle),
              const SizedBox(height: 6),
              Text('今天听点喜欢的，也遇见一点新鲜', style: AppTypography.pageSubtitle),
              const SizedBox(height: 22),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 760;
                  final daily = _DailyHero(
                    songs: controller.dailySongs,
                    loading: controller.loadingDaily,
                    error: controller.dailyError,
                    onOpen: controller.dailySongs.isEmpty
                        ? () => controller.loadDaily(refresh: true)
                        : onOpenDaily,
                    onPlay: controller.dailySongs.isEmpty
                        ? () => controller.loadDaily(refresh: true)
                        : () => onPlay(
                            controller.dailySongs.first,
                            controller.dailySongs,
                          ),
                  );
                  final fm = _FmHero(
                    controller: controller,
                    currentSong: currentSong,
                    onPlay: onPlayFm,
                  );
                  if (stacked) {
                    return Column(
                      children: [daily, const SizedBox(height: 14), fm],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 11, child: daily),
                      const SizedBox(width: 14),
                      Expanded(flex: 9, child: fm),
                    ],
                  );
                },
              ),
              if (controller.dailySongs.isNotEmpty) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    Text('今天先听这几首', style: AppTypography.panelTitle),
                    const Spacer(),
                    Tooltip(
                      message: '查看全部',
                      child: IconButton(
                        onPressed: onOpenDaily,
                        tooltip: '查看全部',
                        icon: const Icon(Icons.arrow_forward_rounded, size: 19),
                        style: IconButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          backgroundColor: AppColors.primary.withValues(
                            alpha: AppColors.isDark ? 0.14 : 0.09,
                          ),
                          hoverColor: AppColors.primary.withValues(alpha: 0.16),
                          shape: const CircleBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _DailyPreview(
                  songs: controller.dailySongs.take(3).toList(),
                  onPlay: onPlay,
                  queue: controller.dailySongs,
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _DailyHero extends StatelessWidget {
  const _DailyHero({
    required this.songs,
    required this.loading,
    required this.error,
    required this.onOpen,
    required this.onPlay,
  });

  final List<Song> songs;
  final bool loading;
  final String? error;
  final VoidCallback onOpen;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark;
    final aurora = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        AppColors.primary.withValues(alpha: dark ? 0.20 : 0.12),
        AppColors.accent.withValues(alpha: dark ? 0.14 : 0.08),
      ],
    );
    return GlassSurface(
      radius: AppRadius.xxl,
      shadows: AppShadows.card,
      child: SizedBox(
        height: _heroHeight,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(decoration: BoxDecoration(gradient: aurora)),
            ),
            Positioned(
              right: -38,
              top: -64,
              child: _AuroraBlob(
                size: 190,
                color: AppColors.primary,
                alpha: dark ? 0.16 : 0.10,
              ),
            ),
            Positioned(
              left: -46,
              bottom: -78,
              child: _AuroraBlob(
                size: 170,
                color: AppColors.accent,
                alpha: dark ? 0.12 : 0.08,
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 20, 8, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const _DateBadge(),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '每日推荐',
                                  style: AppTypography.style(
                                    19,
                                    780,
                                    color: AppColors.text,
                                  ),
                                ),
                                Text(
                                  songs.isEmpty
                                      ? '每天为你更新'
                                      : '${songs.length} 首 · 为你定制',
                                  style: AppTypography.style(
                                    12,
                                    600,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          loading ? '正在准备今天的音乐…' : error ?? '从熟悉的声音开始，也留一点未知',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.style(
                            12,
                            500,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _GlassRoundButton(
                              loading: loading,
                              tooltip: '播放每日推荐',
                              onPressed: onPlay,
                            ),
                            const SizedBox(width: 8),
                            _GlassRoundButton(
                              loading: loading,
                              filled: false,
                              size: 36,
                              icon: Icons.arrow_forward_rounded,
                              tooltip: '查看歌单',
                              onPressed: onOpen,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 168, child: _CoverStack(songs: songs)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DateBadge extends StatelessWidget {
  const _DateBadge();

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.primary.withValues(alpha: 0.18)
            : AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isDark
              ? AppColors.primary.withValues(alpha: 0.35)
              : AppColors.primary.withValues(alpha: 0.22),
          width: 1,
        ),
      ),
      child: Text(
        '${DateTime.now().day}',
        style: AppTypography.style(18, 800, color: AppColors.primary),
      ),
    );
  }
}

class _AuroraBlob extends StatelessWidget {
  const _AuroraBlob({
    required this.size,
    required this.color,
    required this.alpha,
  });

  final double size;
  final Color color;
  final double alpha;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    ),
  );
}

class _CoverStack extends StatelessWidget {
  const _CoverStack({required this.songs});
  final List<Song> songs;

  @override
  Widget build(BuildContext context) {
    final covers = songs.take(3).toList();
    if (covers.isEmpty) {
      return Center(
        child: Icon(
          Icons.wb_sunny_rounded,
          color: AppColors.primary.withValues(alpha: 0.42),
          size: 72,
        ),
      );
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        for (var index = 0; index < covers.length; index++)
          Transform.translate(
            offset: Offset((index - 1) * 24, (index - 1).abs() * 7),
            child: Transform.rotate(
              angle: (index - 1) * 0.09,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(color: AppColors.surface, width: 3),
                  boxShadow: AppShadows.card,
                ),
                child: AlbumArt(
                  size: index == 1 ? 104 : 92,
                  imageUrl: covers[index].coverUrl,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FmHero extends StatelessWidget {
  const _FmHero({
    required this.controller,
    required this.currentSong,
    required this.onPlay,
  });

  static const _modes = ['normal', 'small', 'peak'];

  final RecommendationController controller;
  final Song? currentSong;
  final SongPlayRequest onPlay;

  Song? get _displaySong {
    if (currentSong != null && controller.isFmSong(currentSong!)) {
      return currentSong;
    }
    return controller.fmSongs.isEmpty ? null : controller.fmSongs.first;
  }

  @override
  Widget build(BuildContext context) {
    final song = _displaySong;
    final modeIndex = _modes.indexOf(controller.fmMode);
    return GlassSurface(
      radius: AppRadius.xxl,
      shadows: AppShadows.card,
      child: SizedBox(
        height: _heroHeight,
        child: Stack(
          children: [
            Positioned(
              right: -44,
              top: -56,
              child: _AuroraBlob(
                size: 160,
                color: AppColors.accent,
                alpha: AppColors.isDark ? 0.12 : 0.08,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AlbumArt(
                            size: 78,
                            emphasized: song != null,
                            imageUrl: song?.coverUrl,
                          ),
                          Positioned(
                            right: -4,
                            bottom: -4,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: AppColors.accentSoft,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.surface,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.radio_rounded,
                                size: 14,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '私人 FM',
                              style: AppTypography.style(
                                19,
                                780,
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              song?.title ?? '等待你的第一首歌',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.style(
                                13,
                                700,
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              controller.loadingFm
                                  ? '正在寻找下一首…'
                                  : controller.fmError ??
                                        song?.artist ??
                                        '选择频道与偏好后开始',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.style(
                                11,
                                500,
                                color: controller.fmError == null
                                    ? AppColors.muted
                                    : AppColors.danger,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _GlassRoundButton(
                        loading: controller.loadingFm,
                        tooltip: '重新获取并播放私人 FM',
                        onPressed: () => unawaited(_play()),
                      ),
                    ],
                  ),
                  const Spacer(),
                  _FmProfileRow(
                    label: '频道',
                    tabs: const ['红心', '小众', '速览'],
                    selectedIndex: modeIndex < 0 ? 0 : modeIndex,
                    loading: controller.loadingFm,
                    onChanged: (index) =>
                        unawaited(_change(mode: _modes[index])),
                  ),
                  const SizedBox(height: 8),
                  _FmProfileRow(
                    label: '偏好',
                    tabs: const ['口味', '风格', '探索'],
                    selectedIndex: controller.fmSongPoolId.clamp(0, 2),
                    loading: controller.loadingFm,
                    onChanged: (index) => unawaited(_change(pool: index)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _change({String? mode, int? pool}) async {
    final song = await controller.selectFmProfile(
      mode: mode ?? controller.fmMode,
      songPoolId: pool ?? controller.fmSongPoolId,
    );
    if (song != null) onPlay(song, controller.fmSongs);
  }

  Future<void> _play() async {
    final song = await controller.restartFm();
    if (song != null) onPlay(song, controller.fmSongs);
  }
}

class _FmProfileRow extends StatelessWidget {
  const _FmProfileRow({
    required this.label,
    required this.tabs,
    required this.selectedIndex,
    required this.loading,
    required this.onChanged,
  });

  final String label;
  final List<String> tabs;
  final int selectedIndex;
  final bool loading;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 34,
        child: Text(
          label,
          style: AppTypography.style(11, 600, color: AppColors.faint),
        ),
      ),
      IgnorePointer(
        ignoring: loading,
        child: AnimatedOpacity(
          duration: AppMotion.fast,
          curve: AppMotion.curve,
          opacity: loading ? 0.6 : 1,
          child: GlassTabBar(
            dense: true,
            tabs: tabs,
            selectedIndex: selectedIndex,
            onChanged: onChanged,
          ),
        ),
      ),
    ],
  );
}

class _GlassRoundButton extends StatefulWidget {
  const _GlassRoundButton({
    required this.loading,
    required this.tooltip,
    required this.onPressed,
    this.icon = Icons.play_arrow_rounded,
    this.filled = true,
    this.size = 38,
  });

  final bool loading;
  final String tooltip;
  final VoidCallback onPressed;
  final IconData icon;
  final bool filled;
  final double size;

  @override
  State<_GlassRoundButton> createState() => _GlassRoundButtonState();
}

class _GlassRoundButtonState extends State<_GlassRoundButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = !widget.loading;
    final scale = !enabled
        ? 1.0
        : _pressed
        ? 0.97
        : _hovered
        ? 1.02
        : 1.0;
    final Color background;
    final Color foreground;
    if (widget.filled) {
      background = !enabled
          ? AppColors.primary.withValues(alpha: 0.38)
          : _pressed
          ? AppColors.primaryPressed
          : AppColors.primary;
      foreground = Colors.white;
    } else {
      background = AppColors.primary.withValues(
        alpha: !enabled
            ? 0.06
            : (_hovered || _pressed)
            ? 0.16
            : 0.10,
      );
      foreground = enabled ? AppColors.primary : AppColors.faint;
    }
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() {
          _hovered = false;
          _pressed = false;
        }),
        child: GestureDetector(
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: () => setState(() => _pressed = false),
          onTap: enabled ? widget.onPressed : null,
          child: AnimatedScale(
            scale: scale,
            duration: AppMotion.fast,
            curve: AppMotion.curve,
            child: AnimatedContainer(
              duration: AppMotion.fast,
              curve: AppMotion.curve,
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: widget.filled && enabled
                    ? Border.all(
                        color: Colors.white.withValues(
                          alpha: _hovered ? 0.52 : 0.32,
                        ),
                        width: 1,
                      )
                    : Border.all(
                        color: AppColors.isDark
                            ? Colors.white.withValues(
                                alpha: _hovered ? 0.20 : 0.10,
                              )
                            : Colors.white.withValues(
                                alpha: _hovered ? 0.85 : 0.60,
                              ),
                        width: 1,
                      ),
                boxShadow: widget.filled && enabled
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(
                            alpha: AppColors.isDark ? 0.40 : 0.28,
                          ),
                          blurRadius: _hovered ? 16 : 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: widget.loading
                    ? SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: foreground,
                        ),
                      )
                    : Icon(
                        widget.icon,
                        size: widget.size >= 38 ? 20 : 18,
                        color: foreground,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyPreview extends StatelessWidget {
  const _DailyPreview({
    required this.songs,
    required this.onPlay,
    required this.queue,
  });
  final List<Song> songs;
  final SongPlayRequest onPlay;
  final List<Song> queue;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = (constraints.maxWidth - 20) / songs.length;
      return Row(
        children: [
          for (var index = 0; index < songs.length; index++) ...[
            if (index > 0) const SizedBox(width: 10),
            SizedBox(
              width: width,
              child: _PreviewTile(
                song: songs[index],
                onTap: () => onPlay(songs[index], queue),
              ),
            ),
          ],
        ],
      );
    },
  );
}

class _PreviewTile extends StatefulWidget {
  const _PreviewTile({required this.song, required this.onTap});
  final Song song;
  final VoidCallback onTap;

  @override
  State<_PreviewTile> createState() => _PreviewTileState();
}

class _PreviewTileState extends State<_PreviewTile> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() {
      _hovered = false;
      _pressed = false;
    }),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed
            ? 0.97
            : _hovered
            ? 1.02
            : 1.0,
        duration: AppMotion.fast,
        curve: AppMotion.curve,
        child: GlassSurface(
          radius: AppRadius.xl,
          tint: _hovered ? AppGlass.surfaceStrong : AppGlass.surface,
          child: SizedBox(
            height: 72,
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: Row(
                children: [
                  AlbumArt(size: 52, imageUrl: widget.song.coverUrl),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.style(
                            13.5,
                            700,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.style(
                            11.5,
                            500,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.play_arrow_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
