import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../services/net_worth/net_worth_calculator.dart';

class NetWorthCard extends StatelessWidget {
  final NetWorthSnapshot snapshot;
  final VoidCallback onAddCash;
  final VoidCallback onSyncGmail;
  final VoidCallback onTestSandbox;

  const NetWorthCard({
    super.key,
    required this.snapshot,
    required this.onAddCash,
    required this.onSyncGmail,
    required this.onTestSandbox,
  });

  @override
  Widget build(BuildContext context) {
    final netWorth = snapshot.netWorth;
    final isPositive = netWorth >= 0;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E293B),
            Color(0xFF0F172A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF334155), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.emerald.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet,
                      color: AppColors.emerald,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'TOTAL NET WORTH',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isPositive
                      ? AppColors.emerald.withOpacity(0.15)
                      : AppColors.ruby.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isPositive ? 'HEALTHY' : 'DEFICIT',
                  style: TextStyle(
                    color: isPositive ? AppColors.emerald : AppColors.ruby,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Main Net Worth Display in INR
          Text(
            IndianCurrencyFormatter.format(netWorth),
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '(Liquid Bank Balances + Total Assets) − Total Debts',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),

          // Three Metric Pillars
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _MetricPillar(
                    title: 'Liquid Bank',
                    amount: snapshot.liquidBalances,
                    color: AppColors.liquid,
                    icon: Icons.account_balance,
                  ),
                ),
                Container(height: 36, width: 1, color: const Color(0xFF334155)),
                Expanded(
                  child: _MetricPillar(
                    title: 'Total Assets',
                    amount: snapshot.totalAssets,
                    color: AppColors.asset,
                    icon: Icons.trending_up,
                  ),
                ),
                Container(height: 36, width: 1, color: const Color(0xFF334155)),
                Expanded(
                  child: _MetricPillar(
                    title: 'Total Debts',
                    amount: snapshot.totalDebts,
                    color: AppColors.debt,
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
                child: OutlinedButton.icon(
                  onPressed: onAddCash,
                  icon: const Icon(Icons.add, size: 16, color: AppColors.textPrimary),
                  label: const Text(
                    'Add Cash',
                    style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF334155)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onSyncGmail,
                  icon: const Icon(Icons.mail_outline, size: 16, color: AppColors.royalBlue),
                  label: const Text(
                    'Sync Gmail',
                    style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF334155)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onTestSandbox,
                  icon: const Icon(Icons.science_outlined, size: 16, color: AppColors.aiEngine),
                  label: const Text(
                    'Test SMS',
                    style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF334155)),
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

  const _MetricPillar({
    required this.title,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
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
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
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
  }
}
