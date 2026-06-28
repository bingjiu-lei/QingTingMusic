class SongArtist {
  const SongArtist({required this.name, this.id});

  final String name;
  final int? id;

  Map<String, Object?> toJson() => {'name': name, 'id': id};

  factory SongArtist.fromJson(Map<String, Object?> json) {
    return SongArtist(
      name: json['name']?.toString() ?? '',
      id: int.tryParse(json['id']?.toString() ?? ''),
    );
  }
}

class Song {
  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.audioUrl,
    this.hash,
    this.albumId,
    this.albumAudioId,
    this.coverUrl,
    this.fileId,
    this.artistId,
    this.artists = const [],
    this.isCloud = false,
    this.cloudAudioId,
    this.liked = false,
    this.playbackNotice,
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final String audioUrl;
  final String? hash;
  final int? albumId;
  final int? albumAudioId;
  final String? coverUrl;
  final int? fileId;
  final int? artistId;
  final List<SongArtist> artists;
  final bool isCloud;
  final int? cloudAudioId;
  final bool liked;
  final String? playbackNotice;

  Song copyWith({
    String? audioUrl,
    String? artist,
    int? artistId,
    List<SongArtist>? artists,
    int? fileId,
    bool? liked,
    String? playbackNotice,
  }) {
    return Song(
      id: id,
      title: title,
      artist: artist ?? this.artist,
      album: album,
      duration: duration,
      audioUrl: audioUrl ?? this.audioUrl,
      hash: hash,
      albumId: albumId,
      albumAudioId: albumAudioId,
      coverUrl: coverUrl,
      fileId: fileId ?? this.fileId,
      artistId: artistId ?? this.artistId,
      artists: artists ?? this.artists,
      isCloud: isCloud,
      cloudAudioId: cloudAudioId,
      liked: liked ?? this.liked,
      playbackNotice: playbackNotice ?? this.playbackNotice,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'album': album,
    'duration': duration.inMilliseconds,
    'audioUrl': audioUrl,
    'hash': hash,
    'albumId': albumId,
    'albumAudioId': albumAudioId,
    'coverUrl': coverUrl,
    'fileId': fileId,
    'artistId': artistId,
    'artists': artists.map((item) => item.toJson()).toList(),
    'isCloud': isCloud,
    'cloudAudioId': cloudAudioId,
    'liked': liked,
  };

  factory Song.fromJson(Map<String, Object?> json) {
    int? readInt(Object? value) => int.tryParse(value?.toString() ?? '');
    return Song(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      artist: json['artist']?.toString() ?? '',
      album: json['album']?.toString() ?? '',
      duration: Duration(milliseconds: readInt(json['duration']) ?? 0),
      audioUrl: json['audioUrl']?.toString() ?? '',
      hash: json['hash']?.toString(),
      albumId: readInt(json['albumId']),
      albumAudioId: readInt(json['albumAudioId']),
      coverUrl: json['coverUrl']?.toString(),
      fileId: readInt(json['fileId']),
      artistId: readInt(json['artistId']),
      artists: (json['artists'] is List ? json['artists'] as List : const [])
          .whereType<Map>()
          .map((item) => SongArtist.fromJson(item.cast<String, Object?>()))
          .where((item) => item.name.isNotEmpty)
          .toList(),
      isCloud: json['isCloud'] == true,
      cloudAudioId: readInt(json['cloudAudioId']),
      liked: json['liked'] == true,
    );
  }
}
