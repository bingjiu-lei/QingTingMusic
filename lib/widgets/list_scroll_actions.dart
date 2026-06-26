import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Lightweight floating actions for long song lists.
class ListScrollActions extends StatefulWidget {
  const ListScrollActions({
    super.key,
    required this.controller,
    this.currentIndex,
    this.itemExtent = 67.0,
    this.scrollPadding = 0.0,
  });

  final ScrollController controller;

  /// Index of the currently playing song in the list, or null if none.
  final int? currentIndex;

  /// Height of a single list row including its separator.
  final double itemExtent;

  /// Top padding of the scrollable content (e.g. ListView padding).
  final double scrollPadding;

  @override
  State<ListScrollActions> createState() => _ListScrollActionsState();
}

class _ListScrollActionsState extends State<ListScrollActions> {
  bool _showTop = false;
  bool _showLocate = false;

  void _updateVisibility() {
    if (!mounted || !widget.controller.hasClients) return;
    final pos = widget.controller.position;
    final canScroll = pos.maxScrollExtent > 0;
    final showTop = canScroll && pos.pixels > 8;

    bool showLocate = false;
    if (canScroll && widget.currentIndex != null) {
      final itemTop =
          widget.scrollPadding + widget.currentIndex! * widget.itemExtent;
      final itemBottom = itemTop + widget.itemExtent;
      showLocate =
          itemTop < pos.pixels - 1 ||
          itemBottom > pos.pixels + pos.viewportDimension + 1;
    }

    if (showTop != _showTop || showLocate != _showLocate) {
      setState(() {
        _showTop = showTop;
        _showLocate = showLocate;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateVisibility);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateVisibility());
  }

  @override
  void didUpdateWidget(covariant ListScrollActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_updateVisibility);
      widget.controller.addListener(_updateVisibility);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateVisibility());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateVisibility);
    super.dispose();
  }

  void _scrollToTop() {
    widget.controller.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _scrollToCurrent() {
    if (widget.currentIndex == null || !widget.controller.hasClients) return;
    final pos = widget.controller.position;
    final itemTop =
        widget.scrollPadding + widget.currentIndex! * widget.itemExtent;
    final target = (itemTop - pos.viewportDimension / 3).clamp(
      0.0,
      pos.maxScrollExtent,
    );
    widget.controller.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_showTop && !_showLocate) return const SizedBox.shrink();
    return Positioned(
      bottom: 12,
      right: 12,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_showLocate)
            _ActionButton(
              icon: Icons.my_location_rounded,
              tooltip: '定位当前歌曲',
              onTap: _scrollToCurrent,
            ),
          if (_showLocate && _showTop) const SizedBox(height: 8),
          if (_showTop)
            _ActionButton(
              icon: Icons.keyboard_arrow_up_rounded,
              tooltip: '回到顶部',
              onTap: _scrollToTop,
            ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.tooltip,
        waitDuration: const Duration(milliseconds: 400),
        child: Material(
          color: _hovered
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.surface.withValues(
                  alpha: AppColors.isDark ? 0.9 : 0.82,
                ),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(8),
            hoverColor: Colors.transparent,
            child: SizedBox(
              width: 34,
              height: 34,
              child: Icon(
                widget.icon,
                size: 18,
                color: _hovered ? AppColors.primary : AppColors.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
