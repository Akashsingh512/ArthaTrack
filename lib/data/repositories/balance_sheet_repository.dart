import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../database/tables/balance_sheet_table.dart';
import '../models/balance_sheet_item_model.dart';

class BalanceSheetRepository {
  final AppDatabase _dbProvider;

  BalanceSheetRepository({AppDatabase? dbProvider})
      : _dbProvider = dbProvider ?? AppDatabase.instance;

  Future<List<BalanceSheetItemModel>> getAllItems() async {
    final db = await _dbProvider.database;
    final maps = await db.query(
      BalanceSheetTable.tableName,
      orderBy: '${BalanceSheetTable.colAmount} DESC',
    );
    return maps.map((e) => BalanceSheetItemModel.fromMap(e)).toList();
  }

  Future<List<BalanceSheetItemModel>> getAssets() async {
    final db = await _dbProvider.database;
    final maps = await db.query(
      BalanceSheetTable.tableName,
      where: '${BalanceSheetTable.colType} = ?',
      whereArgs: ['ASSET'],
      orderBy: '${BalanceSheetTable.colAmount} DESC',
    );
    return maps.map((e) => BalanceSheetItemModel.fromMap(e)).toList();
  }

  Future<List<BalanceSheetItemModel>> getDebts() async {
    final db = await _dbProvider.database;
    final maps = await db.query(
      BalanceSheetTable.tableName,
      where: '${BalanceSheetTable.colType} = ?',
      whereArgs: ['DEBT'],
      orderBy: '${BalanceSheetTable.colAmount} DESC',
    );
    return maps.map((e) => BalanceSheetItemModel.fromMap(e)).toList();
  }

  Future<double> getTotalAssets() async {
    final db = await _dbProvider.database;
    final result = await db.rawQuery(
      'SELECT SUM(${BalanceSheetTable.colAmount}) as total FROM ${BalanceSheetTable.tableName} WHERE ${BalanceSheetTable.colType} = ?',
      ['ASSET'],
    );
    final total = result.first['total'] as num?;
    return total?.toDouble() ?? 0.0;
  }

  Future<double> getTotalDebts() async {
    final db = await _dbProvider.database;
    final result = await db.rawQuery(
      'SELECT SUM(${BalanceSheetTable.colAmount}) as total FROM ${BalanceSheetTable.tableName} WHERE ${BalanceSheetTable.colType} = ?',
      ['DEBT'],
    );
    final total = result.first['total'] as num?;
    return total?.toDouble() ?? 0.0;
  }

  Future<int> insertItem(BalanceSheetItemModel item) async {
    final db = await _dbProvider.database;
    return await db.insert(
      BalanceSheetTable.tableName,
      item.toMap()..remove('id'),
    );
  }

  Future<int> updateItem(BalanceSheetItemModel item) async {
    final db = await _dbProvider.database;
    return await db.update(
      BalanceSheetTable.tableName,
      item.toMap(),
      where: '${BalanceSheetTable.colId} = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteItem(int id) async {
    final db = await _dbProvider.database;
    return await db.delete(
      BalanceSheetTable.tableName,
      where: '${BalanceSheetTable.colId} = ?',
      whereArgs: [id],
    );
  }

  /// Allocates savings into an asset (either updating an existing asset or creating a new one)
  Future<void> allocateToAsset({
    required String assetName,
    required String category,
    required double amount,
  }) async {
    final db = await _dbProvider.database;
    final trimmed = assetName.trim();
    final existing = await db.query(
      BalanceSheetTable.tableName,
      where: 'LOWER(${BalanceSheetTable.colName}) = ? AND ${BalanceSheetTable.colType} = ?',
      whereArgs: [trimmed.toLowerCase(), 'ASSET'],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final current = BalanceSheetItemModel.fromMap(existing.first);
      await updateItem(current.copyWith(
        amount: current.amount + amount,
        updatedAt: DateTime.now().toIso8601String(),
      ));
    } else {
      await insertItem(BalanceSheetItemModel(
        name: trimmed,
        type: 'ASSET',
        amount: amount,
        category: category,
        updatedAt: DateTime.now().toIso8601String(),
      ));
    }
  }
}
