import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AlbumArt extends StatelessWidget {
  const AlbumArt({super.key, required this.size, this.emphasized = false});

  final double size;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: emphasized ? AppColors.primary : const Color(0xFFDCE7F3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          Positioned(
            left: size * 0.15,
            right: size * 0.15,
            top: size * 0.28,
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          Positioned(
            left: size * 0.22,
            right: size * 0.12,
            top: size * 0.48,
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.38),
            ),
          ),
          Center(
            child: Icon(
              Icons.music_note_rounded,
              size: size * 0.43,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
