import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../database/tables/accounts_table.dart';
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

  /// Calculates total liquid bank and cash balance (including credit card debt as negative)
  Future<double> getTotalLiquidBalance() async {
    final accounts = await getAllAccounts();
    double total = 0.0;
    for (final acc in accounts) {
      total += acc.balance;
    }
    return total;
  }
}
