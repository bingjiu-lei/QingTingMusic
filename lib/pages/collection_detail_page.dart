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
    required this.isLoading,
    required this.onBack,
    required this.onPlay,
    required this.onLike,
    required this.onOpenArtist,
    required this.onOpenAlbum,
    required this.onOpenCatalog,
    this.currentSong,
    this.isPlaying = false,
  });

  final CollectionDetailKind kind;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final List<Song> songs;
  final List<SearchCatalogItem> relatedItems;
  final bool isLoading;
  final VoidCallback onBack;
  final ValueChanged<Song> onPlay;
  final ValueChanged<Song> onLike;
  final ValueChanged<Song> onOpenArtist;
  final ValueChanged<Song> onOpenAlbum;
  final ValueChanged<SearchCatalogItem> onOpenCatalog;
  final Song? currentSong;
  final bool isPlaying;

  @override
  State<CollectionDetailPage> createState() => _CollectionDetailPageState();
}

class _CollectionDetailPageState extends State<CollectionDetailPage> {
  int selectedTab = 0;

  List<String> get tabs => switch (widget.kind) {
    CollectionDetailKind.playlist => ['歌曲', '歌手', '专辑'],
    CollectionDetailKind.artist => ['歌曲', '专辑'],
    CollectionDetailKind.album => ['歌曲'],
  };

  @override
  void didUpdateWidget(covariant CollectionDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title || oldWidget.kind != widget.kind) {
      selectedTab = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(30, 18, 30, 24),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: '返回',
                onPressed: widget.onBack,
                icon: Icon(Icons.arrow_back_rounded),
              ),
              SizedBox(width: 10),
              AlbumArt(size: 92, imageUrl: widget.imageUrl),
              SizedBox(width: 20),
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
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      widget.subtitle,
                      style: TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                    SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: widget.songs.isEmpty
                          ? null
                          : () => widget.onPlay(widget.songs.first),
                      icon: Icon(Icons.play_arrow_rounded, size: 19),
                      label: Text('播放全部'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 22),
          Row(
            children: [
              for (var index = 0; index < tabs.length; index++) ...[
                _DetailTab(
                  label: tabs[index],
                  selected: selectedTab == index,
                  onTap: () => setState(() => selectedTab = index),
                ),
                if (index != tabs.length - 1) SizedBox(width: 26),
              ],
            ],
          ),
          SizedBox(height: 8),
          Expanded(
            child: widget.isLoading
                ? Center(child: CircularProgressIndicator(strokeWidth: 2.2))
                : _content(),
          ),
        ],
      ),
    );
  }

  Widget _content() {
    final tab = tabs[selectedTab];
    if (tab == '歌曲') {
      return SongPanel(
        title: '歌曲',
        songs: widget.songs,
        currentSong: widget.currentSong,
        isPlaying: widget.isPlaying,
        onPlay: widget.onPlay,
        onLike: widget.onLike,
        onArtist: widget.onOpenArtist,
        onAlbum: widget.onOpenAlbum,
        emptyText: '暂无歌曲',
      );
    }
    if (widget.kind == CollectionDetailKind.artist &&
        tab == '专辑' &&
        widget.relatedItems.isNotEmpty) {
      return _CatalogGrid(
        items: widget.relatedItems,
        onTap: widget.onOpenCatalog,
      );
    }
    return _FacetGrid(
      songs: widget.songs,
      artists: tab == '歌手',
      onTap: tab == '歌手' ? widget.onOpenArtist : widget.onOpenAlbum,
    );
  }
}

class _CatalogGrid extends StatelessWidget {
  const _CatalogGrid({required this.items, required this.onTap});

  final List<SearchCatalogItem> items;
  final ValueChanged<SearchCatalogItem> onTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 230,
        mainAxisExtent: 72,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: () => onTap(item),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: EdgeInsets.all(10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 50,
                      height: 50,
                      color: Color(0xFFE6EDF5),
                      child: item.imageUrl == null
                          ? Icon(Icons.album_rounded, color: AppColors.muted)
                          : Image.network(item.imageUrl!, fit: BoxFit.cover),
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
      },
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
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.text : AppColors.muted,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            SizedBox(height: 7),
            Container(
              width: selected ? 22 : 0,
              height: 2,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _FacetGrid extends StatelessWidget {
  const _FacetGrid({
    required this.songs,
    required this.artists,
    required this.onTap,
  });

  final List<Song> songs;
  final bool artists;
  final ValueChanged<Song> onTap;

  @override
  Widget build(BuildContext context) {
    final unique = <String, Song>{};
    for (final song in songs) {
      final key = artists ? song.artist : '${song.albumId}:${song.album}';
      if (key.trim().isNotEmpty && key != '未知歌手' && key != 'null:未知专辑') {
        unique.putIfAbsent(key, () => song);
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
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 230,
        mainAxisExtent: 72,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: values.length,
      itemBuilder: (context, index) {
        final song = values[index];
        return Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: () => onTap(song),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: EdgeInsets.all(10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(artists ? 25 : 6),
                    child: Container(
                      width: 50,
                      height: 50,
                      color: Color(0xFFE6EDF5),
                      child: song.coverUrl == null
                          ? Icon(
                              artists
                                  ? Icons.person_rounded
                                  : Icons.album_rounded,
                              color: AppColors.muted,
                            )
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
