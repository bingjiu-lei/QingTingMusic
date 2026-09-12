import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum AppShortcutAction {
  togglePlay,
  playPrevious,
  playNext,
  volumeUp,
  volumeDown,
}

abstract final class AppShortcutService {
  /// 检查当前焦点是否位于可编辑文本组件内（例如 TextField、EditableText）。
  /// 处于文本输入状态时，所有按键均应让出给输入法与原生文本操作，避免误触发快捷键。
  static bool isEditableFocused() {
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null) return false;
    final context = primaryFocus.context;
    if (context == null) return false;
    if (context.widget is EditableText) return true;
    return context.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  /// 处理全局键盘事件。
  ///
  /// 返回 `true` 表示快捷键已被消费并拦截；返回 `false` 则让事件继续在 Flutter 事件树中传递。
  static bool handleKeyEvent({
    required KeyEvent event,
    bool isEnabled = true,
    bool isModalActive = false,
    required void Function(AppShortcutAction action) onAction,
  }) {
    if (!isEnabled) return false;
    if (event is! KeyDownEvent) return false;

    // 1. 处于输入法或输入框上下文中时，绝对不拦截任何按键
    if (isEditableFocused()) return false;

    // 2. 如果上层有模态弹窗（如提示框、确认框），快捷键让位给弹窗的原生交互
    if (isModalActive) return false;

    final key = event.logicalKey;

    // 硬件多媒体按键支持
    if (key == LogicalKeyboardKey.mediaPlayPause) {
      onAction(AppShortcutAction.togglePlay);
      return true;
    }
    if (key == LogicalKeyboardKey.mediaTrackPrevious) {
      onAction(AppShortcutAction.playPrevious);
      return true;
    }
    if (key == LogicalKeyboardKey.mediaTrackNext) {
      onAction(AppShortcutAction.playNext);
      return true;
    }
    if (key == LogicalKeyboardKey.audioVolumeUp) {
      onAction(AppShortcutAction.volumeUp);
      return true;
    }
    if (key == LogicalKeyboardKey.audioVolumeDown) {
      onAction(AppShortcutAction.volumeDown);
      return true;
    }

    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final isAlt = HardwareKeyboard.instance.isAltPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final isMeta = HardwareKeyboard.instance.isMetaPressed;

    // 无修饰键：Space 播放/暂停
    if (!isCtrl && !isAlt && !isShift && !isMeta) {
      if (key == LogicalKeyboardKey.space) {
        onAction(AppShortcutAction.togglePlay);
        return true;
      }
    }

    // Ctrl + 方向键（上一首、下一首、音量加减）
    if (isCtrl && !isAlt && !isShift && !isMeta) {
      if (key == LogicalKeyboardKey.arrowLeft) {
        onAction(AppShortcutAction.playPrevious);
        return true;
      }
      if (key == LogicalKeyboardKey.arrowRight) {
        onAction(AppShortcutAction.playNext);
        return true;
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        onAction(AppShortcutAction.volumeUp);
        return true;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        onAction(AppShortcutAction.volumeDown);
        return true;
      }
    }

    return false;
  }
}
