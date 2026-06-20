enum SearchCategory {
  song('单曲'),
  artist('歌手'),
  album('专辑');

  const SearchCategory(this.label);

  final String label;
}

class SearchCatalogItem {
  const SearchCatalogItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    this.imageUrl,
  });

  final String id;
  final String title;
  final String subtitle;
  final SearchCategory category;
  final String? imageUrl;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'category': category.name,
    'imageUrl': imageUrl,
  };

  factory SearchCatalogItem.fromJson(Map<String, Object?> json) {
    return SearchCatalogItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      category: SearchCategory.values.firstWhere(
        (item) => item.name == json['category'],
        orElse: () => SearchCategory.artist,
      ),
      imageUrl: json['imageUrl']?.toString(),
    );
  }
}
