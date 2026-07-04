import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../models/song.dart';
import '../theme/app_theme.dart';
import 'list_scroll_actions.dart';
import 'song_row.dart';

typedef SongPlayRequest = void Function(Song song, List<Song> queue);

class SongPanel extends StatefulWidget {
  const SongPanel({
    super.key,
    required this.title,
    required this.songs,
    required this.onPlay,
    this.currentSong,
    this.isPlaying = false,
    this.compactRows = false,
    this.emptyText = '暂无歌曲',
    this.onLike,
    this.onArtist,
    this.onAlbum,
    this.onAddToPlaylist,
    this.onRemoveFromPlaylist,
    this.showAlbum = true,
  });

  final String title;
  final List<Song> songs;
  final SongPlayRequest onPlay;
  final Song? currentSong;
  final bool isPlaying;
  final bool compactRows;
  final String emptyText;
  final ValueChanged<Song>? onLike;
  final ValueChanged<Song>? onArtist;
  final ValueChanged<Song>? onAlbum;
  final ValueChanged<Song>? onAddToPlaylist;
  final ValueChanged<Song>? onRemoveFromPlaylist;
  final bool showAlbum;

  @override
  State<SongPanel> createState() => _SongPanelState();
}

class _SongPanelState extends State<SongPanel> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _filterController = TextEditingController();
  final FocusNode _filterFocusNode = FocusNode();

  String _filterText = '';
  bool _filterExpanded = false;

  @override
  void dispose() {
    _scrollController.dispose();
    _filterController.dispose();
    _filterFocusNode.dispose();
    super.dispose();
  }

  List<Song> get _visibleSongs {
    final keyword = _filterText.trim().toLowerCase();
    if (keyword.isEmpty) return widget.songs;
    return widget.songs.where((song) {
      return song.title.toLowerCase().contains(keyword) ||
          song.artist.toLowerCase().contains(keyword) ||
          song.album.toLowerCase().contains(keyword);
    }).toList();
  }

  int? get _currentIndex {
    final current = widget.currentSong;
    if (current == null) return null;
    final songs = _visibleSongs;
    for (var i = 0; i < songs.length; i++) {
      if (songs[i].id == current.id) return i;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final itemExtent = widget.compactRows ? 59.0 : 67.0;
    final visibleSongs = _visibleSongs;
    final hasFilter = _filterText.trim().isNotEmpty;
    return Container(
      padding: EdgeInsets.fromLTRB(18, 16, 18, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.isDark ? null : AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (widget.songs.isNotEmpty)
                _ListFilterField(
                  controller: _filterController,
                  focusNode: _filterFocusNode,
                  expanded: _filterExpanded,
                  hasFilter: hasFilter,
                  onExpand: () {
                    setState(() => _filterExpanded = true);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _filterFocusNode.requestFocus();
                    });
                  },
                  onChanged: (value) => setState(() => _filterText = value),
                  onSubmitted: (_) {
                    if (!hasFilter) {
                      setState(() => _filterExpanded = false);
                    }
                  },
                  onClear: () {
                    _filterController.clear();
                    setState(() {
                      _filterText = '';
                      _filterExpanded = false;
                    });
                    _filterFocusNode.unfocus();
                  },
                ),
            ],
          ),
          SizedBox(height: 10),
          Expanded(
            child: widget.songs.isEmpty
                ? Center(
                    child: Text(
                      widget.emptyText,
                      style: TextStyle(color: AppColors.faint, fontSize: 13),
                    ),
                  )
                : visibleSongs.isEmpty
                ? Center(
                    child: Text(
                      hasFilter ? '当前列表没有匹配的歌曲' : widget.emptyText,
                      style: TextStyle(color: AppColors.faint, fontSize: 13),
                    ),
                  )
                : Stack(
                    children: [
                      ListView.builder(
                        key: widget.key is PageStorageKey ? widget.key : null,
                        controller: _scrollController,
                        padding: const EdgeInsets.only(bottom: 18),
                        itemCount: visibleSongs.length,
                        itemExtent: itemExtent,
                        scrollCacheExtent: ScrollCacheExtent.pixels(
                          itemExtent * 14,
                        ),
                        itemBuilder: (context, index) {
                          final song = visibleSongs[index];
                          return Column(
                            children: [
                              SongRow(
                                song: song,
                                index: index,
                                compact: widget.compactRows,
                                isCurrent: widget.currentSong?.id == song.id,
                                isPlaying: widget.isPlaying,
                                onPlay: () => widget.onPlay(song, visibleSongs),
                                onLike: widget.onLike == null
                                    ? null
                                    : () => widget.onLike!(song),
                                onArtist: widget.onArtist == null
                                    ? null
                                    : () => widget.onArtist!(song),
                                onArtistLink: widget.onArtist == null
                                    ? null
                                    : (artist) => widget.onArtist!(
                                        song.copyWith(
                                          artist: artist.name,
                                          artistId: artist.id,
                                          artists: [artist],
                                        ),
                                      ),
                                onAlbum: widget.onAlbum == null
                                    ? null
                                    : () => widget.onAlbum!(song),
                                onAddToPlaylist: widget.onAddToPlaylist == null
                                    ? null
                                    : () => widget.onAddToPlaylist!(song),
                                onRemoveFromPlaylist:
                                    widget.onRemoveFromPlaylist == null
                                    ? null
                                    : () => widget.onRemoveFromPlaylist!(song),
                                showAlbum: widget.showAlbum,
                              ),
                              Divider(
                                height: 1,
                                thickness: 0.5,
                                color: AppColors.divider.withValues(
                                  alpha: AppColors.isDark ? 0.72 : 0.8,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      ListScrollActions(
                        controller: _scrollController,
                        currentIndex: _currentIndex,
                        itemExtent: itemExtent,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ListFilterField extends StatelessWidget {
  const _ListFilterField({
    required this.controller,
    required this.focusNode,
    required this.expanded,
    required this.hasFilter,
    required this.onExpand,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool expanded;
  final bool hasFilter;
  final VoidCallback onExpand;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final showField = expanded || hasFilter;
    return AnimatedContainer(
      duration: AppMotion.normal,
      curve: AppMotion.curve,
      width: showField ? 178 : 34,
      height: 34,
      child: showField
          ? TextField(
              focusNode: focusNode,
              controller: controller,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              cursorColor: AppColors.primary,
              cursorHeight: 16,
              style: TextStyle(
                color: AppColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search_rounded, size: 17),
                suffixIcon: hasFilter
                    ? IconButton(
                        tooltip: '清空',
                        onPressed: onClear,
                        icon: Icon(Icons.close_rounded, size: 16),
                      )
                    : null,
                filled: true,
                fillColor: AppColors.isDark
                    ? AppColors.surfaceMuted.withValues(alpha: 0.42)
                    : const Color(0xFFF8FAFD),
                contentPadding: EdgeInsets.zero,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(
                    color: AppColors.border.withValues(alpha: 0.72),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(
                    color: AppColors.border.withValues(alpha: 0.72),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.48),
                    width: 1,
                  ),
                ),
              ),
            )
          : Tooltip(
              message: '筛选当前列表',
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: InkWell(
                  onTap: onExpand,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  hoverColor: AppColors.surfaceHover,
                  mouseCursor: SystemMouseCursors.click,
                  child: Center(
                    child: Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
