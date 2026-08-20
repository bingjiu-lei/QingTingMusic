import 'package:flutter/material.dart';

import '../controllers/player_controller.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';
import 'album_art.dart';
import 'app_icon_button.dart';
import 'smooth_mouse_scroll.dart';
import 'song_row.dart';

class PlayQueuePanel extends StatefulWidget {
  const PlayQueuePanel({
    super.key,
    required this.controller,
    required this.onClose,
  });

  final PlayerController controller;
  final VoidCallback onClose;

  @override
  State<PlayQueuePanel> createState() => _PlayQueuePanelState();
}

class _PlayQueuePanelState extends State<PlayQueuePanel> {
  static const _itemExtent = 58.0;
  static const _listTopPadding = 10.0;

  final _scrollController = ScrollController();
  int _lastScrolledIndex = -1;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrent(force: true);
    });
  }

  @override
  void didUpdateWidget(covariant PlayQueuePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
      _lastScrolledIndex = -1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToCurrent(force: true);
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    _scrollToCurrent();
  }

  void _scrollToCurrent({bool force = false}) {
    final index = widget.controller.queueIndex;
    if (index < 0 || (!force && index == _lastScrolledIndex)) return;
    _lastScrolledIndex = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final viewport = _scrollController.position.viewportDimension;
      final target =
          _listTopPadding + index * _itemExtent - (viewport - _itemExtent) / 2;
      final safeTarget = target.clamp(
        _scrollController.position.minScrollExtent,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.animateTo(
        safeTarget,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final queue = widget.controller.queue;
        final currentIndex = widget.controller.queueIndex;
        return Container(
          width: 388,
          height: double.infinity,
          margin: const EdgeInsets.only(top: 36, bottom: 104),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(16),
            ),
            border: Border.all(color: AppColors.divider),
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
                    AppIconButton.ghost(
                      tooltip: '清空队列',
                      icon: Icons.delete_outline_rounded,
                      onPressed: queue.isEmpty
                          ? null
                          : widget.controller.clearQueue,
                      size: 36,
                      iconSize: 18,
                      hoverIconColor: AppColors.danger,
                      shadowColor: AppColors.danger,
                    ),
                    const SizedBox(width: 4),
                    AppIconButton.ghost(
                      tooltip: '关闭',
                      icon: Icons.close_rounded,
                      onPressed: widget.onClose,
                      size: 36,
                      iconSize: 18,
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
                    : SmoothMouseScroll(
                        controller: _scrollController,
                        child: ListView.builder(
                          controller: _scrollController,
                          physics: const ClampingScrollPhysics(),
                          itemExtent: _itemExtent,
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                          itemCount: queue.length,
                          itemBuilder: (context, index) {
                            final song = queue[index];
                            final current =
                                widget.controller.currentSong?.id == song.id;
                            return _QueueTile(
                              song: song,
                              index: index,
                              current: current,
                              playing: current && widget.controller.isPlaying,
                              onPlay: () =>
                                  widget.controller.playQueueSong(song),
                              onRemove: () =>
                                  widget.controller.removeFromQueue(song),
                            );
                          },
                        ),
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
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: widget.onPlay,
          borderRadius: BorderRadius.circular(12),
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
                  child: AppIconButton.ghost(
                    tooltip: '移出队列',
                    icon: Icons.close_rounded,
                    onPressed: widget.onRemove,
                    size: 28,
                    iconSize: 15,
                    hoverIconColor: AppColors.danger,
                    shadowColor: AppColors.danger,
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
