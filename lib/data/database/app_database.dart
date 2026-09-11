import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/indian_banking_constants.dart';
import 'tables/accounts_table.dart';
import 'tables/balance_sheet_table.dart';
import 'tables/budgets_table.dart';
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
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute(
          'ALTER TABLE ${TransactionsTable.tableName} ADD COLUMN ${TransactionsTable.colReferenceNumber} TEXT;',
        );
      } catch (_) {}
    }
    if (oldVersion < 3) {
      try {
        await db.execute(
          'ALTER TABLE ${TransactionsTable.tableName} ADD COLUMN ${TransactionsTable.colPaymentSource} TEXT;',
        );
      } catch (_) {}
    }
    if (oldVersion < 4) {
      try {
        await db.execute(BudgetsTable.createTableQuery);
      } catch (_) {}
    }
    if (oldVersion < 5) {
      try {
        final rows = await db.query(TransactionsTable.tableName);
        for (final row in rows) {
          final rawText = row[TransactionsTable.colRawText] as String? ?? '';
          final currentSource = row[TransactionsTable.colPaymentSource] as String?;
          final currentMerchant = row[TransactionsTable.colMerchant] as String? ?? '';
          final id = row[TransactionsTable.colId] as int?;

          if (id == null || rawText.isEmpty) continue;
          final updates = <String, dynamic>{};

          if (currentSource == null || currentSource.isEmpty || currentSource == 'Primary Bank Account') {
            final bankMatch = IndianBankingConstants.bankOrSourceRegex.firstMatch(rawText);
            if (bankMatch != null && bankMatch.groupCount >= 1) {
              final rawBank = bankMatch.group(1);
              if (rawBank != null) {
                updates[TransactionsTable.colPaymentSource] = IndianBankingConstants.normalizeBankName(rawBank);
              }
            }
          }

          if (currentMerchant.toLowerCase() == 'vi') {
            final textWithoutVia = rawText.replaceAll(RegExp(r'\bvia\b', caseSensitive: false), '');
            final hasRealVi = RegExp(r'\bvi\b', caseSensitive: false).hasMatch(textWithoutVia);
            if (!hasRealVi) {
              final vpaMatch = IndianBankingConstants.vpaOrMerchantRegex.firstMatch(rawText);
              if (vpaMatch != null && vpaMatch.groupCount >= 1) {
                var cand = vpaMatch.group(1)?.trim();
                if (cand != null &&
                    cand.isNotEmpty &&
                    !cand.toLowerCase().contains('your') &&
                    !cand.toLowerCase().contains('a/c') &&
                    !cand.toLowerCase().contains('account') &&
                    !cand.toLowerCase().contains('bank')) {
                  cand = cand.replaceAll(RegExp(r'\s+(?:via|on|ref|upi|avl|bal|ending|dispute|trxn).*$', caseSensitive: false), '').trim();
                  cand = cand.replaceAll(RegExp(r'[\.\,\:\-]+$'), '').trim();
                  if (cand.isNotEmpty && cand.length > 1) {
                    updates[TransactionsTable.colMerchant] = cand;
                    updates[TransactionsTable.colCategory] = 'Other';
                  }
                }
              }
            }
          }

          if (updates.isNotEmpty) {
            await db.update(
              TransactionsTable.tableName,
              updates,
              where: '${TransactionsTable.colId} = ?',
              whereArgs: [id],
            );
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(AccountsTable.createTableQuery);
    await db.execute(BalanceSheetTable.createTableQuery);
    await db.execute(TransactionsTable.createTableQuery);
    await db.execute(BudgetsTable.createTableQuery);

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
