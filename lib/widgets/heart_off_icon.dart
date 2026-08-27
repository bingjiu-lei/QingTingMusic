import 'package:flutter/material.dart';

/// 极简轻量风格的“不喜欢”图标 (Heart-Off / Heart-Slash)
/// 基于全局统一的 Material 圆角爱心 (Icons.favorite_border_rounded)，
/// 搭配精准轻量 45° 穿心斜杠，视觉内敛协调，与左侧收藏爱心及其他控制图标完全一致。
class HeartOffIcon extends StatelessWidget {
  const HeartOffIcon({
    super.key,
    this.size = 20.0,
    this.color,
    this.strokeWidth = 1.7,
  });

  final double size;
  final Color? color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? IconTheme.of(context).color ?? Colors.white;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 与左侧收藏爱心 100% 保持同源的 Material 圆角爱心
          Icon(Icons.favorite_border_rounded, size: size, color: iconColor),
          // 极简轻量 45 度对角穿心斜杠 (精致内敛，与图标轮廓自然齐平)
          Positioned.fill(
            child: CustomPaint(
              painter: _HeartSlashPainter(
                color: iconColor,
                strokeWidth: strokeWidth,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeartSlashPainter extends CustomPainter {
  const _HeartSlashPainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // 精准 45° 斜杠 (从左上 16% 至右下 84%)，自然契合爱心外缘
    final start = Offset(size.width * 0.16, size.height * 0.16);
    final end = Offset(size.width * 0.84, size.height * 0.84);

    canvas.drawLine(start, end, paint);
  }

  @override
  bool shouldRepaint(covariant _HeartSlashPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}
