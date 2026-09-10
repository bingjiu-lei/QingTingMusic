import 'dart:async';

import 'package:flutter/material.dart';

import '../models/music_playlist.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';
import 'album_art.dart';
import 'app_dialog.dart';
import 'app_scrollbar.dart';

class AddToPlaylistDialog extends StatefulWidget {
  const AddToPlaylistDialog({
    super.key,
    required this.song,
    required this.playlists,
    this.containingPlaylistIds = const {},
    this.containingPlaylistIdsFuture,
    this.onContainingStateLoaded,
    this.onAddToPlaylist,
    this.onRemoveFromPlaylist,
    this.onRemoveAndSkipCurrent,
    this.currentPlayingPlaylist,
    this.isCurrentPlayingSong = false,
    this.onSelected,
  });

  final Song song;
  final List<MusicPlaylist> playlists;
  final Set<String> containingPlaylistIds;
  final Future<Set<String>>? containingPlaylistIdsFuture;
  final VoidCallback? onContainingStateLoaded;
  final Future<void> Function(MusicPlaylist playlist)? onAddToPlaylist;
  final Future<void> Function(MusicPlaylist playlist)? onRemoveFromPlaylist;
  final Future<void> Function(MusicPlaylist playlist)? onRemoveAndSkipCurrent;
  final MusicPlaylist? currentPlayingPlaylist;
  final bool isCurrentPlayingSong;
  final ValueChanged<MusicPlaylist>? onSelected;

  @override
  State<AddToPlaylistDialog> createState() => _AddToPlaylistDialogState();
}

class _AddToPlaylistDialogState extends State<AddToPlaylistDialog> {
  late Set<String> _containingPlaylistIds;
  final Set<String> _operatingPlaylistKeys = <String>{};
  final Set<String> _manuallyRemovedKeys = <String>{};
  final Set<String> _manuallyAddedKeys = <String>{};
  bool _quickRemovingCurrent = false;
  String? _hoveredPlaylistKey;

  @override
  void initState() {
    super.initState();
    _containingPlaylistIds = {...widget.containingPlaylistIds};
    final future = widget.containingPlaylistIdsFuture;
    if (future != null) {
      unawaited(_loadContainingPlaylistIds(future));
    }
  }

  Future<void> _loadContainingPlaylistIds(Future<Set<String>> future) async {
    try {
      final containingIds = await future;
      if (!mounted) return;
      setState(() {
        final updated = {...containingIds, ..._manuallyAddedKeys};
        updated.removeAll(_manuallyRemovedKeys);
        _containingPlaylistIds = updated;
      });
      widget.onContainingStateLoaded?.call();
    } catch (_) {
      if (mounted) widget.onContainingStateLoaded?.call();
    }
  }

  String _getPlaylistKey(MusicPlaylist playlist) {
    return playlist.listId.isNotEmpty ? playlist.listId : playlist.id;
  }

  Future<void> _handleToggle(MusicPlaylist playlist) async {
    final key = _getPlaylistKey(playlist);
    if (_operatingPlaylistKeys.contains(key)) return;

    if (widget.onAddToPlaylist == null && widget.onRemoveFromPlaylist == null) {
      Navigator.of(context).pop(playlist);
      widget.onSelected?.call(playlist);
      return;
    }

    final isAlreadyAdded = _containingPlaylistIds.contains(key);
    if (isAlreadyAdded) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AppConfirmDialog(
          icon: Icons.delete_outline_rounded,
          isDanger: true,
          title: '移出歌单',
          content: '确定要将《${widget.song.title}》从歌单「${playlist.name}」中移出吗？',
          cancelLabel: '取消',
          confirmLabel: '确认移出',
          onCancel: () => Navigator.of(dialogContext).pop(false),
          onConfirm: () => Navigator.of(dialogContext).pop(true),
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _operatingPlaylistKeys.add(key));

    try {
      if (isAlreadyAdded) {
        await widget.onRemoveFromPlaylist?.call(playlist);
        if (!mounted) return;
        _manuallyRemovedKeys.add(key);
        _manuallyAddedKeys.remove(key);
        setState(() => _containingPlaylistIds.remove(key));
      } else {
        await widget.onAddToPlaylist?.call(playlist);
        if (!mounted) return;
        _manuallyAddedKeys.add(key);
        _manuallyRemovedKeys.remove(key);
        setState(() => _containingPlaylistIds.add(key));
      }
    } finally {
      if (mounted) {
        setState(() => _operatingPlaylistKeys.remove(key));
      }
    }
  }

