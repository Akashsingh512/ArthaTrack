import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../data/models/budget_model.dart';
import 'set_budget_sheet.dart';

class MonthlyBudgetsCard extends StatelessWidget {
  final List<BudgetProgress> budgets;

  const MonthlyBudgetsCard({
    super.key,
    required this.budgets,
  });

  void _openSetBudget(BuildContext context, {BudgetModel? existingBudget}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SetBudgetSheet(existingBudget: existingBudget),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.pie_chart_outline,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Monthly Budgets',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => _openSetBudget(context),
                icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
                label: const Text(
                  'Set Limit',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Content: Empty State OR List of Budgets
          if (budgets.isEmpty)
            _buildEmptyState(context)
          else
            Column(
              children: budgets.map((item) => _buildBudgetItem(context, item)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return InkWell(
      onTap: () => _openSetBudget(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.background.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10, style: BorderStyle.solid),
        ),
        child: Column(
          children: [
            Icon(Icons.savings_outlined, size: 36, color: Colors.white.withOpacity(0.3)),
            const SizedBox(height: 8),
            const Text(
              'No category budgets set',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap here to set spending limits for Food, Travel, etc.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetItem(BuildContext context, BudgetProgress progress) {
    final isOver = progress.isOverBudget;
    final ratio = progress.progressRatio;
    
    // Status color: Red if >=100%, Amber if >=80%, Emerald green otherwise
    final progressColor = isOver
        ? AppColors.expenseRed
        : (ratio >= 0.8 ? Colors.amberAccent : AppColors.incomeGreen);

    return InkWell(
      onTap: () => _openSetBudget(context, existingBudget: progress.budget),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Category Name + Spent / Limit
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _getCategoryIcon(progress.budget.category),
                      size: 16,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      progress.budget.category,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: CurrencyFormatter.formatINR(progress.spent),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isOver ? AppColors.expenseRed : Colors.white,
                        ),
                      ),
                      TextSpan(
                        text: ' / ${CurrencyFormatter.formatINR(progress.budget.monthlyLimit)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Row 2: Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
            const SizedBox(height: 6),

            // Row 3: Remaining / Overspent status + percentage
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isOver
                      ? '${CurrencyFormatter.formatINR(progress.overspent)} over budget!'
                      : '${CurrencyFormatter.formatINR(progress.remaining)} remaining',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isOver ? AppColors.expenseRed : Colors.white54,
                  ),
                ),
                Text(
                  '${progress.progressPercentage.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: progressColor,
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.white10, height: 16),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Icons.restaurant;
      case 'groceries':
        return Icons.shopping_cart_outlined;
      case 'travel':
        return Icons.directions_car_outlined;
      case 'shopping':
        return Icons.shopping_bag_outlined;
      case 'bills':
        return Icons.receipt_long_outlined;
      case 'entertainment':
        return Icons.movie_outlined;
      case 'health':
        return Icons.medical_services_outlined;
      case 'investment':
        return Icons.trending_up;
      default:
        return Icons.category_outlined;
    }
  }
}
