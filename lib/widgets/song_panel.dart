import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

import '../models/song.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import 'app_icon_button.dart';
import 'list_scroll_actions.dart';
import 'smooth_mouse_scroll.dart';
import 'song_row.dart';

export 'app_icon_button.dart';

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
    this.onAddToPlaylist,
    this.onRemoveFromPlaylist,
    this.onArtist,
    this.onAlbum,
    this.showAlbum = true,
    this.showHeader = false,
    this.filterText = '',
    this.reversed = false,
  });

  final String title;
  final List<Song> songs;
  final Song? currentSong;
  final bool isPlaying;
  final bool compactRows;
  final String emptyText;
  final SongPlayRequest onPlay;
  final ValueChanged<Song>? onLike;
  final ValueChanged<Song>? onAddToPlaylist;
  final ValueChanged<Song>? onRemoveFromPlaylist;
  final ValueChanged<Song>? onArtist;
  final ValueChanged<Song>? onAlbum;
  final bool showAlbum;
  final bool showHeader;
  final String filterText;
  final bool reversed;

  @override
  State<SongPanel> createState() => _SongPanelState();
}

class _SongPanelState extends State<SongPanel> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<Song> get _visibleSongs {
    final source = widget.reversed ? widget.songs.reversed.toList() : widget.songs;
    final keyword = widget.filterText.trim().toLowerCase();
    if (keyword.isEmpty) return source;
    return source.where((song) {
      return song.title.toLowerCase().contains(keyword) ||
          song.artist.toLowerCase().contains(keyword) ||
          song.album.toLowerCase().contains(keyword);
    }).toList();
  }

  int? _currentIndexIn(List<Song> songs) {
    final current = widget.currentSong;
    if (current == null) return null;
    for (var i = 0; i < songs.length; i++) {
      if (songs[i].id == current.id) return i;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final itemExtent = widget.compactRows ? 59.0 : 67.0;
    final visibleSongs = _visibleSongs;
    final hasFilter = widget.filterText.trim().isNotEmpty;

    return GlassSurface(
      radius: AppRadius.xl,
      tint: AppColors.surface.withValues(
        alpha: AppColors.isDark ? 0.72 : 0.80,
      ),
      shadows: AppColors.isDark ? null : AppShadows.soft,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
                          Colors.white,
                          Colors.white,
                          Colors.transparent,
                        ],
                        stops: [0, 0.955, 1],
                      ).createShader(bounds),
                      child: SmoothMouseScroll(
                        controller: _scrollController,
                        child: ListView.builder(
                          key: widget.key is PageStorageKey
                              ? widget.key
                              : null,
                          controller: _scrollController,
                          physics: const ClampingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(4, 6, 4, 20),
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
                      currentIndex: _currentIndexIn(visibleSongs),
                      itemExtent: itemExtent,
                    ),
                  ],
                ),
    );
  }
}

class SongHeaderActions extends StatelessWidget {
  const SongHeaderActions({
    super.key,
    required this.songs,
    required this.onPlayAll,
    required this.filterController,
    required this.filterFocusNode,
    required this.filterExpanded,
    required this.hasFilter,
    required this.onExpandFilter,
    required this.onChangedFilter,
    required this.onClearFilter,
    required this.reversed,
    required this.onToggleSort,
    this.showPlayAll = true,
  });

  final List<Song> songs;
  final VoidCallback? onPlayAll;
  final TextEditingController filterController;
  final FocusNode filterFocusNode;
  final bool filterExpanded;
  final bool hasFilter;
  final VoidCallback onExpandFilter;
  final ValueChanged<String> onChangedFilter;
  final VoidCallback onClearFilter;
  final bool reversed;
  final VoidCallback onToggleSort;
  final bool showPlayAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (songs.isNotEmpty) ...[
          if (showPlayAll) ...[
            PlayAllHeaderButton(onTap: onPlayAll, size: 32),
            const SizedBox(width: 8),
          ],
          _ListFilterField(
            controller: filterController,
            focusNode: filterFocusNode,
            expanded: filterExpanded,
            hasFilter: hasFilter,
            onExpand: onExpandFilter,
            onChanged: onChangedFilter,
            onSubmitted: (_) {
              if (!hasFilter) onClearFilter();
            },
            onClear: onClearFilter,
          ),
          const SizedBox(width: 4),
          _ListSortButton(
            reversed: reversed,
            onTap: onToggleSort,
          ),
        ],
      ],
    );
  }
}

class PlayAllHeaderButton extends StatelessWidget {
  const PlayAllHeaderButton({
    super.key,
    required this.onTap,
    this.size = 36.0,
    this.songCount,
  });

  final VoidCallback? onTap;
  final double size;
  final int? songCount;

  @override
  Widget build(BuildContext context) {
    return AppIconButton.filled(
      icon: Icons.play_arrow_rounded,
      tooltip: songCount != null ? '播放全部 ($songCount首)' : '播放全部',
      onPressed: onTap,
      size: size,
      iconSize: size * 0.55,
      iconColor: AppColors.primary,
      hoverIconColor: AppColors.primary,
      hoverBackgroundColor: AppColors.primary.withValues(
        alpha: AppColors.isDark ? 0.18 : 0.10,
      ),
      shadowColor: AppColors.primary,
      alwaysGlow: true,
      scaleFactor: 1.08,
    );
  }
}

typedef CircularHoverButton = AppIconButton;

class _ListSortButton extends StatelessWidget {
  const _ListSortButton({required this.reversed, required this.onTap});

  final bool reversed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppIconButton.filled(
      icon: reversed
          ? Icons.south_rounded
          : Icons.format_list_numbered_rounded,
      tooltip: reversed ? '切换为原顺序' : '切换为倒序',
      onPressed: onTap,
      size: 36,
      iconSize: 18,
      selected: reversed,
      iconColor: reversed ? AppColors.primary : AppColors.muted,
      hoverIconColor: AppColors.primary,
      selectedColor: AppColors.primary,
      shadowColor: AppColors.primary,
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
    if (!showField) {
      return AppIconButton.filled(
        icon: Icons.search_rounded,
        tooltip: '筛选当前列表',
        onPressed: onExpand,
        size: 36,
        iconSize: 18,
      );
    }

    return AnimatedContainer(
      duration: AppMotion.normal,
      curve: AppMotion.curve,
      width: 172,
      height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(
              alpha: AppColors.isDark ? 0.25 : 0.08,
            ),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        focusNode: focusNode,
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        cursorColor: AppColors.primary,
        cursorHeight: 15,
        style: TextStyle(
          color: AppColors.text,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 16,
            color: AppColors.primary,
          ),
          suffixIcon: hasFilter
              ? IconButton(
                  tooltip: '清除',
                  onPressed: onClear,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 15,
                    color: AppColors.muted,
                  ),
                )
              : null,
          filled: true,
          fillColor: AppColors.isDark
              ? AppColors.surfaceMuted.withValues(alpha: 0.60)
              : const Color(0xFFF8FAFD),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            borderSide: BorderSide(
              color: AppColors.border.withValues(alpha: 0.72),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            borderSide: BorderSide(
              color: AppColors.border.withValues(alpha: 0.72),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            borderSide: BorderSide(
              color: AppColors.primary.withValues(alpha: 0.65),
              width: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}
