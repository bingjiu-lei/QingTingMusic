import 'package:flutter_test/flutter_test.dart';

import 'package:qing_ting_music/models/music_playlist.dart';
import 'package:qing_ting_music/models/search_catalog_item.dart';
import 'package:qing_ting_music/models/song.dart';
import 'package:qing_ting_music/services/kugou_api_client.dart';

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

  test(
    'isMvReplacementCandidate filters candidates under 90 seconds or teasers',
    () {
      const sourceSong = Song(
        id: 'src-1',
        title: 'BOOMPALA',
        artist: 'LE SSERAFIM',
        album: 'CRAZY',
        duration: Duration(minutes: 3, seconds: 28),
        audioUrl: '',
      );

      // 1. Duration < 90 seconds: rejected
      final shortCandidate = SearchCatalogItem(
        id: 'short-mv',
        title: "LE SSERAFIM 'BOOMPALA' OFFICIAL MV",
        subtitle: 'LE SSERAFIM',
        category: SearchCategory.mv,
        hash: 'HASH_SHORT_CLIP',
        duration: const Duration(seconds: 45),
      );
      expect(isMvReplacementCandidate(sourceSong, shortCandidate), isFalse);

      final edgeCandidate89s = SearchCatalogItem(
        id: 'edge-mv',
        title: "LE SSERAFIM 'BOOMPALA' OFFICIAL MV",
        subtitle: 'LE SSERAFIM',
        category: SearchCategory.mv,
        hash: 'HASH_EDGE_CLIP',
        duration: const Duration(seconds: 89),
      );
      expect(isMvReplacementCandidate(sourceSong, edgeCandidate89s), isFalse);

      // 2. Duration >= 90 seconds: accepted
      final validCandidate90s = SearchCatalogItem(
        id: 'valid-90s',
        title: "LE SSERAFIM 'BOOMPALA' OFFICIAL MV",
        subtitle: 'LE SSERAFIM',
        category: SearchCategory.mv,
        hash: 'HASH_VALID_90S',
        duration: const Duration(seconds: 90),
      );
      expect(isMvReplacementCandidate(sourceSong, validCandidate90s), isTrue);

      final validCandidateFull = SearchCatalogItem(
        id: 'valid-full',
        title: "LE SSERAFIM 'BOOMPALA' OFFICIAL MV",
        subtitle: 'LE SSERAFIM',
        category: SearchCategory.mv,
        hash: 'HASH_VALID_FULL',
        duration: const Duration(seconds: 208),
      );
      expect(isMvReplacementCandidate(sourceSong, validCandidateFull), isTrue);

      // 3. Teaser / Clip keywords: rejected even if duration >= 90s
      final teaserCandidate = SearchCatalogItem(
        id: 'teaser-mv',
        title: "LE SSERAFIM 'BOOMPALA' Teaser 1",
        subtitle: 'LE SSERAFIM',
        category: SearchCategory.mv,
        hash: 'HASH_TEASER',
        duration: const Duration(seconds: 120),
      );
      expect(isMvReplacementCandidate(sourceSong, teaserCandidate), isFalse);

      final trailerCandidate = SearchCatalogItem(
        id: 'trailer-mv',
        title: "LE SSERAFIM 'BOOMPALA' 预告片",
        subtitle: 'LE SSERAFIM',
        category: SearchCategory.mv,
        hash: 'HASH_TRAILER',
        duration: const Duration(seconds: 100),
      );
      expect(isMvReplacementCandidate(sourceSong, trailerCandidate), isFalse);
    },
  );
}
