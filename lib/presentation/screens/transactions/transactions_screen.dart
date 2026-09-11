import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../controllers/dashboard_controller.dart';
import '../../controllers/transaction_controller.dart';
import '../../widgets/engine_badge.dart';
import 'widgets/add_cash_transaction_sheet.dart';
import 'widgets/edit_transaction_sheet.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _searchController = TextEditingController();

  final List<String> _categories = [
    'ALL',
    'Food',
    'Groceries',
    'Travel',
    'Shopping',
    'Bills',
    'Entertainment',
    'Health',
    'Salary',
    'Transfer',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TransactionController>(context, listen: false).loadTransactions();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionController>(
      builder: (context, controller, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('All Transactions'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => controller.loadTransactions(),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: AppColors.emerald,
            foregroundColor: Colors.black,
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: AppColors.surface,
                builder: (context) => const AddCashTransactionSheet(),
              ).then((_) {
                controller.loadTransactions();
                Provider.of<DashboardController>(context, listen: false).loadDashboardData();
              });
            },
            child: const Icon(Icons.add),
          ),
          body: Column(
            children: [
              // Search Input
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search merchant, note, or raw SMS...',
                    prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textMuted),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              controller.setSearchQuery('');
                            },
                          )
                        : null,
                  ),
                  onChanged: (val) => controller.setSearchQuery(val),
                ),
              ),

              // Month Filter Horizontal List
              SizedBox(
                height: 38,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  children: [
                    ChoiceChip(
                      label: const Text('All Time', style: TextStyle(fontSize: 11)),
                      selected: controller.selectedMonth == null,
                      selectedColor: AppColors.emerald,
                      backgroundColor: AppColors.surfaceElevated,
                      labelStyle: TextStyle(
                        color: controller.selectedMonth == null ? Colors.black : AppColors.textSecondary,
                        fontWeight: controller.selectedMonth == null ? FontWeight.w700 : FontWeight.w500,
                      ),
                      onSelected: (_) => controller.setMonthFilter(null),
                    ),
                    const SizedBox(width: 6),
                    ...controller.availableMonths.map((m) {
                      final isSelected = controller.selectedMonth != null &&
                          controller.selectedMonth!.year == m.year &&
                          controller.selectedMonth!.month == m.month;
                      final label = DateFormatter.formatMonthYear(m);

                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(label, style: const TextStyle(fontSize: 11)),
                          selected: isSelected,
                          selectedColor: AppColors.emerald,
                          backgroundColor: AppColors.surfaceElevated,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.black : AppColors.textSecondary,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                          onSelected: (_) => controller.setMonthFilter(m),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 4),

              // Filter Chips Row (Type: All, Expense, Income)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    _buildTypeChip('ALL', controller.selectedType == null, () {
                      controller.setTypeFilter('ALL');
                    }),
                    const SizedBox(width: 8),
                    _buildTypeChip('EXPENSES', controller.selectedType == 'EXPENSE', () {
                      controller.setTypeFilter('EXPENSE');
                    }),
                    const SizedBox(width: 8),
                    _buildTypeChip('INCOME', controller.selectedType == 'INCOME', () {
                      controller.setTypeFilter('INCOME');
                    }),
                  ],
                ),
              ),

              // Category Filter Horizontal List
              SizedBox(
                height: 44,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = (cat == 'ALL' && controller.selectedCategory == null) ||
                        (controller.selectedCategory == cat);

                    return ChoiceChip(
                      label: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? Colors.black : AppColors.textSecondary,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.emerald,
                      backgroundColor: AppColors.surfaceElevated,
                      onSelected: (_) => controller.setCategoryFilter(cat),
                    );
                  },
                ),
              ),

              // Transaction List View
              Expanded(
                child: controller.isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.emerald))
                    : controller.transactions.isEmpty
                        ? const Center(
                            child: Text(
                              'No matching transactions found.',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                            itemCount: controller.transactions.length,
                            separatorBuilder: (_, __) =>
                                const Divider(color: Color(0xFF1E293B), height: 1),
                            itemBuilder: (context, index) {
                              final tx = controller.transactions[index];
                              final isIncome = tx.isIncome;
                              final catColor =
                                  AppColors.categoryColors[tx.category] ?? AppColors.textMuted;

                              return Dismissible(
                                key: ValueKey(tx.id),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  color: AppColors.ruby,
                                  child: const Icon(Icons.delete, color: Colors.white),
                                ),
                                onDismissed: (_) {
                                  controller.deleteTransaction(tx.id!);
                                  Provider.of<DashboardController>(context, listen: false)
                                      .loadDashboardData();
                                },
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 4),
                                  onTap: () => _openEditSheet(context, tx),
                                  leading: Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: catColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      _getCategoryIcon(tx.category),
                                      color: catColor,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    tx.merchant,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Text(
                                            DateFormatter.formatShort(
                                                DateFormatter.parse(tx.date)),
                                            style: const TextStyle(
                                                fontSize: 11, color: AppColors.textMuted),
                                          ),
                                          const SizedBox(width: 5),
                                          const Text('•',
                                              style: TextStyle(
                                                  color: AppColors.textMuted, fontSize: 10)),
                                          const SizedBox(width: 5),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: catColor.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              tx.category,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: catColor,
                                              ),
                                            ),
                                          ),
                                          if (tx.paymentSource != null && tx.paymentSource!.isNotEmpty) ...[
                                            const SizedBox(width: 5),
                                            const Text('•',
                                                style: TextStyle(
                                                    color: AppColors.textMuted, fontSize: 10)),
                                            const SizedBox(width: 5),
                                            Flexible(
                                              child: Text(
                                                '${tx.paymentSource!.toLowerCase().contains('card') ? '💳 ' : (tx.paymentSource!.toLowerCase().contains('cash') ? '💵 ' : '🏦 ')}${tx.paymentSource}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.textSecondary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${isIncome ? '+' : '-'}${IndianCurrencyFormatter.format(tx.amount)}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: isIncome
                                              ? AppColors.income
                                              : AppColors.expense,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.edit_outlined, size: 14, color: AppColors.textMuted),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTypeChip(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.emerald.withOpacity(0.2) : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.emerald : const Color(0xFF334155),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isSelected ? AppColors.emerald : AppColors.textMuted,
          ),
        ),
      ),
    );
  }

  static IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Food':
        return Icons.restaurant;
      case 'Groceries':
        return Icons.shopping_basket;
      case 'Travel':
        return Icons.directions_car;
      case 'Shopping':
        return Icons.shopping_bag;
      case 'Bills':
        return Icons.receipt_long;
      case 'Entertainment':
        return Icons.movie;
      case 'Health':
        return Icons.medical_services;
      case 'Salary':
        return Icons.payments;
      case 'Transfer':
        return Icons.swap_horiz;
      default:
        return Icons.account_balance_wallet;
    }
  }

  void _openEditSheet(BuildContext context, dynamic tx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (context) => EditTransactionSheet(transaction: tx),
    ).then((_) {
      Provider.of<DashboardController>(context, listen: false).loadDashboardData();
    });
  }
}
