import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';

class PaymentModeCard extends StatelessWidget {
  final Map<String, double> paymentModeBreakdown;
  final double totalExpense;

  const PaymentModeCard({
    super.key,
    required this.paymentModeBreakdown,
    required this.totalExpense,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final nonZeroEntries = paymentModeBreakdown.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (nonZeroEntries.isEmpty || totalExpense <= 0) {
      return const SizedBox.shrink();
    }

    final modeColors = <String, Color>{
      'UPI': colors.primary,
      'Credit Card': colors.ruby,
      'Debit Card': colors.royalBlue,
      'Net Banking': colors.amber,
      'Cash / Other': const Color(0xFF64748B),
    };

    final modeIcons = <String, IconData>{
      'UPI': Icons.qr_code_2_rounded,
      'Credit Card': Icons.credit_card_rounded,
      'Debit Card': Icons.credit_card_outlined,
      'Net Banking': Icons.account_balance_rounded,
      'Cash / Other': Icons.payments_outlined,
    };

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
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: colors.indigo.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(Icons.account_balance_wallet_rounded, color: colors.indigo, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'Payment Channels',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Multi-segment proportional bar
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              height: 8,
              child: Row(
                children: nonZeroEntries.map((entry) {
                  final ratio = (entry.value / totalExpense).clamp(0.0, 1.0);
                  final color = modeColors[entry.key] ?? colors.textMuted;
                  return Flexible(
                    flex: (ratio * 1000).toInt(),
                    child: Container(color: color),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Breakdown list
          ...nonZeroEntries.map((entry) {
            final percentage = (entry.value / totalExpense) * 100;
            final color = modeColors[entry.key] ?? colors.textMuted;
            final icon = modeIcons[entry.key] ?? Icons.payment;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(icon, size: 14, color: color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      entry.key,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    IndianCurrencyFormatter.format(entry.value),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
