import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../theme/app_theme.dart';

class AppWindowCaption extends StatelessWidget {
  const AppWindowCaption({
    super.key,
    required this.enabled,
    this.backgroundColor,
    this.sidebarWidth,
    this.transparentOverlay = false,
  });

  static const height = 30.0;

  final bool enabled;
  final Color? backgroundColor;
  final double? sidebarWidth;
  final bool transparentOverlay;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return const SizedBox(height: height);
    }

    final dark = Theme.of(context).brightness == Brightness.dark;
    if (transparentOverlay) {
      return SizedBox(
        height: height,
        child: Row(
          children: [
            const Expanded(child: DragToMoveArea(child: SizedBox.expand())),
            WindowCaptionButton.minimize(
              brightness: dark ? Brightness.dark : Brightness.light,
              onPressed: windowManager.minimize,
            ),
            FutureBuilder<bool>(
              future: windowManager.isMaximized(),
              builder: (context, snapshot) => snapshot.data == true
                  ? WindowCaptionButton.unmaximize(
                      brightness: dark ? Brightness.dark : Brightness.light,
                      onPressed: windowManager.unmaximize,
                    )
                  : WindowCaptionButton.maximize(
                      brightness: dark ? Brightness.dark : Brightness.light,
                      onPressed: windowManager.maximize,
                    ),
            ),
            WindowCaptionButton.close(
              brightness: dark ? Brightness.dark : Brightness.light,
              onPressed: windowManager.close,
            ),
          ],
        ),
      );
    }
    final caption = WindowCaption(
      backgroundColor: Colors.transparent,
      brightness: dark ? Brightness.dark : Brightness.light,
    );
    return ColoredBox(
      color: backgroundColor ?? AppColors.page,
      child: SizedBox(
        height: height,
        child: sidebarWidth == null || backgroundColor != null
            ? caption
            : Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: sidebarWidth!,
                    child: ColoredBox(color: AppColors.sidebar),
                  ),
                  Positioned.fill(child: caption),
                ],
              ),
      ),
    );
  }
}
