import 'package:flutter/material.dart';

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
      padding: EdgeInsets.zero,
      itemCount: items.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, thickness: 0.5, color: AppColors.divider),
      itemBuilder: (context, index) {
        final item = items[index];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onSelected(item),
            hoverColor: AppColors.selected.withValues(alpha: 0.48),
            child: SizedBox(
              height: 72,
              child: Row(
                children: [
                  _CatalogImage(item: item),
                  SizedBox(width: 14),
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
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 5),
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
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.faint,
                  ),
                  SizedBox(width: 6),
                ],
              ),
            ),
          ),
        );
      },
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
      SearchCategory.song => Icons.music_note_rounded,
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(
        item.category == SearchCategory.artist ? 24 : 7,
      ),
      child: Container(
        width: 48,
        height: 48,
        color: Color(0xFFE6EDF5),
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
