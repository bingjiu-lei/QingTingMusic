import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/recommendation_controller.dart';
import '../models/rank_chart_item.dart';
import '../models/search_catalog_item.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';
import '../widgets/album_art.dart';
import '../widgets/glass.dart';
import '../widgets/preparing_dots.dart';
import '../widgets/rank_picker_dialog.dart';
import '../widgets/song_panel.dart';

const double _heroHeight = 210;

class _AlphabetRail extends StatelessWidget {
  const _AlphabetRail({required this.selectedLetter, required this.onSelect});

  final String selectedLetter;
  final ValueChanged<String> onSelect;

  static const _letters = [
    '全部',
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;
    return Container(
      width: 36,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.035)
            : Colors.black.withValues(alpha: 0.025),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final letter in _letters) _buildLetterItem(letter, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLetterItem(String letter, bool isDark) {
    final isSelected = selectedLetter == letter;
    final isAll = letter == '全部';
    final displayText = isAll ? '全' : letter;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelect(letter),
        child: Container(
          width: 28,
          height: 22,
          margin: const EdgeInsets.symmetric(vertical: 1.5),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 4,
                      offset: const Offset(0, 1.5),
                    ),
                  ]
                : null,
          ),
          child: Text(
            displayText,
            style: TextStyle(
              fontSize: isAll ? 11.5 : 12.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _ArtistDirectoryView extends StatelessWidget {
  const _ArtistDirectoryView({
    required this.controller,
    required this.onOpenArtist,
  });

  final RecommendationController controller;
  final ValueChanged<SearchCatalogItem> onOpenArtist;

  static const double _railWidth = 36;
  static const double _columnGap = 14;

  @override
  Widget build(BuildContext context) {
    final artists =
        controller.artistDirectory?.artistsFor(controller.artistLetter) ??
        const <SearchCatalogItem>[];

    const typeOptions = [(0, '全部'), (1, '华语'), (2, '欧美'), (5, '日本'), (6, '韩国')];
    final typeIndex = typeOptions.indexWhere(
      (opt) => opt.$1 == controller.artistType,
    );
    final safeTypeIndex = typeIndex >= 0 ? typeIndex : 0;

    const sexOptions = [(0, '全部'), (1, '男歌手'), (2, '女歌手'), (3, '乐队组合')];
    final sexIndex = sexOptions.indexWhere(
      (opt) => opt.$1 == controller.artistSexType,
    );
    final safeSexIndex = sexIndex >= 0 ? sexIndex : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: _railWidth,
                    child: Center(
                      child: Text(
                        '地区',
                        style: AppTypography.style(
                          11,
                          600,
                          color: AppColors.faint,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: _columnGap),
                  GlassTabBar(
                    tabs: const ['全部', '华语', '欧美', '日本', '韩国'],
                    selectedIndex: safeTypeIndex,
                    onChanged: (index) =>
                        controller.selectArtistType(typeOptions[index].$1),
                    dense: true,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  SizedBox(
                    width: _railWidth,
                    child: Center(
                      child: Text(
                        '分类',
                        style: AppTypography.style(
                          11,
                          600,
                          color: AppColors.faint,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: _columnGap),
                  GlassTabBar(
                    tabs: const ['全部', '男歌手', '女歌手', '乐队组合'],
                    selectedIndex: safeSexIndex,
                    onChanged: (index) =>
                        controller.selectArtistSexType(sexOptions[index].$1),
                    dense: true,
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: _railWidth,
                child: _AlphabetRail(
                  selectedLetter: controller.artistLetter,
                  onSelect: controller.selectArtistLetter,
                ),
              ),
              const SizedBox(width: _columnGap),
              Expanded(
                child: CustomScrollView(
                  key: PageStorageKey(
                    'recommendation-artists-${controller.artistType}-${controller.artistSexType}',
                  ),
                  slivers: [
                    if (controller.loadingArtists)
                      SliverFillRemaining(
                        child: Center(
                          child: PreparingDots(color: AppColors.primary),
                        ),
                      )
                    else if (controller.artistError != null)
                      SliverFillRemaining(
                        child: Center(
                          child: TextButton.icon(
                            onPressed: () =>
                                controller.loadArtists(refresh: true),
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(controller.artistError!),
                          ),
                        ),
                      )
                    else if (artists.isEmpty)
                      SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                controller.artistLetter == '全部'
                                    ? '这里暂时没有歌手'
                                    : '未找到首字母为 “${controller.artistLetter}” 的歌手',
                                style: AppTypography.pageSubtitle,
                              ),
                              if (controller.artistLetter != '全部') ...[
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: () =>
                                      controller.selectArtistLetter('全部'),
                                  child: const Text('查看全部'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.only(bottom: 16),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 220,
                                mainAxisExtent: 64,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _ArtistTile(
                              artist: artists[index],
                              onTap: () => onOpenArtist(artists[index]),
                            ),
                            childCount: artists.length,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ArtistTile extends StatefulWidget {
  const _ArtistTile({required this.artist, required this.onTap});

  final SearchCatalogItem artist;
  final VoidCallback onTap;

  @override
  State<_ArtistTile> createState() => _ArtistTileState();
}

class _ArtistTileState extends State<_ArtistTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final artist = widget.artist;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hovered ? 1.015 : 1.0,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOutQuad,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            curve: Curves.easeOutQuad,
            decoration: BoxDecoration(
              color: _hovered
                  ? AppColors.primary.withValues(alpha: isDark ? 0.08 : 0.04)
                  : AppGlass.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: _hovered
                    ? AppColors.primary.withValues(alpha: isDark ? 0.22 : 0.12)
                    : AppGlass.border,
              ),
              boxShadow: isDark ? null : AppShadows.soft,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                ClipOval(
                  child: Container(
                    width: 46,
                    height: 46,
                    color: AppColors.surfaceMuted,
                    child: (artist.imageUrl == null || artist.imageUrl!.isEmpty)
                        ? Icon(
                            Icons.person_rounded,
                            color: AppColors.muted,
                            size: 24,
                          )
                        : Image.network(
                            artist.imageUrl!,
                            fit: BoxFit.cover,
                            cacheWidth: (46 * pixelRatio).round(),
                            gaplessPlayback: true,
                            errorBuilder: (_, _, _) => Icon(
                              Icons.person_rounded,
                              color: AppColors.muted,
                              size: 24,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    artist.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _hovered
                          ? AppColors.primaryPressed
                          : AppColors.text,
                      fontSize: 13.5,
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

class RecommendationPage extends StatelessWidget {
  const RecommendationPage({
    super.key,
    required this.controller,
    required this.currentSong,
    required this.onPlay,
    required this.onPlayFm,
    required this.onOpenDaily,
    required this.onOpenArtist,
    required this.onOpenRank,
  });

  final RecommendationController controller;
  final Song? currentSong;
  final SongPlayRequest onPlay;
  final SongPlayRequest onPlayFm;
  final VoidCallback onOpenDaily;
  final ValueChanged<SearchCatalogItem> onOpenArtist;
  final ValueChanged<RankChartItem> onOpenRank;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('推荐', style: AppTypography.pageTitle),
          const SizedBox(height: 6),
          Text('今天听点喜欢的，也遇见一点新鲜', style: AppTypography.pageSubtitle),
          const SizedBox(height: 14),
          GlassTabBar(
            tabs: const ['个性推荐', '热门歌手'],
            selectedIndex: controller.selectedTab,
            onChanged: controller.selectTab,
            dense: true,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: controller.selectedTab == 0
                ? _PersonalRecommendationView(
                    controller: controller,
                    currentSong: currentSong,
                    onPlay: onPlay,
                    onPlayFm: onPlayFm,
                    onOpenDaily: onOpenDaily,
                    onOpenRank: onOpenRank,
                  )
                : _ArtistDirectoryView(
                    controller: controller,
                    onOpenArtist: onOpenArtist,
                  ),
          ),
        ],
      ),
    ),
  );
}

class _PersonalRecommendationView extends StatelessWidget {
  const _PersonalRecommendationView({
    required this.controller,
    required this.currentSong,
    required this.onPlay,
    required this.onPlayFm,
    required this.onOpenDaily,
    required this.onOpenRank,
  });

  final RecommendationController controller;
  final Song? currentSong;
  final SongPlayRequest onPlay;
  final SongPlayRequest onPlayFm;
  final VoidCallback onOpenDaily;
  final ValueChanged<RankChartItem> onOpenRank;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      key: const PageStorageKey('recommendation-personal'),
      physics: const BouncingScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, heroConstraints) {
                final stacked = heroConstraints.maxWidth < 760;
                final daily = _DailyHero(
                  songs: controller.dailySongs,
                  loading: controller.loadingDaily,
                  error: controller.dailyError,
                  onOpen: controller.dailySongs.isEmpty
                      ? () => controller.loadDaily(refresh: true)
                      : onOpenDaily,
                  onPlay: controller.dailySongs.isEmpty
                      ? () => controller.loadDaily(refresh: true)
                      : () => onPlay(
                          controller.dailySongs.first,
                          controller.dailySongs,
                        ),
                );
                final fm = _FmHero(
                  controller: controller,
                  currentSong: currentSong,
                  onPlay: onPlayFm,
                );
                if (stacked) {
                  return Column(
                    children: [daily, const SizedBox(height: 14), fm],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 11, child: daily),
                    const SizedBox(width: 14),
                    Expanded(flex: 9, child: fm),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            _RankPreviewSection(
              controller: controller,
              onPlay: onPlay,
              onOpenRank: onOpenRank,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );
}

class _RankPreviewSection extends StatelessWidget {
  const _RankPreviewSection({
    required this.controller,
    required this.onPlay,
    required this.onOpenRank,
  });

  final RecommendationController controller;
  final SongPlayRequest onPlay;
  final ValueChanged<RankChartItem> onOpenRank;

  @override
  Widget build(BuildContext context) {
    final rank = controller.activeRank;
    final songs = controller.activeRankSongs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '精选榜',
              style: AppTypography.style(17, 750, color: AppColors.text),
            ),
            if (rank != null) ...[
              const SizedBox(width: 8),
              _RankPillSelector(
                rank: rank,
                onTap: () => showRankPickerDialog(
                  context: context,
                  ranks: controller.allRanks,
                  selectedRank: rank,
                  onSelect: (selected) => controller.selectRank(selected),
                ),
              ),
            ],
            const Spacer(),
            if (controller.loadingActiveRank)
              PreparingDots(color: AppColors.primary)
            else if (controller.activeRankError != null)
              TextButton.icon(
                onPressed: () => controller.initActiveRank(refresh: true),
                icon: const Icon(Icons.refresh_rounded, size: 15),
                label: const Text('重试', style: TextStyle(fontSize: 12)),
              )
            else if (rank != null)
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onOpenRank(rank),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '查看全部',
                          style: AppTypography.style(
                            12.5,
                            600,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 11,
                          color: AppColors.muted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (controller.loadingActiveRank && songs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: PreparingDots(color: AppColors.primary)),
          )
        else if (songs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                controller.activeRankError ?? '暂无歌曲',
                style: AppTypography.style(12, 500, color: AppColors.muted),
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final previewSongs = songs.take(4).toList();
              if (width < 760) {
                return Column(
                  children: [
                    Row(
                      children: [
                        for (
                          var i = 0;
                          i < 2 && i < previewSongs.length;
                          i++
                        ) ...[
                          if (i > 0) const SizedBox(width: 10),
                          Expanded(
                            child: _RankSongCard(
                              song: previewSongs[i],
                              onTap: () => onPlay(previewSongs[i], songs),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (previewSongs.length > 2) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          for (
                            var i = 2;
                            i < 4 && i < previewSongs.length;
                            i++
                          ) ...[
                            if (i > 2) const SizedBox(width: 10),
                            Expanded(
                              child: _RankSongCard(
                                song: previewSongs[i],
                                onTap: () => onPlay(previewSongs[i], songs),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                );
              }

              return Row(
                children: [
                  for (var i = 0; i < previewSongs.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(
                      child: _RankSongCard(
                        song: previewSongs[i],
                        onTap: () => onPlay(previewSongs[i], songs),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
      ],
    );
  }
}

class _RankPillSelector extends StatefulWidget {
  const _RankPillSelector({required this.rank, required this.onTap});

  final RankChartItem rank;
  final VoidCallback onTap;

  @override
  State<_RankPillSelector> createState() => _RankPillSelectorState();
}

class _RankPillSelectorState extends State<_RankPillSelector> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutQuad,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.10)
                : AppColors.primary.withValues(alpha: isDark ? 0.08 : 0.045),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: _hovered
                  ? AppColors.primary.withValues(alpha: isDark ? 0.38 : 0.22)
                  : AppColors.primary.withValues(alpha: isDark ? 0.16 : 0.10),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.leaderboard_rounded,
                size: 13,
                color: AppColors.primary,
              ),
              const SizedBox(width: 5),
              Text(
                widget.rank.cleanName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _hovered ? AppColors.primaryPressed : AppColors.text,
                ),
              ),
              const SizedBox(width: 3),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 14,
                color: _hovered ? AppColors.primary : AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankSongCard extends StatefulWidget {
  const _RankSongCard({required this.song, required this.onTap});

  final Song song;
  final VoidCallback onTap;

  @override
  State<_RankSongCard> createState() => _RankSongCardState();
}

class _RankSongCardState extends State<_RankSongCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;
    final cardTint = isDark
        ? (_hovered ? const Color(0xFF1B2432) : AppGlass.surface)
        : (_hovered ? Colors.white : AppGlass.surface);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed
              ? 0.98
              : _hovered
              ? 1.015
              : 1.0,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOutQuad,
          child: GlassSurface(
            radius: AppRadius.xl,
            tint: cardTint,
            shadows: _hovered ? AppShadows.card : AppShadows.soft,
            child: SizedBox(
              height: 72,
              child: Padding(
                padding: const EdgeInsets.all(9),
                child: Row(
                  children: [
                    AlbumArt(size: 52, imageUrl: widget.song.coverUrl),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.style(
                              13.5,
                              700,
                              color: _hovered
                                  ? AppColors.primaryPressed
                                  : AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.style(
                              11.5,
                              500,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 90),
                      opacity: _hovered ? 1.0 : 0.45,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: _hovered
                              ? AppColors.primary.withValues(
                                  alpha: isDark ? 0.20 : 0.12,
                                )
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyHero extends StatelessWidget {
  const _DailyHero({
    required this.songs,
    required this.loading,
    required this.error,
    required this.onOpen,
    required this.onPlay,
  });

  final List<Song> songs;
  final bool loading;
  final String? error;
  final VoidCallback onOpen;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark;
    final aurora = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        AppColors.primary.withValues(alpha: dark ? 0.20 : 0.12),
        AppColors.accent.withValues(alpha: dark ? 0.14 : 0.08),
      ],
    );
    return GlassSurface(
      radius: AppRadius.xxl,
      shadows: AppShadows.card,
      child: SizedBox(
        height: _heroHeight,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(decoration: BoxDecoration(gradient: aurora)),
            ),
            Positioned(
              right: -38,
              top: -64,
              child: _AuroraBlob(
                size: 190,
                color: AppColors.primary,
                alpha: dark ? 0.16 : 0.10,
              ),
            ),
            Positioned(
              left: -46,
              bottom: -78,
              child: _AuroraBlob(
                size: 170,
                color: AppColors.accent,
                alpha: dark ? 0.12 : 0.08,
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 20, 8, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _DateBadge(),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '每日推荐',
                                  style: AppTypography.style(
                                    19,
                                    780,
                                    color: AppColors.text,
                                  ),
                                ),
                                Text(
                                  songs.isEmpty
                                      ? '每天为你更新'
                                      : '${songs.length} 首 · 为你定制',
                                  style: AppTypography.style(
                                    12,
                                    600,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          loading ? '正在准备今天的音乐…' : error ?? '从熟悉的声音开始，也留一点未知',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.style(
                            12,
                            500,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _GlassRoundButton(
                              loading: loading,
                              tooltip: '播放每日推荐',
                              onPressed: onPlay,
                            ),
                            const SizedBox(width: 8),
                            _GlassRoundButton(
                              loading: loading,
                              filled: false,
                              size: 36,
                              icon: Icons.arrow_forward_rounded,
                              tooltip: '查看歌单',
                              onPressed: onOpen,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 168, child: _CoverStack(songs: songs)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DateBadge extends StatelessWidget {
  const _DateBadge();

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.primary.withValues(alpha: 0.18)
            : AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isDark
              ? AppColors.primary.withValues(alpha: 0.35)
              : AppColors.primary.withValues(alpha: 0.22),
          width: 1,
        ),
      ),
      child: Text(
        '${DateTime.now().day}',
        style: AppTypography.style(18, 800, color: AppColors.primary),
      ),
    );
  }
}

class _AuroraBlob extends StatelessWidget {
  const _AuroraBlob({
    required this.size,
    required this.color,
    required this.alpha,
  });

  final double size;
  final Color color;
  final double alpha;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    ),
  );
}

class _CoverStack extends StatelessWidget {
  const _CoverStack({required this.songs});
  final List<Song> songs;

  @override
  Widget build(BuildContext context) {
    final covers = songs.take(3).toList().reversed.toList();
    if (covers.isEmpty) {
      return Center(
        child: Icon(
          Icons.wb_sunny_rounded,
          color: AppColors.primary.withValues(alpha: 0.42),
          size: 72,
        ),
      );
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        for (var index = 0; index < covers.length; index++)
          Transform.translate(
            offset: Offset((index - 1) * 24, (index - 1).abs() * 7),
            child: Transform.rotate(
              angle: (index - 1) * 0.09,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(color: AppColors.surface, width: 3),
                  boxShadow: AppShadows.card,
                ),
                child: AlbumArt(
                  size: index == covers.length - 1
                      ? 100
                      : (index == 1 ? 104 : 92),
                  imageUrl: covers[index].coverUrl,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FmHero extends StatelessWidget {
  const _FmHero({
    required this.controller,
    required this.currentSong,
    required this.onPlay,
  });

  static const _modes = ['normal', 'small', 'peak'];

  final RecommendationController controller;
  final Song? currentSong;
  final SongPlayRequest onPlay;

  Song? get _displaySong {
    if (currentSong != null && controller.isFmSong(currentSong!)) {
      return currentSong;
    }
    return controller.fmSongs.isEmpty ? null : controller.fmSongs.first;
  }

  @override
  Widget build(BuildContext context) {
    final song = _displaySong;
    final modeIndex = _modes.indexOf(controller.fmMode);
    return GlassSurface(
      radius: AppRadius.xxl,
      shadows: AppShadows.card,
      child: SizedBox(
        height: _heroHeight,
        child: Stack(
          children: [
            Positioned(
              right: -44,
              top: -56,
              child: _AuroraBlob(
                size: 160,
                color: AppColors.accent,
                alpha: AppColors.isDark ? 0.12 : 0.08,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AlbumArt(
                            size: 78,
                            emphasized: song != null,
                            imageUrl: song?.coverUrl,
                          ),
                          Positioned(
                            right: -4,
                            bottom: -4,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: AppColors.accentSoft,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.surface,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.radio_rounded,
                                size: 14,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '私人 FM',
                              style: AppTypography.style(
                                19,
                                780,
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              song?.title ?? '等待你的第一首歌',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.style(
                                13,
                                700,
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              controller.loadingFm
                                  ? '正在寻找下一首…'
                                  : controller.fmError ??
                                        song?.artist ??
                                        '选择频道与偏好后开始',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.style(
                                11,
                                500,
                                color: controller.fmError == null
                                    ? AppColors.muted
                                    : AppColors.danger,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _GlassRoundButton(
                        loading: controller.loadingFm,
                        tooltip: '重新获取并播放私人 FM',
                        onPressed: () => unawaited(_play()),
                      ),
                    ],
                  ),
                  const Spacer(),
                  _FmProfileRow(
                    label: '频道',
                    tabs: const ['红心', '小众', '速览'],
                    selectedIndex: modeIndex < 0 ? 0 : modeIndex,
                    loading: controller.loadingFm,
                    onChanged: (index) =>
                        unawaited(_change(mode: _modes[index])),
                  ),
                  const SizedBox(height: 8),
                  _FmProfileRow(
                    label: '偏好',
                    tabs: const ['口味', '风格', '探索'],
                    selectedIndex: controller.fmSongPoolId.clamp(0, 2),
                    loading: controller.loadingFm,
                    onChanged: (index) => unawaited(_change(pool: index)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _change({String? mode, int? pool}) async {
    final song = await controller.selectFmProfile(
      mode: mode ?? controller.fmMode,
      songPoolId: pool ?? controller.fmSongPoolId,
    );
    if (song != null) onPlay(song, controller.fmSongs);
  }

  Future<void> _play() async {
    final song = await controller.restartFm();
    if (song != null) onPlay(song, controller.fmSongs);
  }
}

class _FmProfileRow extends StatelessWidget {
  const _FmProfileRow({
    required this.label,
    required this.tabs,
    required this.selectedIndex,
    required this.loading,
    required this.onChanged,
  });

  final String label;
  final List<String> tabs;
  final int selectedIndex;
  final bool loading;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 34,
        child: Text(
          label,
          style: AppTypography.style(11, 600, color: AppColors.faint),
        ),
      ),
      IgnorePointer(
        ignoring: loading,
        child: AnimatedOpacity(
          duration: AppMotion.fast,
          curve: AppMotion.curve,
          opacity: loading ? 0.6 : 1,
          child: GlassTabBar(
            dense: true,
            tabs: tabs,
            selectedIndex: selectedIndex,
            onChanged: onChanged,
          ),
        ),
      ),
    ],
  );
}

class _GlassRoundButton extends StatelessWidget {
  const _GlassRoundButton({
    required this.loading,
    required this.tooltip,
    required this.onPressed,
    this.icon = Icons.play_arrow_rounded,
    this.filled = true,
    this.size = 42,
  });

  final bool loading;
  final String tooltip;
  final VoidCallback onPressed;
  final IconData icon;
  final bool filled;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return AppIconButton.filled(
        tooltip: loading ? '正在准备' : tooltip,
        icon: icon,
        onPressed: loading ? null : onPressed,
        size: size,
        iconSize: 25,
        backgroundColor: AppColors.primary,
        hoverBackgroundColor: AppColors.primaryPressed,
        iconColor: Colors.white,
        hoverIconColor: Colors.white,
        shadowColor: AppColors.primary,
        alwaysGlow: true,
        scaleFactor: 1.08,
        child: loading ? const PreparingDots(color: Colors.white) : null,
      );
    }

    return AppIconButton.filled(
      tooltip: tooltip,
      icon: icon,
      onPressed: loading ? null : onPressed,
      size: size,
      iconSize: size * 0.55,
      iconColor: AppColors.primary,
      hoverIconColor: AppColors.primary,
      shadowColor: AppColors.primary,
      scaleFactor: 1.08,
      child: loading ? PreparingDots(color: AppColors.primary) : null,
    );
  }
}
