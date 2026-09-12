import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';

class CategoryBreakdownChart extends StatelessWidget {
  final Map<String, double> categoryExpenses;
  final double totalMonthlyExpense;

  const CategoryBreakdownChart({
    super.key,
    required this.categoryExpenses,
    required this.totalMonthlyExpense,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (categoryExpenses.isEmpty || totalMonthlyExpense <= 0) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          children: [
            Icon(Icons.pie_chart_outline, size: 36, color: colors.textMuted),
            const SizedBox(height: 10),
            Text(
              'No Expense Records This Month',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Transactions from bank notifications or Gmail will appear here categorized automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: colors.textMuted),
            ),
          ],
        ),
      );
    }

    // Sort categories descending by amount
    final sortedEntries = categoryExpenses.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

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
                  Text(
                    'Where it went',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: colors.emerald.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'THIS MONTH',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: colors.emerald,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                IndianCurrencyFormatter.format(totalMonthlyExpense),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Multi-segmented proportional bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: Row(
                children: sortedEntries.map((entry) {
                  final ratio = (entry.value / totalMonthlyExpense).clamp(0.0, 1.0);
                  final color = AppColors.categoryColors[entry.key] ?? colors.textMuted;
                  return Flexible(
                    flex: (ratio * 1000).toInt(),
                    child: Container(color: color),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Detailed Category Rows (Linear Progress Bars)
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sortedEntries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final entry = sortedEntries[index];
              final percentage = (entry.value / totalMonthlyExpense) * 100;
              final color = AppColors.categoryColors[entry.key] ?? colors.textMuted;

              return Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.key,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        IndianCurrencyFormatter.format(entry.value),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: colors.surfaceElevated,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 4,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

