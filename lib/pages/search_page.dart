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
          padding: const EdgeInsets.fromLTRB(24, 26, 30, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 900),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    border: Border.all(
                      color: _focusNode.hasFocus
                          ? AppColors.primary
                          : AppColors.border,
                      width: _focusNode.hasFocus ? 1.4 : 1,
                    ),
                    boxShadow: AppColors.isDark ? null : AppShadows.soft,
                  ),
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onTap: () => setState(() {}),
                    onChanged: (value) {
                      widget.controller.updateKeyword(value);
                      setState(() {});
                    },
                    onSubmitted: widget.controller.search,
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: '搜索歌曲、歌单、歌手或专辑',
                      hintStyle: TextStyle(
                        color: AppColors.faint,
                        fontWeight: FontWeight.w500,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: _focusNode.hasFocus
                            ? AppColors.primary
                            : AppColors.muted,
                      ),
                      suffixIcon: _textController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: '清空',
                              constraints: const BoxConstraints.tightFor(
                                width: 44,
                                height: 44,
                              ),
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                _textController.clear();
                                widget.controller.updateKeyword('');
                                setState(() {});
                              },
                              icon: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceMuted,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 17,
                                  color: AppColors.muted,
                                ),
                              ),
                            ),
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 1120),
                  child: AnimatedSwitcher(
                    duration: AppMotion.normal,
                    switchInCurve: AppMotion.curve,
                    switchOutCurve: Curves.easeInCubic,
                    child: _content(),
                  ),
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
        key: const ValueKey('search-results'),
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
        key: const ValueKey('search-suggestions'),
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
      key: const ValueKey('search-history'),
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

class _SearchPromptShell extends StatelessWidget {
  const _SearchPromptShell({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: AppColors.border),
            boxShadow: AppColors.isDark ? null : AppShadows.soft,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 2, 4, 10),
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    ?trailing,
                  ],
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _PromptTile extends StatelessWidget {
  const _PromptTile({
    required this.value,
    required this.icon,
    required this.onTap,
    this.onRemove,
    this.trailingIcon = Icons.north_west_rounded,
  });

  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  final IconData trailingIcon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        hoverColor: AppColors.surfaceHover,
        highlightColor: AppColors.surfacePressed,
        mouseCursor: SystemMouseCursors.click,
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              const SizedBox(width: 10),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.selected.withValues(
                    alpha: AppColors.isDark ? 0.44 : 0.9,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, size: 17, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (onRemove == null)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(trailingIcon, color: AppColors.faint, size: 17),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: IconButton(
                    tooltip: '删除记录',
                    onPressed: onRemove,
                    icon: Icon(Icons.close_rounded, size: 17),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchResults extends StatefulWidget {
  const _SearchResults({
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
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.isDark ? null : AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (controller.isLoading)
            const Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          Row(
            children: [
              for (final category in SearchCategory.values) ...[
                _CategoryTab(
                  category: category,
                  selected: controller.category == category,
                  onTap: () => controller.selectCategory(category),
                ),
                if (category != SearchCategory.values.last)
                  const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: 4),
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
        key: PageStorageKey(
          'search-song-${controller.keyword.trim().toLowerCase()}',
        ),
        controller: _scrollController,
        padding: const EdgeInsets.only(top: 6, bottom: 20),
        cacheExtent: 900,
        itemCount: controller.results.length,
        separatorBuilder: (_, _) => Divider(
          height: 1,
          thickness: 0.5,
          color: AppColors.divider.withValues(
            alpha: AppColors.isDark ? 0.72 : 0.8,
          ),
        ),
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
      storageKey: PageStorageKey(
        'search-${controller.category.name}-${controller.keyword.trim().toLowerCase()}',
      ),
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
      color: selected ? AppColors.selected : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        hoverColor: AppColors.surfaceHover,
        mouseCursor: SystemMouseCursors.click,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          child: Column(
            children: [
              Text(
                category.label,
                style: TextStyle(
                  color: selected ? AppColors.text : AppColors.muted,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
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
  const _Suggestions({
    super.key,
    required this.values,
    required this.onSelected,
  });

  final List<String> values;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const _SuggestionEmptyState();
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 2, 4, 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 17,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      '相关搜索',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: values.length,
                itemBuilder: (context, index) => _SuggestionTile(
                  value: values[index],
                  onTap: () => onSelected(values[index]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentSearchEmptyState extends StatelessWidget {
  const _RecentSearchEmptyState();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: const Alignment(0, -0.2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.selected,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_rounded,
              color: AppColors.primary,
              size: 25,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '搜索你想听的音乐',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({required this.value, required this.onTap});

  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        hoverColor: AppColors.surfaceHover,
        mouseCursor: SystemMouseCursors.click,
        child: SizedBox(
          height: 42,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Icon(Icons.search_rounded, color: AppColors.muted, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value,
                    maxLines: 1,
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
      ),
    );
  }
}

class _SuggestionEmptyState extends StatelessWidget {
  const _SuggestionEmptyState();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 72),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.selected,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_rounded,
                color: AppColors.primary,
                size: 25,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '搜索你想听的音乐',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
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
    super.key,
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
      return const _RecentSearchEmptyState();
    }

    return _SearchPromptShell(
      title: '最近搜索',
      icon: Icons.history_rounded,
      trailing: TextButton(onPressed: onClear, child: Text('清空')),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: values.length,
        itemBuilder: (context, index) {
          final value = values[index];
          return _PromptTile(
            value: value,
            icon: Icons.history_rounded,
            onTap: () => onSelected(value),
            onRemove: () => onRemove(value),
            trailingIcon: Icons.close_rounded,
          );
        },
      ),
    );
  }
}
