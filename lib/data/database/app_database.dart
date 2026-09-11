import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../../core/constants/app_constants.dart';
import 'tables/accounts_table.dart';
import 'tables/balance_sheet_table.dart';
import 'tables/transactions_table.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._internal();
  static Database? _database;

  AppDatabase._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, AppConstants.databaseName);

    return await openDatabase(
      path,
      version: AppConstants.databaseVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(AccountsTable.createTableQuery);
    await db.execute(BalanceSheetTable.createTableQuery);
    await db.execute(TransactionsTable.createTableQuery);

    await _seedInitialData(db);
  }

  /// Clean initial setup with ZERO demo data:
  /// - Only empty default accounts with 0.00 balance
  /// - Zero demo assets
  /// - Zero demo debts
  /// - Zero demo transactions
  Future<void> _seedInitialData(Database db) async {
    final now = DateTime.now().toIso8601String();

    // 1. Clean primary accounts with 0 balance
    await db.insert(AccountsTable.tableName, {
      AccountsTable.colName: 'Primary Bank Account',
      AccountsTable.colType: 'SAVINGS',
      AccountsTable.colBalance: 0.00,
      AccountsTable.colUpdatedAt: now,
    });

    await db.insert(AccountsTable.tableName, {
      AccountsTable.colName: 'Cash in Hand',
      AccountsTable.colType: 'CASH',
      AccountsTable.colBalance: 0.00,
      AccountsTable.colUpdatedAt: now,
    });

    // Zero demo assets, zero demo debts, zero demo transactions!
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
