import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/account_model.dart';
import '../../../../data/models/transaction_model.dart';
import '../../../../data/repositories/account_repository.dart';
import '../../../../data/repositories/transaction_repository.dart';
import '../../../controllers/dashboard_controller.dart';
import '../../../controllers/transaction_controller.dart';

class CardDisambiguationSheet extends StatefulWidget {
  final AccountModel ambiguousAccount;
  final List<AccountModel> candidateCards;

  const CardDisambiguationSheet({
    super.key,
    required this.ambiguousAccount,
    required this.candidateCards,
  });

  static Future<void> show(
    BuildContext context, {
    required AccountModel ambiguousAccount,
    required List<AccountModel> candidateCards,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => CardDisambiguationSheet(
        ambiguousAccount: ambiguousAccount,
        candidateCards: candidateCards,
      ),
    );
  }

  @override
  State<CardDisambiguationSheet> createState() => _CardDisambiguationSheetState();
}

class _CardDisambiguationSheetState extends State<CardDisambiguationSheet> {
  final TransactionRepository _transactionRepo = TransactionRepository();
  final AccountRepository _accountRepo = AccountRepository();

  List<TransactionModel> _transactions = [];
  bool _isLoading = true;
  int? _selectedCandidateId;

  @override
  void initState() {
    super.initState();
    if (widget.candidateCards.isNotEmpty) {
      _selectedCandidateId = widget.candidateCards.first.id;
    }
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final allTx = await _transactionRepo.getAllTransactions();
    final filtered = allTx.where((t) => t.accountId == widget.ambiguousAccount.id).toList();
    setState(() {
      _transactions = filtered;
      _isLoading = false;
    });
  }

  Future<void> _mergeAllIntoCandidate(BuildContext context, int targetAccountId) async {
    final sourceId = widget.ambiguousAccount.id;
    if (sourceId == null) return;

    await _accountRepo.mergeAccounts(sourceId, targetAccountId);

    if (context.mounted) {
      Provider.of<DashboardController>(context, listen: false).loadDashboardData();
      Provider.of<TransactionController>(context, listen: false).loadTransactions();
      Navigator.of(context).pop();

      final targetCard = widget.candidateCards.firstWhere((c) => c.id == targetAccountId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully merged all transactions into ${targetCard.name}!'),
          backgroundColor: AppColors.emerald,
        ),
      );
    }
  }

  Future<void> _reassignSingleTransaction(BuildContext context, TransactionModel tx, int targetAccountId) async {
    final updated = tx.copyWith(accountId: targetAccountId);
    await _transactionRepo.updateTransaction(updated);

    await _loadTransactions();
    if (_transactions.isEmpty && context.mounted) {
      Provider.of<DashboardController>(context, listen: false).loadDashboardData();
      Provider.of<TransactionController>(context, listen: false).loadTransactions();
      Navigator.of(context).pop();
    }
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
      child: _isLoading
          ? const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator(color: AppColors.emerald)),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
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
                  const SizedBox(height: 16),

                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.amber.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.credit_card, color: AppColors.amber, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Assign "${widget.ambiguousAccount.name}"',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_transactions.length} transaction${_transactions.length == 1 ? '' : 's'} need card verification',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF26334D)),
                    ),
                    child: const Text(
                      'Some bank SMS messages omit the card ending digits. Choose which of your specific cards these transactions belong to.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 1-Tap Merge Option
                  const Text(
                    'Quick Merge All Transactions Into:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  ...widget.candidateCards.map((candidate) {
                    final isSelected = candidate.id == _selectedCandidateId;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () {
                          setState(() => _selectedCandidateId = candidate.id);
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.emerald.withOpacity(0.15)
                                : AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? AppColors.emerald : const Color(0xFF26334D),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                color: isSelected ? AppColors.emerald : AppColors.textMuted,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  candidate.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? AppColors.emerald : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  minimumSize: Size.zero,
                                  backgroundColor: isSelected ? AppColors.emerald : const Color(0xFF26334D),
                                ),
                                onPressed: () => _mergeAllIntoCandidate(context, candidate.id!),
                                child: const Text(
                                  'Merge All',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFF26334D)),
                  const SizedBox(height: 12),

                  // Individual Transactions List
                  const Text(
                    'Or Review Individual Transactions:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (_transactions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          'No transactions remaining to assign.',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    ..._transactions.map((tx) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF26334D)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tx.merchant,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '₹${tx.amount.toStringAsFixed(2)} • ${tx.formattedDate}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<int>(
                              icon: const Icon(Icons.swap_horiz, color: AppColors.emerald, size: 20),
                              tooltip: 'Assign to card',
                              onSelected: (targetId) => _reassignSingleTransaction(context, tx, targetId),
                              itemBuilder: (context) {
                                return widget.candidateCards.map((c) {
                                  return PopupMenuItem<int>(
                                    value: c.id,
                                    child: Text(c.name, style: const TextStyle(fontSize: 13)),
                                  );
                                }).toList();
                              },
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
