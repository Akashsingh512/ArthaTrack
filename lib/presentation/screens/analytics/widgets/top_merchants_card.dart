import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../controllers/analytics_controller.dart';

class TopMerchantsCard extends StatelessWidget {
  final List<MerchantSpendSummary> topMerchants;

  const TopMerchantsCard({
    super.key,
    required this.topMerchants,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (topMerchants.isEmpty) {
      return const SizedBox.shrink();
    }

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
                  color: colors.amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(Icons.storefront_rounded, color: colors.amber, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'Top Spending Destinations',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Where your money went most frequently this period.',
            style: TextStyle(fontSize: 12, color: colors.textMuted),
          ),
          const SizedBox(height: 16),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: topMerchants.length,
            separatorBuilder: (_, __) => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1),
            ),
            itemBuilder: (context, index) {
              final item = topMerchants[index];
              final catColor = AppColors.categoryColors[item.category] ?? colors.textMuted;
              final isTop3 = index < 3;

              return Row(
                children: [
                  // Rank badge
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isTop3 ? colors.primary.withOpacity(0.15) : colors.surfaceElevated,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isTop3 ? colors.primary.withOpacity(0.4) : colors.border,
                      ),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isTop3 ? colors.primary : colors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Merchant Name and Category Chip
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.merchant,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: catColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.category,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: catColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${item.transactionCount} txn${item.transactionCount == 1 ? "" : "s"}',
                              style: TextStyle(fontSize: 11, color: colors.textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Amount and Percentage
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        IndianCurrencyFormatter.format(item.totalAmount),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        '${item.percentageOfTotal.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
