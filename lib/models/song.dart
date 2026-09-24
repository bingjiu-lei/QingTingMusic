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
    this.catalogHash,
    this.albumId,
    this.albumAudioId,
    this.coverUrl,
    this.fileId,
    this.artistId,
    this.artists = const [],
    this.isCloud = false,
    this.cloudAudioId,
    this.isMv = false,
    this.mvId,
    this.isSpecialSource = false,
    this.liked = false,
    this.privilege,
    this.playbackNotice,
    this.playbackQuality,
    this.cloudQuality,
    this.playbackSource,
    this.climaxSegments = const [],
    this.addTime,
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final String audioUrl;
  final String? hash;
  final String? catalogHash;
  final int? albumId;
  final int? albumAudioId;
  final String? coverUrl;
  final int? fileId;
  final int? artistId;
  final List<SongArtist> artists;
  final bool isCloud;
  final int? cloudAudioId;
  final bool isMv;
  final String? mvId;
  final bool isSpecialSource;
  final bool liked;
  final int? privilege;
  final String? playbackNotice;
  final String? playbackQuality;
  final String? cloudQuality;
  final String? playbackSource;
  final List<SongClimaxSegment> climaxSegments;
  final int? addTime;

  bool get isEligibleForCloudUpload =>
      !isCloud &&
      audioUrl.isNotEmpty &&
      (isSpecialSource || isMv || playbackQuality == 'MV');

  Song copyWith({
    String? audioUrl,
    String? hash,
    String? artist,
    int? artistId,
    List<SongArtist>? artists,
    int? fileId,
    Duration? duration,
    bool? isCloud,
    bool? isMv,
    String? mvId,
    bool? isSpecialSource,
    bool? liked,
    int? privilege,
    String? playbackNotice,
    String? playbackQuality,
    String? cloudQuality,
    String? playbackSource,
    List<SongClimaxSegment>? climaxSegments,
    int? addTime,
  }) {
    return Song(
      id: id,
      title: title,
      artist: artist ?? this.artist,
      album: album,
      duration: duration ?? this.duration,
      audioUrl: audioUrl ?? this.audioUrl,
      hash: hash ?? this.hash,
      catalogHash: catalogHash,
      albumId: albumId,
      albumAudioId: albumAudioId,
      coverUrl: coverUrl,
      fileId: fileId ?? this.fileId,
      artistId: artistId ?? this.artistId,
      artists: artists ?? this.artists,
      isCloud: isCloud ?? this.isCloud,
      cloudAudioId: cloudAudioId,
      isMv: isMv ?? this.isMv,
      mvId: mvId ?? this.mvId,
      isSpecialSource: isSpecialSource ?? this.isSpecialSource,
      liked: liked ?? this.liked,
      privilege: privilege ?? this.privilege,
      playbackNotice: playbackNotice ?? this.playbackNotice,
      playbackQuality: playbackQuality ?? this.playbackQuality,
      cloudQuality: cloudQuality ?? this.cloudQuality,
      playbackSource: playbackSource ?? this.playbackSource,
      climaxSegments: climaxSegments ?? this.climaxSegments,
      addTime: addTime ?? this.addTime,
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
    'catalogHash': catalogHash,
    'albumId': albumId,
    'albumAudioId': albumAudioId,
    'coverUrl': coverUrl,
    'fileId': fileId,
    'artistId': artistId,
    'artists': artists.map((item) => item.toJson()).toList(),
    'isCloud': isCloud,
    'cloudAudioId': cloudAudioId,
    'addTime': addTime,
    'isMv': isMv,
    'mvId': mvId,
    'isSpecialSource': isSpecialSource,
    'liked': liked,
    'privilege': privilege,
    'playbackQuality': playbackQuality,
    'cloudQuality': cloudQuality,
    'playbackSource': playbackSource,
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
      catalogHash: json['catalogHash']?.toString(),
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
      addTime: readInt(json['addTime']),
      isMv: json['isMv'] == true,
      mvId: json['mvId']?.toString(),
      isSpecialSource: json['isSpecialSource'] == true,
      liked: json['liked'] == true,
      privilege: readInt(json['privilege']),
      playbackQuality: json['playbackQuality']?.toString(),
      cloudQuality: json['cloudQuality']?.toString(),
      playbackSource: json['playbackSource']?.toString(),
    );
  }
}
