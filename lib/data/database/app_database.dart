import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/indian_banking_constants.dart';
import '../../core/utils/currency_formatter.dart';
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
    if (oldVersion < 6) {
      try {
        // Auto-discover latest real balance from past transactions in SQLite
        final rows = await db.query(
          TransactionsTable.tableName,
          orderBy: '${TransactionsTable.colDate} DESC',
        );

        final seenAccounts = <int>{};
        for (final row in rows) {
          final rawText = row[TransactionsTable.colRawText] as String? ?? '';
          final accId = row[TransactionsTable.colAccountId] as int?;
          if (accId == null || rawText.isEmpty || seenAccounts.contains(accId)) continue;

          final balMatch = IndianBankingConstants.balanceRegex.firstMatch(rawText);
          if (balMatch != null && balMatch.groupCount >= 1) {
            final rawBal = balMatch.group(1);
            if (rawBal != null) {
              final bal = IndianCurrencyFormatter.parse(rawBal);
              if (bal > 0) {
                seenAccounts.add(accId);
                await db.update(
                  AccountsTable.tableName,
                  {
                    AccountsTable.colBalance: bal,
                    AccountsTable.colUpdatedAt: DateTime.now().toIso8601String(),
                  },
                  where: '${AccountsTable.colId} = ?',
                  whereArgs: [accId],
                );
              }
            }
          }
        }

        // For any savings/cash account that still has a negative balance due to untracked starting balance,
        // reset to 0.00 so Net Worth is never artificially negative
        await db.rawUpdate('''
          UPDATE ${AccountsTable.tableName}
          SET ${AccountsTable.colBalance} = 0.0,
              ${AccountsTable.colUpdatedAt} = ?
          WHERE ${AccountsTable.colBalance} < 0 
            AND ${AccountsTable.colType} IN ('SAVINGS', 'CASH')
        ''', [DateTime.now().toIso8601String()]);
      } catch (_) {}
    }
    if (oldVersion < 7) {
      try {
        // Automatically purge any non-transactional bill payment reminders or due notices
        final rows = await db.query(TransactionsTable.tableName);
        for (final row in rows) {
          final rawText = row[TransactionsTable.colRawText] as String? ?? '';
          final id = row[TransactionsTable.colId] as int?;
          if (id == null || rawText.isEmpty) continue;

          final lower = rawText.toLowerCase();
          final isBlocked = IndianBankingConstants.promotionalBlocklistRegex.hasMatch(rawText);
          final hasIncome = IndianBankingConstants.incomeTriggerRegex.hasMatch(lower);
          final hasExpense = IndianBankingConstants.expenseTriggerRegex.hasMatch(lower);

          if (isBlocked || (!hasIncome && !hasExpense)) {
            await db.delete(
              TransactionsTable.tableName,
              where: '${TransactionsTable.colId} = ?',
              whereArgs: [id],
            );
          }
        }
      } catch (_) {}
    }
    if (oldVersion < 8) {
      try {
        // Automatically purge any credit card / loan / bill payment receipt acknowledgements
        // that were mistakenly recorded as INCOME, and heal account balances!
        final rows = await db.query(TransactionsTable.tableName);
        for (final row in rows) {
          final rawText = row[TransactionsTable.colRawText] as String? ?? '';
          final id = row[TransactionsTable.colId] as int?;
          final type = row[TransactionsTable.colType] as String? ?? '';
          final amount = (row[TransactionsTable.colAmount] as num?)?.toDouble() ?? 0.0;
          final accId = row[TransactionsTable.colAccountId] as int?;

          if (id == null || rawText.isEmpty) continue;

          final lower = rawText.toLowerCase();
          final isReceipt = IndianBankingConstants.promotionalBlocklistRegex.hasMatch(rawText);
          final isCreditCardReceiptIncome = type.toUpperCase() == 'INCOME' &&
              (lower.contains('received towards') ||
               (lower.contains('payment of') && lower.contains('credit card')) ||
               (lower.contains('towards') && lower.contains('card')));

          if (isReceipt || isCreditCardReceiptIncome) {
            await db.delete(
              TransactionsTable.tableName,
              where: '${TransactionsTable.colId} = ?',
              whereArgs: [id],
            );

            // If it was previously added as INCOME, heal the account balance by deducting this false income!
            if (type.toUpperCase() == 'INCOME' && accId != null && amount > 0) {
              await db.rawUpdate('''
                UPDATE ${AccountsTable.tableName}
                SET ${AccountsTable.colBalance} = MAX(0.0, ${AccountsTable.colBalance} - ?),
                    ${AccountsTable.colUpdatedAt} = ?
                WHERE ${AccountsTable.colId} = ?
              ''', [amount, DateTime.now().toIso8601String(), accId]);
            }
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
