import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';
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
    AppHaptics.medium();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SetBudgetSheet(existingBudget: existingBudget),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
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
                      color: colors.emerald.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.pie_chart_outline,
                      color: colors.emerald,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Monthly Budgets',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => _openSetBudget(context),
                icon: Icon(Icons.add, size: 15, color: colors.emerald),
                label: Text(
                  'Set Limit',
                  style: TextStyle(
                    color: colors.emerald,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
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
            _buildEmptyState(context, colors)
          else
            Column(
              children: budgets.map((item) => _buildBudgetItem(context, item, colors)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppThemeColors colors) {
    return InkWell(
      onTap: () => _openSetBudget(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.borderSubtle),
        ),
        child: Column(
          children: [
            Icon(Icons.savings_outlined, size: 32, color: colors.textMuted),
            const SizedBox(height: 8),
            Text(
              'No category budgets set',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap here to set spending limits for Food, Travel, etc.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetItem(BuildContext context, BudgetProgress progress, AppThemeColors colors) {
    final isOver = progress.isOverBudget;
    final ratio = progress.progressRatio;
    
    // Status color: Red if >=100%, Amber if >=80%, Emerald green otherwise
    final progressColor = isOver
        ? colors.ruby
        : (ratio >= 0.8 ? colors.amber : colors.emerald);

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
                      color: colors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      progress.budget.category,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
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
                          color: isOver ? colors.ruby : colors.textPrimary,
                        ),
                      ),
                      TextSpan(
                        text: ' / ${CurrencyFormatter.formatINR(progress.budget.monthlyLimit)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textMuted,
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
                minHeight: 5,
                backgroundColor: colors.surfaceElevated,
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
                    color: isOver ? colors.ruby : colors.textMuted,
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
            Divider(color: colors.borderSubtle, height: 16),
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
