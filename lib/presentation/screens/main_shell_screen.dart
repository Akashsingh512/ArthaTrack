import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../services/ingestion/notification_listener_channel.dart';
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

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentIndex = 0;
  final _notificationChannel = NotificationListenerChannel();

  @override
  void initState() {
    super.initState();

    // Start background listening to the Android native NotificationListenerService EventChannel
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

    // Initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DashboardController>(context, listen: false).loadDashboardData();
      Provider.of<TransactionController>(context, listen: false).loadTransactions();
      Provider.of<BalanceSheetController>(context, listen: false).loadBalanceSheet();
      Provider.of<SettingsController>(context, listen: false).loadSettings();
    });
  }

  @override
  void dispose() {
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
