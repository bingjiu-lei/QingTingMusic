import 'dart:async';

import 'package:flutter/material.dart';

import '../models/music_playlist.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';
import 'album_art.dart';
import 'app_dialog.dart';

class AddToPlaylistDialog extends StatefulWidget {
  const AddToPlaylistDialog({
    super.key,
    required this.song,
    required this.playlists,
    this.containingPlaylistIds = const {},
    this.containingPlaylistIdsFuture,
    this.onContainingStateLoaded,
    this.onSelected,
  });

  final Song song;
  final List<MusicPlaylist> playlists;
  final Set<String> containingPlaylistIds;
  final Future<Set<String>>? containingPlaylistIdsFuture;
  final VoidCallback? onContainingStateLoaded;
  final ValueChanged<MusicPlaylist>? onSelected;

  @override
  State<AddToPlaylistDialog> createState() => _AddToPlaylistDialogState();
}

class _AddToPlaylistDialogState extends State<AddToPlaylistDialog> {
  late Set<String> _containingPlaylistIds;
  bool _selectionPending = false;

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
      setState(() => _containingPlaylistIds = {...containingIds});
      widget.onContainingStateLoaded?.call();
    } catch (_) {
      if (mounted) widget.onContainingStateLoaded?.call();
    }
  }

  String _getPlaylistKey(MusicPlaylist playlist) {
    return playlist.listId.isNotEmpty ? playlist.listId : playlist.id;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;

    return AppDialog(
      icon: Icons.playlist_add_rounded,
      title: '添加到歌单',
      subtitle: '选择要加入的自建歌单',
      showCloseButton: true,
      maxWidth: 420,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current song card preview
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1C222B)
                  : const Color(0xFFF3F6FA),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            child: Row(
              children: [
                AlbumArt(size: 38, imageUrl: widget.song.coverUrl),
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
                          color: AppColors.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Playlists list
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: widget.playlists.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      child: Text(
                        '还没有可添加的自建歌单',
                        style: TextStyle(
                          color: AppColors.faint,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: widget.playlists.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final playlist = widget.playlists[index];
                      final key = _getPlaylistKey(playlist);
                      final isAlreadyAdded =
                          _containingPlaylistIds.contains(key);

                      return Material(
                        color: isAlreadyAdded
                            ? (isDark
                                ? Colors.white.withValues(alpha: 0.03)
                                : Colors.black.withValues(alpha: 0.02))
                            : (isDark
                                ? const Color(0xFF1C222B)
                                : const Color(0xFFF3F6FA)),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          onTap: isAlreadyAdded || _selectionPending
                              ? null
                              : () {
                                  setState(() => _selectionPending = true);
                                  Navigator.of(context).pop(playlist);
                                  widget.onSelected?.call(playlist);
                                },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    playlist.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isAlreadyAdded
                                          ? AppColors.muted
                                          : AppColors.text,
                                      fontWeight: FontWeight.w600,
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
                                if (isAlreadyAdded) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(
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
                                          Icons.check_circle_rounded,
                                          size: 12,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          '已包含',
                                          style: TextStyle(
                                            color: AppColors.primary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
