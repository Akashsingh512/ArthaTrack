import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../database/tables/budgets_table.dart';
import '../database/tables/transactions_table.dart';
import '../models/budget_model.dart';

class BudgetRepository {
  final AppDatabase _dbProvider;

  BudgetRepository({AppDatabase? dbProvider})
      : _dbProvider = dbProvider ?? AppDatabase.instance;

  /// Fetches all user-defined budgets
  Future<List<BudgetModel>> getAllBudgets() async {
    final db = await _dbProvider.database;
    final maps = await db.query(
      BudgetsTable.tableName,
      orderBy: '${BudgetsTable.colCategory} ASC',
    );
    return maps.map((m) => BudgetModel.fromMap(m)).toList();
  }

  /// Sets or updates a budget limit for a category
  Future<int> setBudget(String category, double monthlyLimit) async {
    final db = await _dbProvider.database;
    final now = DateTime.now();
    return await db.insert(
      BudgetsTable.tableName,
      {
        BudgetsTable.colCategory: category,
        BudgetsTable.colMonthlyLimit: monthlyLimit,
        BudgetsTable.colCreatedAt: now.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Deletes a budget for a category
  Future<int> deleteBudget(String category) async {
    final db = await _dbProvider.database;
    return await db.delete(
      BudgetsTable.tableName,
      where: '${BudgetsTable.colCategory} = ?',
      whereArgs: [category],
    );
  }

  /// Fetches all budgets with current month spending progress
  Future<List<BudgetProgress>> getBudgetProgressForCurrentMonth({DateTime? forMonth}) async {
    final db = await _dbProvider.database;
    final targetMonth = forMonth ?? DateTime.now();
    final start = DateTime(targetMonth.year, targetMonth.month, 1).toIso8601String();
    final end = DateTime(targetMonth.year, targetMonth.month + 1, 1).toIso8601String();

    final budgets = await getAllBudgets();
    if (budgets.isEmpty) return [];

    // Query spending grouped by category for the current month
    final expenseRows = await db.rawQuery('''
      SELECT ${TransactionsTable.colCategory}, SUM(${TransactionsTable.colAmount}) as total
      FROM ${TransactionsTable.tableName}
      WHERE UPPER(${TransactionsTable.colType}) = 'EXPENSE'
        AND ${TransactionsTable.colDate} >= ?
        AND ${TransactionsTable.colDate} < ?
      GROUP BY ${TransactionsTable.colCategory}
    ''', [start, end]);

    final Map<String, double> categorySpent = {};
    for (final row in expenseRows) {
      final cat = (row[TransactionsTable.colCategory] as String?) ?? 'Other';
      final total = (row['total'] as num?)?.toDouble() ?? 0.0;
      categorySpent[cat] = total;
    }

    return budgets.map((b) {
      final spent = categorySpent[b.category] ?? 0.0;
      return BudgetProgress(budget: b, spent: spent);
    }).toList();
  }
}
