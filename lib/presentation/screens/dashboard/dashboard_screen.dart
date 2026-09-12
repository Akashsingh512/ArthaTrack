import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../data/models/transaction_model.dart';
import '../../../../services/ingestion/sms_sync_service.dart';
import '../../controllers/dashboard_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../controllers/transaction_controller.dart';
import '../transactions/widgets/add_cash_transaction_sheet.dart';
import '../transactions/widgets/edit_transaction_sheet.dart';
import 'widgets/allocate_savings_sheet.dart';
import 'widgets/category_breakdown_chart.dart';
import 'widgets/monthly_budgets_card.dart';
import 'widgets/monthly_cash_flow_card.dart';
import 'widgets/net_worth_card.dart';
import 'widgets/recent_transactions_list.dart';

class DashboardScreen extends StatelessWidget {
  final VoidCallback onNavigateToTransactions;
  final VoidCallback onNavigateToSettings;

  const DashboardScreen({
    super.key,
    required this.onNavigateToTransactions,
    required this.onNavigateToSettings,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Consumer<DashboardController>(
      builder: (context, controller, child) {
        if (controller.isLoading && controller.netWorth == null) {
          return Center(
            child: CircularProgressIndicator(color: colors.emerald),
          );
        }

        final snapshot = controller.netWorth;

        // Today's captured transactions count (Direction 2c)
        final now = DateTime.now();
        final todayCount = controller.recentTransactions.where((t) {
          final d = DateTime.tryParse(t.date);
          return d != null && d.day == now.day && d.month == now.month && d.year == now.year;
        }).length;

        return RefreshIndicator(
          color: colors.emerald,
          backgroundColor: colors.surfaceElevated,
          onRefresh: () async {
            try {
              final smsService = SmsSyncService();
              if (await smsService.isPermissionGranted()) {
                await smsService.syncInbox(limit: 5000);
              }
            } catch (_) {}
            await controller.loadDashboardData();
            if (context.mounted) {
              await Provider.of<TransactionController>(context, listen: false).loadTransactions();
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top App Bar Greeting (Quiet Ledger)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ArthaTrack',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Consumer<SettingsController>(
                          builder: (context, settings, _) {
                            return Text(
                              settings.activeEngineLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: settings.isAiActive
                                    ? colors.aiEngine
                                    : colors.regexEngine,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.settings_outlined, color: colors.textPrimary, size: 22),
                      onPressed: onNavigateToSettings,
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Direction 2c: Ambient Capture Feed Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: colors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.bolt, color: colors.emerald, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          todayCount > 0
                              ? '$todayCount transaction${todayCount > 1 ? 's' : ''} captured today • SMS • UPI'
                              : 'Auto-capture active • SMS & notifications processed on-device',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: colors.emerald,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Net Worth Hero Card (Quiet Ledger 2a & 2d)
                if (snapshot != null)
                  NetWorthCard(
                    snapshot: snapshot,
                    onAddCash: () => _openAddCashSheet(context),
                    onSyncSms: () => _syncSms(context),
                    onSyncGmail: () => _syncGmail(context),
                  ),
                const SizedBox(height: 16),

                // Edge Case Alert: Payment Declined / Action Required
                if (controller.recentTransactions.any((t) => t.isFailed)) ...[
                  _FailedPaymentAlertBanner(
                    failedTransactions: controller.recentTransactions.where((t) => t.isFailed).toList(),
                    onTapTransaction: (tx) => _openEditSheet(context, tx),
                  ),
                  const SizedBox(height: 16),
                ],

                // Monthly Cash Flow: Received Income vs Total Expenses (Direction 2a)
                MonthlyCashFlowCard(
                  totalMonthlyIncome: controller.totalMonthlyIncome,
                  totalMonthlyExpense: controller.totalMonthlyExpense,
                  onAllocateSavings: () => _openAllocateSavingsSheet(context, controller.netCashFlow),
                ),
                const SizedBox(height: 18),

                // Category Budgets Card
                MonthlyBudgetsCard(
                  budgets: controller.budgetProgressList,
                ),
                const SizedBox(height: 18),

                // Category Expense Breakdown Chart ("Where it went")
                CategoryBreakdownChart(
                  categoryExpenses: controller.categoryExpenses,
                  totalMonthlyExpense: controller.totalMonthlyExpense,
                ),
                const SizedBox(height: 18),

                // Recent Transactions List ("Latest")
                RecentTransactionsList(
                  transactions: controller.recentTransactions,
                  onViewAll: onNavigateToTransactions,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openAddCashSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (context) => const AddCashTransactionSheet(),
    ).then((_) {
      Provider.of<DashboardController>(context, listen: false).loadDashboardData();
      Provider.of<TransactionController>(context, listen: false).loadTransactions();
    });
  }

  void _openAllocateSavingsSheet(BuildContext context, double netSavings) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (context) => AllocateSavingsSheet(netSavings: netSavings),
    ).then((_) {
      Provider.of<DashboardController>(context, listen: false).loadDashboardData();
      Provider.of<TransactionController>(context, listen: false).loadTransactions();
    });
  }

  Future<void> _syncSms(BuildContext context) async {
    final settings = Provider.of<SettingsController>(context, listen: false);
    final dashboard = Provider.of<DashboardController>(context, listen: false);
    final txController = Provider.of<TransactionController>(context, listen: false);
    final scaffold = ScaffoldMessenger.of(context);

    scaffold.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Scanning bank SMS messages from inbox...'),
          ],
        ),
        duration: Duration(seconds: 4),
      ),
    );

    final result = await settings.syncSmsInbox();

    if (result.status == SmsSyncStatus.permissionDenied) {
      scaffold.showSnackBar(
        SnackBar(
          content: const Text('SMS permission denied. Tap to open Settings to allow SMS access.'),
          backgroundColor: AppColors.ruby,
          action: SnackBarAction(
            label: 'Settings',
            textColor: Colors.white,
            onPressed: () => settings.openSmsAppSettings(),
          ),
        ),
      );
    } else if (result.status == SmsSyncStatus.error) {
      scaffold.showSnackBar(
        SnackBar(
          content: Text('SMS sync notice: ${result.errorMessage}'),
          backgroundColor: AppColors.ruby,
        ),
      );
    } else {
      scaffold.showSnackBar(
        SnackBar(
          content: Text(
            result.importedCount > 0
                ? 'Successfully imported ${result.importedCount} new bank transactions from SMS!'
                : 'All bank SMS messages are already up to date (0 new found).',
          ),
          backgroundColor: AppColors.emerald,
        ),
      );
      await dashboard.loadDashboardData();
      await txController.loadTransactions();
    }
  }

  Future<void> _syncGmail(BuildContext context) async {
    final settings = Provider.of<SettingsController>(context, listen: false);
    final dashboard = Provider.of<DashboardController>(context, listen: false);
    final scaffold = ScaffoldMessenger.of(context);

    try {
      scaffold.showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Connecting to Google / Gmail...'),
            ],
          ),
          duration: Duration(seconds: 4),
        ),
      );

      if (!settings.gmailService.isSignedIn) {
        await settings.gmailService.signIn();
      }

      final count = await settings.gmailService.scanRecentEmails();
      scaffold.showSnackBar(
        SnackBar(
          content: Text('Successfully imported $count new transactions from Gmail!'),
          backgroundColor: AppColors.emerald,
        ),
      );

      await dashboard.loadDashboardData();
    } catch (e) {
      scaffold.showSnackBar(
        SnackBar(
          content: Text(
            'Google Connection Notice: $e\nTip: Use offline "Sync SMS" which requires no Google Cloud configuration!',
          ),
          backgroundColor: AppColors.surfaceElevated,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  void _openEditSheet(BuildContext context, TransactionModel tx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (ctx) => EditTransactionSheet(transaction: tx),
    ).then((_) {
      Provider.of<DashboardController>(context, listen: false).loadDashboardData();
      Provider.of<TransactionController>(context, listen: false).loadTransactions();
    });
  }
}

class _FailedPaymentAlertBanner extends StatelessWidget {
  final List<TransactionModel> failedTransactions;
  final Function(TransactionModel) onTapTransaction;

  const _FailedPaymentAlertBanner({
    required this.failedTransactions,
    required this.onTapTransaction,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final latest = failedTransactions.first;
    final count = failedTransactions.length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.ruby.withOpacity(colors.isDark ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.ruby.withOpacity(0.35)),
      ),
      child: InkWell(
        onTap: () => onTapTransaction(latest),
        borderRadius: BorderRadius.circular(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.ruby.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.warning_amber_rounded, color: colors.ruby, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        count > 1 ? '$count Payments Declined' : 'Payment Declined by Bank',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: colors.ruby,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Details',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: colors.royalBlue,
                        ),
                      ),
                      Icon(Icons.chevron_right, size: 14, color: colors.royalBlue),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${latest.merchant}: ${IndianCurrencyFormatter.format(latest.amount)} was declined${latest.failureReason != null ? ' (${latest.failureReason})' : ''}. Balance was protected.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: colors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                  if (latest.supportRecourse != null && latest.supportRecourse!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.shield_outlined, size: 12, color: colors.amber),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            latest.supportRecourse!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: colors.amber,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


