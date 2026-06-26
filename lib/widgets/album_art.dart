import 'package:flutter/material.dart';

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
    final placeholder = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        'assets/images/album_placeholder.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
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
