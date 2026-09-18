import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../controllers/analytics_controller.dart';

class DailySpendingBarChart extends StatelessWidget {
  final Map<int, DailySpendEntry> dailyExpenses;
  final double averageDailySpend;
  final int? selectedDay;
  final ValueChanged<int?> onDaySelected;

  const DailySpendingBarChart({
    super.key,
    required this.dailyExpenses,
    required this.averageDailySpend,
    this.selectedDay,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (dailyExpenses.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxSpend = dailyExpenses.values.fold<double>(
      0.0,
      (max, e) => math.max(max, e.amount),
    );

    final selectedEntry = selectedDay != null ? dailyExpenses[selectedDay] : null;

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
                      color: colors.ruby.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(Icons.bar_chart_rounded, color: colors.ruby, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Daily Spending Trend',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
              if (averageDailySpend > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.border),
                  ),
                  child: Text(
                    'Avg: ${IndianCurrencyFormatter.format(averageDailySpend)}/day',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Selected Day Tooltip Card
          if (selectedEntry != null) ...[
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.primary.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: colors.primary.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.calendar_today_rounded, size: 14, color: colors.primary),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Day ${selectedEntry.day} (${_getWeekdayName(selectedEntry.date.weekday)})',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                          Text(
                            '${selectedEntry.transactionCount} transaction${selectedEntry.transactionCount == 1 ? "" : "s"}',
                            style: TextStyle(fontSize: 11, color: colors.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Text(
                    IndianCurrencyFormatter.format(selectedEntry.amount),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: selectedEntry.amount > 0 ? colors.ruby : colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Bar Chart Canvas / Layout
          SizedBox(
            height: 140,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final count = dailyExpenses.length;
                final barWidth = math.max(6.0, (constraints.maxWidth / count) - 3.5);

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: dailyExpenses.values.map((entry) {
                    final heightRatio = maxSpend > 0 ? (entry.amount / maxSpend).clamp(0.04, 1.0) : 0.04;
                    final isSelected = selectedDay == entry.day;
                    final isPeak = maxSpend > 0 && entry.amount == maxSpend && entry.amount > 0;

                    Color barColor;
                    if (isSelected) {
                      barColor = colors.primary;
                    } else if (isPeak) {
                      barColor = colors.ruby;
                    } else if (entry.amount > averageDailySpend && averageDailySpend > 0) {
                      barColor = colors.ruby.withOpacity(0.75);
                    } else if (entry.amount > 0) {
                      barColor = colors.ruby.withOpacity(0.4);
                    } else {
                      barColor = colors.isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
                    }

                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          AppHaptics.selection();
                          onDaySelected(isSelected ? null : entry.day);
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Bar
                            Container(
                              width: barWidth,
                              height: 110 * heightRatio,
                              decoration: BoxDecoration(
                                color: barColor,
                                borderRadius: BorderRadius.circular(barWidth / 2),
                                border: isSelected
                                    ? Border.all(color: Colors.white, width: 1.5)
                                    : null,
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: colors.primary.withOpacity(0.4),
                                          blurRadius: 6,
                                          offset: const Offset(0, 1),
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Day Number label (sparse labels to avoid clutter)
                            if (entry.day == 1 ||
                                entry.day == 5 ||
                                entry.day == 10 ||
                                entry.day == 15 ||
                                entry.day == 20 ||
                                entry.day == 25 ||
                                entry.day == count ||
                                isSelected)
                              Text(
                                '${entry.day}',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                  color: isSelected
                                      ? colors.primary
                                      : (entry.isWeekend ? colors.amber : colors.textMuted),
                                ),
                              )
                            else
                              const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Chart Footnote Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: colors.ruby.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text('Above Avg', style: TextStyle(fontSize: 10, color: colors.textMuted)),
                  const SizedBox(width: 12),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: colors.amber,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text('Weekend', style: TextStyle(fontSize: 10, color: colors.textMuted)),
                ],
              ),
              Text(
                'Tap any bar to inspect',
                style: TextStyle(fontSize: 10, color: colors.textMuted, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getWeekdayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Mon';
      case DateTime.tuesday:
        return 'Tue';
      case DateTime.wednesday:
        return 'Wed';
      case DateTime.thursday:
        return 'Thu';
      case DateTime.friday:
        return 'Fri';
      case DateTime.saturday:
        return 'Sat';
      case DateTime.sunday:
        return 'Sun';
      default:
        return '';
    }
  }
}
