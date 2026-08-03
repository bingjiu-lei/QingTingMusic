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

/// 服务端标注的歌曲高潮片段。时间均来自酷狗的 `audio_climax` 接口，
/// 没有返回时保持为空，绝不根据歌曲时长猜测。
class SongClimaxSegment {
  const SongClimaxSegment({required this.start, required this.end});

  final Duration start;
  final Duration end;
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
    this.climaxSegments = const [],
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
  final List<SongClimaxSegment> climaxSegments;

  Song copyWith({
    String? audioUrl,
    String? artist,
    int? artistId,
    List<SongArtist>? artists,
    int? fileId,
    Duration? duration,
    bool? liked,
    String? playbackNotice,
    List<SongClimaxSegment>? climaxSegments,
  }) {
    return Song(
      id: id,
      title: title,
      artist: artist ?? this.artist,
      album: album,
      duration: duration ?? this.duration,
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
      climaxSegments: climaxSegments ?? this.climaxSegments,
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
