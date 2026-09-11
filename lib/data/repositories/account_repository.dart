import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../database/tables/accounts_table.dart';
import '../database/tables/transactions_table.dart';
import '../models/account_model.dart';

class AccountRepository {
  final AppDatabase _dbProvider;

  AccountRepository({AppDatabase? dbProvider})
      : _dbProvider = dbProvider ?? AppDatabase.instance;

  Future<List<AccountModel>> getAllAccounts() async {
    final db = await _dbProvider.database;
    final maps = await db.query(
      AccountsTable.tableName,
      orderBy: '${AccountsTable.colId} ASC',
    );
    return maps.map((e) => AccountModel.fromMap(e)).toList();
  }

  Future<AccountModel?> getAccountById(int id) async {
    final db = await _dbProvider.database;
    final maps = await db.query(
      AccountsTable.tableName,
      where: '${AccountsTable.colId} = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return AccountModel.fromMap(maps.first);
    }
    return null;
  }

  Future<AccountModel?> getDefaultAccount() async {
    final accounts = await getAllAccounts();
    if (accounts.isEmpty) return null;
    return accounts.firstWhere(
      (a) => a.isSavings,
      orElse: () => accounts.first,
    );
  }

  /// Finds existing account by name (case-insensitive) or creates a new one
  Future<AccountModel> getOrCreateAccountByName(String name, {String? type}) async {
    final trimmed = name.trim();
    final db = await _dbProvider.database;
    final maps = await db.query(
      AccountsTable.tableName,
      where: 'LOWER(${AccountsTable.colName}) = ?',
      whereArgs: [trimmed.toLowerCase()],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return AccountModel.fromMap(maps.first);
    }

    final inferredType = type ??
        ((trimmed.toLowerCase().contains('card') || trimmed.toLowerCase().contains('credit'))
            ? 'CREDIT_CARD'
            : (trimmed.toLowerCase().contains('cash') ? 'CASH' : 'SAVINGS'));

    // Smart Single Card Resolution:
    // If incoming card name is generic (omits digits like XX1234) and user has exactly ONE numbered card for this bank,
    // automatically link to that existing card!
    final hasDigits = RegExp(r'\d{3,4}').hasMatch(trimmed);
    if (!hasDigits && (inferredType == 'CREDIT_CARD' || trimmed.toLowerCase().contains('card'))) {
      final all = await getAllAccounts();
      final lower = trimmed.toLowerCase();
      final bankKeyword = lower.contains('axis')
          ? 'axis'
          : (lower.contains('sbi')
              ? 'sbi'
              : (lower.contains('hdfc')
                  ? 'hdfc'
                  : (lower.contains('icici') ? 'icici' : (lower.contains('kotak') ? 'kotak' : null))));

      if (bankKeyword != null) {
        final matchingBankCards = all
            .where((a) => a.isCreditCard && a.name.toLowerCase().contains(bankKeyword) && RegExp(r'\d{3,4}').hasMatch(a.name))
            .toList();
        if (matchingBankCards.length == 1) {
          return matchingBankCards.first;
        }
      }
    }

    final newAcc = AccountModel(
      name: trimmed,
      type: inferredType,
      balance: 0.0,
      updatedAt: DateTime.now().toIso8601String(),
    );

    final insertedId = await insertAccount(newAcc);
    return newAcc.copyWith(id: insertedId);
  }

  Future<int> insertAccount(AccountModel account) async {
    final db = await _dbProvider.database;
    return await db.insert(
      AccountsTable.tableName,
      account.toMap()..remove('id'),
    );
  }

  Future<int> updateAccount(AccountModel account) async {
    final db = await _dbProvider.database;
    return await db.update(
      AccountsTable.tableName,
      account.toMap(),
      where: '${AccountsTable.colId} = ?',
      whereArgs: [account.id],
    );
  }

