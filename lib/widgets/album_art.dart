import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AlbumArt extends StatelessWidget {
  const AlbumArt({
    super.key,
    required this.size,
    this.emphasized = false,
    this.imageUrl,
  });

  final double size;
  final bool emphasized;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: emphasized ? AppColors.primary : Color(0xFFDCE7F3),
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
    if (imageUrl == null || imageUrl!.isEmpty) return placeholder;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      ),
    );
  }
}
