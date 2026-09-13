import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../controllers/category_controller.dart';
import '../../../controllers/dashboard_controller.dart';
import '../../../controllers/transaction_controller.dart';

class BulkCategorizeSheet extends StatefulWidget {
  final int count;

  const BulkCategorizeSheet({super.key, required this.count});

  static Future<void> show(BuildContext context, {required int count}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => BulkCategorizeSheet(count: count),
    );
  }

  @override
  State<BulkCategorizeSheet> createState() => _BulkCategorizeSheetState();
}

class _BulkCategorizeSheetState extends State<BulkCategorizeSheet> {
  String? _selectedCategory;
  final _customCategoryController = TextEditingController();
  bool _isCreatingNew = false;

  @override
  void dispose() {
    _customCategoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catController = Provider.of<CategoryController>(context);
    final txController = Provider.of<TransactionController>(context, listen: false);
    final dashController = Provider.of<DashboardController>(context, listen: false);

    final categories = catController.categories;
    final effectiveCategory = _isCreatingNew
        ? _customCategoryController.text.trim()
        : _selectedCategory;

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

          // Title & Count Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.emerald.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.label_outline, color: AppColors.emerald, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bulk Categorize (${widget.count})',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Select a destination category for all ${widget.count} transactions.',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Category Chips Grid
          const Text(
            'CHOOSE CATEGORY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...categories.map((cat) {
                final isSelected = !_isCreatingNew && _selectedCategory == cat;
                final catColor = AppColors.categoryColors[cat] ?? AppColors.primary;

                return GestureDetector(
                  onTap: () {
                    AppHaptics.selection();
                    setState(() {
                      _isCreatingNew = false;
                      _selectedCategory = cat;
                    });
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
                        Container(
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
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? catColor : AppColors.textSecondary,
                          ),
                          child: Text(cat),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              // Button to toggle custom category input (e.g. "Work Travel")
              GestureDetector(
                onTap: () {
                  AppHaptics.selection();
                  setState(() {
                    _isCreatingNew = true;
                    _selectedCategory = null;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isCreatingNew
                        ? AppColors.emerald.withOpacity(0.2)
                        : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isCreatingNew ? AppColors.emerald : const Color(0xFF334155),
                      width: _isCreatingNew ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add,
                        size: 14,
                        color: _isCreatingNew ? AppColors.emerald : AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'New Category...',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: _isCreatingNew ? FontWeight.w700 : FontWeight.w500,
                          color: _isCreatingNew ? AppColors.emerald : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Custom Category Text Field (Visible when creating new)
          if (_isCreatingNew) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _customCategoryController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'e.g. Work Travel, Pet Care, Freelance',
                labelText: 'New Category Name',
                prefixIcon: const Icon(Icons.create_new_folder_outlined, size: 18),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: () => _customCategoryController.clear(),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],

          const SizedBox(height: 24),

          // Apply Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (effectiveCategory == null || effectiveCategory.trim().isEmpty)
                  ? null
                  : () async {
                      AppHaptics.medium();
                      final finalCat = effectiveCategory.trim();

                      // If new custom category, also register it in category repository
                      if (_isCreatingNew && !categories.contains(finalCat)) {
                        await catController.addCategory(finalCat);
                      }

                      final updatedCount = await txController.bulkCategorize(finalCat);
                      dashController.loadDashboardData();

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Updated $updatedCount transactions to "$finalCat"!',
                            ),
                            backgroundColor: AppColors.emerald,
                          ),
                        );
                      }
                    },
              child: Text(effectiveCategory != null && effectiveCategory.isNotEmpty
                  ? 'Assign ${widget.count} Transactions to "$effectiveCategory"'
                  : 'Select Category Above'),
            ),
          ),
        ],
      ),
    );
  }
}
