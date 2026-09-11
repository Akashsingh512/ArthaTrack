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

  Future<void> _seedInitialData(Database db) async {
    final now = DateTime.now().toIso8601String();

    // 1. Seed Accounts
    final savingsId = await db.insert(AccountsTable.tableName, {
      AccountsTable.colName: 'Primary Savings Bank',
      AccountsTable.colType: 'SAVINGS',
      AccountsTable.colBalance: 54250.00,
      AccountsTable.colUpdatedAt: now,
    });

    final cashId = await db.insert(AccountsTable.tableName, {
      AccountsTable.colName: 'Cash in Hand',
      AccountsTable.colType: 'CASH',
      AccountsTable.colBalance: 4200.00,
      AccountsTable.colUpdatedAt: now,
    });

    final creditCardId = await db.insert(AccountsTable.tableName, {
      AccountsTable.colName: 'HDFC Regalia Credit Card',
      AccountsTable.colType: 'CREDIT_CARD',
      AccountsTable.colBalance: -12800.00,
      AccountsTable.colUpdatedAt: now,
    });

    // 2. Seed Balance Sheet Assets & Debts
    await db.insert(BalanceSheetTable.tableName, {
      BalanceSheetTable.colName: 'Physical 24K Gold & SGB',
      BalanceSheetTable.colType: 'ASSET',
      BalanceSheetTable.colAmount: 240000.00,
      BalanceSheetTable.colInterestRate: 2.50,
      BalanceSheetTable.colCategory: 'Gold',
      BalanceSheetTable.colUpdatedAt: now,
    });

    await db.insert(BalanceSheetTable.tableName, {
      BalanceSheetTable.colName: 'Nifty 50 Index Mutual Funds',
      BalanceSheetTable.colType: 'ASSET',
      BalanceSheetTable.colAmount: 480000.00,
      BalanceSheetTable.colInterestRate: 13.50,
      BalanceSheetTable.colCategory: 'Stocks & Equity',
      BalanceSheetTable.colUpdatedAt: now,
    });

    await db.insert(BalanceSheetTable.tableName, {
      BalanceSheetTable.colName: 'HDFC Car Loan',
      BalanceSheetTable.colType: 'DEBT',
      BalanceSheetTable.colAmount: 185000.00,
      BalanceSheetTable.colInterestRate: 8.40,
      BalanceSheetTable.colCategory: 'Auto Loan',
      BalanceSheetTable.colUpdatedAt: now,
    });

    // 3. Seed Realistic Historical Transactions
    final yesterday = DateTime.now().subtract(const Duration(days: 1)).toIso8601String();
    final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2)).toIso8601String();
    final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3)).toIso8601String();
    final fiveDaysAgo = DateTime.now().subtract(const Duration(days: 5)).toIso8601String();

    await db.insert(TransactionsTable.tableName, {
      TransactionsTable.colAccountId: savingsId,
      TransactionsTable.colAmount: 85000.00,
      TransactionsTable.colType: 'INCOME',
      TransactionsTable.colCategory: 'Salary',
      TransactionsTable.colMerchant: 'Infosys Payroll',
      TransactionsTable.colRawText: 'A/C 1234 credited with INR 85,000.00 on 01-Sep by Salary. Bal: INR 94,250.00',
      TransactionsTable.colDate: fiveDaysAgo,
      TransactionsTable.colSource: 'NOTIFICATION',
      TransactionsTable.colEngine: 'REGEX',
    });

    await db.insert(TransactionsTable.tableName, {
      TransactionsTable.colAccountId: savingsId,
      TransactionsTable.colAmount: 460.00,
      TransactionsTable.colType: 'EXPENSE',
      TransactionsTable.colCategory: 'Food',
      TransactionsTable.colMerchant: 'Swiggy',
      TransactionsTable.colRawText: 'Rs 460.00 debited from a/c **1234 on 08-Sep-26 to SWIGGY UPI. Avl bal Rs 93,790.00',
      TransactionsTable.colDate: threeDaysAgo,
      TransactionsTable.colSource: 'NOTIFICATION',
      TransactionsTable.colEngine: 'AI',
    });

    await db.insert(TransactionsTable.tableName, {
      TransactionsTable.colAccountId: savingsId,
      TransactionsTable.colAmount: 1890.00,
      TransactionsTable.colType: 'EXPENSE',
      TransactionsTable.colCategory: 'Groceries',
      TransactionsTable.colMerchant: 'Blinkit',
      TransactionsTable.colRawText: 'Paid INR 1,890.00 to Blinkit via UPI. Updated balance INR 91,900.00',
      TransactionsTable.colDate: twoDaysAgo,
      TransactionsTable.colSource: 'NOTIFICATION',
      TransactionsTable.colEngine: 'REGEX',
    });

    await db.insert(TransactionsTable.tableName, {
      TransactionsTable.colAccountId: creditCardId,
      TransactionsTable.colAmount: 3499.00,
      TransactionsTable.colType: 'EXPENSE',
      TransactionsTable.colCategory: 'Shopping',
      TransactionsTable.colMerchant: 'Amazon India',
      TransactionsTable.colRawText: 'Alert: Your HDFC Bank Card ending 8812 was spent for INR 3,499.00 at Amazon.in',
      TransactionsTable.colDate: yesterday,
      TransactionsTable.colSource: 'EMAIL',
      TransactionsTable.colEngine: 'AI',
    });

    await db.insert(TransactionsTable.tableName, {
      TransactionsTable.colAccountId: cashId,
      TransactionsTable.colAmount: 250.00,
      TransactionsTable.colType: 'EXPENSE',
      TransactionsTable.colCategory: 'Travel',
      TransactionsTable.colMerchant: 'Auto Rickshaw Fare',
      TransactionsTable.colRawText: 'Manual cash payment for metro auto transit',
      TransactionsTable.colDate: yesterday,
      TransactionsTable.colSource: 'MANUAL',
      TransactionsTable.colEngine: 'REGEX',
    });
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
