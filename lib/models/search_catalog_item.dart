import 'music_playlist.dart';
import 'song.dart';

enum SearchCategory {
  song('单曲'),
  playlist('歌单'),
  artist('歌手'),
  album('专辑'),
  mv('MV');

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
    this.duration,
    this.hash,
  });

  final String id;
  final String title;
  final String subtitle;
  final SearchCategory category;
  final String? imageUrl;
  final String? listId;
  final String? ownerId;
  final String? releaseDate;
  final Duration? duration;
  final String? hash;

  String? get formattedReleaseDate => formatReleaseDate(releaseDate);

  Song toSong() {
    final mvHash = hash ?? listId ?? '';
    return Song(
      id: mvHash.isNotEmpty
          ? mvHash
          : (id.isNotEmpty ? 'mv_$id' : 'mv_${title.hashCode}'),
      title: title,
      artist: subtitle,
      album: 'MV音源',
      audioUrl: '',
      coverUrl: imageUrl,
      hash: mvHash.isNotEmpty ? mvHash : null,
      duration: duration ?? Duration.zero,
      isMv: true,
      mvId: int.tryParse(id) != null ? id : null,
      artists: subtitle.isNotEmpty ? [SongArtist(name: subtitle)] : const [],
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'category': category.name,
    'imageUrl': imageUrl,
    'listId': listId,
    'ownerId': ownerId,
    'releaseDate': releaseDate,
    'duration': duration?.inMilliseconds,
    'hash': hash,
  };

  factory SearchCatalogItem.fromJson(Map<String, Object?> json) {
    final durMs = int.tryParse(json['duration']?.toString() ?? '');
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
      duration: durMs != null ? Duration(milliseconds: durMs) : null,
      hash: json['hash']?.toString(),
    );
  }
}
