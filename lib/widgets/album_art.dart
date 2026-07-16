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
    final radius = BorderRadius.circular(
      size >= 50 ? AppRadius.lg : AppRadius.sm,
    );
    final placeholder = Image.asset(
      'assets/images/album_placeholder.png',
      width: size,
      height: size,
      fit: BoxFit.cover,
      gaplessPlayback: true,
    );
    final image = imageUrl == null || imageUrl!.isEmpty
        ? placeholder
        : Image.network(
            imageUrl!,
            key: ValueKey(imageUrl),
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            cacheWidth: (size * 2).round(),
            errorBuilder: (_, _, _) => placeholder,
          );

    return AnimatedContainer(
      duration: AppMotion.normal,
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: emphasized
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.34))
            : null,
        boxShadow: emphasized ? AppShadows.card : null,
      ),
      child: AnimatedSwitcher(
        duration: AppMotion.normal,
        switchInCurve: AppMotion.curve,
        switchOutCurve: Curves.easeInCubic,
        child: ClipRRect(
          key: ValueKey(imageUrl ?? 'placeholder'),
          borderRadius: radius,
          child: image,
        ),
      ),
    );
  }
}
