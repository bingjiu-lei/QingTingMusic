enum MusicPlaylistKind {
  createdPlaylist,
  collectedPlaylist,
  album,
  favoriteSongs,
}

class MusicPlaylist {
  const MusicPlaylist({
    required this.id,
    required this.listId,
    required this.name,
    required this.songCount,
    this.coverUrl,
    this.sourceId,
    this.sourceListId,
    this.isDefault = false,
    this.isMine = false,
    this.kind = MusicPlaylistKind.createdPlaylist,
    this.releaseDate,
  });

  final String id;
  final String listId;
  final String name;
  final int songCount;
  final String? coverUrl;
  final String? sourceId;
  final String? sourceListId;
  final bool isDefault;
  final bool isMine;
  final MusicPlaylistKind kind;
  final String? releaseDate;

  String? get formattedReleaseDate => formatReleaseDate(releaseDate);

  Map<String, Object?> toJson() => {
    'id': id,
    'listId': listId,
    'name': name,
    'songCount': songCount,
    'coverUrl': coverUrl,
    'sourceId': sourceId,
    'sourceListId': sourceListId,
    'isDefault': isDefault,
    'isMine': isMine,
    'kind': kind.name,
    'releaseDate': releaseDate,
  };

  factory MusicPlaylist.fromJson(Map<String, Object?> json) {
    return MusicPlaylist(
      id: json['id']?.toString() ?? '',
      listId: json['listId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      songCount: int.tryParse(json['songCount']?.toString() ?? '') ?? 0,
      coverUrl: json['coverUrl']?.toString(),
      sourceId: json['sourceId']?.toString(),
      sourceListId: json['sourceListId']?.toString(),
      isDefault: json['isDefault'] == true,
      isMine: json['isMine'] == true,
      kind: MusicPlaylistKind.values.firstWhere(
        (item) => item.name == json['kind'],
        orElse: () => MusicPlaylistKind.createdPlaylist,
      ),
      releaseDate: json['releaseDate']?.toString(),
    );
  }
}

String? formatReleaseDate(String? raw) {
  if (raw == null) return null;
  final str = raw.trim();
  if (str.isEmpty) return null;

  final numVal = int.tryParse(str);
  if (numVal != null) {
    if (numVal > 100000000) {
      try {
        final dt = numVal > 10000000000
            ? DateTime.fromMillisecondsSinceEpoch(numVal)
            : DateTime.fromMillisecondsSinceEpoch(numVal * 1000);
        if (dt.year >= 1950 && dt.year <= 2100) {
          final year = dt.year.toString();
          final month = dt.month.toString().padLeft(2, '0');
          final day = dt.day.toString().padLeft(2, '0');
          return '$year-$month-$day';
        }
      } catch (_) {}
    }
  }

  if (RegExp(r'^\d{8}$').hasMatch(str)) {
    return '${str.substring(0, 4)}-${str.substring(4, 6)}-${str.substring(6, 8)}';
  }

  final dateMatch =
      RegExp(r'^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})').firstMatch(str);
  if (dateMatch != null) {
    final year = dateMatch.group(1)!;
    final month = dateMatch.group(2)!.padLeft(2, '0');
    final day = dateMatch.group(3)!.padLeft(2, '0');
    return '$year-$month-$day';
  }

  if (RegExp(r'^\d{4}$').hasMatch(str)) {
    return str;
  }

  return null;
}
