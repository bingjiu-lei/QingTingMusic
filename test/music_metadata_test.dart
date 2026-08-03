import 'package:flutter_test/flutter_test.dart';

import 'package:qing_ting_music/models/music_playlist.dart';
import 'package:qing_ting_music/models/song.dart';

void main() {
  test('formats release dates from the official API variants', () {
    expect(formatReleaseDate('2024-12-31'), '2024-12-31');
    expect(formatReleaseDate('20241231'), '2024-12-31');
    expect(formatReleaseDate('1735603200'), '2024-12-31');
  });

  test('preserves only explicitly supplied climax segments on a song', () {
    const segment = SongClimaxSegment(
      start: Duration(minutes: 1),
      end: Duration(minutes: 1, seconds: 18),
    );
    const song = Song(
      id: 'song-id',
      title: 'Song',
      artist: 'Artist',
      album: 'Album',
      duration: Duration(minutes: 3),
      audioUrl: '',
    );

    final updated = song.copyWith(climaxSegments: const [segment]);

    expect(song.climaxSegments, isEmpty);
    expect(updated.climaxSegments, hasLength(1));
    expect(updated.climaxSegments.single.start, segment.start);
    expect(updated.climaxSegments.single.end, segment.end);
  });
}
