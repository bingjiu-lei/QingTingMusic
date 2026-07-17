import 'package:flutter/material.dart';

import '../models/song.dart';
import '../models/search_catalog_item.dart';
import '../theme/app_theme.dart';
import '../widgets/album_art.dart';
import '../widgets/song_panel.dart';

enum CollectionDetailKind { playlist, artist, album }

class CollectionDetailPage extends StatefulWidget {
  const CollectionDetailPage({
    super.key,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.songs,
    required this.relatedItems,
    required this.relatedItemsLoadingMore,
    required this.relatedItemsCanLoadMore,
    required this.isLoading,
    required this.onBack,
    this.onOpenHeaderArtist,
    required this.onPlay,
    required this.onLike,
    required this.onAddToPlaylist,
    required this.onOpenArtist,
    required this.onOpenAlbum,
    required this.onOpenCatalog,
    required this.onLoadMoreRelatedItems,
    required this.selectedTab,
    required this.onTabChanged,
    required this.storageKeyPrefix,
    required this.isCollected,
    this.openedFromArtist = false,
    this.onRemoveFromPlaylist,
    this.onToggleCollection,
    this.collectionItem,
    this.currentSong,
    this.isPlaying = false,
  });

  final CollectionDetailKind kind;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final List<Song> songs;
  final List<SearchCatalogItem> relatedItems;
  final bool relatedItemsLoadingMore;
  final bool relatedItemsCanLoadMore;
  final bool isLoading;
  final VoidCallback onBack;
  final VoidCallback? onOpenHeaderArtist;
  final SongPlayRequest onPlay;
  final ValueChanged<Song> onLike;
  final ValueChanged<Song> onAddToPlaylist;
  final ValueChanged<Song>? onRemoveFromPlaylist;
  final ValueChanged<Song>? onOpenArtist;
  final ValueChanged<Song> onOpenAlbum;
  final ValueChanged<SearchCatalogItem> onOpenCatalog;
  final VoidCallback onLoadMoreRelatedItems;
  final int selectedTab;
  final ValueChanged<int> onTabChanged;
  final String storageKeyPrefix;
  final bool isCollected;
  final bool openedFromArtist;
  final Song? currentSong;
  final bool isPlaying;
  final SearchCatalogItem? collectionItem;
  final VoidCallback? onToggleCollection;

  @override
  State<CollectionDetailPage> createState() => _CollectionDetailPageState();
}

class _CollectionDetailPageState extends State<CollectionDetailPage> {
  List<String> get tabs => switch (widget.kind) {
    CollectionDetailKind.playlist => ['歌曲'],
    CollectionDetailKind.artist => ['歌曲', '专辑'],
    CollectionDetailKind.album => ['歌曲'],
  };

