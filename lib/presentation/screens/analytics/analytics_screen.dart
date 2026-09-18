import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../controllers/analytics_controller.dart';
import 'widgets/cash_flow_comparison_card.dart';
import 'widgets/category_donut_chart.dart';
import 'widgets/daily_spending_bar_chart.dart';
import 'widgets/payment_mode_card.dart';
import 'widgets/top_merchants_card.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AnalyticsController>(context, listen: false).loadAnalytics();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Consumer<AnalyticsController>(
      builder: (context, controller, child) {
        final monthStr = DateFormat('MMMM yyyy').format(controller.selectedMonth);

        return Scaffold(
          backgroundColor: colors.background,
          appBar: AppBar(
            backgroundColor: colors.surface,
            elevation: 0,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: colors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(Icons.insights_rounded, color: colors.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  'Analytics & Insights',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          body: controller.isLoading && controller.filteredTransactions.isEmpty
              ? Center(child: CircularProgressIndicator(color: colors.primary))
              : RefreshIndicator(
                  color: colors.primary,
                  onRefresh: () async {
                    AppHaptics.light();
                    await controller.loadAnalytics();
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Month Selector Header
                        _buildMonthSelector(context, controller, monthStr),
                        const SizedBox(height: 12),

                        // Time Range Selector Chips
                        _buildRangeSelector(context, controller),
                        const SizedBox(height: 16),

                        // Top KPI Cards Row
                        _buildKpiMetricsGrid(context, controller),
                        const SizedBox(height: 16),

                        // Interactive Category Donut Chart
                        CategoryDonutChart(
                          categoryExpenses: controller.categoryExpenses,
                          categoryPercentages: controller.categoryPercentages,
                          totalExpense: controller.totalExpense,
                          selectedCategory: controller.inspectedCategory,
                          onCategorySelected: (cat) =>
                              controller.selectCategoryForInspection(cat),
                        ),
                        const SizedBox(height: 16),

                        // Daily Spending Trend Bar Chart (single month view)
                        if (controller.selectedRange == AnalyticsTimeRange.thisMonth) ...[
                          DailySpendingBarChart(
                            dailyExpenses: controller.dailyExpenses,
                            averageDailySpend: controller.averageDailySpend,
                            selectedDay: controller.inspectedDay,
                            onDaySelected: (day) => controller.selectDayForInspection(day),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Cash Flow & Savings Comparison
                        CashFlowComparisonCard(
                          totalIncome: controller.totalIncome,
                          totalExpense: controller.totalExpense,
                          netSavings: controller.netSavings,
                          savingsRate: controller.savingsRate,
                        ),
                        const SizedBox(height: 16),

                        // Top Merchants Leaderboard
                        TopMerchantsCard(
                          topMerchants: controller.topMerchants,
                        ),
                        const SizedBox(height: 16),

                        // Payment Channels Distribution
                        PaymentModeCard(
                          paymentModeBreakdown: controller.paymentModeBreakdown,
                          totalExpense: controller.totalExpense,
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildMonthSelector(
    BuildContext context,
    AnalyticsController controller,
    String monthStr,
  ) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            color: colors.textSecondary,
            onPressed: () {
              AppHaptics.selection();
              controller.previousMonth();
            },
          ),
          Row(
            children: [
              Icon(Icons.calendar_month_rounded, size: 16, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                monthStr,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            color: colors.textSecondary,
            onPressed: () {
              AppHaptics.selection();
              controller.nextMonth();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRangeSelector(BuildContext context, AnalyticsController controller) {
    final colors = context.colors;
    final currentRange = controller.selectedRange;

    final ranges = [
      {'label': 'Selected Month', 'range': AnalyticsTimeRange.thisMonth},
      {'label': 'Last Month', 'range': AnalyticsTimeRange.lastMonth},
      {'label': 'Last 3 Months', 'range': AnalyticsTimeRange.last3Months},
      {'label': 'All Time', 'range': AnalyticsTimeRange.allTime},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ranges.map((item) {
          final range = item['range'] as AnalyticsTimeRange;
          final isSelected = currentRange == range;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                AppHaptics.selection();
                controller.setTimeRange(range);
              },
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.primary.withOpacity(0.18)
                      : colors.surfaceCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? colors.primary : colors.border,
                    width: isSelected ? 1.4 : 1.0,
                  ),
                ),
                child: Text(
                  item['label'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? colors.primary : colors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildKpiMetricsGrid(BuildContext context, AnalyticsController controller) {
    final colors = context.colors;

    return Row(
      children: [
        // Total Spent
        Expanded(
          child: _KpiTile(
            title: 'Spent',
            value: IndianCurrencyFormatter.format(controller.totalExpense),
            icon: Icons.arrow_upward_rounded,
            iconColor: colors.ruby,
            bgTint: colors.ruby.withOpacity(0.1),
          ),
        ),
        const SizedBox(width: 8),

        // Total Income
        Expanded(
          child: _KpiTile(
            title: 'Income',
            value: IndianCurrencyFormatter.format(controller.totalIncome),
            icon: Icons.arrow_downward_rounded,
            iconColor: colors.emerald,
            bgTint: colors.emerald.withOpacity(0.1),
          ),
        ),
        const SizedBox(width: 8),

        // Daily Avg
        Expanded(
          child: _KpiTile(
            title: 'Daily Avg',
            value: IndianCurrencyFormatter.format(controller.averageDailySpend),
            icon: Icons.speed_rounded,
            iconColor: colors.royalBlue,
            bgTint: colors.royalBlue.withOpacity(0.1),
          ),
        ),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color bgTint;

  const _KpiTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.bgTint,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: bgTint,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 13, color: iconColor),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
