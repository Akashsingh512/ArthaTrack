import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/account_model.dart';
import '../../../../data/repositories/account_repository.dart';
import '../../controllers/category_controller.dart';
import '../../controllers/dashboard_controller.dart';
import '../../controllers/transaction_controller.dart';
import '../../widgets/engine_badge.dart';
import 'widgets/add_cash_transaction_sheet.dart';
import 'widgets/card_disambiguation_sheet.dart';
import 'widgets/edit_transaction_sheet.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _searchController = TextEditingController();
  List<AccountModel> _ambiguousAccounts = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TransactionController>(context, listen: false).loadTransactions();
      _checkAmbiguousCards();
    });
  }

  Future<void> _checkAmbiguousCards() async {
    final ambiguous = await AccountRepository().getAmbiguousCardAccounts();
    if (mounted) {
      setState(() {
        _ambiguousAccounts = ambiguous;
      });
    }
  }

  void _openCardDisambiguation(AccountModel ambiguous) async {
    final all = await AccountRepository().getAllAccounts();
    final lower = ambiguous.name.toLowerCase();
    final bankKeyword = lower.contains('axis')
        ? 'axis'
        : (lower.contains('sbi') ? 'sbi' : (lower.contains('hdfc') ? 'hdfc' : 'icici'));
    final candidates = all
        .where((a) => a.isCreditCard && a.name.toLowerCase().contains(bankKeyword) && RegExp(r'\d{3,4}').hasMatch(a.name))
        .toList();

    if (mounted && candidates.isNotEmpty) {
      await CardDisambiguationSheet.show(
        context,
        ambiguousAccount: ambiguous,
        candidateCards: candidates,
      );
      _checkAmbiguousCards();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catController = Provider.of<CategoryController>(context);
    final filterCategories = ['ALL', ...catController.categories];

    final colors = context.colors;

    return Consumer<TransactionController>(
      builder: (context, controller, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Transactions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: colors.textPrimary,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.refresh, color: colors.textPrimary),
                onPressed: () => controller.loadTransactions(),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: colors.emerald,
            foregroundColor: colors.isDark ? Colors.black : Colors.white,
            elevation: 2,
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: colors.surface,
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
                    prefixIcon: Icon(Icons.search, size: 20, color: colors.textMuted),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, size: 18, color: colors.textMuted),
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

              // Ambiguous Card Resolution Banner
              if (_ambiguousAccounts.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: InkWell(
                    onTap: () => _openCardDisambiguation(_ambiguousAccounts.first),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: colors.amber.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.amber.withOpacity(0.35)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: colors.amber, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Card Review: "${_ambiguousAccounts.first.name}"',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Tap to assign transactions to your specific card (e.g. ending in 7876 or 323)',
                                  style: TextStyle(fontSize: 11, color: colors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: colors.amber, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),

              // Filtered Totals Quick Bar (Received vs Spent)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.arrow_downward, size: 13, color: colors.income),
                        const SizedBox(width: 3),
                        Text(
                          'Received: +${IndianCurrencyFormatter.format(controller.filteredIncome)}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: colors.income,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.arrow_upward, size: 13, color: colors.expense),
                        const SizedBox(width: 3),
                        Text(
                          'Spent: -${IndianCurrencyFormatter.format(controller.filteredExpense)}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: colors.expense,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),

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
                      selectedColor: colors.emerald,
                      backgroundColor: colors.surfaceElevated,
                      labelStyle: TextStyle(
                        color: controller.selectedMonth == null
                            ? (colors.isDark ? Colors.black : Colors.white)
                            : colors.textSecondary,
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
                          selectedColor: colors.emerald,
                          backgroundColor: colors.surfaceElevated,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? (colors.isDark ? Colors.black : Colors.white)
                                : colors.textSecondary,
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
                    if (controller.hasFailedTransactions) ...[
                      const Spacer(),
                      _buildDeclinedBadgeChip(
                        controller.failedCount,
                        controller.selectedType == 'FAILED',
                        () {
                          if (controller.selectedType == 'FAILED') {
                            controller.setTypeFilter('ALL');
                          } else {
                            controller.setTypeFilter('FAILED');
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),

              // Category Filter Horizontal List
              SizedBox(
                height: 44,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  scrollDirection: Axis.horizontal,
                  itemCount: filterCategories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final cat = filterCategories[index];
                    final isSelected = (cat == 'ALL' && controller.selectedCategory == null) ||
                        (controller.selectedCategory == cat);

                    return ChoiceChip(
                      label: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? (colors.isDark ? Colors.black : Colors.white) : colors.textSecondary,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: colors.emerald,
                      backgroundColor: colors.surfaceElevated,
                      onSelected: (_) => controller.setCategoryFilter(cat),
                    );
                  },
                ),
              ),

              // Transaction List View
              Expanded(
                child: controller.isLoading
                    ? Center(child: CircularProgressIndicator(color: colors.emerald))
                    : controller.transactions.isEmpty
                        ? Center(
                            child: Text(
                              'No matching transactions found.',
                              style: TextStyle(color: colors.textMuted),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                            itemCount: controller.transactions.length,
                            separatorBuilder: (_, __) =>
                                Divider(color: colors.borderSubtle, height: 1),
                            itemBuilder: (context, index) {
                              final tx = controller.transactions[index];
                              final isIncome = tx.isIncome;
                              final catColor =
                                  AppColors.categoryColors[tx.category] ?? colors.textMuted;

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
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: colors.textPrimary,
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
                                            style: TextStyle(
                                                fontSize: 11, color: colors.textMuted),
                                          ),
                                          const SizedBox(width: 5),
                                          Text('•',
                                              style: TextStyle(
                                                  color: colors.textMuted, fontSize: 10)),
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
                                           if (tx.displayPaymentSource.isNotEmpty) ...[
                                             const SizedBox(width: 5),
                                             Text('•',
                                                 style: TextStyle(
                                                     color: colors.textMuted, fontSize: 10)),
                                             const SizedBox(width: 5),
                                             Flexible(
                                               child: Text(
                                                 tx.displayPaymentSource,
                                                 maxLines: 1,
                                                 overflow: TextOverflow.ellipsis,
                                                 style: TextStyle(
                                                   fontSize: 10,
                                                   fontWeight: FontWeight.w600,
                                                   color: colors.textSecondary,
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
                                       Column(
                                         crossAxisAlignment: CrossAxisAlignment.end,
                                         mainAxisAlignment: MainAxisAlignment.center,
                                         children: [
                                           Text(
                                             tx.isFailed
                                                 ? IndianCurrencyFormatter.format(tx.amount)
                                                 : '${isIncome ? '+' : '-'}${IndianCurrencyFormatter.format(tx.amount)}',
                                             style: TextStyle(
                                               fontSize: 14,
                                               fontWeight: FontWeight.w700,
                                               decoration: tx.isFailed ? TextDecoration.lineThrough : null,
                                               color: tx.isFailed
                                                   ? colors.ruby
                                                   : (tx.isPendingHold
                                                       ? colors.amber
                                                       : (isIncome
                                                           ? colors.income
                                                           : colors.expense)),
                                             ),
                                           ),
                                           if (tx.isFailed || tx.isRefund || tx.isPendingHold) ...[
                                             const SizedBox(height: 2),
                                             Container(
                                               padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                               decoration: BoxDecoration(
                                                 color: tx.isFailed
                                                     ? AppColors.ruby.withOpacity(0.15)
                                                     : (tx.isPendingHold
                                                         ? const Color(0xFFF59E0B).withOpacity(0.15)
                                                         : AppColors.emerald.withOpacity(0.15)),
                                                 borderRadius: BorderRadius.circular(4),
                                               ),
                                               child: Text(
                                                 tx.isFailed
                                                     ? 'DECLINED'
                                                     : (tx.isPendingHold ? 'ON HOLD' : 'REFUND'),
                                                 style: TextStyle(
                                                   fontSize: 8.5,
                                                   fontWeight: FontWeight.w800,
                                                   letterSpacing: 0.3,
                                                   color: tx.isFailed
                                                       ? AppColors.ruby
                                                       : (tx.isPendingHold
                                                           ? const Color(0xFFF59E0B)
                                                           : AppColors.emerald),
                                                 ),
                                               ),
                                             ),
                                           ],
                                         ],
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
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.emerald.withOpacity(colors.isDark ? 0.2 : 0.12)
              : colors.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? colors.emerald : colors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isSelected ? colors.emerald : colors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildDeclinedBadgeChip(int count, bool isSelected, VoidCallback onTap) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.ruby.withOpacity(colors.isDark ? 0.25 : 0.15)
              : colors.ruby.withOpacity(colors.isDark ? 0.12 : 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? colors.ruby : colors.ruby.withOpacity(0.35),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, size: 13, color: colors.ruby),
            const SizedBox(width: 4),
            Text(
              'Declined ($count)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: colors.ruby,
              ),
            ),
          ],
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
