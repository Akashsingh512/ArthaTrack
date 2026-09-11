import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../database/tables/accounts_table.dart';
import '../database/tables/transactions_table.dart';
import '../models/transaction_model.dart';

class TransactionRepository {
  final AppDatabase _dbProvider;

  TransactionRepository({AppDatabase? dbProvider})
      : _dbProvider = dbProvider ?? AppDatabase.instance;

  Future<List<TransactionModel>> getAllTransactions() async {
    final db = await _dbProvider.database;
    final maps = await db.query(
      TransactionsTable.tableName,
      orderBy: '${TransactionsTable.colDate} DESC',
    );
    return maps.map((e) => TransactionModel.fromMap(e)).toList();
  }

  Future<List<TransactionModel>> getRecentTransactions({int limit = 20}) async {
    final db = await _dbProvider.database;
    final maps = await db.query(
      TransactionsTable.tableName,
      orderBy: '${TransactionsTable.colDate} DESC',
      limit: limit,
    );
    return maps.map((e) => TransactionModel.fromMap(e)).toList();
  }

  Future<bool> hasDuplicateRawText(String rawText) async {
    if (rawText.trim().isEmpty) return false;
    final db = await _dbProvider.database;
    final maps = await db.query(
      TransactionsTable.tableName,
      where: '${TransactionsTable.colRawText} = ?',
      whereArgs: [rawText.trim()],
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  /// Comprehensive deduplication across multiple SMS and push notifications:
  /// 1. Exact raw text match
  /// 2. Reference number match (UPI Ref / RRN / Txn ID)
  /// 3. Fuzzy time-window match (+/- 15 mins with same amount and type)
  Future<bool> isDuplicate(TransactionModel tx) async {
    final db = await _dbProvider.database;

    // 1. Exact raw text match
    if (tx.rawText.trim().isNotEmpty) {
      final rawMatch = await db.query(
        TransactionsTable.tableName,
        where: '${TransactionsTable.colRawText} = ?',
        whereArgs: [tx.rawText.trim()],
        limit: 1,
      );
      if (rawMatch.isNotEmpty) return true;
    }

    // 2. Reference Number Match (UPI Ref, RRN, Txn ID)
    if (tx.referenceNumber != null && tx.referenceNumber!.trim().isNotEmpty) {
      final refMatch = await db.query(
        TransactionsTable.tableName,
        where: '${TransactionsTable.colReferenceNumber} = ?',
        whereArgs: [tx.referenceNumber!.trim()],
        limit: 1,
      );
      if (refMatch.isNotEmpty) return true;
    }

    // 3. Time Window Fuzzy Match (Same Amount, Same Type, within +/- 15 minutes)
    final txDateTime = DateTime.tryParse(tx.date);
    if (txDateTime != null && tx.amount > 0.0) {
      final startWindow = txDateTime.subtract(const Duration(minutes: 15)).toIso8601String();
      final endWindow = txDateTime.add(const Duration(minutes: 15)).toIso8601String();

      final fuzzyMatch = await db.query(
        TransactionsTable.tableName,
        where: '''
          ${TransactionsTable.colAmount} = ? 
          AND ${TransactionsTable.colType} = ? 
          AND ${TransactionsTable.colDate} >= ? 
          AND ${TransactionsTable.colDate} <= ?
        ''',
        whereArgs: [tx.amount, tx.type, startWindow, endWindow],
        limit: 1,
      );
      if (fuzzyMatch.isNotEmpty) return true;
    }

    return false;
  }

  /// Inserts transaction and atomically updates the linked account balance
  Future<int> insertTransaction(TransactionModel transaction) async {
    final db = await _dbProvider.database;

    return await db.transaction((txn) async {
      final id = await txn.insert(
        TransactionsTable.tableName,
        transaction.toMap()..remove('id'),
      );

      // Adjust account balance:
      // If EXPENSE -> decrease balance
      // If INCOME -> increase balance
      final delta = transaction.isExpense ? -transaction.amount : transaction.amount;

      await txn.rawUpdate('''
        UPDATE ${AccountsTable.tableName}
        SET ${AccountsTable.colBalance} = ${AccountsTable.colBalance} + ?,
            ${AccountsTable.colUpdatedAt} = ?
        WHERE ${AccountsTable.colId} = ?
      ''', [delta, DateTime.now().toIso8601String(), transaction.accountId]);

      return id;
    });
  }

  /// Deletes transaction and reverts the balance change
  Future<int> deleteTransaction(int id) async {
    final db = await _dbProvider.database;

    return await db.transaction((txn) async {
      final maps = await txn.query(
        TransactionsTable.tableName,
        where: '${TransactionsTable.colId} = ?',
        whereArgs: [id],
      );

      if (maps.isEmpty) return 0;
      final tx = TransactionModel.fromMap(maps.first);

      // Reverse adjustment
      final revertDelta = tx.isExpense ? tx.amount : -tx.amount;
      await txn.rawUpdate('''
        UPDATE ${AccountsTable.tableName}
        SET ${AccountsTable.colBalance} = ${AccountsTable.colBalance} + ?,
            ${AccountsTable.colUpdatedAt} = ?
        WHERE ${AccountsTable.colId} = ?
      ''', [revertDelta, DateTime.now().toIso8601String(), tx.accountId]);

      return await txn.delete(
        TransactionsTable.tableName,
        where: '${TransactionsTable.colId} = ?',
        whereArgs: [id],
      );
    });
  }

  /// Updates transaction details (merchant, category, account, paymentSource)
  /// and adjusts account balances if the account was changed
  Future<int> updateTransaction(TransactionModel updatedTx, {int? previousAccountId}) async {
    final db = await _dbProvider.database;

    return await db.transaction((txn) async {
      if (previousAccountId != null && previousAccountId != updatedTx.accountId) {
        // Revert delta on previous account
        final revertDelta = updatedTx.isExpense ? updatedTx.amount : -updatedTx.amount;
        await txn.rawUpdate('''
          UPDATE ${AccountsTable.tableName}
          SET ${AccountsTable.colBalance} = ${AccountsTable.colBalance} + ?,
              ${AccountsTable.colUpdatedAt} = ?
          WHERE ${AccountsTable.colId} = ?
        ''', [revertDelta, DateTime.now().toIso8601String(), previousAccountId]);

        // Apply delta to new account
        final newDelta = updatedTx.isExpense ? -updatedTx.amount : updatedTx.amount;
        await txn.rawUpdate('''
          UPDATE ${AccountsTable.tableName}
          SET ${AccountsTable.colBalance} = ${AccountsTable.colBalance} + ?,
              ${AccountsTable.colUpdatedAt} = ?
          WHERE ${AccountsTable.colId} = ?
        ''', [newDelta, DateTime.now().toIso8601String(), updatedTx.accountId]);
      }

      return await txn.update(
        TransactionsTable.tableName,
        updatedTx.toMap(),
        where: '${TransactionsTable.colId} = ?',
        whereArgs: [updatedTx.id],
      );
    });
  }

  /// Returns total expenses for the given month
  Future<double> getTotalMonthlyExpenses({DateTime? forMonth}) async {
    final targetMonth = forMonth ?? DateTime.now();
    final start = DateTime(targetMonth.year, targetMonth.month, 1).toIso8601String();
    final end = DateTime(targetMonth.year, targetMonth.month + 1, 1).toIso8601String();

    final db = await _dbProvider.database;
    final result = await db.rawQuery('''
      SELECT SUM(${TransactionsTable.colAmount}) as total
      FROM ${TransactionsTable.tableName}
      WHERE UPPER(${TransactionsTable.colType}) = 'EXPENSE'
        AND ${TransactionsTable.colDate} >= ?
        AND ${TransactionsTable.colDate} < ?
    ''', [start, end]);

    final total = result.first['total'] as num?;
    return total?.toDouble() ?? 0.0;
  }

  /// Returns total income for the given month
  Future<double> getTotalMonthlyIncome({DateTime? forMonth}) async {
    final targetMonth = forMonth ?? DateTime.now();
    final start = DateTime(targetMonth.year, targetMonth.month, 1).toIso8601String();
    final end = DateTime(targetMonth.year, targetMonth.month + 1, 1).toIso8601String();

    final db = await _dbProvider.database;
    final result = await db.rawQuery('''
      SELECT SUM(${TransactionsTable.colAmount}) as total
      FROM ${TransactionsTable.tableName}
      WHERE UPPER(${TransactionsTable.colType}) = 'INCOME'
        AND ${TransactionsTable.colDate} >= ?
        AND ${TransactionsTable.colDate} < ?
    ''', [start, end]);

    final total = result.first['total'] as num?;
    return total?.toDouble() ?? 0.0;
  }

  /// Returns category breakdown map { 'Food': 4500.0, 'Travel': 1200.0 } for a given month
  Future<Map<String, double>> getCategoryExpenses({DateTime? forMonth}) async {
    final targetMonth = forMonth ?? DateTime.now();
    final start = DateTime(targetMonth.year, targetMonth.month, 1).toIso8601String();
    final end = DateTime(targetMonth.year, targetMonth.month + 1, 1).toIso8601String();

    final db = await _dbProvider.database;
    final result = await db.rawQuery('''
      SELECT ${TransactionsTable.colCategory} as category,
             SUM(${TransactionsTable.colAmount}) as total
      FROM ${TransactionsTable.tableName}
      WHERE UPPER(${TransactionsTable.colType}) = 'EXPENSE'
        AND ${TransactionsTable.colDate} >= ?
        AND ${TransactionsTable.colDate} < ?
      GROUP BY ${TransactionsTable.colCategory}
      ORDER BY total DESC
    ''', [start, end]);

    final breakdown = <String, double>{};
    for (final row in result) {
      final cat = row['category'] as String;
      final total = (row['total'] as num).toDouble();
      breakdown[cat] = total;
    }
    return breakdown;
  }
}
