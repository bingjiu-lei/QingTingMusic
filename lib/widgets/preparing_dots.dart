import 'package:flutter/material.dart';

/// The lightweight three-dot loading mark used by the primary play button and
/// short-lived async operation feedback.
class PreparingDots extends StatefulWidget {
  const PreparingDots({super.key, this.color = Colors.white});

  final Color color;

  @override
  State<PreparingDots> createState() => _PreparingDotsState();
}

class _PreparingDotsState extends State<PreparingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) {
      final phase = _controller.value;
      return SizedBox(
        width: 20,
        height: 20,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            final offset = (phase + index / 3) % 1;
            final opacity = 0.32 + (offset < 0.5 ? offset : 1 - offset) * 1.36;
            return Container(
              width: 3.5,
              height: 3.5,
              margin: const EdgeInsets.symmetric(horizontal: 1.2),
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: opacity.clamp(0.2, 1.0)),
                shape: BoxShape.circle,
              ),
            );
          }),
        ),
      );
    },
  );
}
