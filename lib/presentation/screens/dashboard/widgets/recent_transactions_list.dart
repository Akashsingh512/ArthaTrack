import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/transaction_model.dart';
import '../../../controllers/dashboard_controller.dart';
import '../../../widgets/engine_badge.dart';
import '../../transactions/widgets/edit_transaction_sheet.dart';

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
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Latest',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              TextButton(
                onPressed: onViewAll,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.royalBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (transactions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No transactions recorded yet.',
                  style: TextStyle(color: colors.textMuted, fontSize: 13),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: transactions.length,
              separatorBuilder: (_, __) => Divider(color: colors.borderSubtle, height: 16),
              itemBuilder: (context, index) {
                final tx = transactions[index];
                final isIncome = tx.isIncome;
                final catColor = AppColors.categoryColors[tx.category] ?? colors.textMuted;

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
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    DateFormatter.getRelativeTime(
                                      DateFormatter.parse(tx.date),
                                    ),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: colors.textMuted,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text('•', style: TextStyle(color: colors.textMuted, fontSize: 10)),
                                  const SizedBox(width: 5),
                                  Text(
                                    tx.category,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: catColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (tx.displayPaymentSource.isNotEmpty) ...[
                                    const SizedBox(width: 5),
                                    Text('•', style: TextStyle(color: colors.textMuted, fontSize: 10)),
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
                        ),

                        // Amount & Status
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
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
                                        : (isIncome ? colors.income : colors.expense)),
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
              if (tx.status != 'SUCCESS')
                _DetailRow(
                  label: 'Status',
                  value: tx.status,
                  valueColor: tx.isFailed ? AppColors.ruby : const Color(0xFFF59E0B),
                ),
              if (tx.failureReason != null && tx.failureReason!.isNotEmpty)
                _DetailRow(
                  label: 'Decline Reason',
                  value: tx.failureReason!,
                  valueColor: AppColors.ruby,
                ),
              _DetailRow(label: 'Category', value: tx.category),
              _DetailRow(label: 'Payment Source', value: tx.displayPaymentSource),
              _DetailRow(label: 'Date & Time', value: DateFormatter.formatWithTime(DateFormatter.parse(tx.date))),
              if (tx.referenceNumber != null && tx.referenceNumber!.isNotEmpty)
                _DetailRow(label: 'Reference / UPI ID', value: tx.referenceNumber!),
              _DetailRow(label: 'Parsing Engine', value: tx.engine == 'AI' ? 'BYOK AI Key Engine' : 'Offline Indian Banking Regex'),
              if (tx.supportRecourse != null && tx.supportRecourse!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF451A03).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.shield_outlined, color: Color(0xFFF59E0B), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Bank Fraud & Dispute Recourse',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFF59E0B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            SelectableText(
                              tx.supportRecourse!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: AppColors.surface,
                      builder: (ctx) => EditTransactionSheet(transaction: tx),
                    ).then((_) {
                      Provider.of<DashboardController>(context, listen: false).loadDashboardData();
                    });
                  },
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit Transaction Details'),
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
  final Color? valueColor;

  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
