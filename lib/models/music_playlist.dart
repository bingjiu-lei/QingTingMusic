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
    this.isDefault = false,
    this.isMine = false,
    this.kind = MusicPlaylistKind.createdPlaylist,
  });

  final String id;
  final String listId;
  final String name;
  final int songCount;
  final String? coverUrl;
  final bool isDefault;
  final bool isMine;
  final MusicPlaylistKind kind;

  Map<String, Object?> toJson() => {
    'id': id,
    'listId': listId,
    'name': name,
    'songCount': songCount,
    'coverUrl': coverUrl,
    'isDefault': isDefault,
    'isMine': isMine,
    'kind': kind.name,
  };

  factory MusicPlaylist.fromJson(Map<String, Object?> json) {
    return MusicPlaylist(
      id: json['id']?.toString() ?? '',
      listId: json['listId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      songCount: int.tryParse(json['songCount']?.toString() ?? '') ?? 0,
      coverUrl: json['coverUrl']?.toString(),
      isDefault: json['isDefault'] == true,
      isMine: json['isMine'] == true,
      kind: MusicPlaylistKind.values.firstWhere(
        (item) => item.name == json['kind'],
        orElse: () => MusicPlaylistKind.createdPlaylist,
      ),
    );
  }
}
