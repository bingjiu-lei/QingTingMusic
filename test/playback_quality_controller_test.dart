import 'package:flutter_test/flutter_test.dart';
import 'package:qing_ting_music/controllers/playback_quality_controller.dart';
import 'package:qing_ting_music/models/song.dart';

void main() {
  test('only exposes quality resources confirmed for the current song', () {
    final controller = PlaybackQualityController();
    final song = _song('catalog-song');

    controller.setCurrentSong(song);
    expect(controller.availableQualities, isEmpty);
    expect(controller.availabilityChecked, isFalse);

    controller.setAvailableQualities(song, ['128', 'flac', 'super', 'invalid']);

    expect(controller.availableQualities, [
      PlaybackQuality.standard,
      PlaybackQuality.lossless,
    ]);
    expect(controller.availabilityChecked, isTrue);
  });

  test('cloud-only songs do not inherit catalog quality options', () {
    final controller = PlaybackQualityController();
    final base = _song('cloud-song');
    final cloudSong = Song(
      id: base.id,
      title: base.title,
      artist: base.artist,
      album: base.album,
      duration: base.duration,
      audioUrl: '',
      hash: 'cloud-hash',
      isCloud: true,
    );

    controller.setCurrentSong(cloudSong);
    controller.markAvailabilityChecked(cloudSong);

    expect(controller.availableQualities, isEmpty);
    expect(controller.hasCloudSource, isTrue);
  });

  test('linked cloud songs can expose confirmed catalog qualities', () {
    final controller = PlaybackQualityController();
    final cloudSong = _song('linked-cloud').copyWith(hash: 'cloud-hash');
    final linkedCloudSong = Song(
      id: cloudSong.id,
      title: cloudSong.title,
      artist: cloudSong.artist,
      album: cloudSong.album,
      duration: cloudSong.duration,
      audioUrl: '',
      hash: cloudSong.hash,
      catalogHash: 'catalog-hash',
      isCloud: true,
    );

    controller.setCurrentSong(linkedCloudSong);
    controller.setAvailableQualities(linkedCloudSong, [320]);

    expect(controller.availableQualities, [PlaybackQuality.high]);
  });
}

Song _song(String id) => Song(
  id: id,
  title: id,
  artist: 'artist',
  album: 'album',
  duration: const Duration(minutes: 3),
  audioUrl: '',
  hash: '$id-hash',
);