  Future<void> updateBalance(int accountId, double newBalance) async {
    final db = await _dbProvider.database;
    await db.update(
      AccountsTable.tableName,
      {
        AccountsTable.colBalance: newBalance,
        AccountsTable.colUpdatedAt: DateTime.now().toIso8601String(),
      },
      where: '${AccountsTable.colId} = ?',
      whereArgs: [accountId],
    );
  }

  Future<void> adjustBalance(int accountId, double delta) async {
    final db = await _dbProvider.database;
    await db.rawUpdate('''
      UPDATE ${AccountsTable.tableName}
      SET ${AccountsTable.colBalance} = ${AccountsTable.colBalance} + ?,
          ${AccountsTable.colUpdatedAt} = ?
      WHERE ${AccountsTable.colId} = ?
    ''', [delta, DateTime.now().toIso8601String(), accountId]);
  }

  Future<int> deleteAccount(int id) async {
    final db = await _dbProvider.database;
    return await db.delete(
      AccountsTable.tableName,
      where: '${AccountsTable.colId} = ?',
      whereArgs: [id],
    );
  }

  /// Calculates total liquid bank and cash balance (savings + cash only)
  Future<double> getTotalLiquidBalance() async {
    final accounts = await getAllAccounts();
    double total = 0.0;
    for (final acc in accounts) {
      if (acc.isSavings || acc.isCash) {
        // If an account has a positive balance, add it.
        // If negative due to untracked starting balance, clamp to 0 so Net Worth is never falsely negative.
        total += acc.balance > 0 ? acc.balance : 0.0;
      }
    }
    return total;
  }

  /// Calculates total credit card outstanding dues (liabilities)
  /// Note: Positive balances on credit cards represent Available Credit Limits from SMS
  /// and must NEVER be treated as debt liabilities.
  Future<double> getCreditCardDues() async {
    final accounts = await getAllAccounts();
    double dues = 0.0;
    for (final acc in accounts) {
      if (acc.isCreditCard) {
        if (acc.balance < 0) {
          dues += acc.balance.abs();
        }
      }
    }
    return dues;
  }

  /// Merges all transactions from [sourceAccountId] into [targetAccountId] and deletes [sourceAccountId].
  Future<void> mergeAccounts(int sourceAccountId, int targetAccountId) async {
    if (sourceAccountId == targetAccountId) return;
    final db = await _dbProvider.database;
    await db.transaction((txn) async {
      await txn.rawUpdate('''
        UPDATE ${TransactionsTable.tableName}
        SET ${TransactionsTable.colAccountId} = ?
        WHERE ${TransactionsTable.colAccountId} = ?
      ''', [targetAccountId, sourceAccountId]);

      await txn.delete(
        AccountsTable.tableName,
        where: '${AccountsTable.colId} = ?',
        whereArgs: [sourceAccountId],
      );
    });
  }

  /// Finds generic card accounts (omitting card digits) where specific numbered cards also exist
  Future<List<AccountModel>> getAmbiguousCardAccounts() async {
    final all = await getAllAccounts();
    final cards = all.where((a) => a.isCreditCard).toList();
    final ambiguous = <AccountModel>[];

    for (final card in cards) {
      final hasDigits = RegExp(r'\d{3,4}').hasMatch(card.name);
      if (!hasDigits) {
        final lower = card.name.toLowerCase();
        final bankKeyword = lower.contains('axis')
            ? 'axis'
            : (lower.contains('sbi')
                ? 'sbi'
                : (lower.contains('hdfc')
                    ? 'hdfc'
                    : (lower.contains('icici') ? 'icici' : null)));
        if (bankKeyword != null) {
          final hasSpecificCards = cards.any(
            (c) => c.id != card.id && c.name.toLowerCase().contains(bankKeyword) && RegExp(r'\d{3,4}').hasMatch(c.name),
          );
          if (hasSpecificCards) {
            ambiguous.add(card);
          }
        }
      }
    }
    return ambiguous;
  }
}
