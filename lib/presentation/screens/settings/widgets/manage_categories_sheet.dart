import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../controllers/category_controller.dart';
import '../../../controllers/transaction_controller.dart';
import '../../../../data/database/tables/categories_table.dart';
import '../../../../data/repositories/category_repository.dart';

class ManageCategoriesSheet extends StatefulWidget {
  const ManageCategoriesSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const ManageCategoriesSheet(),
    );
  }

  @override
  State<ManageCategoriesSheet> createState() => _ManageCategoriesSheetState();
}

class _ManageCategoriesSheetState extends State<ManageCategoriesSheet> {
  final _categoryTextController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _categoryTextController.dispose();
    super.dispose();
  }

  Future<void> _addNewCategory(CategoryController catController) async {
    AppHaptics.medium();
    if (!_formKey.currentState!.validate()) return;

    final name = _categoryTextController.text.trim();
    setState(() => _isSubmitting = true);

    final success = await catController.addCategory(name);
    setState(() => _isSubmitting = false);

    if (mounted) {
      if (success) {
        _categoryTextController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Category "$name" added successfully!'),
            backgroundColor: AppColors.emerald,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Category "$name" already exists or is invalid.'),
            backgroundColor: AppColors.ruby,
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    CategoryController catController,
    String categoryName,
  ) async {
    AppHaptics.heavy();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Delete Category?'),
        content: Text(
          'Are you sure you want to delete "$categoryName"? Existing transactions in this category will be moved to "Other".',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.ruby),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await catController.deleteCategory(categoryName);
      if (mounted && success) {
        final txController = Provider.of<TransactionController>(context, listen: false);
        await txController.loadTransactions();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Category "$categoryName" deleted.'),
            backgroundColor: AppColors.emerald,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CategoryController>(
      builder: (context, catController, child) {
        final allCategories = catController.categories;

        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
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
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Row(
                children: [
                  Icon(Icons.category, color: AppColors.primary, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Manage Categories',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Add custom spending categories tailored to your life. Custom categories appear in transaction filters, budgeting, and charts.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 18),

              // Add New Category Input
              Form(
                key: _formKey,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _categoryTextController,
                        textCapitalization: TextCapitalization.words,
                        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'e.g. Fitness, Pets, Books, Rent',
                          hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          filled: true,
                          fillColor: AppColors.surfaceElevated,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF334155)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF334155)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.primary),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Enter a category name';
                          if (val.trim().length > 30) return 'Name is too long';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isSubmitting ? null : () => _addNewCategory(catController),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Add', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'ACTIVE CATEGORIES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 10),

              // Categories List
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: allCategories.map((catName) {
                      final isDefault = CategoryRepository.defaultCategories.any(
                        (d) => d.toLowerCase() == catName.toLowerCase(),
                      );

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDefault ? AppColors.surfaceElevated : AppColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDefault ? const Color(0xFF334155) : AppColors.primary.withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              catName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDefault ? AppColors.textPrimary : AppColors.primary,
                              ),
                            ),
                            if (!isDefault) ...[
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: () => _confirmDelete(context, catController, catName),
                                child: const Icon(Icons.close, size: 14, color: AppColors.ruby),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
