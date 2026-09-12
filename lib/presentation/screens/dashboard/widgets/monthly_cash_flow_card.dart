import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';

import 'package:intl/intl.dart';

class MonthlyCashFlowCard extends StatelessWidget {
  final double totalMonthlyIncome;
  final double totalMonthlyExpense;
  final VoidCallback? onAllocateSavings;

  const MonthlyCashFlowCard({
    super.key,
    required this.totalMonthlyIncome,
    required this.totalMonthlyExpense,
    this.onAllocateSavings,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final netCashFlow = totalMonthlyIncome - totalMonthlyExpense;
    final isPositive = netCashFlow >= 0;

    final now = DateTime.now();
    final monthName = DateFormat('MMMM').format(now);
    final totalDays = DateTime(now.year, now.month + 1, 0).day;
    final currentDay = now.day;

    final double incomeFlex = totalMonthlyIncome > 0 ? totalMonthlyIncome : 1.0;
    final double expenseFlex = totalMonthlyExpense > 0 ? totalMonthlyExpense : 0.0;
    final double flowTotal = incomeFlex + expenseFlex;
    final double outRatio = flowTotal > 0 ? (expenseFlex / flowTotal).clamp(0.0, 1.0) : 0.0;
    final int spentPercentOfIncome = totalMonthlyIncome > 0
        ? ((totalMonthlyExpense / totalMonthlyIncome) * 100).round()
        : 100;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Month Name & Days Progress
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    monthName.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: colors.surfaceElevated,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: colors.borderSubtle),
                    ),
                    child: Text(
                      '$currentDay of $totalDays days',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: colors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPositive
                      ? colors.emerald.withOpacity(0.12)
                      : colors.ruby.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isPositive ? 'NET POSITIVE' : 'NET DEFICIT',
                  style: TextStyle(
                    color: isPositive ? colors.emerald : colors.ruby,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // In vs Out Numerical Headline
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              // In (Income)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(color: colors.emerald, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'In',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    IndianCurrencyFormatter.format(totalMonthlyIncome),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: colors.emerald,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),

              // Out (Expense)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Text(
                        'Out',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textMuted),
                      ),
                      const SizedBox(width: 5),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(color: colors.ruby, shape: BoxShape.circle),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    IndianCurrencyFormatter.format(totalMonthlyExpense),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Dual-Segment Sleek Progress Track (Direction 2a)
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 7,
              width: double.infinity,
              color: colors.surfaceElevated,
              child: Row(
                children: [
                  Expanded(
                    flex: ((1.0 - outRatio) * 1000).toInt().clamp(1, 1000),
                    child: Container(color: colors.emerald),
                  ),
                  Expanded(
                    flex: (outRatio * 1000).toInt().clamp(0, 1000),
                    child: Container(color: colors.ruby.withOpacity(0.85)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Helper Text Caption (Direction 2a)
          Text(
            totalMonthlyIncome > 0
                ? '$spentPercentOfIncome% of what came in has gone out • Net ${isPositive ? 'saved' : 'deficit'} ${IndianCurrencyFormatter.format(netCashFlow.abs())}'
                : (totalMonthlyExpense > 0
                    ? 'Total outflow of ${IndianCurrencyFormatter.format(totalMonthlyExpense)} recorded'
                    : 'No transactions recorded yet this month'),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: colors.textMuted,
            ),
          ),

          // Allocate Savings Action Banner (If positive net cash flow)
          if (isPositive && netCashFlow > 0) ...[
            const SizedBox(height: 14),
            Divider(color: colors.borderSubtle, height: 1),
            const SizedBox(height: 12),
            InkWell(
              onTap: onAllocateSavings,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: colors.emerald.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.emerald.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: colors.emerald.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.savings_outlined, color: colors.emerald, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'You saved ${IndianCurrencyFormatter.format(netCashFlow)} this month!',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Tap to confirm or allocate to investments/savings',
                            style: TextStyle(
                              fontSize: 10,
                              color: colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: colors.emerald, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