  @override
  void didUpdateWidget(covariant CollectionDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedTab >= tabs.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onTabChanged(0);
      });
    }
  }

  int get selectedTab =>
      widget.selectedTab >= tabs.length ? 0 : widget.selectedTab;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 18, 12),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 46,
                height: 46,
                child: IconButton(
                  tooltip: '返回',
                  mouseCursor: SystemMouseCursors.click,
                  onPressed: widget.onBack,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surfaceMuted.withValues(
                      alpha: AppColors.isDark ? 0.54 : 0.72,
                    ),
                    hoverColor: AppColors.surfaceHover,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  icon: Icon(Icons.arrow_back_rounded, size: 24),
                ),
              ),
              SizedBox(width: 10),
              AlbumArt(size: 80, imageUrl: widget.imageUrl),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        height: 1.16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _HeaderSubtitle(
                      text: widget.subtitle,
                      onTap: widget.onOpenHeaderArtist,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        if (widget.collectionItem != null)
                          IconButton(
                            tooltip: widget.isCollected ? '取消收藏' : '收藏',
                            onPressed: widget.onToggleCollection,
                            style: IconButton.styleFrom(
                              minimumSize: const Size(40, 40),
                              fixedSize: const Size(40, 40),
                              foregroundColor: widget.isCollected
                                  ? AppColors.favorite
                                  : AppColors.muted,
                              backgroundColor: AppColors.surfaceMuted
                                  .withValues(alpha: 0.42),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: Icon(
                              widget.isCollected
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 18,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var index = 0; index < tabs.length; index++) ...[
                _DetailTab(
                  label: tabs[index],
                  selected: selectedTab == index,
                  onTap: () => widget.onTabChanged(index),
                ),
                if (index != tabs.length - 1) SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: widget.isLoading
                ? const _DetailLoadingPlaceholder()
                : _content(),
          ),
        ],
      ),
    );
  }

  Widget _content() {
    final tab = tabs[selectedTab];
    final songs = _songsForDisplay();
    if (tab == '歌曲') {
      return SongPanel(
        key: PageStorageKey('${widget.storageKeyPrefix}:songs'),
        title: '歌曲',
        songs: songs,
        currentSong: widget.currentSong,
        isPlaying: widget.isPlaying,
        compactRows: true,
        onPlay: widget.onPlay,
        onLike: widget.onLike,
        onAddToPlaylist: widget.onAddToPlaylist,
        onRemoveFromPlaylist: widget.onRemoveFromPlaylist,
        onArtist: _enableArtistLinks ? widget.onOpenArtist : null,
        onAlbum: widget.kind == CollectionDetailKind.album
            ? null
            : widget.onOpenAlbum,
        showAlbum: widget.kind != CollectionDetailKind.album,
        emptyText: '暂无歌曲',
      );
    }
    if (widget.kind == CollectionDetailKind.artist &&
        tab == '专辑' &&
        widget.relatedItems.isNotEmpty) {
      return _CatalogGrid(
        storageKey: PageStorageKey('${widget.storageKeyPrefix}:artist-albums'),
        items: widget.relatedItems,
        onTap: widget.onOpenCatalog,
        canLoadMore: widget.relatedItemsCanLoadMore,
        loadingMore: widget.relatedItemsLoadingMore,
        onLoadMore: widget.onLoadMoreRelatedItems,
      );
    }
    return _FacetGrid(
      songs: songs,
      artists: tab == '歌手',
      storageKey: PageStorageKey('${widget.storageKeyPrefix}:facet:$tab'),
      onTap: tab == '歌手' ? widget.onOpenArtist : widget.onOpenAlbum,
    );
  }

  bool get _enableArtistLinks =>
      widget.onOpenArtist != null &&
      widget.kind != CollectionDetailKind.artist &&
      !widget.openedFromArtist;

  List<Song> _songsForDisplay() {
    if (widget.kind != CollectionDetailKind.artist) return widget.songs;
    return widget.songs
        .map(
          (song) => song.copyWith(
            artist: widget.title,
            artists: [SongArtist(name: widget.title)],
          ),
        )
        .toList();
  }
}

class _HeaderSubtitle extends StatelessWidget {
  const _HeaderSubtitle({required this.text, this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Text(
      text,
      style: TextStyle(
        color: onTap == null ? AppColors.muted : AppColors.primary,
        fontSize: 13,
        fontWeight: onTap == null ? FontWeight.w500 : FontWeight.w600,
      ),
    );
    if (onTap == null) return child;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: child),
    );
  }
}

class _DetailLoadingPlaceholder extends StatelessWidget {
  const _DetailLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 18, 10, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LoadingBar(width: 220),
            const SizedBox(height: 18),
            for (var index = 0; index < 5; index++) ...[
              Row(
                children: [
                  _LoadingBar(width: 42, height: 42, radius: 8),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LoadingBar(width: 180 - index * 8),
                      const SizedBox(height: 8),
                      _LoadingBar(width: 108 + index * 10, height: 8),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
            ],
          ],
        ),
      ),
    );
  }
}

class _LoadingBar extends StatelessWidget {
  const _LoadingBar({required this.width, this.height = 12, this.radius = 999});

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.45, end: 1),
      duration: const Duration(milliseconds: 820),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Opacity(opacity: value, child: child);
      },
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted.withValues(
            alpha: AppColors.isDark ? 0.42 : 0.78,
          ),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class _CatalogGrid extends StatefulWidget {
  const _CatalogGrid({
    required this.items,
    required this.onTap,
    required this.storageKey,
    required this.canLoadMore,
    required this.loadingMore,
    required this.onLoadMore,
  });

  final List<SearchCatalogItem> items;
  final ValueChanged<SearchCatalogItem> onTap;
  final PageStorageKey<String> storageKey;
  final bool canLoadMore;
  final bool loadingMore;
  final VoidCallback onLoadMore;

  @override
  State<_CatalogGrid> createState() => _CatalogGridState();
}

