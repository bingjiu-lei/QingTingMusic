import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qing_ting_music/models/song.dart';
import 'package:qing_ting_music/services/app_storage_service.dart';
import 'package:qing_ting_music/services/api_endpoint_service.dart';
import 'package:qing_ting_music/services/cache_management_service.dart';
import 'package:qing_ting_music/services/recent_songs_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('qingting-storage-');
    AppStorageService.overrideForTesting(tempDirectory);
  });

  tearDown(() async {
    AppStorageService.overrideForTesting(null);
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('persists API endpoint and verifies it', () async {
    final service = ApiEndpointService(verifier: (_) async {});
    await service.save('https://kugou.bingjiu.cc.cd/');
    expect(await service.load(), 'https://kugou.bingjiu.cc.cd');
    expect(await AppStorageService.file('settings.json').exists(), isTrue);
  });

  test('uses official API mode when endpoint is not configured', () async {
    final service = ApiEndpointService(verifier: (_) async {});
    expect(await service.load(), isEmpty);
    await service.save('   ');
    expect(await service.load(), isEmpty);
  });

  test('persists recent songs', () async {
    final service = RecentSongsService();
    const song = Song(
      id: 'recent',
      title: '最近播放测试',
      artist: '晴听音乐',
      album: '本地缓存',
      duration: Duration(minutes: 3),
      audioUrl: 'https://example.com/song.mp3',
    );
    await service.save([song]);
    final restored = await service.load();
    expect(restored.single.title, song.title);
  });

  test('clears managed cache without deleting login and settings', () async {
    await AppStorageService.file('session.dat').writeAsString('login');
    await AppStorageService.file('settings.json').writeAsString('{}');
    await AppStorageService.file('preferences.json').writeAsString('{}');
    await AppStorageService.file('library-cache.json').writeAsString('{}');
    await AppStorageService.file('search-cache.json').writeAsString('{}');
    await AppStorageService.directory('audio').create(recursive: true);
    await File(
      '${AppStorageService.directory('audio').path}\\song.mp3',
    ).writeAsString('cache');

    final service = CacheManagementService();
    expect(await service.cacheSizeBytes(), greaterThan(0));

    await service.clearCache();

    expect(await AppStorageService.file('session.dat').exists(), isTrue);
    expect(await AppStorageService.file('settings.json').exists(), isTrue);
    expect(await AppStorageService.file('preferences.json').exists(), isTrue);
    expect(
      await AppStorageService.file('library-cache.json').exists(),
      isFalse,
    );
    expect(await AppStorageService.file('search-cache.json').exists(), isFalse);
    expect(await AppStorageService.directory('audio').exists(), isFalse);
  });
}
