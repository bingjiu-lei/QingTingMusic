import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CoverPaletteService {
  CoverPaletteService._();

  static final Map<String, Future<Color?>> _cache = {};

  static Future<Color?> colorFor(String url) {
    if (url.trim().isEmpty) return Future.value(null);
    return _cache.putIfAbsent(url, () => _extract(url));
  }

  static Future<Color?> _extract(String url) async {
    try {
      final data = await NetworkAssetBundle(Uri.parse(url)).load(url);
      final buffer = await ui.ImmutableBuffer.fromUint8List(
        data.buffer.asUint8List(),
      );
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final codec = await descriptor.instantiateCodec(
        targetWidth: 24,
        targetHeight: 24,
      );
      final frame = await codec.getNextFrame();
      final pixels = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      frame.image.dispose();
      codec.dispose();
      descriptor.dispose();
      buffer.dispose();
      return pixels == null
          ? null
          : _weightedColor(pixels.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  static Color? _weightedColor(Uint8List rgba) {
    var red = 0.0;
    var green = 0.0;
    var blue = 0.0;
    var total = 0.0;
    for (var index = 0; index + 3 < rgba.length; index += 4) {
      if (rgba[index + 3] < 180) continue;
      final r = rgba[index] / 255;
      final g = rgba[index + 1] / 255;
      final b = rgba[index + 2] / 255;
      final maximum = [r, g, b].reduce((a, b) => a > b ? a : b);
      final minimum = [r, g, b].reduce((a, b) => a < b ? a : b);
      final brightness = (maximum + minimum) / 2;
      if (brightness < 0.08 || brightness > 0.94) continue;
      final saturation = maximum == 0 ? 0 : (maximum - minimum) / maximum;
      final weight = 0.28 + saturation * 1.9;
      red += r * weight;
      green += g * weight;
      blue += b * weight;
      total += weight;
    }
    if (total == 0) return null;
    final hsv = HSVColor.fromColor(
      Color.fromARGB(
        255,
        (red / total * 255).round(),
        (green / total * 255).round(),
        (blue / total * 255).round(),
      ),
    );
    return hsv
        .withSaturation(hsv.saturation.clamp(0.34, 0.72))
        .withValue(hsv.value.clamp(0.48, 0.82))
        .toColor();
  }
}
