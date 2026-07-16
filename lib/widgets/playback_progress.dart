import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class PlaybackProgress extends StatefulWidget {
  const PlaybackProgress({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
    this.bufferedPosition = Duration.zero,
    this.showTimes = false,
    this.compact = false,
  });

  final Duration position;
  final Duration duration;
  final Duration bufferedPosition;
  final ValueChanged<double> onSeek;
  final bool showTimes;
  final bool compact;

  @override
  State<PlaybackProgress> createState() => _PlaybackProgressState();
}

class _PlaybackProgressState extends State<PlaybackProgress> {
  bool _hovered = false;
  bool _dragging = false;
  double? _previewRatio;

  bool get _enabled => widget.duration.inMilliseconds > 0;

  @override
  Widget build(BuildContext context) {
    final played = _ratio(widget.position);
    final buffered = _ratio(widget.bufferedPosition);
    final active = _hovered || _dragging;
    final track = LayoutBuilder(
      builder: (context, constraints) {
        return MouseRegion(
          cursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() {
            _hovered = false;
            if (!_dragging) _previewRatio = null;
          }),
          onHover: (event) {
            if (!_enabled || constraints.maxWidth <= 0) return;
            setState(() {
              _previewRatio = (event.localPosition.dx / constraints.maxWidth)
                  .clamp(0.0, 1.0);
            });
          },
          child: Builder(
            builder: (context) {
              void seek(Offset offset) {
                if (!_enabled || constraints.maxWidth <= 0) return;
                final ratio = (offset.dx / constraints.maxWidth).clamp(
                  0.0,
                  1.0,
                );
                setState(() => _previewRatio = ratio);
                widget.onSeek(ratio);
              }

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) => seek(details.localPosition),
                onHorizontalDragStart: (details) {
                  setState(() => _dragging = true);
                  seek(details.localPosition);
                },
                onHorizontalDragUpdate: (details) =>
                    seek(details.localPosition),
                onHorizontalDragEnd: (_) => setState(() {
                  _dragging = false;
                  if (!_hovered) _previewRatio = null;
                }),
                child: SizedBox(
                  height: widget.compact ? 22 : 30,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.centerLeft,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _ProgressPainter(
                            played: played,
                            buffered: buffered,
                            active: active,
                            enabled: _enabled,
                          ),
                        ),
                      ),
                      if (active && _enabled && _previewRatio != null)
                        Positioned(
                          left: _previewLeft(
                            constraints.maxWidth,
                            _previewRatio!,
                          ),
                          top: widget.compact ? -22 : -18,
                          child: IgnorePointer(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.tooltipSurface,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.sm,
                                ),
                                boxShadow: AppShadows.popover,
                              ),
                              child: Text(
                                _format(widget.duration * _previewRatio!),
                                style: TextStyle(
                                  color: AppColors.tooltipText,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );

    return Semantics(
      label: '播放进度',
      value: '${_format(widget.position)} / ${_format(widget.duration)}',
      onIncrease: _enabled ? () => _seekBy(const Duration(seconds: 5)) : null,
      onDecrease: _enabled ? () => _seekBy(const Duration(seconds: -5)) : null,
      child: widget.showTimes
          ? Row(
              children: [
                _ProgressTime(value: widget.position),
                const SizedBox(width: 12),
                Expanded(child: track),
                const SizedBox(width: 12),
                _ProgressTime(value: widget.duration),
              ],
            )
          : track,
    );
  }

  double _ratio(Duration value) {
    if (!_enabled) return 0;
    return (value.inMilliseconds / widget.duration.inMilliseconds).clamp(
      0.0,
      1.0,
    );
  }

  double _previewLeft(double width, double ratio) {
    const bubbleWidth = 44.0;
    return (width * ratio - bubbleWidth / 2).clamp(0.0, width - bubbleWidth);
  }

  void _seekBy(Duration delta) {
    final target = widget.position + delta;
    final safe = target < Duration.zero
        ? Duration.zero
        : target > widget.duration
        ? widget.duration
        : target;
    widget.onSeek(_ratio(safe));
  }
}

class _ProgressTime extends StatelessWidget {
  const _ProgressTime({required this.value});

  final Duration value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 44,
    child: Text(
      _format(value),
      textAlign: TextAlign.center,
      style: TextStyle(
        color: AppColors.muted,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    ),
  );
}

class _ProgressPainter extends CustomPainter {
  const _ProgressPainter({
    required this.played,
    required this.buffered,
    required this.active,
    required this.enabled,
  });

  final double played;
  final double buffered;
  final bool active;
  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    final trackHeight = active ? 6.0 : 4.0;
    final top = (size.height - trackHeight) / 2;
    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, top, size.width, trackHeight),
      const Radius.circular(999),
    );
    canvas.drawRRect(track, Paint()..color = AppColors.progressTrack);
    if (!enabled) return;

    final bufferedWidth = size.width * buffered.clamp(played, 1.0);
    if (bufferedWidth > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, top, bufferedWidth, trackHeight),
          const Radius.circular(999),
        ),
        Paint()..color = AppColors.progressBuffered,
      );
    }
    final playedWidth = size.width * played.clamp(0.0, 1.0);
    if (playedWidth > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, top, playedWidth, trackHeight),
          const Radius.circular(999),
        ),
        Paint()
          ..shader = LinearGradient(
            colors: [AppColors.primary, AppColors.accent],
          ).createShader(Rect.fromLTWH(0, top, size.width, trackHeight)),
      );
    }
    if (!active) return;
    final center = Offset(
      playedWidth.clamp(6.0, size.width - 6.0),
      size.height / 2,
    );
    canvas.drawCircle(
      center,
      8,
      Paint()..color = AppColors.primary.withValues(alpha: 0.16),
    );
    canvas.drawCircle(center, 5, Paint()..color = AppColors.surface);
    canvas.drawCircle(center, 3, Paint()..color = AppColors.primary);
  }

  @override
  bool shouldRepaint(covariant _ProgressPainter oldDelegate) =>
      oldDelegate.played != played ||
      oldDelegate.buffered != buffered ||
      oldDelegate.active != active ||
      oldDelegate.enabled != enabled;
}

String _format(Duration duration) {
  final totalSeconds = duration.inSeconds.clamp(0, 359999).toInt();
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
