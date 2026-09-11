import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../data/models/account_model.dart';
import '../../../../data/repositories/account_repository.dart';
import '../../../controllers/balance_sheet_controller.dart';
import '../../../controllers/dashboard_controller.dart';

class AccountBalancesSheet extends StatefulWidget {
  const AccountBalancesSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const AccountBalancesSheet(),
    );
  }

  @override
  State<AccountBalancesSheet> createState() => _AccountBalancesSheetState();
}

class _AccountBalancesSheetState extends State<AccountBalancesSheet> {
  final _accountRepo = AccountRepository();
  List<AccountModel> _accounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final accs = await _accountRepo.getAllAccounts();
    if (mounted) {
      setState(() {
        _accounts = accs;
        _isLoading = false;
      });
    }
  }

  void _showEditBalanceDialog(AccountModel acc) {
    final balCtrl = TextEditingController(
      text: acc.balance == 0.0 ? '' : acc.balance.toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Text(
          'Set Balance for ${acc.name}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              acc.isCreditCard
                  ? 'Enter outstanding card dues (e.g. 1500)'
                  : 'Enter current available bank balance (e.g. 50000)',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: balCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Balance / Amount',
                prefixText: '₹ ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newBal = double.tryParse(balCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
              final targetBal = acc.isCreditCard && newBal > 0 ? -newBal : newBal;
              await _accountRepo.updateBalance(acc.id!, targetBal);
              if (mounted) {
                Provider.of<DashboardController>(context, listen: false).loadDashboardData();
                Provider.of<BalanceSheetController>(context, listen: false).loadBalanceSheet();
                Navigator.pop(ctx);
                _loadAccounts();
              }
            },
            child: const Text('Save Balance'),
          ),
        ],
      ),
    );
  }

  void _showMergeDialog(AccountModel sourceAcc) {
    final lower = sourceAcc.name.toLowerCase();
    final bankKeyword = lower.contains('axis')
        ? 'axis'
        : (lower.contains('sbi')
            ? 'sbi'
            : (lower.contains('hdfc')
                ? 'hdfc'
                : (lower.contains('icici') ? 'icici' : 'kotak')));
    final candidates = _accounts
        .where((a) => a.id != sourceAcc.id && a.isCreditCard && a.name.toLowerCase().contains(bankKeyword))
        .toList();

    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No numbered cards found for ${sourceAcc.name} to merge into.'),
          backgroundColor: AppColors.surfaceElevated,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Text(
          'Merge "${sourceAcc.name}"',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select which card to merge this account into. All transactions will be moved, and this duplicate account will be deleted.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ...candidates.map((c) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.credit_card, color: AppColors.emerald),
                  title: Text(c.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () async {
                    await _accountRepo.mergeAccounts(sourceAcc.id!, c.id!);
                    if (mounted) {
                      Provider.of<DashboardController>(context, listen: false).loadDashboardData();
                      Provider.of<BalanceSheetController>(context, listen: false).loadBalanceSheet();
                      Navigator.pop(ctx);
                      _loadAccounts();
                    }
                  },
                )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF334155),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Accounts & Balances',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Tap any account to set or update its current balance',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: AppColors.emerald))
          else if (_accounts.isEmpty)
            const Center(
              child: Text('No accounts found.', style: TextStyle(color: AppColors.textMuted)),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _accounts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final acc = _accounts[index];
                final isCard = acc.isCreditCard;
                final isCash = acc.isCash;
                final icon = isCard
                    ? Icons.credit_card
                    : (isCash ? Icons.money : Icons.account_balance);
                final color = isCard ? AppColors.ruby : AppColors.liquid;

                return InkWell(
                  onTap: () => _showEditBalanceDialog(acc),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(icon, color: color, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                acc.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isCard
                                    ? 'Credit Card'
                                    : (isCash ? 'Cash in Hand' : 'Savings Account'),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              IndianCurrencyFormatter.format(acc.balance.abs()),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: acc.balance < 0 ? AppColors.ruby : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Row(
                              children: [
                                Text(
                                  'Set Balance',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.emerald,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: 2),
                                Icon(Icons.edit, size: 10, color: AppColors.emerald),
                              ],
                            ),
                            if (isCard && !RegExp(r'\d{3,4}').hasMatch(acc.name)) ...[
                              const SizedBox(height: 4),
                              InkWell(
                                onTap: () => _showMergeDialog(acc),
                                child: const Row(
                                  children: [
                                    Text(
                                      'Merge Card',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.amber,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(width: 2),
                                    Icon(Icons.merge_type, size: 10, color: AppColors.amber),
                                  ],
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
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
