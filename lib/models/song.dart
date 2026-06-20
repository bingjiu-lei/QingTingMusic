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
    this.isCloud = false,
    this.cloudAudioId,
    this.liked = false,
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
  final bool isCloud;
  final int? cloudAudioId;
  final bool liked;

  Song copyWith({String? audioUrl, int? fileId, bool? liked}) {
    return Song(
      id: id,
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      audioUrl: audioUrl ?? this.audioUrl,
      hash: hash,
      albumId: albumId,
      albumAudioId: albumAudioId,
      coverUrl: coverUrl,
      fileId: fileId ?? this.fileId,
      artistId: artistId,
      isCloud: isCloud,
      cloudAudioId: cloudAudioId,
      liked: liked ?? this.liked,
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
      isCloud: json['isCloud'] == true,
      cloudAudioId: readInt(json['cloudAudioId']),
      liked: json['liked'] == true,
    );
  }
}
