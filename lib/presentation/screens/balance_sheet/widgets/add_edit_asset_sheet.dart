import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../data/models/balance_sheet_item_model.dart';
import '../../../controllers/balance_sheet_controller.dart';
import '../../../controllers/dashboard_controller.dart';

class AddEditAssetSheet extends StatefulWidget {
  final BalanceSheetItemModel? existingAsset;

  const AddEditAssetSheet({super.key, this.existingAsset});

  @override
  State<AddEditAssetSheet> createState() => _AddEditAssetSheetState();
}

class _AddEditAssetSheetState extends State<AddEditAssetSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  late TextEditingController _rateController;

  String _category = 'Gold';

  final List<String> _categories = [
    'Gold',
    'Stocks & Equity',
    'Mutual Funds',
    'Real Estate',
    'Fixed Deposit (FD)',
    'Provident Fund (PF/PPF)',
    'Crypto',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    final asset = widget.existingAsset;
    _nameController = TextEditingController(text: asset?.name ?? '');
    _amountController = TextEditingController(
      text: asset != null ? asset.amount.toStringAsFixed(2) : '',
    );
    _rateController = TextEditingController(
      text: asset != null ? asset.interestRate.toString() : '0.0',
    );
    if (asset != null && _categories.contains(asset.category)) {
      _category = asset.category;
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
    final isEditing = widget.existingAsset != null;
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
                isEditing ? 'Edit Asset' : 'Add Physical / Liquid Asset',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // Asset Name
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Asset Name',
                  hintText: 'e.g. Sovereign Gold Bonds, Bengaluru Plot, Nifty Index',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter asset name';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Asset Category
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Asset Category'),
                dropdownColor: AppColors.surfaceElevated,
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _category = val);
                },
              ),
              const SizedBox(height: 14),

              // Current Value / Amount in INR
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  prefixText: '₹ ',
                  prefixStyle: TextStyle(fontWeight: FontWeight.w700, color: AppColors.asset),
                  labelText: 'Current Valuation',
                  hintText: '0.00',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter valuation';
                  final n = double.tryParse(val.replaceAll(',', '').trim());
                  if (n == null || n < 0) return 'Enter valid valuation';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Expected Annual Return / Interest Rate %
              TextFormField(
                controller: _rateController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  suffixText: '% p.a.',
                  labelText: 'Expected Return / Appreciation Rate (Optional)',
                  hintText: '0.0',
                ),
              ),
              const SizedBox(height: 20),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.asset),
                  onPressed: () async {
                    AppHaptics.medium();
                    if (_formKey.currentState?.validate() ?? false) {
                      final name = _nameController.text.trim();
                      final amount = double.parse(_amountController.text.replaceAll(',', '').trim());
                      final rate = double.tryParse(_rateController.text.trim()) ?? 0.0;

                      if (isEditing) {
                        await controller.updateAsset(
                          widget.existingAsset!.copyWith(
                            name: name,
                            amount: amount,
                            category: _category,
                            interestRate: rate,
                          ),
                        );
                      } else {
                        await controller.addAsset(
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
                    isEditing ? 'Update Asset' : 'Save Asset',
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
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
