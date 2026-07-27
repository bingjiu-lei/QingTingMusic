import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';

import '../controllers/music_search_controller.dart';
import '../models/search_catalog_item.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import '../widgets/list_scroll_actions.dart';
import '../widgets/search_catalog_list.dart';
import '../widgets/song_panel.dart';
import '../widgets/song_row.dart';
import '../widgets/smooth_mouse_scroll.dart';

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
    _focusNode = FocusNode()..addListener(_handleFocusChanged);
  }

  void _handleFocusChanged() {
    if (mounted) setState(() {});
  }

  void _clearSearch() {
    _textController.clear();
    widget.controller.updateKeyword('');
    _focusNode.requestFocus();
    setState(() {});
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
            _focusNode.requestFocus(),
        const SingleActivator(LogicalKeyboardKey.escape): _clearSearch,
      },
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(14, 26, 18, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: _searchField(),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1120),
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
      ),
    );
  }

  Widget _searchField() {
    final focused = _focusNode.hasFocus;
    return AnimatedContainer(
      duration: AppMotion.normal,
      curve: AppMotion.curve,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: focused
            ? AppShadows.primaryGlow
            : (AppColors.isDark ? null : AppShadows.soft),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: focused ? AppColors.primary : AppGlass.border,
          width: focused ? 1.4 : 1,
        ),
      ),
      child: GlassSurface(
        radius: AppRadius.pill,
        showBorder: false,
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
          style: AppTypography.style(16, 600, color: AppColors.text),
          decoration: InputDecoration(
            hintText: '搜索歌曲、歌单、歌手或专辑',
            hintStyle: AppTypography.style(16, 500, color: AppColors.faint),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(
                Icons.search_rounded,
                color: focused ? AppColors.primary : AppColors.muted,
              ),
            ),
            suffixIcon: _textController.text.isEmpty
                ? null
                : Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: IconButton(
                      tooltip: '清空',
                      constraints: const BoxConstraints.tightFor(
                        width: 44,
                        height: 44,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: _clearSearch,
                      icon: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: AppGlass.surfaceSoft,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppGlass.border),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: AppColors.muted,
                        ),
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
        child: GlassSurface(
          radius: AppRadius.xl,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          shadows: AppColors.isDark ? null : AppShadows.soft,
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
                      style: AppTypography.style(
                        14,
                        750,
                        color: AppColors.text,
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
        hoverColor: AppColors.surfaceHover.withValues(
          alpha: AppColors.isDark ? 0.6 : 0.8,
        ),
        highlightColor: AppColors.surfacePressed.withValues(
          alpha: AppColors.isDark ? 0.6 : 0.8,
        ),
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
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withValues(
                        alpha: AppColors.isDark ? 0.22 : 0.12,
                      ),
                      AppColors.accent.withValues(
                        alpha: AppColors.isDark ? 0.18 : 0.10,
                      ),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppGlass.border),
                ),
                child: Icon(icon, size: 17, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.style(14, 600, color: AppColors.text),
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
                    icon: const Icon(Icons.close_rounded, size: 17),
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
    return GlassSurface(
      radius: AppRadius.xl,
      tint: AppGlass.surfaceStrong,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
      shadows: AppColors.isDark ? null : AppShadows.soft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('搜索结果', style: AppTypography.panelTitle),
              const Spacer(),
              if (controller.isLoading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 10),
          GlassTabBar(
            dense: true,
            tabs: [
              for (final category in SearchCategory.values) category.label,
            ],
            selectedIndex: SearchCategory.values.indexOf(controller.category),
            onChanged: (index) =>
                controller.selectCategory(SearchCategory.values[index]),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Stack(
              children: [
                _hasVisibleData()
                    ? ShaderMask(
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
                          stops: [0, 0.022, 0.965, 1],
                        ).createShader(bounds),
                        child: _body(),
                      )
                    : _body(),
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
            style: AppTypography.style(13, 500, color: AppColors.faint),
          ),
        );
      }
      return SmoothMouseScroll(
        controller: _scrollController,
        child: ListView.separated(
          key: PageStorageKey(
            'search-song-${controller.keyword.trim().toLowerCase()}',
          ),
          controller: _scrollController,
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.only(top: 6, bottom: 20),
          scrollCacheExtent: const ScrollCacheExtent.pixels(900),
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
        ),
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

class _SearchLoading extends StatefulWidget {
  const _SearchLoading();

  @override
  State<_SearchLoading> createState() => _SearchLoadingState();
}

class _SearchLoadingState extends State<_SearchLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = AppGlass.surfaceSoft;
    final sheen = Colors.white.withValues(
      alpha: AppColors.isDark ? 0.10 : 0.60,
    );
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, _) {
        return ListView.separated(
          padding: const EdgeInsets.only(top: 10),
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 7,
          separatorBuilder: (_, _) => const SizedBox(height: 7),
          itemBuilder: (_, index) {
            final phase = (_shimmer.value + index * 0.09) % 1.0;
            final dx = phase * 4 - 2;
            return Container(
              height: 62,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppGlass.border),
                gradient: LinearGradient(
                  begin: Alignment(dx - 1, -0.3),
                  end: Alignment(dx + 1, 0.3),
                  colors: [base, sheen, base],
                ),
              ),
            );
          },
        );
      },
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

    return _SearchPromptShell(
      title: '相关搜索',
      icon: Icons.auto_awesome_rounded,
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: values.length,
        itemBuilder: (context, index) => _SuggestionTile(
          value: values[index],
          onTap: () => onSelected(values[index]),
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
      alignment: const Alignment(0, -0.08),
      child: SizedBox(
        width: 520,
        height: 250,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 72,
              top: 28,
              child: Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              right: 74,
              bottom: 28,
              child: Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary, AppColors.accent],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppGlass.highlight),
                    boxShadow: AppShadows.primaryGlow,
                  ),
                  child: const Icon(
                    Icons.search_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  '下一首喜欢的歌，就从这里找到',
                  style: AppTypography.style(18, 800, color: AppColors.text),
                ),
                const SizedBox(height: 8),
                Text(
                  '搜索歌曲、歌手、歌单或专辑',
                  style: AppTypography.style(12, 450, color: AppColors.muted),
                ),
                const SizedBox(height: 18),
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ShortcutHint(keys: 'Ctrl  K', label: '聚焦搜索'),
                    SizedBox(width: 8),
                    _ShortcutHint(keys: 'Enter', label: '开始搜索'),
                    SizedBox(width: 8),
                    _ShortcutHint(keys: 'Esc', label: '清空'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ShortcutHint extends StatelessWidget {
  const _ShortcutHint({required this.keys, required this.label});
  final String keys;
  final String label;

  @override
  Widget build(BuildContext context) => GlassSurface(
    radius: AppRadius.pill,
    tint: AppGlass.surfaceSoft,
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(keys, style: AppTypography.style(10, 750, color: AppColors.text)),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTypography.style(10, 480, color: AppColors.muted),
        ),
      ],
    ),
  );
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
        hoverColor: AppColors.surfaceHover.withValues(
          alpha: AppColors.isDark ? 0.6 : 0.8,
        ),
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
                    style: AppTypography.style(14, 600, color: AppColors.text),
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
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.16),
                    AppColors.accent.withValues(alpha: 0.12),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(color: AppGlass.border),
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
              style: AppTypography.style(15, 700, color: AppColors.text),
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
          const SizedBox(height: 12),
          Text(
            message,
            style: AppTypography.style(14, 500, color: AppColors.muted),
          ),
          if (showLogin) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onLogin,
              icon: const Icon(Icons.qr_code_rounded, size: 18),
              label: const Text('扫码登录'),
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
      trailing: TextButton(onPressed: onClear, child: const Text('清空')),
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
