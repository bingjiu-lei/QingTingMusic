import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qing_ting_music/models/song.dart';
import 'package:qing_ting_music/services/app_storage_service.dart';
import 'package:qing_ting_music/services/favorite_bilibili_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('bilibili_test_');
    AppStorageService.overrideForTesting(tempDir);
  });

  tearDown(() async {
    AppStorageService.overrideForTesting(null);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'FavoriteBilibiliService strips temporary audioUrl upon adding and loading',
    () async {
      final service = FavoriteBilibiliService();
      await service.initialize();

      const sampleSong = Song(
        id: 'bili_BV1xx411c7mD',
        title: '测试B站歌曲',
        artist: 'UP主',
        album: 'B站',
        duration: Duration(seconds: 180),
        audioUrl:
            'https://xy183x14x163x40xy.mcdn.bilivideo.cn/test.m4s?deadline=1700000000',
        coverUrl: 'https://i0.hdslb.com/bfs/archive/test.jpg',
        mvId: 'BV1xx411c7mD',
        playbackSource: 'bilibili',
      );

      // 1. 添加收藏
      await service.add(sampleSong);
      expect(service.songs.length, 1);
      expect(
        service.songs.first.audioUrl,
        isEmpty,
        reason: '内存中的收藏歌曲 audioUrl 必须置空',
      );

      // 2. 检查落盘 JSON 文件
      final file = AppStorageService.file(FavoriteBilibiliService.fileName);
      expect(file.existsSync(), isTrue);
      final jsonList = jsonDecode(await file.readAsString()) as List;
      expect(jsonList.length, 1);
      final savedMap = jsonList.first as Map<String, dynamic>;
      expect(savedMap['audioUrl'], isEmpty, reason: '持久化文件中的 audioUrl 必须置空');

      // 3. 模拟持久化文件中存在包含临时 URL 的脏数据
      savedMap['audioUrl'] =
          'https://dirty.bilivideo.cn/outdated.m4s?deadline=1600000000';
      await file.writeAsString(jsonEncode([savedMap]));

      // 4. 重新加载并验证自动脱敏
      final reloadedService = FavoriteBilibiliService();
      await reloadedService.initialize();
      expect(
        reloadedService.songs.first.audioUrl,
        isEmpty,
        reason: '加载脏数据后也必须自动清理掉过期 audioUrl',
      );
    },
  );
}
