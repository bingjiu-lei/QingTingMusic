import 'package:flutter_test/flutter_test.dart';
import 'package:qing_ting_music/models/song.dart';
import 'package:qing_ting_music/widgets/cloud_upload_dialog.dart';

Song _testSong({
  required String id,
  required String title,
  required String artist,
  String album = 'album',
  int? fileId,
  int? albumAudioId,
  String? hash,
  String? catalogHash,
}) => Song(
  id: id,
  title: title,
  artist: artist,
  album: album,
  duration: const Duration(minutes: 3),
  audioUrl: 'https://example.com/$id.mp3',
  fileId: fileId,
  albumAudioId: albumAudioId,
  hash: hash,
  catalogHash: catalogHash,
);

void main() {
  group('CloudUploadDialog.cleanMvMetadata', () {
    test('cleans quotes, trailing MV tags and extracts artist and title', () {
      final res1 = CloudUploadDialog.cleanMvMetadata(
        rawTitle: "IVE ‘BANG BANG’ MV",
        rawArtist: 'IVE',
      );
      expect(res1.title, 'BANG BANG');
      expect(res1.artist, 'IVE');

      final res2 = CloudUploadDialog.cleanMvMetadata(
        rawTitle: 'IVE ‘BANG BANG’ MV',
        rawArtist: '',
      );
      expect(res2.title, 'BANG BANG');
      expect(res2.artist, 'IVE');

      final res3 = CloudUploadDialog.cleanMvMetadata(
        rawTitle: '周杰伦 - 晴天 (Official Music Video)',
        rawArtist: '周杰伦',
      );
      expect(res3.title, '晴天');
      expect(res3.artist, '周杰伦');

      final res4 = CloudUploadDialog.cleanMvMetadata(
        rawTitle: '【4K 60帧】周杰伦 - 告白气球 MV',
        rawArtist: '未知歌手',
      );
      expect(res4.title, '告白气球');
      expect(res4.artist, '周杰伦');

      final res5 = CloudUploadDialog.cleanMvMetadata(
        rawTitle: '[MV] IU(아이유) _ Blueming(블露밍)',
        rawArtist: 'IU',
      );
      expect(res5.title, 'Blueming(블露밍)');
      expect(res5.artist, 'IU');

      final res6 = CloudUploadDialog.cleanMvMetadata(
        rawTitle: 'aespa 《Whiplash》MV',
        rawArtist: 'aespa',
      );
      expect(res6.title, 'Whiplash');
      expect(res6.artist, 'aespa');
    });

    test('preserves normal titles without MV tags', () {
      final res = CloudUploadDialog.cleanMvMetadata(
        rawTitle: '七里香',
        rawArtist: '周杰伦',
      );
      expect(res.title, '七里香');
      expect(res.artist, '周杰伦');
    });
  });

  group('CloudUploadDialog.findHighConfidenceMatch', () {
    test('matches candidate with exact title, artist and valid official id', () {
      final candidates = [
        _testSong(
          id: '1',
          title: 'BANG BANG (伴奏)',
          artist: 'IVE',
          album: 'BANG BANG',
          fileId: 101,
          albumAudioId: 201,
        ),
        _testSong(
          id: '2',
          title: 'BANG BANG',
          artist: 'IVE (아이브)',
          album: 'BANG BANG',
          fileId: 102,
          albumAudioId: 202,
        ),
      ];

      final match = CloudUploadDialog.findHighConfidenceMatch(
        results: candidates,
        targetTitle: 'BANG BANG',
        targetArtist: 'IVE',
      );

      expect(match, isNotNull);
      expect(match!.id, '2');
      expect(match.fileId, 102);
    });

    test('returns null when target artist is empty to avoid blind false match', () {
      final candidates = [
        _testSong(
          id: '1',
          title: 'BANG BANG',
          artist: 'Jessie J / Ariana Grande / Nicki Minaj',
          fileId: 101,
        ),
      ];

      final match = CloudUploadDialog.findHighConfidenceMatch(
        results: candidates,
        targetTitle: 'BANG BANG',
        targetArtist: '',
      );

      expect(match, isNull);
    });

    test('returns null when candidates have no valid official ID or hash', () {
      final candidates = [
        _testSong(
          id: '1',
          title: 'BANG BANG',
          artist: 'IVE',
          fileId: 0,
          albumAudioId: 0,
          hash: '',
        ),
      ];

      final match = CloudUploadDialog.findHighConfidenceMatch(
        results: candidates,
        targetTitle: 'BANG BANG',
        targetArtist: 'IVE',
      );

      expect(match, isNull);
    });

    test('returns null when candidates artist does not match', () {
      final candidates = [
        _testSong(
          id: '1',
          title: 'BANG BANG',
          artist: 'Green Day',
          fileId: 101,
          albumAudioId: 201,
        ),
      ];

      final match = CloudUploadDialog.findHighConfidenceMatch(
        results: candidates,
        targetTitle: 'BANG BANG',
        targetArtist: 'IVE',
      );

      expect(match, isNull);
    });
  });

  group('CloudUploadDialog.isMatchedSongInCloud', () {
    final cloudList = <Song>[
      const Song(
        id: 'cloud_1001',
        title: '萍聚',
        artist: '卓依婷',
        album: '蜕变1少女的心情故事',
        duration: Duration(minutes: 3),
        audioUrl: '',
        isCloud: true,
        cloudAudioId: 998877,
        albumAudioId: 887766,
        fileId: 1001,
        hash: 'hash_pingju_123',
        catalogHash: 'hashstd_pingju_123',
      ),
      const Song(
        id: 'cloud_1002',
        title: '晴天',
        artist: '周杰伦',
        album: '叶惠美',
        duration: Duration(minutes: 4),
        audioUrl: '',
        isCloud: true,
        cloudAudioId: 112233,
        albumAudioId: 223344,
        fileId: 1002,
      ),
    ];

    test('matches by cloudAudioId / matchedAudioId', () {
      final exists = CloudUploadDialog.isMatchedSongInCloud(
        cloudSongs: cloudList,
        matchedAudioId: 998877,
        matchedTitle: '萍聚',
        matchedArtist: '卓依婷',
      );
      expect(exists, isTrue);
    });

    test('matches by albumAudioId', () {
      final exists = CloudUploadDialog.isMatchedSongInCloud(
        cloudSongs: cloudList,
        matchedAlbumAudioId: 887766,
        matchedTitle: '萍聚',
        matchedArtist: '卓依婷',
      );
      expect(exists, isTrue);
    });

    test('matches by hash or catalogHash', () {
      final exists = CloudUploadDialog.isMatchedSongInCloud(
        cloudSongs: cloudList,
        matchedHashStd: 'HASHSTD_PINGJU_123',
        matchedTitle: '萍聚',
        matchedArtist: '卓依婷',
      );
      expect(exists, isTrue);
    });

    test('matches by normalized title and artist', () {
      final exists = CloudUploadDialog.isMatchedSongInCloud(
        cloudSongs: cloudList,
        matchedTitle: '《萍聚》',
        matchedArtist: '卓依婷',
      );
      expect(exists, isTrue);
    });

    test('returns false when song is not in cloud', () {
      final exists = CloudUploadDialog.isMatchedSongInCloud(
        cloudSongs: cloudList,
        matchedAudioId: 556677,
        matchedTitle: '七里香',
        matchedArtist: '周杰伦',
      );
      expect(exists, isFalse);
    });

    test('returns false when cloudSongs list is empty', () {
      final exists = CloudUploadDialog.isMatchedSongInCloud(
        cloudSongs: const [],
        matchedAudioId: 998877,
        matchedTitle: '萍聚',
        matchedArtist: '卓依婷',
      );
      expect(exists, isFalse);
    });
  });
}
