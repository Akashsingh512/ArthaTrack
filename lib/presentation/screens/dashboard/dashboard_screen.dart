import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../services/ingestion/sms_sync_service.dart';
import '../../controllers/dashboard_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../controllers/transaction_controller.dart';
import '../settings/widgets/raw_sms_test_sandbox.dart';
import '../transactions/widgets/add_cash_transaction_sheet.dart';
import 'widgets/category_breakdown_chart.dart';
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
    return Consumer<DashboardController>(
      builder: (context, controller, child) {
        if (controller.isLoading && controller.netWorth == null) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.emerald),
          );
        }

        final snapshot = controller.netWorth;

        return RefreshIndicator(
          color: AppColors.emerald,
          backgroundColor: AppColors.surfaceElevated,
          onRefresh: () => controller.loadDashboardData(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top App Bar Greeting
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ArthaTrack',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: AppColors.textPrimary,
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
                                    ? AppColors.aiEngine
                                    : AppColors.regexEngine,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined, color: AppColors.textPrimary),
                      onPressed: onNavigateToSettings,
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Net Worth Hero Card
                if (snapshot != null)
                  NetWorthCard(
                    snapshot: snapshot,
                    onAddCash: () => _openAddCashSheet(context),
                    onSyncSms: () => _syncSms(context),
                    onSyncGmail: () => _syncGmail(context),
                    onTestSandbox: () => _openTestSandbox(context),
                  ),
                const SizedBox(height: 20),

                // Category Expense Breakdown Chart
                CategoryBreakdownChart(
                  categoryExpenses: controller.categoryExpenses,
                  totalMonthlyExpense: controller.totalMonthlyExpense,
                ),
                const SizedBox(height: 20),

                // Recent Transactions List
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

  void _openTestSandbox(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (context) => const RawSmsTestSandbox(),
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
}
