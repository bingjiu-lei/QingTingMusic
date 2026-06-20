import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../theme/app_theme.dart';

class AppWindowCaption extends StatelessWidget {
  const AppWindowCaption({super.key, required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return SizedBox(height: 36);
    }

    return SizedBox(
      height: 36,
      child: WindowCaption(
        backgroundColor: AppColors.page,
        brightness: Brightness.light,
      ),
    );
  }
}
