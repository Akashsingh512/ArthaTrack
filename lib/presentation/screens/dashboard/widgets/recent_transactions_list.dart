import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/transaction_model.dart';
import '../../../widgets/engine_badge.dart';

class RecentTransactionsList extends StatelessWidget {
  final List<TransactionModel> transactions;
  final VoidCallback onViewAll;

  const RecentTransactionsList({
    super.key,
    required this.transactions,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF26334D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Transactions',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              TextButton(
                onPressed: onViewAll,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.royalBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (transactions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No transactions recorded yet.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: transactions.length,
              separatorBuilder: (_, __) => const Divider(color: Color(0xFF1E293B), height: 16),
              itemBuilder: (context, index) {
                final tx = transactions[index];
                final isIncome = tx.isIncome;
                final catColor = AppColors.categoryColors[tx.category] ?? AppColors.textMuted;

                return InkWell(
                  onTap: () => _showTransactionDetailModal(context, tx),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        // Category Avatar Icon
                        Container(
                          width: 40,
                          height: 40,
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
                        const SizedBox(width: 12),

                        // Merchant & Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tx.merchant,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    DateFormatter.getRelativeTime(
                                      DateFormatter.parse(tx.date),
                                    ),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text('•', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                                  const SizedBox(width: 6),
                                  EngineBadge(engine: tx.engine, compact: true),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Amount
                        Text(
                          '${isIncome ? '+' : '-'}${IndianCurrencyFormatter.format(tx.amount)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isIncome ? AppColors.income : AppColors.expense,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
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
      case 'Investment':
        return Icons.trending_up;
      case 'Salary':
        return Icons.payments;
      case 'Transfer':
        return Icons.swap_horiz;
      default:
        return Icons.account_balance_wallet;
    }
  }

  void _showTransactionDetailModal(BuildContext context, TransactionModel tx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF334155),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    tx.merchant,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  EngineBadge(engine: tx.engine),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${tx.isIncome ? '+' : '-'}${IndianCurrencyFormatter.format(tx.amount)}',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: tx.isIncome ? AppColors.income : AppColors.expense,
                ),
              ),
              const SizedBox(height: 16),
              _DetailRow(label: 'Category', value: tx.category),
              _DetailRow(label: 'Date & Time', value: DateFormatter.formatWithTime(DateFormatter.parse(tx.date))),
              _DetailRow(label: 'Source', value: tx.source),
              _DetailRow(label: 'Parsing Engine', value: tx.engine == 'AI' ? 'BYOK AI Key Engine' : 'Offline Indian Banking Regex'),
              const SizedBox(height: 16),
              const Text(
                'Raw Intercepted Text',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: SelectableText(
                  tx.rawText,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
