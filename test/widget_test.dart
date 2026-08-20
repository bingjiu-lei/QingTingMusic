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
    await _settleForUi(tester);
    expect(find.byType(TextField), findsOneWidget);

    await tester.tap(find.text('我的音乐').first);
    await _settleForUi(tester);
    expect(find.text('我的音乐'), findsWidgets);
    expect(find.textContaining('歌曲'), findsWidgets);
    expect(find.textContaining('歌单'), findsOneWidget);
    expect(find.textContaining('云盘'), findsOneWidget);
    expect(find.textContaining('最近播放'), findsOneWidget);

    await tester.tap(find.byTooltip('设置'));
    await _settleForUi(tester);
    expect(find.text('播放音质'), findsOneWidget);
    expect(find.text('后端 API'), findsNothing);
  });

  testWidgets('searches demo songs and stores the query', (tester) async {
    await _pumpApp(tester, const Size(1280, 720));
    await tester.tap(find.text('搜索'));
    await _settleForUi(tester);

    await tester.enterText(find.byType(TextField), 'Imagine');
    await _settleForUi(tester);
    expect(find.text('Imagine'), findsWidgets);

    tester.widget<TextField>(find.byType(TextField)).onSubmitted?.call('Imagine');
    await _settleForUi(tester);
    expect(find.text('搜索结果'), findsOneWidget);
    expect(find.text('单曲'), findsOneWidget);
    expect(find.text('歌单'), findsOneWidget);
    expect(find.text('歌手'), findsOneWidget);
    expect(find.text('专辑'), findsOneWidget);
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
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
  });

  await tester.pumpWidget(
    const QingTingMusicApp(
      enableAudio: false,
      enableWindowControls: false,
      useDemoData: true,
    ),
  );
  await _settleForUi(tester);
}

Future<void> _settleForUi(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
