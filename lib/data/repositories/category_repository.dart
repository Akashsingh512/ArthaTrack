import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../database/tables/categories_table.dart';
import '../database/tables/merchant_categories_table.dart';
import '../database/tables/transactions_table.dart';

class CategoryRepository {
  final AppDatabase _dbProvider;

  CategoryRepository({AppDatabase? dbProvider})
      : _dbProvider = dbProvider ?? AppDatabase.instance;

  static const List<String> defaultCategories = [
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

  Future<List<String>> getAllCategoryNames() async {
    try {
      final db = await _dbProvider.database;
      final rows = await db.query(
        CategoriesTable.tableName,
        columns: [CategoriesTable.colName],
        orderBy: '${CategoriesTable.colIsDefault} DESC, ${CategoriesTable.colName} ASC',
      );
      if (rows.isEmpty) return defaultCategories;
      final list = rows.map((r) => r[CategoriesTable.colName] as String).toList();
      // Ensure all default categories are included
      for (final def in defaultCategories) {
        if (!list.contains(def)) list.add(def);
      }
      return list;
    } catch (_) {
      return defaultCategories;
    }
  }

  Future<List<Map<String, dynamic>>> getCategoriesWithMeta() async {
    try {
      final db = await _dbProvider.database;
      final rows = await db.query(
        CategoriesTable.tableName,
        orderBy: '${CategoriesTable.colIsDefault} DESC, ${CategoriesTable.colName} ASC',
      );
      return rows;
    } catch (_) {
      return defaultCategories.map((c) => {
        CategoriesTable.colName: c,
        CategoriesTable.colIsDefault: 1,
      }).toList();
    }
  }

  Future<bool> addCustomCategory(String name, {String? icon}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;

    // Check if already exists case-insensitively
    final all = await getAllCategoryNames();
    if (all.any((c) => c.toLowerCase() == trimmed.toLowerCase())) {
      return false; // already exists
    }

    try {
      final db = await _dbProvider.database;
      await db.insert(
        CategoriesTable.tableName,
        {
          CategoriesTable.colName: trimmed,
          CategoriesTable.colIcon: icon,
          CategoriesTable.colIsDefault: 0,
          CategoriesTable.colCreatedAt: DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      return true;
    } catch (e) {
      print('Error adding custom category: $e');
      return false;
    }
  }

  Future<bool> deleteCategory(String name) async {
    final trimmed = name.trim();
    if (defaultCategories.any((d) => d.toLowerCase() == trimmed.toLowerCase())) {
      return false; // Cannot delete core system categories
    }

    try {
      final db = await _dbProvider.database;
      await db.transaction((txn) async {
        // Re-assign transactions belonging to this category to 'Other'
        await txn.rawUpdate('''
          UPDATE ${TransactionsTable.tableName}
          SET ${TransactionsTable.colCategory} = 'Other'
          WHERE LOWER(${TransactionsTable.colCategory}) = ?
        ''', [trimmed.toLowerCase()]);

        await txn.delete(
          CategoriesTable.tableName,
          where: 'LOWER(${CategoriesTable.colName}) = ?',
          whereArgs: [trimmed.toLowerCase()],
        );
      });
      return true;
    } catch (e) {
      print('Error deleting category: $e');
      return false;
    }
  }

  Future<void> rememberMerchantCategory(String merchant, String category) async {
    final mTrim = merchant.trim().toLowerCase();
    if (mTrim.isEmpty || mTrim == 'unknown' || mTrim == 'unknown merchant') return;
    try {
      final db = await _dbProvider.database;
      await db.insert(
        MerchantCategoriesTable.tableName,
        {
          MerchantCategoriesTable.colMerchant: mTrim,
          MerchantCategoriesTable.colCategory: category.trim(),
          MerchantCategoriesTable.colUpdatedAt: DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  Future<String?> getRememberedCategory(String merchant) async {
    final mTrim = merchant.trim().toLowerCase();
    if (mTrim.isEmpty || mTrim == 'unknown' || mTrim == 'unknown merchant') return null;
    try {
      final db = await _dbProvider.database;
      final rows = await db.query(
        MerchantCategoriesTable.tableName,
        where: '${MerchantCategoriesTable.colMerchant} = ?',
        whereArgs: [mTrim],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        return rows.first[MerchantCategoriesTable.colCategory] as String?;
      }
    } catch (_) {}
    return null;
  }
}
