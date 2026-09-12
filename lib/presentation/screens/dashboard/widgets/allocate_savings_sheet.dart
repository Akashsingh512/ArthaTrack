import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../data/models/account_model.dart';
import '../../../../data/models/balance_sheet_item_model.dart';
import '../../../../data/repositories/account_repository.dart';
import '../../../../data/repositories/balance_sheet_repository.dart';
import '../../../controllers/dashboard_controller.dart';

class AllocateSavingsSheet extends StatefulWidget {
  final double netSavings;

  const AllocateSavingsSheet({
    super.key,
    required this.netSavings,
  });

  @override
  State<AllocateSavingsSheet> createState() => _AllocateSavingsSheetState();
}

class _AllocateSavingsSheetState extends State<AllocateSavingsSheet> {
  int _selectedOption = 2; // 1 = Keep in Bank, 2 = Move to Asset/Goal
  late double _allocatedAmount;
  late TextEditingController _amountController;
  late TextEditingController _customGoalController;

  String _selectedGoalPreset = 'Emergency Fund';
  String _selectedGoalCategory = 'Emergency Fund';
  int? _selectedAccountId;
  List<AccountModel> _savingsAccounts = [];
  List<BalanceSheetItemModel> _existingAssets = [];
  bool _isLoading = true;

  final List<Map<String, dynamic>> _goalPresets = [
    {'name': 'Emergency Fund', 'category': 'Emergency Fund', 'icon': Icons.shield_outlined},
    {'name': 'Fixed Deposit (FD)', 'category': 'Bank Deposit', 'icon': Icons.account_balance_outlined},
    {'name': 'Mutual Funds / SIP', 'category': 'Investment', 'icon': Icons.trending_up},
    {'name': 'Gold / Silver', 'category': 'Precious Metals', 'icon': Icons.monetization_on_outlined},
    {'name': 'Custom Goal', 'category': 'Savings Goal', 'icon': Icons.flag_outlined},
  ];

  @override
  void initState() {
    super.initState();
    _allocatedAmount = widget.netSavings > 0 ? widget.netSavings : 0.0;
    _amountController = TextEditingController(text: _allocatedAmount.toStringAsFixed(0));
    _customGoalController = TextEditingController(text: 'Emergency Fund');
    _loadAccountsAndAssets();
  }

