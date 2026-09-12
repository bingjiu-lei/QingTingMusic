import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qing_ting_music/services/app_shortcut_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppShortcutService - key event handling', () {
    testWidgets(
      'triggers togglePlay on Space key when not in editable context',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: Center(child: Text('Not editable'))),
          ),
        );

        AppShortcutAction? capturedAction;
        final consumed = AppShortcutService.handleKeyEvent(
          event: const KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.space,
            logicalKey: LogicalKeyboardKey.space,
            timeStamp: Duration.zero,
          ),
          isEnabled: true,
          onAction: (action) => capturedAction = action,
        );

        expect(consumed, isTrue);
        expect(capturedAction, equals(AppShortcutAction.togglePlay));
      },
    );

    testWidgets(
      'does NOT intercept Space or other keys when TextField has focus',
      (tester) async {
        final focusNode = FocusNode();
        final textController = TextEditingController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TextField(
                focusNode: focusNode,
                controller: textController,
                autofocus: true,
              ),
            ),
          ),
        );
        await tester.pump();
        expect(focusNode.hasFocus, isTrue);
        expect(AppShortcutService.isEditableFocused(), isTrue);

        AppShortcutAction? capturedAction;
        final consumed = AppShortcutService.handleKeyEvent(
          event: const KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.space,
            logicalKey: LogicalKeyboardKey.space,
            timeStamp: Duration.zero,
          ),
          isEnabled: true,
          onAction: (action) => capturedAction = action,
        );

        expect(consumed, isFalse);
        expect(capturedAction, isNull);

        focusNode.dispose();
        textController.dispose();
      },
    );

    testWidgets('yields when isEnabled is false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: Text('Not editable'))),
        ),
      );

      AppShortcutAction? capturedAction;
      final consumed = AppShortcutService.handleKeyEvent(
        event: const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.space,
          logicalKey: LogicalKeyboardKey.space,
          timeStamp: Duration.zero,
        ),
        isEnabled: false,
        onAction: (action) => capturedAction = action,
      );

      expect(consumed, isFalse);
      expect(capturedAction, isNull);
    });

    testWidgets('yields when isModalActive is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: Text('Not editable'))),
        ),
      );

      AppShortcutAction? capturedAction;
      final consumed = AppShortcutService.handleKeyEvent(
        event: const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.space,
          logicalKey: LogicalKeyboardKey.space,
          timeStamp: Duration.zero,
        ),
        isEnabled: true,
        isModalActive: true,
        onAction: (action) => capturedAction = action,
      );

      expect(consumed, isFalse);
      expect(capturedAction, isNull);
    });

    testWidgets('handles media hardware keys', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: Text('Not editable'))),
        ),
      );

      final mediaKeys = {
        LogicalKeyboardKey.mediaPlayPause: AppShortcutAction.togglePlay,
        LogicalKeyboardKey.mediaTrackPrevious: AppShortcutAction.playPrevious,
        LogicalKeyboardKey.mediaTrackNext: AppShortcutAction.playNext,
        LogicalKeyboardKey.audioVolumeUp: AppShortcutAction.volumeUp,
        LogicalKeyboardKey.audioVolumeDown: AppShortcutAction.volumeDown,
      };

      for (final entry in mediaKeys.entries) {
        AppShortcutAction? capturedAction;
        final consumed = AppShortcutService.handleKeyEvent(
          event: KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.mediaPlayPause,
            logicalKey: entry.key,
            timeStamp: Duration.zero,
          ),
          isEnabled: true,
          onAction: (action) => capturedAction = action,
        );

        expect(consumed, isTrue);
        expect(capturedAction, equals(entry.value));
      }
    });

    testWidgets('does NOT intercept removed keys (e.g. Esc, M, L, etc.)', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: Text('Not editable'))),
        ),
      );

      final removedKeys = [
        LogicalKeyboardKey.escape,
        LogicalKeyboardKey.keyM,
        LogicalKeyboardKey.keyL,
        LogicalKeyboardKey.keyP,
        LogicalKeyboardKey.keyK,
        LogicalKeyboardKey.keyD,
        LogicalKeyboardKey.keyQ,
        LogicalKeyboardKey.keyB,
      ];

      for (final key in removedKeys) {
        AppShortcutAction? capturedAction;
        final consumed = AppShortcutService.handleKeyEvent(
          event: KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.keyA,
            logicalKey: key,
            timeStamp: Duration.zero,
          ),
          isEnabled: true,
          onAction: (action) => capturedAction = action,
        );

        expect(consumed, isFalse);
        expect(capturedAction, isNull);
      }
    });
  });
}
