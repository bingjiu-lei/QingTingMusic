import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qing_ting_music/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('opens on my music without entitlement placeholders', (
    tester,
  ) async {
    await _pumpApp(tester, const Size(1280, 720));

    expect(find.text('晴听音乐'), findsOneWidget);
    expect(find.text('首页'), findsNothing);
    expect(find.text('我的音乐'), findsNWidgets(2));
    expect(find.text('我的收藏'), findsOneWidget);
    expect(find.text('收藏歌曲'), findsOneWidget);
    expect(find.textContaining('权益'), findsNothing);
  });

  testWidgets('sidebar switches between all desktop pages', (tester) async {
    await _pumpApp(tester, const Size(1280, 720));

    await tester.tap(find.text('搜索'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    await tester.tap(find.text('我的音乐').first);
    await tester.pumpAndSettle();
    expect(find.text('收藏和最近听过的歌曲'), findsOneWidget);

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
    expect(find.textContaining('John Lennon'), findsOneWidget);

    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('搜索结果'), findsOneWidget);
    expect(find.text('Imagine'), findsNWidgets(2));

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getStringList('music_search_history'), ['Imagine']);
  });

  testWidgets('renders the wide desktop layout at 1536 by 900', (tester) async {
    await _pumpApp(tester, const Size(1536, 900));

    expect(find.text('我的收藏'), findsOneWidget);
    expect(find.text('收藏歌曲'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpApp(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    const QingTingMusicApp(enableAudio: false, enableWindowControls: false),
  );
  await tester.pumpAndSettle();
}
