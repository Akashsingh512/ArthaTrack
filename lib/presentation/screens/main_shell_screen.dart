import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../services/ingestion/notification_listener_channel.dart';
import '../../services/ingestion/sms_sync_service.dart';
import '../controllers/balance_sheet_controller.dart';
import '../controllers/dashboard_controller.dart';
import '../controllers/settings_controller.dart';
import '../controllers/transaction_controller.dart';
import 'balance_sheet/balance_sheet_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'settings/settings_screen.dart';
import 'transactions/transactions_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final _notificationChannel = NotificationListenerChannel();
  final _smsSyncService = SmsSyncService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Start background listening to the Android native NotificationListenerService & SmsReceiver EventChannel
    _notificationChannel.startListening(
      onTransactionParsed: (tx) {
        if (mounted) {
          Provider.of<DashboardController>(context, listen: false).loadDashboardData();
          Provider.of<TransactionController>(context, listen: false).loadTransactions();
          Provider.of<BalanceSheetController>(context, listen: false).loadBalanceSheet();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Auto-captured ${tx.type}: ₹${tx.amount.toStringAsFixed(2)} at ${tx.merchant}',
              ),
              backgroundColor: AppColors.emerald,
            ),
          );
        }
      },
    );

    // Initial load & automatic silent detection of any new SMS messages
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DashboardController>(context, listen: false).loadDashboardData();
      Provider.of<TransactionController>(context, listen: false).loadTransactions();
      Provider.of<BalanceSheetController>(context, listen: false).loadBalanceSheet();
      Provider.of<SettingsController>(context, listen: false).loadSettings();

      // Automatically detect and sync recent SMS without user needing to click sync
      _autoDetectAndSyncRecentSms();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Whenever user returns to the app, automatically scan for new messages
      _autoDetectAndSyncRecentSms();
    }
  }

  /// Automatically syncs recent SMS in the background if permission is granted
  Future<void> _autoDetectAndSyncRecentSms() async {
    try {
      final hasPermission = await _smsSyncService.isPermissionGranted();
      if (!hasPermission) return;

      final result = await _smsSyncService.syncInbox(limit: 5000);
      if (result.importedCount > 0 && mounted) {
        Provider.of<DashboardController>(context, listen: false).loadDashboardData();
        Provider.of<TransactionController>(context, listen: false).loadTransactions();
        Provider.of<BalanceSheetController>(context, listen: false).loadBalanceSheet();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Auto-detected ${result.importedCount} new transaction${result.importedCount > 1 ? 's' : ''}',
            ),
            backgroundColor: AppColors.surfaceElevated,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationChannel.dispose();
    super.dispose();
  }

  void _navigateToTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(
        onNavigateToTransactions: () => _navigateToTab(1),
        onNavigateToSettings: () => _navigateToTab(3),
      ),
      const TransactionsScreen(),
      const BalanceSheetScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: screens,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFF1E293B), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.emerald,
          unselectedItemColor: AppColors.textMuted,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long),
              label: 'Transactions',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_outlined),
              activeIcon: Icon(Icons.account_balance),
              label: 'Balance Sheet',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.tune_outlined),
              activeIcon: Icon(Icons.tune),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
