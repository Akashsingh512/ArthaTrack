import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../data/models/balance_sheet_item_model.dart';
import '../../../controllers/balance_sheet_controller.dart';
import '../../../controllers/dashboard_controller.dart';

class AddEditDebtSheet extends StatefulWidget {
  final BalanceSheetItemModel? existingDebt;

  const AddEditDebtSheet({super.key, this.existingDebt});

  @override
  State<AddEditDebtSheet> createState() => _AddEditDebtSheetState();
}

class _AddEditDebtSheetState extends State<AddEditDebtSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  late TextEditingController _rateController;

  String _category = 'Personal Loan';

  final List<String> _categories = [
    'Home Loan',
    'Auto Loan',
    'Personal Loan',
    'Education Loan',
    'Credit Card Dues',
    'Business Loan',
    'Family & Friends',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    final debt = widget.existingDebt;
    _nameController = TextEditingController(text: debt?.name ?? '');
    _amountController = TextEditingController(
      text: debt != null ? debt.amount.toStringAsFixed(2) : '',
    );
    _rateController = TextEditingController(
      text: debt != null ? debt.interestRate.toString() : '0.0',
    );
    if (debt != null && _categories.contains(debt.category)) {
      _category = debt.category;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingDebt != null;
    final controller = Provider.of<BalanceSheetController>(context, listen: false);

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
              Text(
                isEditing ? 'Edit Liability / Debt' : 'Add Liability / Debt',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // Debt Name
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Liability Name',
                  hintText: 'e.g. SBI Home Loan, HDFC Car Loan',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter liability name';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Debt Category
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Debt Category'),
                dropdownColor: AppColors.surfaceElevated,
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _category = val);
                },
              ),
              const SizedBox(height: 14),

              // Outstanding Amount
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  prefixText: '₹ ',
                  prefixStyle: TextStyle(fontWeight: FontWeight.w700, color: AppColors.debt),
                  labelText: 'Outstanding Balance',
                  hintText: '0.00',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter balance';
                  final n = double.tryParse(val.replaceAll(',', '').trim());
                  if (n == null || n < 0) return 'Enter valid balance';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Annual Interest Rate %
              TextFormField(
                controller: _rateController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  suffixText: '% p.a.',
                  labelText: 'Annual Interest Rate % (Optional)',
                  hintText: '8.5',
                ),
              ),
              const SizedBox(height: 20),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.debt),
                  onPressed: () async {
                    AppHaptics.medium();
                    if (_formKey.currentState?.validate() ?? false) {
                      final name = _nameController.text.trim();
                      final amount = double.parse(_amountController.text.replaceAll(',', '').trim());
                      final rate = double.tryParse(_rateController.text.trim()) ?? 0.0;

                      if (isEditing) {
                        await controller.updateDebt(
                          widget.existingDebt!.copyWith(
                            name: name,
                            amount: amount,
                            category: _category,
                            interestRate: rate,
                          ),
                        );
                      } else {
                        await controller.addDebt(
                          name: name,
                          amount: amount,
                          category: _category,
                          interestRate: rate,
                        );
                      }

                      if (context.mounted) {
                        Provider.of<DashboardController>(context, listen: false).loadDashboardData();
                        Navigator.pop(context);
                      }
                    }
                  },
                  child: Text(
                    isEditing ? 'Update Debt' : 'Save Debt',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
