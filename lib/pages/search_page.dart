import 'package:flutter/material.dart';

import '../controllers/music_search_controller.dart';
import '../models/search_catalog_item.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';
import '../widgets/list_scroll_actions.dart';
import '../widgets/search_catalog_list.dart';
import '../widgets/song_panel.dart';
import '../widgets/song_row.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({
    super.key,
    required this.controller,
    required this.currentSong,
    required this.isPlaying,
    required this.onPlay,
    required this.onLogin,
    required this.onOpenCatalog,
    required this.onLike,
    required this.onAddToPlaylist,
    required this.onOpenArtist,
    required this.onOpenAlbum,
  });

  final MusicSearchController controller;
  final Song? currentSong;
  final bool isPlaying;
  final SongPlayRequest onPlay;
  final VoidCallback onLogin;
  final ValueChanged<SearchCatalogItem> onOpenCatalog;
  final ValueChanged<Song> onLike;
  final ValueChanged<Song> onAddToPlaylist;
  final ValueChanged<Song> onOpenArtist;
  final ValueChanged<Song> onOpenAlbum;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.controller.keyword);
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return Padding(
          padding: EdgeInsets.fromLTRB(28, 42, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 920),
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onChanged: widget.controller.updateKeyword,
                  onSubmitted: widget.controller.search,
                  style: TextStyle(color: AppColors.text, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: '搜索歌曲、歌单、歌手或专辑',
                    hintStyle: TextStyle(color: AppColors.faint),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: AppColors.muted,
                    ),
                    suffixIcon: _textController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: '清空',
                            onPressed: () {
                              _textController.clear();
                              widget.controller.updateKeyword('');
                              setState(() {});
                            },
                            icon: Icon(Icons.close_rounded),
                          ),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: EdgeInsets.symmetric(vertical: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 22),
              Expanded(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 1120),
                  child: _content(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _content() {
    final controller = widget.controller;
    if (controller.hasSearched) {
      return _SearchResults(
        controller: controller,
        currentSong: widget.currentSong,
        isPlaying: widget.isPlaying,
        onPlay: widget.onPlay,
        onLogin: widget.onLogin,
        onOpenCatalog: widget.onOpenCatalog,
        onLike: widget.onLike,
        onAddToPlaylist: widget.onAddToPlaylist,
        onOpenArtist: widget.onOpenArtist,
        onOpenAlbum: widget.onOpenAlbum,
      );
    }

    if (controller.keyword.trim().isNotEmpty) {
      return _Suggestions(
        values: controller.suggestions,
        onSelected: (value) {
          _textController.text = value;
          _textController.selection = TextSelection.collapsed(
            offset: value.length,
          );
          controller.search(value);
        },
      );
    }

    return _SearchHistory(
      values: controller.history,
      onSelected: (value) {
        _textController.text = value;
        _textController.selection = TextSelection.collapsed(
          offset: value.length,
        );
        controller.useHistory(value);
      },
      onRemove: controller.removeHistory,
      onClear: controller.clearHistory,
    );
  }
}

class _SearchResults extends StatefulWidget {
  const _SearchResults({
    required this.controller,
    required this.currentSong,
    required this.isPlaying,
    required this.onPlay,
    required this.onLogin,
    required this.onOpenCatalog,
    required this.onLike,
    required this.onAddToPlaylist,
    required this.onOpenArtist,
    required this.onOpenAlbum,
  });

  final MusicSearchController controller;
  final Song? currentSong;
  final bool isPlaying;
  final SongPlayRequest onPlay;
  final VoidCallback onLogin;
  final ValueChanged<SearchCatalogItem> onOpenCatalog;
  final ValueChanged<Song> onLike;
  final ValueChanged<Song> onAddToPlaylist;
  final ValueChanged<Song> onOpenArtist;
  final ValueChanged<Song> onOpenAlbum;

  @override
  State<_SearchResults> createState() => _SearchResultsState();
}

