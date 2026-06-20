import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qing_ting_music/app.dart';
import 'package:qing_ting_music/services/app_preferences_service.dart';
import 'package:qing_ting_music/services/app_storage_service.dart';

void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('qingting-widget-');
    AppStorageService.overrideForTesting(tempDirectory);
  });

  tearDown(() async {
    AppStorageService.overrideForTesting(null);
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  testWidgets('opens on my music without entitlement placeholders', (
    tester,
  ) async {
    await _pumpApp(tester, const Size(1280, 720));

    expect(find.text('晴听音乐'), findsOneWidget);
    expect(find.text('首页'), findsNothing);
    expect(find.text('我的音乐'), findsNWidgets(2));
    expect(find.textContaining('歌曲'), findsWidgets);
    expect(find.textContaining('专辑'), findsOneWidget);
    expect(find.textContaining('歌手'), findsOneWidget);
    expect(find.textContaining('权益'), findsNothing);
  });

  testWidgets('sidebar switches between all desktop pages', (tester) async {
    await _pumpApp(tester, const Size(1280, 720));

    await tester.tap(find.text('搜索'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    await tester.tap(find.text('我的音乐').first);
    await tester.pumpAndSettle();
    expect(find.text('收藏与个人音乐内容'), findsOneWidget);
    expect(find.textContaining('歌曲'), findsWidgets);
    expect(find.textContaining('歌单'), findsOneWidget);
    expect(find.textContaining('云盘'), findsOneWidget);
    expect(find.textContaining('最近播放'), findsOneWidget);

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.text('播放音质'), findsOneWidget);
  });

  testWidgets('searches demo songs and stores the query', (tester) async {
    await _pumpApp(tester, const Size(1280, 720));
    await tester.tap(find.text('搜索'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Imagine');
    await tester.pumpAndSettle();
    expect(find.text('Imagine'), findsOneWidget);

    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('搜索结果'), findsOneWidget);
    expect(find.text('单曲'), findsOneWidget);
    expect(find.text('歌手'), findsOneWidget);
    expect(find.text('专辑'), findsOneWidget);
    expect(find.text('歌单'), findsNothing);
    expect(find.text('Imagine'), findsNWidgets(2));

    final preferences = AppPreferencesService();
    expect(await preferences.read('music_search_history'), ['Imagine']);
  });

  testWidgets('renders the wide desktop layout at 1536 by 900', (tester) async {
    await _pumpApp(tester, const Size(1536, 900));

    expect(find.textContaining('歌曲'), findsWidgets);
    expect(find.textContaining('专辑'), findsOneWidget);
    expect(find.textContaining('歌手'), findsOneWidget);
    expect(find.textContaining('最近播放'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpApp(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    const QingTingMusicApp(
      enableAudio: false,
      enableWindowControls: false,
      useDemoData: true,
    ),
  );
  await tester.pumpAndSettle();
}
