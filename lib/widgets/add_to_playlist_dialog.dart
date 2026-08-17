import 'dart:async';

import 'package:flutter/material.dart';

import '../models/music_playlist.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';
import 'album_art.dart';

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
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '添加到歌单',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  AlbumArt(size: 42, imageUrl: widget.song.coverUrl),
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
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
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
              const SizedBox(height: 16),
              Flexible(
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
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final playlist = widget.playlists[index];
                          final key = _getPlaylistKey(playlist);
                          final isAlreadyAdded = _containingPlaylistIds
                              .contains(key);

                          return Material(
                            color: isAlreadyAdded
                                ? AppColors.page.withValues(alpha: 0.5)
                                : AppColors.page,
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
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
                                            4,
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
                                                fontWeight: FontWeight.w500,
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
        ),
      ),
    );
  }
}
