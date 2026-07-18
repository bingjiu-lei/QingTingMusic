import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/recommendation_controller.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';
import '../widgets/album_art.dart';
import '../widgets/song_panel.dart';

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
              const Text(
                '推荐',
                style: TextStyle(
                  fontSize: 29,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '今天听点喜欢的，也遇见一点新鲜',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
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
                    Text(
                      '今天先听这几首',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: onOpenDaily,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                      iconAlignment: IconAlignment.end,
                      label: const Text('查看全部'),
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
    return _HeroSurface(
      height: 210,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: AppColors.isDark
            ? [const Color(0xFF19283C), const Color(0xFF20203A)]
            : [const Color(0xFFEAF4FF), const Color(0xFFF1EFFF)],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -38,
            top: -64,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.08),
              ),
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
                          Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.surface.withValues(alpha: 0.86),
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.44),
                              ),
                            ),
                            child: Text(
                              '${DateTime.now().day}',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '每日推荐',
                                style: TextStyle(
                                  color: AppColors.text,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                songs.isEmpty
                                    ? '每天为你更新'
                                    : '${songs.length} 首 · 为你定制',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
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
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _LightPlayButton(
                            loading: loading,
                            tooltip: '播放每日推荐',
                            onPressed: onPlay,
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            tooltip: '查看歌单',
                            onPressed: loading ? null : onOpen,
                            mouseCursor: loading
                                ? SystemMouseCursors.basic
                                : SystemMouseCursors.click,
                            icon: const Icon(Icons.arrow_forward_rounded),
                            style: IconButton.styleFrom(
                              minimumSize: const Size(36, 36),
                              fixedSize: const Size(36, 36),
                              iconSize: 18,
                              foregroundColor: AppColors.primary,
                              hoverColor: AppColors.primary.withValues(
                                alpha: 0.10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
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
    );
  }
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
    return _HeroSurface(
      height: 210,
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        song?.title ?? '等待你的第一首歌',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
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
                        style: TextStyle(
                          color: controller.fmError == null
                              ? AppColors.muted
                              : AppColors.danger,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                _LightPlayButton(
                  loading: controller.loadingFm,
                  tooltip: '重新获取并播放私人 FM',
                  onPressed: () => unawaited(_play()),
                ),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: _ProfileGroup(
                    label: '频道',
                    value: controller.fmMode,
                    choices: const [
                      ('normal', '红心'),
                      ('small', '小众'),
                      ('peak', '速览'),
                    ],
                    loading: controller.loadingFm,
                    onSelected: (mode) => unawaited(_change(mode: mode)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ProfileGroup(
                    label: '偏好',
                    value: '${controller.fmSongPoolId}',
                    choices: const [('0', '口味'), ('1', '风格'), ('2', '探索')],
                    loading: controller.loadingFm,
                    onSelected: (pool) =>
                        unawaited(_change(pool: int.parse(pool))),
                  ),
                ),
              ],
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

class _LightPlayButton extends StatelessWidget {
  const _LightPlayButton({
    required this.loading,
    required this.tooltip,
    required this.onPressed,
  });
  final bool loading;
  final String tooltip;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: loading ? null : onPressed,
    mouseCursor: loading ? SystemMouseCursors.basic : SystemMouseCursors.click,
    icon: loading
        ? const SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.play_arrow_rounded),
    style: IconButton.styleFrom(
      minimumSize: const Size(38, 38),
      fixedSize: const Size(38, 38),
      iconSize: 20,
      foregroundColor: AppColors.primary,
      disabledForegroundColor: AppColors.faint,
      backgroundColor: AppColors.primary.withValues(
        alpha: AppColors.isDark ? 0.18 : 0.11,
      ),
      hoverColor: AppColors.primary.withValues(alpha: 0.18),
      highlightColor: AppColors.primary.withValues(alpha: 0.14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}

class _ProfileGroup extends StatelessWidget {
  const _ProfileGroup({
    required this.label,
    required this.value,
    required this.choices,
    required this.loading,
    required this.onSelected,
  });
  final String label;
  final String value;
  final List<(String, String)> choices;
  final bool loading;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 3, bottom: 5),
        child: Text(
          label,
          style: TextStyle(
            color: AppColors.faint,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      Container(
        height: 31,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            for (final choice in choices)
              Expanded(
                child: _ProfileOption(
                  label: choice.$2,
                  selected: value == choice.$1,
                  onTap: loading ? null : () => onSelected(choice.$1),
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

class _ProfileOption extends StatelessWidget {
  const _ProfileOption({
    required this.label,
    required this.selected,
    this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.surface : Colors.transparent,
    borderRadius: BorderRadius.circular(AppRadius.sm),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.primaryPressed : AppColors.muted,
            fontSize: 10,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    ),
  );
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

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({required this.song, required this.onTap});
  final Song song;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(AppRadius.xl),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      mouseCursor: SystemMouseCursors.click,
      child: Container(
        height: 72,
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            AlbumArt(size: 52, imageUrl: song.coverUrl),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(Icons.play_arrow_rounded, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    ),
  );
}

class _HeroSurface extends StatelessWidget {
  const _HeroSurface({
    required this.height,
    required this.child,
    this.gradient,
  });
  final double height;
  final Widget child;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: gradient == null ? AppColors.surface : null,
      gradient: gradient,
      borderRadius: BorderRadius.circular(AppRadius.xxl),
      border: Border.all(color: AppColors.border),
      boxShadow: AppShadows.card,
    ),
    child: child,
  );
}
