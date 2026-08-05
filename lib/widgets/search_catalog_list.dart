import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

import '../models/search_catalog_item.dart';
import '../theme/app_theme.dart';

class SearchCatalogList extends StatelessWidget {
  const SearchCatalogList({
    super.key,
    required this.items,
    required this.emptyText,
    required this.onSelected,
    this.storageKey,
  });

  final List<SearchCatalogItem> items;
  final String emptyText;
  final ValueChanged<SearchCatalogItem> onSelected;
  final PageStorageKey<String>? storageKey;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          emptyText,
          style: TextStyle(color: AppColors.faint, fontSize: 13),
        ),
      );
    }

    return ListView.separated(
      key: storageKey,
      clipBehavior: Clip.hardEdge,
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 12),
      scrollCacheExtent: const ScrollCacheExtent.pixels(720),
      itemCount: items.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        thickness: 0.5,
        color: AppColors.divider.withValues(
          alpha: AppColors.isDark ? 0.72 : 0.8,
        ),
      ),
      itemBuilder: (context, index) {
        return _CatalogTile(
          item: items[index],
          onSelected: onSelected,
        );
      },
    );
  }
}

class _CatalogTile extends StatefulWidget {
  const _CatalogTile({required this.item, required this.onSelected});

  final SearchCatalogItem item;
  final ValueChanged<SearchCatalogItem> onSelected;

  @override
  State<_CatalogTile> createState() => _CatalogTileState();
}

class _CatalogTileState extends State<_CatalogTile> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isDark = AppColors.isDark;

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
        onTap: () => widget.onSelected(item),
        child: AnimatedScale(
          scale: _pressed
              ? 0.98
              : _hovered
              ? 1.01
              : 1.0,
          duration: AppMotion.fast,
          curve: AppMotion.curve,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: _hovered
                  ? AppColors.primary.withValues(alpha: isDark ? 0.08 : 0.04)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Row(
              children: [
                _CatalogImage(item: item),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Tooltip(
                        message: item.title,
                        waitDuration: const Duration(milliseconds: 450),
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _hovered
                                ? AppColors.primaryPressed
                                : AppColors.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (item.category != SearchCategory.artist ||
                          (item.subtitle.isNotEmpty && item.subtitle != '歌手')) ...[
                        const SizedBox(height: 3),
                        Text(
                          (item.category == SearchCategory.album &&
                                  item.formattedReleaseDate != null)
                              ? (item.subtitle == '未知歌手' || item.subtitle.isEmpty
                                  ? item.formattedReleaseDate!
                                  : '${item.subtitle}  ·  ${item.formattedReleaseDate}')
                              : item.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                AnimatedSlide(
                  offset: _hovered ? const Offset(0.15, 0) : Offset.zero,
                  duration: AppMotion.fast,
                  curve: AppMotion.curve,
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: _hovered ? AppColors.primary : AppColors.faint,
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CatalogImage extends StatelessWidget {
  const _CatalogImage({required this.item});

  final SearchCatalogItem item;

  @override
  Widget build(BuildContext context) {
    final icon = switch (item.category) {
      SearchCategory.album => Icons.album_rounded,
      SearchCategory.artist => Icons.person_rounded,
      SearchCategory.playlist => Icons.queue_music_rounded,
      SearchCategory.song => Icons.music_note_rounded,
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(
        item.category == SearchCategory.artist ? 24 : AppRadius.sm,
      ),
      child: Container(
        width: 44,
        height: 44,
        color: AppColors.surfaceMuted,
        child: item.imageUrl == null
            ? Icon(icon, color: AppColors.muted, size: 22)
            : Image.network(
                item.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    Icon(icon, color: AppColors.muted, size: 22),
              ),
      ),
    );
  }
}
