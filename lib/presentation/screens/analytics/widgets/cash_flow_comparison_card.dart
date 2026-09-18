import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';

class CashFlowComparisonCard extends StatelessWidget {
  final double totalIncome;
  final double totalExpense;
  final double netSavings;
  final double savingsRate;

  const CashFlowComparisonCard({
    super.key,
    required this.totalIncome,
    required this.totalExpense,
    required this.netSavings,
    required this.savingsRate,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isSurplus = netSavings >= 0;
    final maxFlow = (totalIncome > totalExpense ? totalIncome : totalExpense);
    final incomeRatio = maxFlow > 0 ? (totalIncome / maxFlow).clamp(0.0, 1.0) : 0.0;
    final expenseRatio = maxFlow > 0 ? (totalExpense / maxFlow).clamp(0.0, 1.0) : 0.0;

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
                      color: colors.royalBlue.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(Icons.swap_vert_circle_rounded, color: colors.royalBlue, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Cash Flow & Savings',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isSurplus ? colors.emerald.withOpacity(0.15) : colors.ruby.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSurplus ? colors.emerald.withOpacity(0.4) : colors.ruby.withOpacity(0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSurplus ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      size: 14,
                      color: isSurplus ? colors.emerald : colors.ruby,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isSurplus ? '+${savingsRate.toStringAsFixed(1)}% Saved' : '${savingsRate.toStringAsFixed(1)}% Deficit',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isSurplus ? colors.emerald : colors.ruby,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Inflow Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: colors.emerald,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Total Inflow (Income & Refunds)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textSecondary),
                      ),
                    ],
                  ),
                  Text(
                    IndianCurrencyFormatter.format(totalIncome),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: colors.emerald),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: incomeRatio,
                  backgroundColor: colors.surfaceElevated,
                  valueColor: AlwaysStoppedAnimation<Color>(colors.emerald),
                  minHeight: 6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Outflow Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: colors.ruby,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Total Outflow (Expenses)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textSecondary),
                      ),
                    ],
                  ),
                  Text(
                    IndianCurrencyFormatter.format(totalExpense),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: colors.ruby),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: expenseRatio,
                  backgroundColor: colors.surfaceElevated,
                  valueColor: AlwaysStoppedAnimation<Color>(colors.ruby),
                  minHeight: 6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Net Saved Summary Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Net Cash Flow Balance',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary),
              ),
              Text(
                '${isSurplus ? "+" : ""}${IndianCurrencyFormatter.format(netSavings)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isSurplus ? colors.emerald : colors.ruby,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
