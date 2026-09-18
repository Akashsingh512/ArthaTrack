import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/account_model.dart';
import '../../../../data/models/transaction_model.dart';
import '../../../../data/repositories/account_repository.dart';
import '../../../../data/repositories/category_repository.dart';
import '../../../../services/parsing/category_finder.dart';
import '../../../controllers/category_controller.dart';
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
  late TextEditingController _amountController;
  late TextEditingController _newAccountController;

  late String _category;
  late String _type;
  late DateTime _selectedDate;
  int? _selectedAccountId;
  bool _isCustomAccount = false;
  bool _showRawText = false;
  String? _suggestedCategory;

  @override
  void initState() {
    super.initState();
    _merchantController = TextEditingController(text: widget.transaction.merchant);
    _amountController = TextEditingController(text: widget.transaction.amount.toStringAsFixed(2));
    _newAccountController = TextEditingController();
    _category = widget.transaction.category;
    _type = widget.transaction.type.toUpperCase();
    _selectedAccountId = widget.transaction.accountId;
    _selectedDate = DateTime.tryParse(widget.transaction.date) ?? DateTime.now();

    _merchantController.addListener(_onMerchantChanged);
  }

  void _onMerchantChanged() {
    final query = _merchantController.text.trim();
    final detected = CategoryFinder.suggestCategory(query);
    if (detected != null && detected != _category) {
      if (detected != _suggestedCategory) {
        setState(() => _suggestedCategory = detected);
      }
    } else if (_suggestedCategory != null) {
      setState(() => _suggestedCategory = null);
    }
  }

  @override
  void dispose() {
    _merchantController.removeListener(_onMerchantChanged);
    _merchantController.dispose();
    _amountController.dispose();
    _newAccountController.dispose();
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

    // Ensure selected account is valid
    if (_selectedAccountId != null &&
        !_isCustomAccount &&
        !accounts.any((a) => a.id == _selectedAccountId)) {
      _selectedAccountId = accounts.isNotEmpty ? accounts.first.id : null;
    }

    // If selected account is generic/primary but transaction has a detected bank/card source, match by name
    final detectedSource = widget.transaction.displayPaymentSource;
    if (_selectedAccountId == 1 && detectedSource != 'Primary Bank Account' && !_isCustomAccount) {
      final matching = accounts.where((a) => a.name.toLowerCase() == detectedSource.toLowerCase());
      if (matching.isNotEmpty) {
        _selectedAccountId = matching.first.id;
      }
    }

    final isIncome = _type == 'INCOME';
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

              // Title and Type Toggle (Expense vs Income)
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
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () {
                            AppHaptics.selection();
                            setState(() => _type = 'EXPENSE');
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOutCubic,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _type == 'EXPENSE'
                                  ? AppColors.ruby.withOpacity(0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 240),
                              curve: Curves.easeOutCubic,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _type == 'EXPENSE' ? AppColors.ruby : AppColors.textMuted,
                              ),
                              child: const Text('EXPENSE'),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            AppHaptics.selection();
                            setState(() => _type = 'INCOME');
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOutCubic,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _type == 'INCOME'
                                  ? AppColors.emerald.withOpacity(0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 240),
                              curve: Curves.easeOutCubic,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _type == 'INCOME' ? AppColors.emerald : AppColors.textMuted,
                              ),
                              child: const Text('INCOME'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Editable Amount & Date Row
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
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Amount Field
                        Expanded(
                          child: TextFormField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: amountColor,
                            ),
                            decoration: InputDecoration(
                              prefixText: '₹ ',
                              prefixStyle: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: amountColor,
                              ),
                              labelText: 'Amount',
                              labelStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFF334155)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFF334155)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: amountColor),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Enter amount';
                              final num = double.tryParse(val.trim());
                              if (num == null || num <= 0) return 'Invalid';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Date picker button
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.dark(
                                      primary: AppColors.primary,
                                      surface: AppColors.surfaceElevated,
                                      onSurface: Colors.white,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setState(() {
                                _selectedDate = DateTime(
                                  picked.year,
                                  picked.month,
                                  picked.day,
                                  _selectedDate.hour,
                                  _selectedDate.minute,
                                  _selectedDate.second,
                                );
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF334155)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_month, size: 16, color: AppColors.primary),
                                const SizedBox(width: 6),
                                Text(
                                  DateFormatter.formatShort(_selectedDate),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (widget.transaction.referenceNumber != null &&
                        widget.transaction.referenceNumber!.isNotEmpty) ...[
                      const SizedBox(height: 8),
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
                  hintText: 'e.g. biteandbrew, zudio, Amazon, Swiggy',
                  prefixIcon: Icon(Icons.storefront_outlined, size: 20),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a shop or person name';
                  }
                  return null;
                },
              ),
              if (_suggestedCategory != null) ...[
                const SizedBox(height: 6),
                InkWell(
                  onTap: () {
                    AppHaptics.selection();
                    setState(() {
                      _category = _suggestedCategory!;
                      _suggestedCategory = null;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome, size: 13, color: AppColors.primary),
                        const SizedBox(width: 5),
                        Text(
                          'Suggested: $_suggestedCategory (Tap to apply)',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
                  itemCount: availableCategories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = availableCategories[index];
                    final isSelected = _category == cat;
                    final catColor = AppColors.categoryColors[cat] ?? AppColors.primary;

                    return GestureDetector(
                      onTap: () {
                        AppHaptics.selection();
                        setState(() => _category = cat);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? catColor.withOpacity(0.2) : AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? catColor : const Color(0xFF334155),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: catColor.withOpacity(0.25),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 240),
                              curve: Curves.easeOutCubic,
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: catColor,
                              ),
                            ),
                            const SizedBox(width: 6),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 240),
                              curve: Curves.easeOutCubic,
                              style: TextStyle(
                                fontSize: 12,
                                color: isSelected ? catColor : AppColors.textSecondary,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              ),
                              child: Text(cat),
                            ),
                          ],
                        ),
                      ),
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
                      return DropdownMenuItem<int>(
                        value: acc.id,
                        child: Text(
                          acc.name,
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }),
                    const DropdownMenuItem<int>(
                      value: -1,
                      child: Text(
                        'Add New Bank / Card...',
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

              // 12-digit UPI Ref / RRN Copy Card
              if (widget.transaction.referenceNumber != null && widget.transaction.referenceNumber!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'UPI Ref / RRN Identifier',
                            style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            widget.transaction.referenceNumber!,
                            style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16, color: AppColors.emerald),
                        tooltip: 'Copy UPI Ref No',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: widget.transaction.referenceNumber!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('UPI Ref No copied to clipboard!'), duration: Duration(seconds: 2)),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],

              // RBI Mandated Dispute / Fraud Helpline & Recourse Card
              if (widget.transaction.supportRecourse != null && widget.transaction.supportRecourse!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF450A0A).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF991B1B).withOpacity(0.6)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.shield_outlined, size: 18, color: Color(0xFFF87171)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Dispute Recourse / Fraud Helpline',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFFCA5A5)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.transaction.supportRecourse!,
                              style: const TextStyle(fontSize: 11, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 18),

              // Delete Transaction Option
              Center(
                child: TextButton.icon(
                  onPressed: () => _confirmDelete(context),
                  icon: const Icon(Icons.delete_outline, color: AppColors.ruby, size: 18),
                  label: const Text(
                    'Delete This Transaction',
                    style: TextStyle(
                      color: AppColors.ruby,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

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

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Delete Transaction?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Are you sure you want to delete this transaction? This will automatically reverse its effect on your account balance.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.ruby),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.transaction.id != null) {
      AppHaptics.heavy();
      final txController = Provider.of<TransactionController>(context, listen: false);
      final dashboardController = Provider.of<DashboardController>(context, listen: false);

      await txController.deleteTransaction(widget.transaction.id!);
      await dashboardController.loadDashboardData();

      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction deleted successfully!'),
            backgroundColor: AppColors.emerald,
          ),
        );
      }
    }
  }

  Future<void> _saveChanges(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    AppHaptics.medium();

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
        orElse: () => AccountModel(
          id: targetAccountId,
          name: 'Primary Bank',
          type: 'SAVINGS',
          balance: 0,
          updatedAt: DateTime.now().toIso8601String(),
        ),
      );
      targetPaymentSource = matchedAcc.name;
    }

    final parsedAmount = double.tryParse(_amountController.text.trim()) ?? widget.transaction.amount;

    final updatedTx = widget.transaction.copyWith(
      amount: parsedAmount,
      date: _selectedDate.toIso8601String(),
      merchant: _merchantController.text.trim(),
      category: _category,
      accountId: targetAccountId,
      paymentSource: targetPaymentSource,
      type: _type,
    );

    await txController.updateTransaction(
      updatedTx,
      previousAccountId: widget.transaction.accountId,
      previousType: widget.transaction.type,
    );

    // Save merchant-to-category rule in SQLite memory so future transactions are auto-tagged!
    await CategoryRepository().rememberMerchantCategory(updatedTx.merchant, updatedTx.category);

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