  Future<void> _loadAccountsAndAssets() async {
    final accountRepo = AccountRepository();
    final balanceSheetRepo = BalanceSheetRepository();

    final allAccounts = await accountRepo.getAllAccounts();
    final assets = await balanceSheetRepo.getAssets();

    setState(() {
      _savingsAccounts = allAccounts.where((a) => a.isSavings || a.isCash).toList();
      if (_savingsAccounts.isNotEmpty) {
        _selectedAccountId = _savingsAccounts.first.id;
      }
      _existingAssets = assets;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _customGoalController.dispose();
    super.dispose();
  }

  void _setPercentage(double percent) {
    final newAmount = (widget.netSavings * percent).clamp(0.0, widget.netSavings);
    setState(() {
      _allocatedAmount = newAmount;
      _amountController.text = newAmount.toStringAsFixed(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final remainingInBank = (widget.netSavings - _allocatedAmount).clamp(0.0, widget.netSavings);

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
                  // Handle
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

                  // Header with celebration
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.emerald.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.savings_outlined, color: AppColors.emerald, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Allocate Monthly Savings',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'You saved ${IndianCurrencyFormatter.format(widget.netSavings)} this month!',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.emerald,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Choose Option Segmented Selector
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF26334D)),
                    ),
                    child: Row(
                      children: [
                        // Option 1: Keep in Liquid Bank
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedOption = 1),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _selectedOption == 1
                                    ? AppColors.surfaceCard
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: _selectedOption == 1
                                    ? Border.all(color: AppColors.emerald.withOpacity(0.5))
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  'Keep in Bank',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _selectedOption == 1
                                        ? AppColors.emerald
                                        : AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Option 2: Move to Asset / Goal
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedOption = 2),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _selectedOption == 2
                                    ? AppColors.surfaceCard
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: _selectedOption == 2
                                    ? Border.all(color: AppColors.emerald.withOpacity(0.5))
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  'Move to Asset / Goal',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _selectedOption == 2
                                        ? AppColors.emerald
                                        : AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Option 1 Details
                  if (_selectedOption == 1) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF26334D)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.check_circle_outline, color: AppColors.emerald, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Keep Full Surplus Liquid',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'The entire ${IndianCurrencyFormatter.format(widget.netSavings)} will remain untouched in your primary liquid bank account for day-to-day liquidity and upcoming expenses.',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Option 2 Details: Move to Asset / Savings Goal
                  if (_selectedOption == 2) ...[
                    const Text(
                      'Select Savings Goal / Asset Destination',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Goal Presets Chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _goalPresets.map((preset) {
                        final isSelected = _selectedGoalPreset == preset['name'];
                        return ChoiceChip(
                          avatar: Icon(
                            preset['icon'] as IconData,
                            size: 14,
                            color: isSelected ? AppColors.emerald : AppColors.textSecondary,
                          ),
                          label: Text(preset['name'] as String),
                          selected: isSelected,
                          selectedColor: AppColors.emerald.withOpacity(0.2),
                          backgroundColor: AppColors.surfaceElevated,
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? AppColors.emerald : AppColors.textSecondary,
                          ),
                          side: BorderSide(
                            color: isSelected ? AppColors.emerald : const Color(0xFF26334D),
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedGoalPreset = preset['name']!;
                                _selectedGoalCategory = preset['category']!;
                                if (preset['name'] != 'Custom Goal') {
                                  _customGoalController.text = preset['name']!;
                                } else {
                                  _customGoalController.text = '';
                                }
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),

                    if (_selectedGoalPreset == 'Custom Goal') ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _customGoalController,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Goal / Asset Name (e.g. Vacation Fund, Laptop)',
                          prefixIcon: Icon(Icons.flag_outlined, color: AppColors.emerald, size: 18),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Amount to Allocate
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Amount to Allocate',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          'Max: ${IndianCurrencyFormatter.format(widget.netSavings)}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.emerald,
                      ),
                      decoration: const InputDecoration(
                        prefixText: '₹ ',
                        prefixStyle: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.emerald,
                        ),
                        hintText: 'Enter amount',
                      ),
                      onChanged: (val) {
                        final parsed = double.tryParse(val) ?? 0.0;
                        setState(() {
                          _allocatedAmount = parsed.clamp(0.0, widget.netSavings);
                        });
                      },
                    ),
                    const SizedBox(height: 10),

                    // Percentage Quick Presets
                    Row(
                      children: [
                        _buildPresetButton('100%', 1.0),
                        const SizedBox(width: 8),
                        _buildPresetButton('75%', 0.75),
                        const SizedBox(width: 8),
                        _buildPresetButton('50%', 0.50),
                        const SizedBox(width: 8),
                        _buildPresetButton('25%', 0.25),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Deduct from Source Account Dropdown
                    if (_savingsAccounts.isNotEmpty) ...[
                      const Text(
                        'Transfer From Bank Account',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        value: _selectedAccountId,
                        dropdownColor: AppColors.surfaceElevated,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                        items: _savingsAccounts.map((acc) {
                          return DropdownMenuItem<int>(
                            value: acc.id,
                            child: Text(
                              '${acc.name} (${IndianCurrencyFormatter.format(acc.balance)})',
                              style: const TextStyle(color: AppColors.textPrimary),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedAccountId = val),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.account_balance, color: AppColors.emerald, size: 18),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Live Allocation Breakdown Preview
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF26334D)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Lock into ${_customGoalController.text.trim().isNotEmpty ? _customGoalController.text.trim() : "Asset"}:',
                                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                              ),
                              Text(
                                '+${IndianCurrencyFormatter.format(_allocatedAmount)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.emerald,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Remains in Liquid Bank:',
                                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                              ),
                              Text(
                                IndianCurrencyFormatter.format(remainingInBank),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ],
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
                          onPressed: () => _confirmAllocation(context),
                          icon: const Icon(Icons.check, size: 18),
                          label: Text(
                            _selectedOption == 1 ? 'Keep in Bank' : 'Confirm & Allocate',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPresetButton(String label, double percent) {
    final isSelected = (_allocatedAmount == (widget.netSavings * percent));
    return Expanded(
      child: GestureDetector(
        onTap: () => _setPercentage(percent),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.emerald.withOpacity(0.2) : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.emerald : const Color(0xFF26334D),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isSelected ? AppColors.emerald : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmAllocation(BuildContext context) async {
    final dashboardController = Provider.of<DashboardController>(context, listen: false);

    if (_selectedOption == 1) {
      // Keep full surplus in designated bank account
      await dashboardController.confirmKeepInSavingsAccount(
        amount: widget.netSavings,
        targetAccountId: _selectedAccountId,
      );
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Confirmed! ${IndianCurrencyFormatter.format(widget.netSavings)} saved to your liquid bank account.',
            ),
            backgroundColor: AppColors.emerald,
          ),
        );
      }
      return;
    }

    // Option 2: Move to Asset / Goal
    final goalName = _customGoalController.text.trim().isEmpty
        ? _selectedGoalPreset
        : _customGoalController.text.trim();

    if (_allocatedAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an amount greater than 0.'),
          backgroundColor: AppColors.ruby,
        ),
      );
      return;
    }

    await dashboardController.allocateMonthlySavings(
      amount: _allocatedAmount,
      assetName: goalName,
      assetCategory: _selectedGoalCategory,
      sourceAccountId: _selectedAccountId,
      deductFromBank: false,
    );

    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Successfully allocated ${IndianCurrencyFormatter.format(_allocatedAmount)} to "$goalName"!',
          ),
          backgroundColor: AppColors.emerald,
        ),
      );
    }
  }
}
