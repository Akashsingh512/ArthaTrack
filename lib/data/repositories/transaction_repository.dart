import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../database/tables/accounts_table.dart';
import '../database/tables/transactions_table.dart';
import '../database/tables/deleted_transactions_table.dart';
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

  /// Returns all existing raw texts as an in-memory Set for ultra-fast fast-forwarding during bulk sync
  Future<Set<String>> getAllRawTextsSet() async {
    final db = await _dbProvider.database;
    final maps = await db.query(
      TransactionsTable.tableName,
      columns: [TransactionsTable.colRawText],
    );
    return maps
        .map((e) => (e[TransactionsTable.colRawText] as String? ?? '').trim())
        .where((s) => s.isNotEmpty)
        .toSet();
  }

  /// Returns all deleted raw texts as an in-memory Set so bulk sync never re-imports deleted transactions
  Future<Set<String>> getDeletedRawTextsSet() async {
    try {
      final db = await _dbProvider.database;
      final maps = await db.query(
        DeletedTransactionsTable.tableName,
        columns: [DeletedTransactionsTable.colRawText],
      );
      return maps
          .map((e) => (e[DeletedTransactionsTable.colRawText] as String? ?? '').trim())
          .where((s) => s.isNotEmpty)
          .toSet();
    } catch (_) {
      return {};
    }
  }

  /// Checks if a transaction has previously been deleted by the user
  Future<bool> isDeleted(TransactionModel tx) async {
    try {
      final db = await _dbProvider.database;

      // 1. Exact raw text match
      if (tx.rawText.trim().isNotEmpty) {
        final rawMatch = await db.query(
          DeletedTransactionsTable.tableName,
          where: '${DeletedTransactionsTable.colRawText} = ?',
          whereArgs: [tx.rawText.trim()],
          limit: 1,
        );
        if (rawMatch.isNotEmpty) return true;
      }

      // 2. Reference Number Match (UPI Ref, RRN, Txn ID, UMRN)
      final ref = tx.referenceNumber?.trim();
      if (ref != null && ref.isNotEmpty) {
        final refMatch = await db.query(
          DeletedTransactionsTable.tableName,
          where: '${DeletedTransactionsTable.colReferenceNumber} = ?',
          whereArgs: [ref],
          limit: 1,
        );
        if (refMatch.isNotEmpty) return true;
      }

      // 3. Same-Day Merchant & Amount Deduplication against deleted items
      final datePrefix = tx.date.length >= 10 ? tx.date.substring(0, 10) : '';
      if (datePrefix.isNotEmpty &&
          tx.amount > 0.0 &&
          tx.merchant != 'Unknown' &&
          tx.merchant != 'Unknown Merchant') {
        final match = await db.query(
          DeletedTransactionsTable.tableName,
          where: '''
            ${DeletedTransactionsTable.colAmount} = ?
            AND LOWER(${DeletedTransactionsTable.colMerchant}) = ?
            AND ${DeletedTransactionsTable.colDate} LIKE ?
          ''',
          whereArgs: [tx.amount, tx.merchant.trim().toLowerCase(), '$datePrefix%'],
          limit: 1,
        );
        if (match.isNotEmpty) return true;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  /// Comprehensive deduplication across multiple SMS and push notifications:
  /// 1. Exact raw text match
  /// 2. Reference number match (UPI Ref / RRN / Txn ID)
  /// 3. Fuzzy time-window match (+/- 15 mins with same amount and type)
  Future<bool> isDuplicate(TransactionModel tx) async {
    // 0. Blacklist Check: If previously deleted by user, treat as duplicate (never re-import)
    if (await isDeleted(tx)) return true;

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

    // 2. Reference Number Match (UPI Ref, RRN, Txn ID, UMRN)
    final ref = tx.referenceNumber?.trim();
    if (ref != null && ref.isNotEmpty) {
      final refMatch = await db.query(
        TransactionsTable.tableName,
        where:
            '${TransactionsTable.colReferenceNumber} = ? AND ${TransactionsTable.colType} = ?',
        whereArgs: [ref, tx.type],
        limit: 1,
      );
      if (refMatch.isNotEmpty) return true;
    }

    // 3. NACH & ACH Duplicate Deduplication:
    // Banks (like Axis Bank) send TWO separate SMS for the same SIP/Mandate:
    // 1) "Debit INR 1000.00 ... ACH-DR-GROWW ..."
    // 2) "NACH debit towards GROWW ... with UMRN ... has been successfully processed in A/c no. XX6535 today"
    final rawLower = tx.rawText.toLowerCase();
    final isMandateTxn =
        rawLower.contains('nach') ||
        rawLower.contains('ach-dr') ||
        rawLower.contains('umrn') ||
        rawLower.contains('mandate');

    final txDateTime = DateTime.tryParse(tx.date);
    final datePrefix = tx.date.length >= 10 ? tx.date.substring(0, 10) : '';

    if (isMandateTxn && tx.amount > 0.0 && datePrefix.isNotEmpty) {
      final nachMatch = await db.query(
        TransactionsTable.tableName,
        where:
            '''
          ${TransactionsTable.colAccountId} = ?
          AND ${TransactionsTable.colAmount} = ?
          AND ${TransactionsTable.colDate} LIKE ?
          AND (
            LOWER(${TransactionsTable.colRawText}) LIKE '%nach%'
            OR LOWER(${TransactionsTable.colRawText}) LIKE '%ach-dr%'
            OR LOWER(${TransactionsTable.colRawText}) LIKE '%umrn%'
            OR LOWER(${TransactionsTable.colRawText}) LIKE '%mandate%'
          )
        ''',
        whereArgs: [tx.accountId, tx.amount, '$datePrefix%'],
        limit: 1,
      );
      if (nachMatch.isNotEmpty) return true;
    }

    // 4. Same-Day Merchant & Amount Deduplication:
    // If a transaction with the same amount, type, and merchant already exists on the same calendar day
    // (prevents duplicate entries from SMS vs Notification or parallel sync runs)
    if (txDateTime != null && tx.amount > 0.0) {
      if (datePrefix.isNotEmpty &&
          tx.merchant != 'Unknown' &&
          tx.merchant != 'Unknown Merchant') {
        final sameDayMatch = await db.query(
          TransactionsTable.tableName,
          where:
              '''
            ${TransactionsTable.colAmount} = ? 
            AND ${TransactionsTable.colType} = ? 
            AND LOWER(${TransactionsTable.colMerchant}) = ?
            AND ${TransactionsTable.colDate} LIKE ?
          ''',
          whereArgs: [
            tx.amount,
            tx.type,
            tx.merchant.trim().toLowerCase(),
            '$datePrefix%',
          ],
          limit: 1,
        );
        if (sameDayMatch.isNotEmpty) return true;
      }

      // 5. Time Window Fuzzy Match (Same Amount, Same Type, within +/- 30 minutes)
      final startWindow = txDateTime
          .subtract(const Duration(minutes: 30))
          .toIso8601String();
      final endWindow = txDateTime
          .add(const Duration(minutes: 30))
          .toIso8601String();

      final fuzzyMatch = await db.query(
        TransactionsTable.tableName,
        where:
            '''
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

      // Adjust account balance ONLY if this is a settled SUCCESS transaction
      // Failed payments or temporary pending holds DO NOT alter account balance!
      if (!transaction.isFailed && !transaction.isPendingHold) {
        // If EXPENSE -> decrease balance
        // If INCOME or REFUND -> increase balance
        final delta = transaction.isExpense
            ? -transaction.amount
            : transaction.amount;

        await txn.rawUpdate(
          '''
          UPDATE ${AccountsTable.tableName}
          SET ${AccountsTable.colBalance} = ${AccountsTable.colBalance} + ?,
              ${AccountsTable.colUpdatedAt} = ?
          WHERE ${AccountsTable.colId} = ?
        ''',
          [delta, DateTime.now().toIso8601String(), transaction.accountId],
        );
      }

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

      // 1. Record in deleted_transactions blacklist so it is NEVER re-imported from SMS or notification
      try {
        await txn.insert(
          DeletedTransactionsTable.tableName,
          {
            DeletedTransactionsTable.colRawText: tx.rawText.trim(),
            DeletedTransactionsTable.colRawTextHash: tx.rawText.trim().hashCode.toString(),
            DeletedTransactionsTable.colReferenceNumber: tx.referenceNumber?.trim(),
            DeletedTransactionsTable.colMerchant: tx.merchant.trim().toLowerCase(),
            DeletedTransactionsTable.colAmount: tx.amount,
            DeletedTransactionsTable.colDate: tx.date,
            DeletedTransactionsTable.colDeletedAt: DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } catch (_) {}

      // 2. Reverse adjustment only if it was a settled SUCCESS transaction
      if (!tx.isFailed && !tx.isPendingHold) {
        final revertDelta = tx.isExpense ? tx.amount : -tx.amount;
        await txn.rawUpdate(
          '''
          UPDATE ${AccountsTable.tableName}
          SET ${AccountsTable.colBalance} = ${AccountsTable.colBalance} + ?,
              ${AccountsTable.colUpdatedAt} = ?
          WHERE ${AccountsTable.colId} = ?
        ''',
          [revertDelta, DateTime.now().toIso8601String(), tx.accountId],
        );
      }

      // 3. Delete from Transactions table
      return await txn.delete(
        TransactionsTable.tableName,
        where: '${TransactionsTable.colId} = ?',
        whereArgs: [id],
      );
    });
  }

  /// Updates transaction details (merchant, category, account, type, paymentSource)
  /// and adjusts account balances if the account or type was changed
  Future<int> updateTransaction(
    TransactionModel updatedTx, {
    int? previousAccountId,
    String? previousType,
  }) async {
    final db = await _dbProvider.database;

    return await db.transaction((txn) async {
      final existingRows = await txn.query(
        TransactionsTable.tableName,
        where: '${TransactionsTable.colId} = ?',
        whereArgs: [updatedTx.id],
      );

      if (existingRows.isNotEmpty) {
        final existing = TransactionModel.fromMap(existingRows.first);
        final oldAccId = previousAccountId ?? existing.accountId;
        final oldType = previousType ?? existing.type;
        final oldIsExpense = oldType.toUpperCase() == 'EXPENSE';
        final newIsExpense = updatedTx.isExpense;

        final amountChanged =
            (existing.amount - updatedTx.amount).abs() > 0.001;
        if (oldAccId != updatedTx.accountId ||
            oldIsExpense != newIsExpense ||
            amountChanged) {
          // Revert old transaction effect on old account
          final revertDelta = oldIsExpense ? existing.amount : -existing.amount;
          await txn.rawUpdate(
            '''
            UPDATE ${AccountsTable.tableName}
            SET ${AccountsTable.colBalance} = ${AccountsTable.colBalance} + ?,
                ${AccountsTable.colUpdatedAt} = ?
            WHERE ${AccountsTable.colId} = ?
          ''',
            [revertDelta, DateTime.now().toIso8601String(), oldAccId],
          );

          // Apply new transaction effect on new account
          final newDelta = newIsExpense ? -updatedTx.amount : updatedTx.amount;
          await txn.rawUpdate(
            '''
            UPDATE ${AccountsTable.tableName}
            SET ${AccountsTable.colBalance} = ${AccountsTable.colBalance} + ?,
                ${AccountsTable.colUpdatedAt} = ?
            WHERE ${AccountsTable.colId} = ?
          ''',
            [newDelta, DateTime.now().toIso8601String(), updatedTx.accountId],
          );
        }
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
    final start = DateTime(
      targetMonth.year,
      targetMonth.month,
      1,
    ).toIso8601String();
    final end = DateTime(
      targetMonth.year,
      targetMonth.month + 1,
      1,
    ).toIso8601String();

    final db = await _dbProvider.database;
    final result = await db.rawQuery(
      '''
      SELECT SUM(${TransactionsTable.colAmount}) as total
      FROM ${TransactionsTable.tableName}
      WHERE UPPER(${TransactionsTable.colType}) = 'EXPENSE'
        AND (${TransactionsTable.colStatus} IS NULL OR UPPER(${TransactionsTable.colStatus}) != 'FAILED')
        AND ${TransactionsTable.colDate} >= ?
        AND ${TransactionsTable.colDate} < ?
    ''',
      [start, end],
    );

    final total = result.first['total'] as num?;
    return total?.toDouble() ?? 0.0;
  }

  /// Returns total income for the given month (includes refunds and excludes failed)
  Future<double> getTotalMonthlyIncome({DateTime? forMonth}) async {
    final targetMonth = forMonth ?? DateTime.now();
    final start = DateTime(
      targetMonth.year,
      targetMonth.month,
      1,
    ).toIso8601String();
    final end = DateTime(
      targetMonth.year,
      targetMonth.month + 1,
      1,
    ).toIso8601String();

    final db = await _dbProvider.database;
    final result = await db.rawQuery(
      '''
      SELECT SUM(${TransactionsTable.colAmount}) as total
      FROM ${TransactionsTable.tableName}
      WHERE UPPER(${TransactionsTable.colType}) IN ('INCOME', 'REFUND')
        AND (${TransactionsTable.colStatus} IS NULL OR UPPER(${TransactionsTable.colStatus}) != 'FAILED')
        AND ${TransactionsTable.colDate} >= ?
        AND ${TransactionsTable.colDate} < ?
    ''',
      [start, end],
    );

    final total = result.first['total'] as num?;
    return total?.toDouble() ?? 0.0;
  }

  /// Returns category breakdown map { 'Food': 4500.0, 'Travel': 1200.0 } for a given month
  Future<Map<String, double>> getCategoryExpenses({DateTime? forMonth}) async {
    final targetMonth = forMonth ?? DateTime.now();
    final start = DateTime(
      targetMonth.year,
      targetMonth.month,
      1,
    ).toIso8601String();
    final end = DateTime(
      targetMonth.year,
      targetMonth.month + 1,
      1,
    ).toIso8601String();

    final db = await _dbProvider.database;
    final result = await db.rawQuery(
      '''
      SELECT ${TransactionsTable.colCategory} as category,
             SUM(${TransactionsTable.colAmount}) as total
      FROM ${TransactionsTable.tableName}
      WHERE UPPER(${TransactionsTable.colType}) = 'EXPENSE'
        AND (${TransactionsTable.colStatus} IS NULL OR UPPER(${TransactionsTable.colStatus}) != 'FAILED')
        AND ${TransactionsTable.colDate} >= ?
        AND ${TransactionsTable.colDate} < ?
      GROUP BY ${TransactionsTable.colCategory}
      ORDER BY total DESC
    ''',
      [start, end],
    );

    final breakdown = <String, double>{};
    for (final row in result) {
      final cat = row['category'] as String;
      final total = (row['total'] as num).toDouble();
      breakdown[cat] = total;
    }
    return breakdown;
  }

  /// Looks up user's previously chosen category for this merchant/payee (Memory Learning)
  Future<String?> getCategoryForMerchant(String merchant) async {
    final trimmed = merchant.trim();
    if (trimmed.isEmpty ||
        trimmed == 'Unknown' ||
        trimmed == 'Unknown Merchant')
      return null;

    final db = await _dbProvider.database;
    final maps = await db.query(
      TransactionsTable.tableName,
      columns: [TransactionsTable.colCategory],
      where:
          'LOWER(${TransactionsTable.colMerchant}) = ? AND ${TransactionsTable.colCategory} != ?',
      whereArgs: [trimmed.toLowerCase(), 'Other'],
      orderBy: '${TransactionsTable.colDate} DESC',
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return maps.first[TransactionsTable.colCategory] as String?;
    }
    return null;
  }

  /// Bulk updates category for multiple transactions in an atomic SQLite transaction
  Future<int> bulkUpdateCategory(
    List<int> transactionIds,
    String newCategory,
  ) async {
    if (transactionIds.isEmpty) return 0;
    final db = await _dbProvider.database;
    return await db.transaction((txn) async {
      final placeholders = List.filled(transactionIds.length, '?').join(',');
      return await txn.rawUpdate(
        '''
        UPDATE ${TransactionsTable.tableName}
        SET ${TransactionsTable.colCategory} = ?
        WHERE ${TransactionsTable.colId} IN ($placeholders)
      ''',
        [newCategory, ...transactionIds],
      );
    });
  }

  /// Scans database and cleans up duplicate NACH/ACH transactions or identical raw messages
  Future<int> cleanupDuplicateTransactions() async {
    final db = await _dbProvider.database;
    final all = await getAllTransactions();
    final toDeleteIds = <int>{};

    // 1. Clean up duplicate NACH vs ACH records (prefer NACH with merchant and UMRN over premature ACH-DR)
    for (var i = 0; i < all.length; i++) {
      for (var j = i + 1; j < all.length; j++) {
        final a = all[i];
        final b = all[j];
        if (a.id == null || b.id == null) continue;
        if (toDeleteIds.contains(a.id) || toDeleteIds.contains(b.id)) continue;

        if (a.accountId == b.accountId && (a.amount - b.amount).abs() < 0.01) {
          final aDate = a.date.length >= 10 ? a.date.substring(0, 10) : '';
          final bDate = b.date.length >= 10 ? b.date.substring(0, 10) : '';
          if (aDate.isNotEmpty && aDate == bDate) {
            final aIsAch = a.rawText.contains('ACH-DR');
            final bIsAch = b.rawText.contains('ACH-DR');
            final aIsNach =
                a.rawText.contains('NACH debit') || a.rawText.contains('UMRN');
            final bIsNach =
                b.rawText.contains('NACH debit') || b.rawText.contains('UMRN');

            if (aIsAch && bIsNach) {
              toDeleteIds.add(a.id!);
            } else if (bIsAch && aIsNach) {
              toDeleteIds.add(b.id!);
            }
          }
        }
      }
    }

    if (toDeleteIds.isNotEmpty) {
      for (final id in toDeleteIds) {
        final match = all.firstWhere((e) => e.id == id, orElse: () => all.first);
        if (match.id == id) {
          try {
            await db.insert(
              DeletedTransactionsTable.tableName,
              {
                DeletedTransactionsTable.colRawText: match.rawText.trim(),
                DeletedTransactionsTable.colRawTextHash: match.rawText.trim().hashCode.toString(),
                DeletedTransactionsTable.colReferenceNumber: match.referenceNumber?.trim(),
                DeletedTransactionsTable.colMerchant: match.merchant.trim().toLowerCase(),
                DeletedTransactionsTable.colAmount: match.amount,
                DeletedTransactionsTable.colDate: match.date,
                DeletedTransactionsTable.colDeletedAt: DateTime.now().toIso8601String(),
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          } catch (_) {}
        }
      }
      final placeholders = List.filled(toDeleteIds.length, '?').join(',');
      await db.delete(
        TransactionsTable.tableName,
        where: '${TransactionsTable.colId} IN ($placeholders)',
        whereArgs: toDeleteIds.toList(),
      );
    }

    // 2. Heal misclassified Salary / Corporate Payroll entries that got marked as Transfer
    try {
      await db.rawUpdate('''
        UPDATE ${TransactionsTable.tableName}
        SET ${TransactionsTable.colCategory} = 'Salary',
            ${TransactionsTable.colMerchant} = 'UNIHEIG (Salary)'
        WHERE (LOWER(${TransactionsTable.colRawText}) LIKE '%uniheig%' 
               OR LOWER(${TransactionsTable.colRawText}) LIKE '%/cdp/%'
               OR ${TransactionsTable.colAmount} = 50367.0)
          AND UPPER(${TransactionsTable.colType}) = 'INCOME'
          AND LOWER(${TransactionsTable.colCategory}) = 'transfer'
      ''');

      // 3. Heal other incoming bank credits that got wrongly categorized as Transfer
      await db.rawUpdate('''
        UPDATE ${TransactionsTable.tableName}
        SET ${TransactionsTable.colCategory} = 'Income'
        WHERE ${TransactionsTable.colMerchant} = 'Bank Credit'
          AND UPPER(${TransactionsTable.colType}) = 'INCOME'
          AND LOWER(${TransactionsTable.colCategory}) = 'transfer'
      ''');
    } catch (_) {}

    return toDeleteIds.length;
  }
}
