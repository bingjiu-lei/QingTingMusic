import 'package:flutter/material.dart';

import '../controllers/player_controller.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';
import 'album_art.dart';
import 'song_row.dart';

class PlayQueuePanel extends StatelessWidget {
  const PlayQueuePanel({
    super.key,
    required this.controller,
    required this.onClose,
  });

  final PlayerController controller;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final queue = controller.queue;
        final currentIndex = controller.queueIndex;
        return Container(
          width: 388,
          height: double.infinity,
          margin: const EdgeInsets.only(top: 36, bottom: 92),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(left: BorderSide(color: AppColors.divider)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: AppColors.isDark ? 0.25 : 0.08,
                ),
                blurRadius: 22,
                offset: const Offset(-8, 0),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '播放队列',
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            queue.isEmpty
                                ? '暂无歌曲'
                                : '${queue.length} 首 · ${currentIndex < 0 ? 0 : currentIndex + 1}/${queue.length}',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: '清空队列',
                      onPressed: queue.isEmpty ? null : controller.clearQueue,
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: onClose,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppColors.divider),
              Expanded(
                child: queue.isEmpty
                    ? Center(
                        child: Text(
                          '双击歌曲后会替换为当前列表',
                          style: TextStyle(color: AppColors.faint),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                        itemCount: queue.length,
                        itemBuilder: (context, index) {
                          final song = queue[index];
                          final current = controller.currentSong?.id == song.id;
                          return _QueueTile(
                            song: song,
                            index: index,
                            current: current,
                            playing: current && controller.isPlaying,
                            onPlay: () => controller.playQueueSong(song),
                            onRemove: () => controller.removeFromQueue(song),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QueueTile extends StatefulWidget {
  const _QueueTile({
    required this.song,
    required this.index,
    required this.current,
    required this.playing,
    required this.onPlay,
    required this.onRemove,
  });

  final Song song;
  final int index;
  final bool current;
  final bool playing;
  final VoidCallback onPlay;
  final VoidCallback onRemove;

  @override
  State<_QueueTile> createState() => _QueueTileState();
}

class _QueueTileState extends State<_QueueTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: widget.current
            ? AppColors.selected
            : _hovered
            ? AppColors.surfaceMuted
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: widget.onPlay,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: widget.current && widget.playing
                      ? Icon(
                          Icons.graphic_eq_rounded,
                          color: AppColors.primary,
                          size: 16,
                        )
                      : Text(
                          '${widget.index + 1}'.padLeft(2, '0'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: widget.current
                                ? AppColors.primary
                                : AppColors.faint,
                            fontSize: 11,
                          ),
                        ),
                ),
                AlbumArt(
                  size: 42,
                  emphasized: widget.current,
                  imageUrl: widget.song.coverUrl,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: widget.current
                              ? AppColors.primary
                              : AppColors.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  formatDuration(widget.song.duration),
                  style: TextStyle(color: AppColors.faint, fontSize: 11),
                ),
                AnimatedOpacity(
                  opacity: _hovered ? 1 : 0,
                  duration: const Duration(milliseconds: 120),
                  child: IconButton(
                    tooltip: '移出队列',
                    onPressed: widget.onRemove,
                    icon: const Icon(Icons.close_rounded, size: 17),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
