import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../data/models/budget_model.dart';
import '../../../controllers/category_controller.dart';
import '../../../controllers/dashboard_controller.dart';

class SetBudgetSheet extends StatefulWidget {
  final BudgetModel? existingBudget;
  final String? initialCategory;

  const SetBudgetSheet({
    super.key,
    this.existingBudget,
    this.initialCategory,
  });

  @override
  State<SetBudgetSheet> createState() => _SetBudgetSheetState();
}

class _SetBudgetSheetState extends State<SetBudgetSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late String _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.existingBudget?.category ??
        widget.initialCategory ??
        'Food';
    _amountController = TextEditingController(
      text: widget.existingBudget != null
          ? widget.existingBudget!.monthlyLimit.toStringAsFixed(0)
          : '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _saveBudget() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    final controller = context.read<DashboardController>();
    await controller.setBudget(_selectedCategory, amount);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surface,
          content: Text(
            'Budget for $_selectedCategory set to ${CurrencyFormatter.formatINR(amount)}/mo',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }
  }

  Future<void> _deleteBudget() async {
    if (widget.existingBudget == null) return;

    final controller = context.read<DashboardController>();
    await controller.deleteBudget(widget.existingBudget!.category);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surface,
          content: Text(
            'Budget for ${widget.existingBudget!.category} deleted',
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingBudget != null;
    final catController = Provider.of<CategoryController>(context);
    final availableCategories = catController.categories
        .where((c) => c != 'Salary' && c != 'Transfer')
        .toList();
    if (!availableCategories.contains(_selectedCategory)) {
      availableCategories.add(_selectedCategory);
    }

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing ? 'Edit Category Budget' : 'Set Category Budget',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (isEditing)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.expenseRed, size: 22),
                      onPressed: _deleteBudget,
                      tooltip: 'Delete Budget',
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Set a monthly limit for this category. As you spend, your progress updates in real-time.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 20),

              // Category Selector
              const Text(
                'CATEGORY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white54,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCategory,
                    isExpanded: true,
                    dropdownColor: AppColors.surface,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    items: availableCategories.map((cat) {
                      return DropdownMenuItem<String>(
                        value: cat,
                        child: Row(
                          children: [
                            Icon(_getCategoryIcon(cat), size: 18, color: Colors.white70),
                            const SizedBox(width: 10),
                            Text(cat),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: isEditing
                        ? null // Lock category when editing existing budget
                        : (val) {
                            if (val != null) setState(() => _selectedCategory = val);
                          },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Monthly Limit Input
              const Text(
                'MONTHLY LIMIT (₹)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white54,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  prefixStyle: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  hintText: 'e.g. 5000',
                  hintStyle: const TextStyle(color: Colors.white24, fontSize: 16),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter monthly budget';
                  }
                  final parsed = double.tryParse(val.trim());
                  if (parsed == null || parsed <= 0) {
                    return 'Please enter a valid positive number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _saveBudget,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isEditing ? 'Update Budget' : 'Save Budget',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Icons.restaurant;
      case 'groceries':
        return Icons.shopping_cart_outlined;
      case 'travel':
        return Icons.directions_car_outlined;
      case 'shopping':
        return Icons.shopping_bag_outlined;
      case 'bills':
        return Icons.receipt_long_outlined;
      case 'entertainment':
        return Icons.movie_outlined;
      case 'health':
        return Icons.medical_services_outlined;
      case 'investment':
        return Icons.trending_up;
      default:
        return Icons.category_outlined;
    }
  }
}
