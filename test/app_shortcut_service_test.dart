import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qing_ting_music/services/app_shortcut_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppShortcutService - key event handling', () {
    late AppShortcutService shortcuts;

    setUp(() => shortcuts = AppShortcutService());
    testWidgets('player shortcuts do not activate a focused account button', (
      tester,
    ) async {
      var accountOpens = 0;
      final actions = <AppShortcutAction>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InkWell(
              autofocus: true,
              onTap: () => accountOpens++,
              child: const Text('Account'),
            ),
          ),
        ),
      );
      await tester.pump();

      KeyEventResult handle(KeyEvent event) {
        final handled = shortcuts.handleKeyEvent(
          event: event,
          onAction: actions.add,
        );
        return handled ? KeyEventResult.handled : KeyEventResult.ignored;
      }

      FocusManager.instance.addEarlyKeyEventHandler(handle);
      try {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        for (final key in [
          LogicalKeyboardKey.arrowRight,
          LogicalKeyboardKey.arrowLeft,
          LogicalKeyboardKey.arrowUp,
          LogicalKeyboardKey.arrowDown,
        ]) {
          await tester.sendKeyDownEvent(key);
          await tester.sendKeyUpEvent(key);
        }
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();
        expect(actions, [
          AppShortcutAction.playNext,
          AppShortcutAction.playPrevious,
          AppShortcutAction.volumeUp,
          AppShortcutAction.volumeDown,
          AppShortcutAction.togglePlay,
        ]);
        expect(accountOpens, 0);
      } finally {
        FocusManager.instance.removeEarlyKeyEventHandler(handle);
      }
    });

    testWidgets('consumes repeat and release without repeating an action', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      var actions = 0;
      void onAction(AppShortcutAction _) => actions++;
      const down = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.space,
        logicalKey: LogicalKeyboardKey.space,
        timeStamp: Duration.zero,
      );
      const repeat = KeyRepeatEvent(
        physicalKey: PhysicalKeyboardKey.space,
        logicalKey: LogicalKeyboardKey.space,
        timeStamp: Duration.zero,
      );
      const up = KeyUpEvent(
        physicalKey: PhysicalKeyboardKey.space,
        logicalKey: LogicalKeyboardKey.space,
        timeStamp: Duration.zero,
      );

      expect(shortcuts.handleKeyEvent(event: down, onAction: onAction), isTrue);
      expect(
        shortcuts.handleKeyEvent(event: repeat, onAction: onAction),
        isTrue,
      );
      expect(
        shortcuts.handleKeyEvent(
          event: up,
          isModalActive: true,
          onAction: onAction,
        ),
        isTrue,
      );
      expect(shortcuts.handleKeyEvent(event: up, onAction: onAction), isFalse);
      expect(actions, 1);
    });

    testWidgets(
      'triggers togglePlay on Space key when not in editable context',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: Center(child: Text('Not editable'))),
          ),
        );

        AppShortcutAction? capturedAction;
        final consumed = shortcuts.handleKeyEvent(
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
        final consumed = shortcuts.handleKeyEvent(
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
      final consumed = shortcuts.handleKeyEvent(
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
      final consumed = shortcuts.handleKeyEvent(
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
        final consumed = shortcuts.handleKeyEvent(
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
        expect(
          shortcuts.handleKeyEvent(
            event: KeyUpEvent(
              physicalKey: PhysicalKeyboardKey.mediaPlayPause,
              logicalKey: entry.key,
              timeStamp: Duration.zero,
            ),
            onAction: (_) {},
          ),
          isTrue,
        );
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
        final consumed = shortcuts.handleKeyEvent(
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
