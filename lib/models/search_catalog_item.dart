import 'music_playlist.dart';

enum SearchCategory {
  song('单曲'),
  playlist('歌单'),
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
    this.listId,
    this.ownerId,
    this.releaseDate,
  });

  final String id;
  final String title;
  final String subtitle;
  final SearchCategory category;
  final String? imageUrl;
  final String? listId;
  final String? ownerId;
  final String? releaseDate;

  String? get formattedReleaseDate => formatReleaseDate(releaseDate);

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'category': category.name,
    'imageUrl': imageUrl,
    'listId': listId,
    'ownerId': ownerId,
    'releaseDate': releaseDate,
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
      listId: json['listId']?.toString(),
      ownerId: json['ownerId']?.toString(),
      releaseDate: json['releaseDate']?.toString(),
    );
  }
}
