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
      decoration: const BoxDecoration(
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
                if (song != null) ...[
                  const AlbumArt(size: 58, emphasized: true),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: compact ? 120 : 190,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          controller.errorText ?? song.artist,
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
                ] else ...[
                  const AlbumArt(size: 58),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: compact ? 120 : 190,
                    child: const Text(
                      '选择一首歌开始播放',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ),
                ],
                IconButton(
                  tooltip: '上一首',
                  onPressed: song == null ? null : controller.playPrevious,
                  icon: const Icon(Icons.skip_previous_rounded),
                ),
                FilledButton(
                  onPressed: song == null ? null : controller.togglePlay,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFD7DEE7),
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(14),
                    elevation: 0,
                  ),
                  child: Icon(
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
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      activeTrackColor: AppColors.primary,
                      inactiveTrackColor: AppColors.divider,
                      thumbColor: AppColors.primary,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 4,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 11,
                      ),
                    ),
                    child: Slider(
                      value: _progress(controller),
                      onChanged: song == null ? null : controller.seekByRatio,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatDuration(
                    controller.duration == Duration.zero && song != null
                        ? song.duration
                        : controller.duration,
                  ),
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
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

  double _progress(PlayerController controller) {
    if (controller.duration.inMilliseconds <= 0) return 0;
    return (controller.position.inMilliseconds /
            controller.duration.inMilliseconds)
        .clamp(0, 1);
  }
}
