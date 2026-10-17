import 'dart:ui';
import 'package:flutter/material.dart';

import '../models/rank_chart_item.dart';
import '../theme/app_theme.dart';
import 'preparing_dots.dart';

Future<void> showRankPickerDialog({
  required BuildContext context,
  required List<RankChartItem> ranks,
  required RankChartItem? selectedRank,
  required ValueChanged<RankChartItem> onSelect,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: '排行榜选择',
    barrierColor: Colors.black.withValues(alpha: 0.50),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return Center(
        child: Material(
          color: Colors.transparent,
          child: _RankPickerContent(
            ranks: ranks,
            selectedRank: selectedRank,
            onSelect: onSelect,
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _RankPickerContent extends StatefulWidget {
  const _RankPickerContent({
    required this.ranks,
    required this.selectedRank,
    required this.onSelect,
  });

  final List<RankChartItem> ranks;
  final RankChartItem? selectedRank;
  final ValueChanged<RankChartItem> onSelect;

  @override
  State<_RankPickerContent> createState() => _RankPickerContentState();
}

class _RankPickerContentState extends State<_RankPickerContent> {
  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;
    final size = MediaQuery.sizeOf(context);
    final dialogWidth = (size.width - 48).clamp(320.0, 520.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xxl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: dialogWidth,
          constraints: const BoxConstraints(maxHeight: 480),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E2024).withValues(alpha: 0.88)
                : Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(AppRadius.xxl),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.black.withValues(alpha: 0.08),
            ),
            boxShadow: AppShadows.popover,
          ),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(
                        alpha: isDark ? 0.16 : 0.10,
                      ),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      Icons.leaderboard_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '排行榜选择',
                    style: AppTypography.style(
                      16.5,
                      750,
                      color: AppColors.text,
                    ),
                  ),
                  const Spacer(),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (widget.ranks.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  child: Center(child: PreparingDots(color: AppColors.primary)),
                )
              else
                Flexible(
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(
                      context,
                    ).copyWith(scrollbars: false),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final rank in widget.ranks)
                              _RankPickerTag(
                                rank: rank,
                                isSelected:
                                    rank.rankId == widget.selectedRank?.rankId,
                                onSelect: () {
                                  Navigator.of(context).pop();
                                  widget.onSelect(rank);
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankPickerTag extends StatefulWidget {
  const _RankPickerTag({
    required this.rank,
    required this.isSelected,
    required this.onSelect,
  });

  final RankChartItem rank;
  final bool isSelected;
  final VoidCallback onSelect;

  @override
  State<_RankPickerTag> createState() => _RankPickerTagState();
}

class _RankPickerTagState extends State<_RankPickerTag> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;
    final isSelected = widget.isSelected;

    Color backgroundColor;
    Color borderColor;
    Color textColor;

    if (isSelected) {
      backgroundColor = AppColors.primary;
      borderColor = AppColors.primary;
      textColor = Colors.white;
    } else if (_hovered) {
      backgroundColor = AppColors.primary.withValues(
        alpha: isDark ? 0.16 : 0.10,
      );
      borderColor = AppColors.primary.withValues(alpha: 0.40);
      textColor = AppColors.primaryPressed;
    } else {
      backgroundColor = isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.black.withValues(alpha: 0.04);
      borderColor = isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.06);
      textColor = AppColors.text;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onSelect,
        child: AnimatedScale(
          scale: _hovered && !isSelected ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOutQuad,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOutQuad,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              widget.rank.cleanName,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: textColor,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
