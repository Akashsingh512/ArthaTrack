import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';

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
    final netCashFlow = totalMonthlyIncome - totalMonthlyExpense;
    final isPositive = netCashFlow >= 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF26334D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.swap_vert, color: AppColors.emerald, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'MONTHLY CASH FLOW',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPositive
                      ? AppColors.emerald.withOpacity(0.15)
                      : AppColors.ruby.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isPositive ? 'NET SAVING' : 'NET DEFICIT',
                  style: TextStyle(
                    color: isPositive ? AppColors.emerald : AppColors.ruby,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Two Pillars: Received (Income) vs Spent (Expense)
          Row(
            children: [
              // Received (Income)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.emerald.withOpacity(0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.arrow_downward, color: AppColors.income, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Received (Income)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '+${IndianCurrencyFormatter.format(totalMonthlyIncome)}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.income,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Spent (Expenses)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.expense.withOpacity(0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.arrow_upward, color: AppColors.expense, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Spent (Expense)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '-${IndianCurrencyFormatter.format(totalMonthlyExpense)}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.expense,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Bottom Net Balance Banner
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Net Cash Flow This Month:',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              Text(
                '${isPositive ? '+' : ''}${IndianCurrencyFormatter.format(netCashFlow)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isPositive ? AppColors.income : AppColors.expense,
                ),
              ),
            ],
          ),

          // Option A: Allocate Monthly Savings Action Button
          if (isPositive && netCashFlow > 0) ...[
            const SizedBox(height: 14),
            const Divider(color: Color(0xFF26334D), height: 1),
            const SizedBox(height: 12),
            InkWell(
              onTap: onAllocateSavings,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.emerald.withOpacity(0.18),
                      AppColors.emerald.withOpacity(0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.emerald.withOpacity(0.35)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.emerald.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.savings_outlined, color: AppColors.emerald, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'You saved ${IndianCurrencyFormatter.format(netCashFlow)} this month!',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Tap to confirm or allocate to savings/assets',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, color: AppColors.emerald, size: 14),
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
