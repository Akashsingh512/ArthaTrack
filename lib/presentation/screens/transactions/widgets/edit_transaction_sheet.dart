import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/account_model.dart';
import '../../../../data/models/transaction_model.dart';
import '../../../../data/repositories/account_repository.dart';
import '../../../controllers/dashboard_controller.dart';
import '../../../controllers/transaction_controller.dart';

class EditTransactionSheet extends StatefulWidget {
  final TransactionModel transaction;

  const EditTransactionSheet({
    super.key,
    required this.transaction,
  });

  @override
  State<EditTransactionSheet> createState() => _EditTransactionSheetState();
}

class _EditTransactionSheetState extends State<EditTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _merchantController;
  late TextEditingController _newAccountController;

  late String _category;
  int? _selectedAccountId;
  bool _isCustomAccount = false;
  bool _showRawText = false;

  final List<String> _categories = [
    'Food',
    'Groceries',
    'Travel',
    'Shopping',
    'Bills',
    'Entertainment',
    'Health',
    'Investment',
    'Salary',
    'Transfer',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _merchantController = TextEditingController(text: widget.transaction.merchant);
    _newAccountController = TextEditingController();
    _category = widget.transaction.category;
    _selectedAccountId = widget.transaction.accountId;
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _newAccountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txController = Provider.of<TransactionController>(context);
    final accounts = txController.accounts;

    // Ensure selected account is valid
    if (_selectedAccountId != null &&
        !_isCustomAccount &&
        !accounts.any((a) => a.id == _selectedAccountId)) {
      _selectedAccountId = accounts.isNotEmpty ? accounts.first.id : null;
    }

    final isIncome = widget.transaction.isIncome;
    final sign = isIncome ? '+' : '-';
    final amountColor = isIncome ? AppColors.income : AppColors.expense;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Modal Handle
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

              // Title and Type Pill
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Edit Transaction',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: amountColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.transaction.type,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: amountColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Read-Only Transaction Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$sign${IndianCurrencyFormatter.format(widget.transaction.amount)}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: amountColor,
                          ),
                        ),
                        Text(
                          DateFormatter.formatShort(DateFormatter.parse(widget.transaction.date)),
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    if (widget.transaction.referenceNumber != null &&
                        widget.transaction.referenceNumber!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Ref / UPI ID: ${widget.transaction.referenceNumber}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Field 1: Where they paid / Shop or Person Name
              const Text(
                'Where did you pay? (Shop / Recipient Name)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _merchantController,
                decoration: const InputDecoration(
                  hintText: 'e.g. Swiggy, Sharma Kirana, Nikhil, Amazon',
                  prefixIcon: Icon(Icons.storefront_outlined, size: 20),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a shop or person name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Field 2: Category Selector
              const Text(
                'Category',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = _category == cat;
                    final catColor = AppColors.categoryColors[cat] ?? AppColors.textMuted;

                    return ChoiceChip(
                      label: Text(cat, style: const TextStyle(fontSize: 12)),
                      selected: isSelected,
                      selectedColor: catColor.withOpacity(0.25),
                      backgroundColor: AppColors.surfaceElevated,
                      side: BorderSide(
                        color: isSelected ? catColor : const Color(0xFF334155),
                      ),
                      labelStyle: TextStyle(
                        color: isSelected ? catColor : AppColors.textSecondary,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                      onSelected: (_) => setState(() => _category = cat),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Field 3: Payment Source / Bank Account
              const Text(
                'Payment Source (Bank Account / Card)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),

              if (!_isCustomAccount) ...[
                DropdownButtonFormField<int>(
                  value: _selectedAccountId,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.account_balance_outlined, size: 20),
                  ),
                  dropdownColor: AppColors.surfaceElevated,
                  items: [
                    ...accounts.map((acc) {
                      final isCard = acc.isCreditCard;
                      final isCash = acc.isCash;
                      final icon = isCard
                          ? '💳 '
                          : isCash
                              ? '💵 '
                              : '🏦 ';
                      return DropdownMenuItem<int>(
                        value: acc.id,
                        child: Text(
                          '$icon${acc.name}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }),
                    const DropdownMenuItem<int>(
                      value: -1,
                      child: Text(
                        '➕ Add New Bank / Card...',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.emerald,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    if (val == -1) {
                      setState(() {
                        _isCustomAccount = true;
                      });
                    } else if (val != null) {
                      setState(() {
                        _selectedAccountId = val;
                      });
                    }
                  },
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _newAccountController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'e.g. SBI Card, Kotak Bank, Axis Bank',
                          prefixIcon: Icon(Icons.add_card, size: 20),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Enter bank or card name';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textMuted),
                      tooltip: 'Back to existing accounts',
                      onPressed: () {
                        setState(() {
                          _isCustomAccount = false;
                        });
                      },
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),

              // Raw SMS Cross-Check Toggle
              InkWell(
                onTap: () => setState(() => _showRawText = !_showRawText),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        _showRawText ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _showRawText ? 'Hide Original Notification' : 'View Original Notification / SMS',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),

              if (_showRawText && widget.transaction.rawText.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: SelectableText(
                    widget.transaction.rawText,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 22),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => _saveChanges(context),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveChanges(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    final txController = Provider.of<TransactionController>(context, listen: false);
    final dashboardController = Provider.of<DashboardController>(context, listen: false);
    final accountRepo = AccountRepository();

    int targetAccountId = widget.transaction.accountId;
    String? targetPaymentSource = widget.transaction.paymentSource;

    if (_isCustomAccount) {
      final customName = _newAccountController.text.trim();
      final newAcc = await accountRepo.getOrCreateAccountByName(customName);
      targetAccountId = newAcc.id ?? targetAccountId;
      targetPaymentSource = customName;
    } else if (_selectedAccountId != null) {
      targetAccountId = _selectedAccountId!;
      final matchedAcc = txController.accounts.firstWhere(
        (a) => a.id == targetAccountId,
        orElse: () => AccountModel(id: targetAccountId, name: 'Primary Bank', type: 'SAVINGS', balance: 0),
      );
      targetPaymentSource = matchedAcc.name;
    }

    final updatedTx = widget.transaction.copyWith(
      merchant: _merchantController.text.trim(),
      category: _category,
      accountId: targetAccountId,
      paymentSource: targetPaymentSource,
    );

    await txController.updateTransaction(
      updatedTx,
      previousAccountId: widget.transaction.accountId,
    );

    await dashboardController.loadDashboardData();

    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Updated "${updatedTx.merchant}" • ${updatedTx.category} successfully!'),
          backgroundColor: AppColors.emerald,
        ),
      );
    }
  }
}
