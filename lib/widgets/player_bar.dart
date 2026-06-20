import 'package:flutter/material.dart';

import '../controllers/player_controller.dart';
import '../theme/app_theme.dart';
import 'album_art.dart';
import 'song_row.dart';

class PlayerBar extends StatelessWidget {
  const PlayerBar({super.key, required this.controller});

  final PlayerController controller;

  @override
  Widget build(BuildContext context) {
    final song = controller.currentSong;
    return Container(
      height: 92,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 920;
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 22),
            child: Row(
              children: [
                AlbumArt(
                  size: 58,
                  emphasized: song != null,
                  imageUrl: song?.coverUrl,
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: compact ? 120 : 190,
                  child: song == null
                      ? Text(
                          '选择一首歌开始播放',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.text,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              controller.errorText ??
                                  (controller.isPreparing
                                      ? '正在准备播放'
                                      : song.artist),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: controller.errorText == null
                                    ? AppColors.muted
                                    : AppColors.danger,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                ),
                IconButton(
                  tooltip: '上一首',
                  onPressed: song == null ? null : controller.playPrevious,
                  icon: const Icon(Icons.skip_previous_rounded),
                ),
                FilledButton(
                  onPressed: song == null || controller.isPreparing
                      ? null
                      : controller.togglePlay,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.primary.withValues(
                      alpha: 0.5,
                    ),
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(14),
                    elevation: 0,
                  ),
                  child: controller.isPreparing
                      ? const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          controller.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 28,
                        ),
                ),
                IconButton(
                  tooltip: '下一首',
                  onPressed: song == null ? null : controller.playNext,
                  icon: const Icon(Icons.skip_next_rounded),
                ),
                SizedBox(width: compact ? 8 : 18),
                Text(
                  formatDuration(controller.position),
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(width: 8),
                Expanded(child: _BufferedProgress(controller: controller)),
                const SizedBox(width: 8),
                Text(
                  formatDuration(
                    controller.duration == Duration.zero && song != null
                        ? song.duration
                        : controller.duration,
                  ),
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                if (!compact) ...[
                  const SizedBox(width: 12),
                  IconButton(
                    tooltip: '音量',
                    onPressed: () {},
                    icon: const Icon(Icons.volume_up_rounded),
                  ),
                  IconButton(
                    tooltip: '播放队列',
                    onPressed: () {},
                    icon: const Icon(Icons.queue_music_rounded),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BufferedProgress extends StatelessWidget {
  const _BufferedProgress({required this.controller});

  final PlayerController controller;

  @override
  Widget build(BuildContext context) {
    final played = _ratio(controller.position);
    final buffered = _ratio(controller.bufferedPosition);
    return SizedBox(
      height: 30,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              minHeight: 4,
              value: buffered,
              color: AppColors.primary.withValues(alpha: 0.22),
              backgroundColor: AppColors.divider,
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: Colors.transparent,
              thumbColor: AppColors.primary,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayColor: AppColors.primary.withValues(alpha: 0.12),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 13),
            ),
            child: Slider(
              value: played,
              onChanged: controller.currentSong == null
                  ? null
                  : controller.seekByRatio,
            ),
          ),
        ],
      ),
    );
  }

  double _ratio(Duration value) {
    if (controller.duration.inMilliseconds <= 0) return 0;
    return (value.inMilliseconds / controller.duration.inMilliseconds).clamp(
      0,
      1,
    );
  }
}
