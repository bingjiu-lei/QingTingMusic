import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/recommendation_controller.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';
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
    builder: (context, _) => Padding(
      padding: const EdgeInsets.fromLTRB(26, 6, 30, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '推荐',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text('今天想听的，和下一首惊喜。', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 20),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 700;
                  final daily = _DailyEntry(
                    count: controller.dailySongs.length,
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
                  final fm = _FmEntry(
                    controller: controller,
                    currentSong: currentSong,
                    onPlay: onPlayFm,
                  );
                  if (stacked)
                    return Column(
                      children: [daily, const SizedBox(height: 10), fm],
                    );
                  return Row(
                    children: [
                      Expanded(child: daily),
                      const SizedBox(width: 12),
                      Expanded(child: fm),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _DailyEntry extends StatelessWidget {
  const _DailyEntry({
    required this.count,
    required this.loading,
    required this.error,
    required this.onOpen,
    required this.onPlay,
  });
  final int count;
  final bool loading;
  final String? error;
  final VoidCallback onOpen;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) => _CompactSurface(
    onTap: onOpen,
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.selected,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Text(
            '${DateTime.now().day}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('每日推荐', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(
                loading ? '正在更新…' : error ?? '为你量身定制',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        _RoundAction(
          icon: Icons.play_arrow_rounded,
          tooltip: '播放每日推荐',
          onPressed: loading ? null : onPlay,
        ),
      ],
    ),
  );
}

class _FmEntry extends StatelessWidget {
  const _FmEntry({
    required this.controller,
    required this.currentSong,
    required this.onPlay,
  });
  final RecommendationController controller;
  final Song? currentSong;
  final SongPlayRequest onPlay;

  @override
  Widget build(BuildContext context) {
    final next = controller.fmSongs.isEmpty ? null : controller.fmSongs.first;
    return _CompactSurface(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.selected,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(Icons.radio_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '私人 FM',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                _LabeledProfileRow(
                  label: '频道',
                  value: controller.fmMode,
                  choices: const [
                    ('normal', '红心'),
                    ('small', '小众'),
                    ('peak', '速览'),
                  ],
                  onSelected: (mode) => unawaited(_change(mode: mode)),
                ),
                const SizedBox(height: 5),
                _LabeledProfileRow(
                  label: '偏好',
                  value: '${controller.fmSongPoolId}',
                  choices: const [('0', '口味'), ('1', '风格'), ('2', '探索')],
                  onSelected: (pool) =>
                      unawaited(_change(pool: int.parse(pool))),
                ),
              ],
            ),
          ),
          _RoundAction(
            icon: Icons.play_arrow_rounded,
            tooltip: '重新获取并播放私人 FM',
            onPressed: controller.loadingFm
                ? null
                : () => unawaited(_play(next)),
          ),
        ],
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

  Future<void> _play(Song? next) async {
    final song = await controller.restartFm();
    if (song != null) onPlay(song, controller.fmSongs);
  }
}

class _CompactSurface extends StatelessWidget {
  const _CompactSurface({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(AppRadius.xl),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      mouseCursor: onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: Container(
        height: 112,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      ),
    ),
  );
}

class _LabeledProfileRow extends StatelessWidget {
  const _LabeledProfileRow({
    required this.label,
    required this.value,
    required this.choices,
    required this.onSelected,
  });
  final String label;
  final String value;
  final List<(String, String)> choices;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 28,
        child: Text(
          label,
          style: TextStyle(color: AppColors.faint, fontSize: 11),
        ),
      ),
      Expanded(
        child: Wrap(
          spacing: 5,
          children: choices
              .map(
                (choice) => ChoiceChip(
                  label: Text(choice.$2),
                  selected: value == choice.$1,
                  onSelected: (_) => onSelected(choice.$1),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  showCheckmark: false,
                  selectedColor: AppColors.selected,
                  side: BorderSide(
                    color: value == choice.$1
                        ? Colors.transparent
                        : AppColors.border,
                  ),
                  labelStyle: TextStyle(
                    color: value == choice.$1
                        ? AppColors.primary
                        : AppColors.muted,
                    fontSize: 11,
                    fontWeight: value == choice.$1
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              )
              .toList(),
        ),
      ),
    ],
  );
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      color: Colors.white,
      style: IconButton.styleFrom(
        backgroundColor: AppColors.primary,
        disabledBackgroundColor: AppColors.faint,
      ),
    ),
  );
}