class _CatalogGridState extends State<_CatalogGrid> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleScroll());
  }

  @override
  void didUpdateWidget(covariant _CatalogGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.canLoadMore && widget.items.length != oldWidget.items.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleScroll());
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!widget.canLoadMore || widget.loadingMore || !_controller.hasClients) {
      return;
    }
    final position = _controller.position;
    if (position.extentAfter < 900) {
      widget.onLoadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      key: widget.storageKey,
      controller: _controller,
      slivers: [
        SliverGrid(
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 230,
            mainAxisExtent: 76,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            final item = widget.items[index];
            return Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: InkWell(
                onTap: () => widget.onTap(item),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                hoverColor: AppColors.surfaceHover,
                mouseCursor: SystemMouseCursors.click,
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: Container(
                          width: 50,
                          height: 50,
                          color: AppColors.surfaceMuted,
                          child: item.imageUrl == null
                              ? Icon(
                                  Icons.album_rounded,
                                  color: AppColors.muted,
                                )
                              : Image.network(
                                  item.imageUrl!,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                      SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.text,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              item.subtitle,
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
              ),
            );
          }, childCount: widget.items.length),
        ),
        SliverToBoxAdapter(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: widget.loadingMore
                ? Padding(
                    key: const ValueKey('album-loading'),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                '正在加载更多专辑',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('album-loading-empty')),
          ),
        ),
      ],
    );
  }
}

class _DetailTab extends StatelessWidget {
  const _DetailTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.selected : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        hoverColor: AppColors.surfaceHover,
        mouseCursor: SystemMouseCursors.click,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.text : AppColors.muted,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
              SizedBox(height: 7),
              AnimatedContainer(
                duration: AppMotion.fast,
                curve: AppMotion.curve,
                width: selected ? 22 : 0,
                height: 2,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FacetGrid extends StatelessWidget {
  const _FacetGrid({
    required this.songs,
    required this.artists,
    required this.storageKey,
    required this.onTap,
  });

  final List<Song> songs;
  final bool artists;
  final PageStorageKey<String> storageKey;
  final ValueChanged<Song>? onTap;

  @override
  Widget build(BuildContext context) {
    final unique = <String, Song>{};
    for (final song in songs) {
      final artistLabel = _facetArtistLabel(song.artist);
      if (artists && artistLabel == '群星') continue;
      final key = artists ? artistLabel : '${song.albumId}:${song.album}';
      if (key.trim().isNotEmpty && key != '未知歌手' && key != 'null:未知专辑') {
        unique.putIfAbsent(
          key,
          () => artists ? song.copyWith(artist: artistLabel) : song,
        );
      }
    }
    final values = unique.values.toList();
    if (values.isEmpty) {
      return Center(
        child: Text(
          artists ? '暂无歌手信息' : '暂无专辑信息',
          style: TextStyle(color: AppColors.faint),
        ),
      );
    }
    return GridView.builder(
      key: storageKey,
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 230,
        mainAxisExtent: 76,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: values.length,
      itemBuilder: (context, index) {
        final song = values[index];
        return Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: InkWell(
            onTap: onTap == null ? null : () => onTap!(song),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            hoverColor: AppColors.surfaceHover,
            mouseCursor: onTap == null
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
            child: Padding(
              padding: EdgeInsets.all(10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(artists ? 25 : 6),
                    child: Container(
                      width: 50,
                      height: 50,
                      color: AppColors.surfaceMuted,
                      child: artists
                          ? Icon(Icons.person_rounded, color: AppColors.muted)
                          : song.coverUrl == null
                          ? Icon(Icons.album_rounded, color: AppColors.muted)
                          : Image.network(song.coverUrl!, fit: BoxFit.cover),
                    ),
                  ),
                  SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      artists ? song.artist : song.album,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

String _facetArtistLabel(String value) {
  final cleaned = value
      .replaceAll(RegExp(r'^[\s/\\|,，、]+|[\s/\\|,，、]+$'), '')
      .trim();
  final hasText = RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(cleaned);
  if (!hasText) return '群星';
  final lower = cleaned.toLowerCase();
  if (lower == '未知歌手' ||
      lower == 'unknown' ||
      lower == 'unknown artist' ||
      lower == 'null') {
    return '群星';
  }
  return cleaned;
}
