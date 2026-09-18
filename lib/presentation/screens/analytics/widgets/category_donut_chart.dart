import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../core/utils/currency_formatter.dart';

class CategoryDonutChart extends StatefulWidget {
  final Map<String, double> categoryExpenses;
  final Map<String, double> categoryPercentages;
  final double totalExpense;
  final String? selectedCategory;
  final ValueChanged<String?> onCategorySelected;

  const CategoryDonutChart({
    super.key,
    required this.categoryExpenses,
    required this.categoryPercentages,
    required this.totalExpense,
    this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  State<CategoryDonutChart> createState() => _CategoryDonutChartState();
}

class _CategoryDonutChartState extends State<CategoryDonutChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _animation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  @override
  void didUpdateWidget(CategoryDonutChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.totalExpense != widget.totalExpense) {
      _animController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (widget.categoryExpenses.isEmpty || widget.totalExpense <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        decoration: BoxDecoration(
          color: colors.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.border),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.pie_chart_outline_rounded, size: 48, color: colors.textMuted),
              const SizedBox(height: 12),
              Text(
                'No Expenses Recorded',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Expenses in this time period will generate an interactive breakdown.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: colors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    final sortedEntries = widget.categoryExpenses.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Determine what to display in the center hole
    final isCategorySelected = widget.selectedCategory != null &&
        widget.categoryExpenses.containsKey(widget.selectedCategory);
    final centerTitle = isCategorySelected
        ? widget.selectedCategory!
        : 'Total Spent';
    final centerAmount = isCategorySelected
        ? widget.categoryExpenses[widget.selectedCategory]!
        : widget.totalExpense;
    final centerSubtitle = isCategorySelected
        ? '${widget.categoryPercentages[widget.selectedCategory]?.toStringAsFixed(1) ?? "0"}% of total'
        : '${sortedEntries.length} categories';
    final centerColor = isCategorySelected
        ? (AppColors.categoryColors[widget.selectedCategory] ?? colors.emerald)
        : colors.textPrimary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: colors.emerald.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(Icons.donut_large_rounded, color: colors.emerald, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Category Breakdown',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
              if (widget.selectedCategory != null)
                InkWell(
                  onTap: () {
                    AppHaptics.selection();
                    widget.onCategorySelected(null);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Reset',
                          style: TextStyle(fontSize: 11, color: colors.textMuted, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.close, size: 12, color: colors.textMuted),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // Custom Donut Canvas Chart
          Center(
            child: SizedBox(
              width: 220,
              height: 220,
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(220, 220),
                        painter: _DonutChartPainter(
                          entries: sortedEntries,
                          total: widget.totalExpense,
                          selectedCategory: widget.selectedCategory,
                          animationValue: _animation.value,
                          isDark: colors.isDark,
                        ),
                      ),
                      // Center Hole Information
                      GestureDetector(
                        onTap: () {
                          if (widget.selectedCategory != null) {
                            AppHaptics.selection();
                            widget.onCategorySelected(null);
                          }
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              centerTitle,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              IndianCurrencyFormatter.format(centerAmount),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: centerColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              centerSubtitle,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Interactive Category Chips Legend
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sortedEntries.map((entry) {
              final cat = entry.key;
              final amount = entry.value;
              final pct = widget.categoryPercentages[cat] ?? 0.0;
              final catColor = AppColors.categoryColors[cat] ?? colors.textMuted;
              final isSelected = widget.selectedCategory == cat;

              return InkWell(
                onTap: () {
                  AppHaptics.selection();
                  widget.onCategorySelected(isSelected ? null : cat);
                },
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? catColor.withOpacity(0.18)
                        : colors.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? catColor : colors.border,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: catColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        cat,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? colors.textPrimary : colors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${pct.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? catColor : colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<MapEntry<String, double>> entries;
  final double total;
  final String? selectedCategory;
  final double animationValue;
  final bool isDark;

  _DonutChartPainter({
    required this.entries,
    required this.total,
    required this.selectedCategory,
    required this.animationValue,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;
    const strokeWidth = 26.0;
    final arcRadius = outerRadius - strokeWidth / 2;

    // Draw background track ring
    final bgPaint = Paint()
      ..color = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, arcRadius, bgPaint);

    double startAngle = -math.pi / 2;
    final maxAngle = 2 * math.pi * animationValue;

    for (final entry in entries) {
      final sweepAngle = (entry.value / total) * 2 * math.pi;
      final effectiveSweep = sweepAngle.clamp(0.0, maxAngle - (startAngle - (-math.pi / 2)));

      if (effectiveSweep > 0) {
        final catColor = AppColors.categoryColors[entry.key] ?? const Color(0xFF94A3B8);
        final isSelected = selectedCategory == entry.key;

        final segmentPaint = Paint()
          ..color = isSelected ? catColor : catColor.withOpacity(selectedCategory != null ? 0.35 : 0.95)
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSelected ? strokeWidth + 4 : strokeWidth
          ..strokeCap = StrokeCap.butt;

        // Gap spacing between segments
        const gap = 0.035;
        final actualStart = startAngle + (entries.length > 1 ? gap : 0.0);
        final actualSweep = math.max(0.0, effectiveSweep - (entries.length > 1 ? gap * 2 : 0.0));

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: arcRadius),
          actualStart,
          actualSweep,
          false,
          segmentPaint,
        );

        // Highlight stroke for selected
        if (isSelected) {
          final highlightPaint = Paint()
            ..color = Colors.white.withOpacity(0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0;
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: arcRadius + strokeWidth / 2 + 2),
            actualStart,
            actualSweep,
            false,
            highlightPaint,
          );
        }
      }

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.selectedCategory != selectedCategory ||
        oldDelegate.total != total;
  }
}
