import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../services/net_worth/net_worth_calculator.dart';
import 'account_balances_sheet.dart';

class NetWorthCard extends StatelessWidget {
  final NetWorthSnapshot snapshot;
  final VoidCallback onAddCash;
  final VoidCallback onSyncSms;
  final VoidCallback onSyncGmail;

  const NetWorthCard({
    super.key,
    required this.snapshot,
    required this.onAddCash,
    required this.onSyncSms,
    required this.onSyncGmail,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final netWorth = snapshot.netWorth;
    final isPositive = netWorth >= 0;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border, width: 1),
        boxShadow: colors.isDark
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Clean Micro-label & Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: isPositive ? colors.emerald : colors.ruby,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'NET WORTH',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: isPositive
                      ? colors.emerald.withOpacity(0.12)
                      : colors.ruby.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive ? Icons.trending_up : Icons.trending_down,
                      size: 13,
                      color: isPositive ? colors.emerald : colors.ruby,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isPositive ? 'HEALTHY' : 'DEFICIT',
                      style: TextStyle(
                        color: isPositive ? colors.emerald : colors.ruby,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Main Net Worth Display in INR (Hero Typography)
          InkWell(
            onTap: () {
              AppHaptics.light();
              AccountBalancesSheet.show(context);
            },
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        IndianCurrencyFormatter.format(netWorth),
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.tune, size: 16, color: colors.textMuted),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Liquid Bank + Assets − Debts • Tap to inspect accounts',
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Three Metric Mini-Pillars (Clean Dividing Lines, Direction 2a)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: colors.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.borderSubtle),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _MetricPillar(
                    title: 'Bank',
                    amount: snapshot.liquidBalances,
                    color: colors.liquid,
                    icon: Icons.account_balance,
                    onTap: () {
                      AppHaptics.light();
                      AccountBalancesSheet.show(context);
                    },
                  ),
                ),
                Container(height: 32, width: 1, color: colors.border),
                Expanded(
                  child: _MetricPillar(
                    title: 'Assets',
                    amount: snapshot.totalAssets,
                    color: colors.asset,
                    icon: Icons.pie_chart_outline,
                  ),
                ),
                Container(height: 32, width: 1, color: colors.border),
                Expanded(
                  child: _MetricPillar(
                    title: 'Debts',
                    amount: snapshot.totalDebts,
                    color: colors.debt,
                    icon: Icons.credit_score,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Quick Actions Row
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: onSyncSms,
                  icon: const Icon(Icons.sync, size: 16),
                  label: const Text('Sync SMS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.emerald,
                    foregroundColor: colors.isDark ? Colors.black : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: onAddCash,
                  icon: Icon(Icons.add, size: 15, color: colors.textPrimary),
                  label: Text(
                    'Cash',
                    style: TextStyle(fontSize: 12, color: colors.textPrimary, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: colors.border),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: onSyncGmail,
                  icon: Icon(Icons.mail_outline, size: 15, color: colors.royalBlue),
                  label: Text(
                    'Gmail',
                    style: TextStyle(fontSize: 12, color: colors.textPrimary, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: colors.border),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


class _MetricPillar extends StatelessWidget {
  final String title;
  final double amount;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  const _MetricPillar({
    required this.title,
    required this.amount,
    required this.color,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colors.textMuted,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            IndianCurrencyFormatter.formatCompact(amount),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: content,
      );
    }
    return content;
  }
}
