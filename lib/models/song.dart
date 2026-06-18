class Song {
  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.audioUrl,
    this.liked = false,
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final String audioUrl;
  final bool liked;

  Song copyWith({bool? liked}) {
    return Song(
      id: id,
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      audioUrl: audioUrl,
      liked: liked ?? this.liked,
    );
  }
}
