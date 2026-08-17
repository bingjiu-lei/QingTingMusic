import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_notice.dart';

/// Gives a short asynchronous action an immediate, reusable visual state.
///
/// The transparent barrier intentionally blocks accidental repeated actions
/// without dimming the whole page. A modal route (for example, a dialog opened
/// above this widget) remains interactive because it is rendered above the
/// shell overlay.
class AsyncOperationOverlay extends StatelessWidget {
  const AsyncOperationOverlay({
    super.key,
    required this.child,
    required this.active,
    required this.message,
    this.top = 72,
    this.blockInput = true,
  });

  final Widget child;
  final bool active;
  final String message;
  final double top;
  final bool blockInput;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (blockInput)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !active,
              child: const ColoredBox(color: Colors.transparent),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          top: top,
          child: IgnorePointer(
            child: Center(
              child: AnimatedSwitcher(
                duration: AppMotion.normal,
                switchInCurve: AppMotion.curve,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(
                      begin: 0.94,
                      end: 1,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: active
                    ? AppNoticeCard(
                        key: ValueKey(message),
                        message: message,
                        kind: AppNoticeKind.loading,
                        minWidth: 280,
                        maxWidth: 420,
                      )
                    : const SizedBox.shrink(
                        key: ValueKey('async-operation-idle'),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
