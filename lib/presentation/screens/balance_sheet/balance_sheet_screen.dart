import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../controllers/balance_sheet_controller.dart';
import '../../controllers/dashboard_controller.dart';
import 'widgets/add_edit_asset_sheet.dart';
import 'widgets/add_edit_debt_sheet.dart';

class BalanceSheetScreen extends StatefulWidget {
  const BalanceSheetScreen({super.key});

  @override
  State<BalanceSheetScreen> createState() => _BalanceSheetScreenState();
}

class _BalanceSheetScreenState extends State<BalanceSheetScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BalanceSheetController>(context, listen: false).loadBalanceSheet();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BalanceSheetController>(
      builder: (context, controller, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Balance Sheet & Wealth'),
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: AppColors.emerald,
              labelColor: AppColors.emerald,
              unselectedLabelColor: AppColors.textMuted,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Accounts'),
                Tab(text: 'Assets'),
                Tab(text: 'Debts'),
              ],
            ),
          ),
          body: controller.isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.emerald))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(context, controller),
                    _buildAccountsTab(context, controller),
                    _buildAssetsTab(context, controller),
                    _buildDebtsTab(context, controller),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildOverviewTab(BuildContext context, BalanceSheetController controller) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Net Worth Headline Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'NET FINANCIAL WORTH',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  IndianCurrencyFormatter.format(controller.netWorth),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Total Assets + Bank Balances − Total Liabilities',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Liquid Bank Balances Card
          _SummaryCard(
            title: 'Liquid Bank & Cash',
            subtitle: '${controller.accounts.length} linked accounts',
            amount: controller.totalLiquid,
            color: AppColors.liquid,
            icon: Icons.account_balance,
            onTap: () => _tabController.animateTo(1),
          ),
          const SizedBox(height: 12),

          // Total Assets Card
          _SummaryCard(
            title: 'Total Assets (Gold, Equity, Property)',
            subtitle: '${controller.assets.length} active investments',
            amount: controller.totalAssets,
            color: AppColors.asset,
            icon: Icons.trending_up,
            onTap: () => _tabController.animateTo(2),
          ),
          const SizedBox(height: 12),

          // Total Debts Card
          _SummaryCard(
            title: 'Total Liabilities & Debts',
            subtitle: '${controller.debts.length} active loans',
            amount: controller.totalDebts,
            color: AppColors.debt,
            icon: Icons.credit_score,
            onTap: () => _tabController.animateTo(3),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountsTab(BuildContext context, BalanceSheetController controller) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.liquid,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('Add Account', style: TextStyle(fontWeight: FontWeight.w700)),
        onPressed: () => _showAddAccountDialog(context, controller),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: controller.accounts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final acc = controller.accounts[index];
          final isCredit = acc.isCreditCard;

          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isCredit ? AppColors.ruby : AppColors.liquid).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isCredit ? Icons.credit_card : (acc.isCash ? Icons.money : Icons.account_balance),
                  color: isCredit ? AppColors.ruby : AppColors.liquid,
                  size: 20,
                ),
              ),
              title: Text(acc.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(acc.type, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              trailing: Text(
                IndianCurrencyFormatter.format(acc.balance),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: acc.balance < 0 ? AppColors.ruby : AppColors.textPrimary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAssetsTab(BuildContext context, BalanceSheetController controller) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.asset,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('Add Asset', style: TextStyle(fontWeight: FontWeight.w700)),
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: AppColors.surface,
            builder: (context) => const AddEditAssetSheet(),
          );
        },
      ),
      body: controller.assets.isEmpty
          ? const Center(child: Text('No assets added yet.', style: TextStyle(color: AppColors.textMuted)))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: controller.assets.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final asset = controller.assets[index];

                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.asset.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.stars, color: AppColors.asset, size: 20),
                    ),
                    title: Text(asset.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${asset.category}${asset.interestRate > 0 ? ' • ${asset.interestRate}% return' : ''}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          IndianCurrencyFormatter.format(asset.amount),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppColors.asset,
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textMuted),
                          color: AppColors.surfaceElevated,
                          onSelected: (val) {
                            if (val == 'edit') {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: AppColors.surface,
                                builder: (context) => AddEditAssetSheet(existingAsset: asset),
                              );
                            } else if (val == 'delete') {
                              controller.deleteAsset(asset.id!);
                              Provider.of<DashboardController>(context, listen: false).loadDashboardData();
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'edit', child: Text('Edit')),
                            const PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildDebtsTab(BuildContext context, BalanceSheetController controller) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.debt,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Liability', style: TextStyle(fontWeight: FontWeight.w700)),
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: AppColors.surface,
            builder: (context) => const AddEditDebtSheet(),
          );
        },
      ),
      body: controller.debts.isEmpty
          ? const Center(child: Text('No liabilities or debts recorded.', style: TextStyle(color: AppColors.textMuted)))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: controller.debts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final debt = controller.debts[index];

                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.debt.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.credit_score, color: AppColors.debt, size: 20),
                    ),
                    title: Text(debt.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${debt.category}${debt.interestRate > 0 ? ' • ${debt.interestRate}% p.a.' : ''}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          IndianCurrencyFormatter.format(debt.amount),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppColors.debt,
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textMuted),
                          color: AppColors.surfaceElevated,
                          onSelected: (val) {
                            if (val == 'edit') {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: AppColors.surface,
                                builder: (context) => AddEditDebtSheet(existingDebt: debt),
                              );
                            } else if (val == 'delete') {
                              controller.deleteDebt(debt.id!);
                              Provider.of<DashboardController>(context, listen: false).loadDashboardData();
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'edit', child: Text('Edit')),
                            const PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showAddAccountDialog(BuildContext context, BalanceSheetController controller) {
    final nameCtrl = TextEditingController();
    final balCtrl = TextEditingController();
    String type = 'SAVINGS';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: const Text('Add Bank Account'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Account Name', hintText: 'e.g. HDFC Salary, ICICI Card'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: type,
                    decoration: const InputDecoration(labelText: 'Account Type'),
                    items: const [
                      DropdownMenuItem(value: 'SAVINGS', child: Text('Savings Bank')),
                      DropdownMenuItem(value: 'CREDIT_CARD', child: Text('Credit Card')),
                      DropdownMenuItem(value: 'CASH', child: Text('Cash Wallet')),
                    ],
                    onChanged: (v) {
                      if (v != null) setStateDialog(() => type = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: balCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Current Balance', prefixText: '₹ '),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isNotEmpty) {
                      final balance = double.tryParse(balCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
                      await controller.addAccount(
                        name: nameCtrl.text.trim(),
                        type: type,
                        balance: balance,
                      );
                      if (context.mounted) {
                        Provider.of<DashboardController>(context, listen: false).loadDashboardData();
                        Navigator.pop(ctx);
                      }
                    }
                  },
                  child: const Text('Add Account'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double amount;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _SummaryCard({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    IndianCurrencyFormatter.format(amount),
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: color),
                  ),
                  const SizedBox(height: 2),
                  const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.textMuted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
