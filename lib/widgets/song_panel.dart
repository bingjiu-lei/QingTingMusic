import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../models/song.dart';
import '../theme/app_theme.dart';
import 'list_scroll_actions.dart';
import 'song_row.dart';
import 'smooth_mouse_scroll.dart';

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
  bool _reversed = false;

  @override
  void dispose() {
    _scrollController.dispose();
    _filterController.dispose();
    _filterFocusNode.dispose();
    super.dispose();
  }

  List<Song> get _visibleSongs {
    final source = _reversed ? widget.songs.reversed.toList() : widget.songs;
    final keyword = _filterText.trim().toLowerCase();
    if (keyword.isEmpty) return source;
    return source.where((song) {
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
        color: AppColors.surface.withValues(
          alpha: AppColors.isDark ? 0.78 : 0.86,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.isDark ? null : AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 58,
                height: 34,
                child: widget.songs.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '播放全部',
                        onPressed: visibleSongs.isEmpty
                            ? null
                            : () => widget.onPlay(
                                visibleSongs.first,
                                visibleSongs,
                              ),
                        mouseCursor: visibleSongs.isEmpty
                            ? SystemMouseCursors.basic
                            : SystemMouseCursors.click,
                        icon: const Icon(Icons.play_arrow_rounded),
                        style: IconButton.styleFrom(
                          minimumSize: const Size(34, 34),
                          fixedSize: const Size(34, 34),
                          iconSize: 19,
                          foregroundColor: AppColors.primary,
                          backgroundColor: AppColors.primary.withValues(
                            alpha: AppColors.isDark ? 0.18 : 0.11,
                          ),
                          hoverColor: AppColors.primary.withValues(alpha: 0.18),
                          highlightColor: AppColors.primary.withValues(
                            alpha: 0.14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                      ),
              ),
              const Spacer(),
              if (widget.songs.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                    const SizedBox(width: 6),
                    _ListSortButton(
                      reversed: _reversed,
                      onTap: () => setState(() => _reversed = !_reversed),
                    ),
                  ],
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
                      ShaderMask(
                        blendMode: BlendMode.dstIn,
                        shaderCallback: (bounds) => const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.white,
                            Colors.white,
                            Colors.transparent,
                          ],
                          stops: [0, 0.025, 0.955, 1],
                        ).createShader(bounds),
                        child: SmoothMouseScroll(
                          controller: _scrollController,
                          child: ListView.builder(
                            key: widget.key is PageStorageKey
                                ? widget.key
                                : null,
                            controller: _scrollController,
                            physics: const ClampingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(0, 8, 0, 20),
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
                                    isCurrent:
                                        widget.currentSong?.id == song.id,
                                    isPlaying: widget.isPlaying,
                                    onPlay: () =>
                                        widget.onPlay(song, visibleSongs),
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
                                    onAddToPlaylist:
                                        widget.onAddToPlaylist == null
                                        ? null
                                        : () => widget.onAddToPlaylist!(song),
                                    onRemoveFromPlaylist:
                                        widget.onRemoveFromPlaylist == null
                                        ? null
                                        : () => widget.onRemoveFromPlaylist!(
                                            song,
                                          ),
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
                        ),
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

class _ListSortButton extends StatelessWidget {
  const _ListSortButton({required this.reversed, required this.onTap});

  final bool reversed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: reversed ? '切换为原顺序' : '切换为倒序',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          hoverColor: AppColors.surfaceHover,
          mouseCursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.curve,
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: reversed
                  ? AppColors.selected.withValues(
                      alpha: AppColors.isDark ? 0.72 : 0.92,
                    )
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              reversed
                  ? Icons.south_rounded
                  : Icons.format_list_numbered_rounded,
              size: reversed ? 17 : 18,
              color: reversed ? AppColors.primary : AppColors.muted,
            ),
          ),
        ),
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
