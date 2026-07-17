import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class SmoothMouseScroll extends StatefulWidget {
  const SmoothMouseScroll({
    super.key,
    required this.controller,
    required this.child,
  });

  final ScrollController controller;
  final Widget child;

  @override
  State<SmoothMouseScroll> createState() => _SmoothMouseScrollState();
}

class _SmoothMouseScrollState extends State<SmoothMouseScroll> {
  double? _target;

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !widget.controller.hasClients) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (signal) {
      final position = widget.controller.position;
      final base =
          _target?.clamp(position.minScrollExtent, position.maxScrollExtent) ??
          position.pixels;
      _target = (base + event.scrollDelta.dy * 0.72).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      widget.controller
          .animateTo(
            _target!,
            duration: const Duration(milliseconds: 125),
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() {
            if (widget.controller.hasClients &&
                (widget.controller.offset - (_target ?? 0)).abs() < 0.5) {
              _target = null;
            }
          });
    });
  }

  @override
  Widget build(BuildContext context) =>
      Listener(onPointerSignal: _handlePointerSignal, child: widget.child);
}
