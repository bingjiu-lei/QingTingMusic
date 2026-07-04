import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../theme/app_theme.dart';

class AppWindowCaption extends StatelessWidget {
  const AppWindowCaption({super.key, required this.enabled});

  static const height = 30.0;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return const SizedBox(height: height);
    }

    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: height,
      child: WindowCaption(
        backgroundColor: AppColors.page,
        brightness: dark ? Brightness.dark : Brightness.light,
      ),
    );
  }
}