class _SearchResultsState extends State<_SearchResults> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int? get _currentIndex {
    final current = widget.currentSong;
    if (current == null) return null;
    final results = widget.controller.results;
    for (var i = 0; i < results.length; i++) {
      if (results[i].id == current.id) return i;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '搜索结果',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 14),
          Row(
            children: [
              for (final category in SearchCategory.values) ...[
                _CategoryTab(
                  category: category,
                  selected: controller.category == category,
                  onTap: () => controller.selectCategory(category),
                ),
                if (category != SearchCategory.values.last)
                  const SizedBox(width: 10),
              ],
            ],
          ),
          Divider(height: 1, color: AppColors.divider),
          Expanded(
            child: Stack(
              children: [
                _body(),
                if (controller.isLoading && _hasVisibleData())
                  const Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                if (controller.category == SearchCategory.song)
                  ListScrollActions(
                    controller: _scrollController,
                    currentIndex: _currentIndex,
                    itemExtent: 67.0,
                    scrollPadding: 8.0,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    final controller = widget.controller;
    if (controller.isLoading && !_hasVisibleData()) {
      return const _SearchLoading();
    }
    if (controller.errorText != null) {
      return _SearchError(
        message: controller.errorText!,
        showLogin: controller.requiresLogin,
        onLogin: widget.onLogin,
      );
    }
    if (controller.category == SearchCategory.song) {
      if (controller.results.isEmpty) {
        return Center(
          child: Text(
            '没有找到相关单曲',
            style: TextStyle(color: AppColors.faint, fontSize: 13),
          ),
        );
      }
      return ListView.separated(
        controller: _scrollController,
        padding: EdgeInsets.only(top: 8),
        itemCount: controller.results.length,
        separatorBuilder: (_, _) =>
            Divider(height: 1, color: AppColors.divider),
        itemBuilder: (context, index) {
          final song = controller.results[index];
          return SongRow(
            song: song,
            index: index,
            isCurrent: widget.currentSong?.id == song.id,
            isPlaying: widget.isPlaying,
            onPlay: () => widget.onPlay(song, controller.results),
            onLike: () => widget.onLike(song),
            onAddToPlaylist: () => widget.onAddToPlaylist(song),
            onArtist: () => widget.onOpenArtist(song),
            onArtistLink: (artist) => widget.onOpenArtist(
              song.copyWith(
                artist: artist.name,
                artistId: artist.id,
                artists: [artist],
              ),
            ),
            onAlbum: () => widget.onOpenAlbum(song),
          );
        },
      );
    }
    return SearchCatalogList(
      items: controller.catalogResults,
      emptyText: '没有找到相关${controller.category.label}',
      onSelected: widget.onOpenCatalog,
    );
  }

  bool _hasVisibleData() {
    final controller = widget.controller;
    return controller.category == SearchCategory.song
        ? controller.results.isNotEmpty
        : controller.catalogResults.isNotEmpty;
  }
}

class _CategoryTab extends StatelessWidget {
  const _CategoryTab({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final SearchCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        hoverColor: AppColors.selected.withValues(alpha: 0.6),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 7, 8, 11),
          child: Column(
            children: [
              Text(
                category.label,
                style: TextStyle(
                  color: selected ? AppColors.text : AppColors.muted,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              SizedBox(height: 8),
              AnimatedContainer(
                duration: Duration(milliseconds: 150),
                width: selected ? 22 : 0,
                height: 2,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchLoading extends StatelessWidget {
  const _SearchLoading();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(top: 10),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 7,
      separatorBuilder: (_, _) => const SizedBox(height: 7),
      itemBuilder: (_, index) => TweenAnimationBuilder<double>(
        duration: Duration(milliseconds: 220 + index * 35),
        tween: Tween(begin: 0, end: 1),
        builder: (_, value, child) => Opacity(opacity: value, child: child),
        child: Container(
          height: 62,
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(7),
          ),
        ),
      ),
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.values, required this.onSelected});

  final List<String> values;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return Center(
        child: Text('暂无联想结果', style: TextStyle(color: AppColors.faint)),
      );
    }

    return ListView.separated(
      itemCount: values.length,
      separatorBuilder: (_, _) => Divider(height: 1),
      itemBuilder: (context, index) {
        final value = values[index];
        return Material(
          color: Colors.transparent,
          child: ListTile(
            onTap: () => onSelected(value),
            contentPadding: EdgeInsets.symmetric(horizontal: 12),
            leading: Icon(Icons.search_rounded, color: AppColors.faint),
            title: Text(
              value,
              style: TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: Icon(
              Icons.north_west_rounded,
              color: AppColors.faint,
              size: 17,
            ),
          ),
        );
      },
    );
  }
}

class _SearchError extends StatelessWidget {
  const _SearchError({
    required this.message,
    required this.showLogin,
    required this.onLogin,
  });

  final String message;
  final bool showLogin;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            showLogin ? Icons.person_outline_rounded : Icons.cloud_off_rounded,
            color: AppColors.faint,
            size: 34,
          ),
          SizedBox(height: 12),
          Text(message, style: TextStyle(color: AppColors.muted)),
          if (showLogin) ...[
            SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onLogin,
              icon: Icon(Icons.qr_code_rounded, size: 18),
              label: Text('扫码登录'),
            ),
          ],
        ],
      ),
    );
  }
}

class _SearchHistory extends StatelessWidget {
  const _SearchHistory({
    required this.values,
    required this.onSelected,
    required this.onRemove,
    required this.onClear,
  });

  final List<String> values;
  final ValueChanged<String> onSelected;
  final ValueChanged<String> onRemove;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return Center(
        child: Text('搜索记录会保存在这里', style: TextStyle(color: AppColors.faint)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '最近搜索',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            Spacer(),
            TextButton(onPressed: onClear, child: Text('清空')),
          ],
        ),
        SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: values.length,
            itemBuilder: (context, index) {
              final value = values[index];
              return Material(
                color: Colors.transparent,
                child: ListTile(
                  onTap: () => onSelected(value),
                  contentPadding: EdgeInsets.symmetric(horizontal: 8),
                  leading: Icon(Icons.history_rounded, color: AppColors.faint),
                  title: Text(value, style: TextStyle(color: AppColors.text)),
                  trailing: IconButton(
                    tooltip: '删除记录',
                    onPressed: () => onRemove(value),
                    icon: Icon(Icons.close_rounded, size: 18),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