  Future<void> _handleRemoveAndSkipCurrent() async {
    final currentPlaylist = widget.currentPlayingPlaylist;
    if (currentPlaylist == null || _quickRemovingCurrent) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppConfirmDialog(
        icon: Icons.delete_outline_rounded,
        isDanger: true,
        title: '从当前歌单移除并切歌',
        content:
            '确定要将《${widget.song.title}》从正在播放的歌单「${currentPlaylist.name}」中移除，并自动切入下一首吗？',
        cancelLabel: '取消',
        confirmLabel: '确认移除',
        onCancel: () => Navigator.of(dialogContext).pop(false),
        onConfirm: () => Navigator.of(dialogContext).pop(true),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _quickRemovingCurrent = true);
    try {
      await widget.onRemoveAndSkipCurrent?.call(currentPlaylist);
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() => _quickRemovingCurrent = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;
    final currentPlaylist = widget.currentPlayingPlaylist;
    final currentPlaylistKey = currentPlaylist != null
        ? _getPlaylistKey(currentPlaylist)
        : null;
    final isPlayingFromContainedPlaylist =
        widget.isCurrentPlayingSong &&
        currentPlaylist != null &&
        currentPlaylistKey != null &&
        _containingPlaylistIds.contains(currentPlaylistKey);

    return AppDialog(
      icon: Icons.playlist_add_check_rounded,
      title: '收藏与歌单管理',
      subtitle: '点击歌单即可添加或移出歌曲',
      showCloseButton: true,
      maxWidth: 440,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current song preview card
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C222B) : const Color(0xFFF3F6FA),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            child: Row(
              children: [
                AlbumArt(size: 40, imageUrl: widget.song.coverUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Scheme 2: Smart banner for current playing playlist
          if (isPlayingFromContainedPlaylist) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2E1C22)
                    : const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: Colors.redAccent.withValues(
                    alpha: isDark ? 0.35 : 0.25,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.play_circle_filled_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '正在播放「${currentPlaylist.name}」',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _quickRemovingCurrent
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.redAccent,
                          ),
                        )
                      : Material(
                          color: Colors.redAccent.withValues(
                            alpha: isDark ? 0.18 : 0.10,
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            onTap: _handleRemoveAndSkipCurrent,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.delete_outline_rounded,
                                    size: 14,
                                    color: Colors.redAccent,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    '从当前歌单移除并切歌',
                                    style: TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Playlists list
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: widget.playlists.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      child: Text(
                        '还没有可管理的自建歌单',
                        style: TextStyle(color: AppColors.faint, fontSize: 13),
                      ),
                    ),
                  )
                : AppScrollbar(
                    child: ListView.separated(
                      padding: const EdgeInsets.only(right: 8),
                      shrinkWrap: true,
                      itemCount: widget.playlists.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final playlist = widget.playlists[index];
                        final key = _getPlaylistKey(playlist);
                        final isAlreadyAdded = _containingPlaylistIds.contains(
                          key,
                        );
                        final isOperating = _operatingPlaylistKeys.contains(
                          key,
                        );
                        final isHovered = _hoveredPlaylistKey == key;

                        final itemBgColor = isAlreadyAdded
                            ? (isHovered
                                  ? (isDark
                                        ? Colors.redAccent.withValues(
                                            alpha: 0.10,
                                          )
                                        : const Color(0xFFFEE2E2))
                                  : (isDark
                                        ? AppColors.primary.withValues(
                                            alpha: 0.08,
                                          )
                                        : AppColors.primary.withValues(
                                            alpha: 0.05,
                                          )))
                            : (isHovered
                                  ? (isDark
                                        ? const Color(0xFF232A35)
                                        : const Color(0xFFEAEFF6))
                                  : (isDark
                                        ? const Color(0xFF1C222B)
                                        : const Color(0xFFF3F6FA)));

                        return Material(
                          color: itemBgColor,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            onHover: (hovered) {
                              setState(() {
                                _hoveredPlaylistKey = hovered ? key : null;
                              });
                            },
                            onTap: isOperating
                                ? null
                                : () => _handleToggle(playlist),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  // Left check / add icon
                                  Icon(
                                    isAlreadyAdded
                                        ? (isHovered
                                              ? Icons
                                                    .remove_circle_outline_rounded
                                              : Icons.check_circle_rounded)
                                        : Icons.add_circle_outline_rounded,
                                    size: 18,
                                    color: isAlreadyAdded
                                        ? (isHovered
                                              ? Colors.redAccent
                                              : AppColors.primary)
                                        : AppColors.muted,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      playlist.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isAlreadyAdded
                                            ? (isHovered
                                                  ? Colors.redAccent
                                                  : AppColors.text)
                                            : AppColors.text,
                                        fontWeight: isAlreadyAdded
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${playlist.songCount} 首',
                                    style: TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Right action status badge
                                  if (isOperating)
                                    SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: isAlreadyAdded
                                            ? Colors.redAccent
                                            : AppColors.primary,
                                      ),
                                    )
                                  else if (isAlreadyAdded)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isHovered
                                            ? Colors.redAccent.withValues(
                                                alpha: 0.15,
                                              )
                                            : AppColors.primary.withValues(
                                                alpha: 0.12,
                                              ),
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.xs,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isHovered
                                                ? Icons.delete_outline_rounded
                                                : Icons.check_rounded,
                                            size: 12,
                                            color: isHovered
                                                ? Colors.redAccent
                                                : AppColors.primary,
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            isHovered ? '移出' : '已收录',
                                            style: TextStyle(
                                              color: isHovered
                                                  ? Colors.redAccent
                                                  : AppColors.primary,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isHovered
                                            ? AppColors.primary.withValues(
                                                alpha: 0.12,
                                              )
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.xs,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.add_rounded,
                                            size: 12,
                                            color: isHovered
                                                ? AppColors.primary
                                                : AppColors.muted,
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            '添加',
                                            style: TextStyle(
                                              color: isHovered
                                                  ? AppColors.primary
                                                  : AppColors.muted,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('完成'),
        ),
      ],
    );
  }
}
