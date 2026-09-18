import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../services/parsing/category_finder.dart';
import '../../../controllers/category_controller.dart';
import '../../../controllers/transaction_controller.dart';

class AddCashTransactionSheet extends StatefulWidget {
  const AddCashTransactionSheet({super.key});

  @override
  State<AddCashTransactionSheet> createState() => _AddCashTransactionSheetState();
}

class _AddCashTransactionSheetState extends State<AddCashTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _merchantController = TextEditingController();

  String _type = 'EXPENSE';
  String _category = 'Food';
  int? _selectedAccountId;
  DateTime _selectedDate = DateTime.now();

  String? _autoDetectedCategory;
  bool _userManuallySelectedCategory = false;

  @override
  void initState() {
    super.initState();
    _merchantController.addListener(_onMerchantChanged);
  }

  void _onMerchantChanged() {
    final query = _merchantController.text.trim();
    final detected = CategoryFinder.suggestCategory(query);
    if (detected != null && detected != _autoDetectedCategory) {
      setState(() {
        _autoDetectedCategory = detected;
        if (!_userManuallySelectedCategory) {
          _category = detected;
          AppHaptics.selection();
        }
      });
    } else if (detected == null && _autoDetectedCategory != null) {
      setState(() {
        _autoDetectedCategory = null;
      });
    }
  }

  @override
  void dispose() {
    _merchantController.removeListener(_onMerchantChanged);
    _amountController.dispose();
    _merchantController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txController = Provider.of<TransactionController>(context);
    final catController = Provider.of<CategoryController>(context);
    final accounts = txController.accounts;

    final availableCategories = catController.categories.contains(_category)
        ? catController.categories
        : [...catController.categories, _category];

    if (_selectedAccountId == null && accounts.isNotEmpty) {
      // Default to CASH account if available
      final cashAcc = accounts.firstWhere(
        (a) => a.isCash,
        orElse: () => accounts.first,
      );
      _selectedAccountId = cashAcc.id;
    }

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
              // Sheet Handle
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

              const Text(
                'Log Cash / Manual Transaction',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // Segmented Type Selector (Expense vs Income)
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        AppHaptics.selection();
                        setState(() => _type = 'EXPENSE');
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _type == 'EXPENSE'
                              ? AppColors.expense.withOpacity(0.2)
                              : AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _type == 'EXPENSE'
                                ? AppColors.expense
                                : const Color(0xFF334155),
                            width: _type == 'EXPENSE' ? 1.5 : 1.0,
                          ),
                        ),
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOutCubic,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: _type == 'EXPENSE'
                                  ? AppColors.expense
                                  : AppColors.textSecondary,
                            ),
                            child: const Text('EXPENSE'),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        AppHaptics.selection();
                        setState(() => _type = 'INCOME');
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _type == 'INCOME'
                              ? AppColors.income.withOpacity(0.2)
                              : AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _type == 'INCOME'
                                ? AppColors.income
                                : const Color(0xFF334155),
                            width: _type == 'INCOME' ? 1.5 : 1.0,
                          ),
                        ),
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOutCubic,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: _type == 'INCOME'
                                  ? AppColors.income
                                  : AppColors.textSecondary,
                            ),
                            child: const Text('INCOME'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Amount Input
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  prefixStyle: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.emerald,
                  ),
                  labelText: 'Amount',
                  hintText: '0.00',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter amount';
                  final num = double.tryParse(val.replaceAll(',', '').trim());
                  if (num == null || num <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Merchant / Description
              TextFormField(
                controller: _merchantController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Merchant / Note',
                  hintText: 'e.g. biteandbrew, zudio, cab, grocery',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter merchant or note';
                  return null;
                },
              ),
              if (_autoDetectedCategory != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, size: 13, color: AppColors.primary),
                    const SizedBox(width: 5),
                    Text(
                      'Auto-detected: $_autoDetectedCategory',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),

              // Category Picker
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                dropdownColor: AppColors.surfaceElevated,
                items: availableCategories.map((c) {
                  return DropdownMenuItem(
                    value: c,
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.categoryColors[c] ?? AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(c),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _category = val;
                      _userManuallySelectedCategory = true;
                    });
                  }
                },
              ),
              const SizedBox(height: 14),

              // Account Picker
              if (accounts.isNotEmpty)
                DropdownButtonFormField<int>(
                  value: _selectedAccountId,
                  decoration: const InputDecoration(labelText: 'Deduct From Account'),
                  dropdownColor: AppColors.surfaceElevated,
                  items: accounts.map((a) {
                    return DropdownMenuItem<int>(
                      value: a.id,
                      child: Text('${a.name} (${a.type})'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedAccountId = val);
                  },
                ),
              const SizedBox(height: 20),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    AppHaptics.medium();
                    if (_formKey.currentState?.validate() ?? false) {
                      final amount = double.parse(_amountController.text.replaceAll(',', '').trim());
                      final merchant = _merchantController.text.trim();
                      final accountId = _selectedAccountId ?? accounts.first.id ?? 1;

                      await txController.addCashTransaction(
                        amount: amount,
                        type: _type,
                        category: _category,
                        merchant: merchant,
                        accountId: accountId,
                        date: _selectedDate,
                      );

                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    }
                  },
                  child: const Text('Record Transaction'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
