import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/indian_banking_constants.dart';
import '../../core/utils/currency_formatter.dart';
import '../../services/parsing/engine_b_regex_parser.dart';
import '../models/parsed_transaction.dart';
import 'tables/accounts_table.dart';
import 'tables/balance_sheet_table.dart';
import 'tables/budgets_table.dart';
import 'tables/categories_table.dart';
import 'tables/merchant_categories_table.dart';
import 'tables/transactions_table.dart';
import 'tables/deleted_transactions_table.dart';
import '../repositories/category_repository.dart';

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
    if (oldVersion < 9) {
      try {
        final rows = await db.query(TransactionsTable.tableName);
        for (final row in rows) {
          final rawText = row[TransactionsTable.colRawText] as String? ?? '';
          final id = row[TransactionsTable.colId] as int?;
          final currentMerchant = row[TransactionsTable.colMerchant] as String? ?? '';
          final typeStr = row[TransactionsTable.colType] as String? ?? 'EXPENSE';
          final amount = (row[TransactionsTable.colAmount] as num?)?.toDouble() ?? 0.0;
          final accId = row[TransactionsTable.colAccountId] as int?;

          if (id == null || rawText.isEmpty) continue;

          final lower = rawText.toLowerCase();

          // 1. Purge bogus credit card / bill payment receipts mistakenly recorded as INCOME
          final isReceipt = IndianBankingConstants.promotionalBlocklistRegex.hasMatch(rawText);
          final isCardOrBillerReceiptIncome = typeStr.toUpperCase() == 'INCOME' &&
              (lower.contains('received payment') ||
               lower.contains('credit card') ||
               lower.contains('payment receipt') ||
               lower.contains('bbps') ||
               (lower.contains('credited to your') && lower.contains('card')) ||
               (lower.contains('towards') && (lower.contains('card') || lower.contains('bill'))));

          if (isReceipt || isCardOrBillerReceiptIncome) {
            await db.delete(
              TransactionsTable.tableName,
              where: '${TransactionsTable.colId} = ?',
              whereArgs: [id],
            );

            // Deduct false income from account balance so Net Worth and Balances stay 100% accurate
            if (typeStr.toUpperCase() == 'INCOME' && accId != null && amount > 0) {
              await db.rawUpdate('''
                UPDATE ${AccountsTable.tableName}
                SET ${AccountsTable.colBalance} = MAX(0.0, ${AccountsTable.colBalance} - ?),
                    ${AccountsTable.colUpdatedAt} = ?
                WHERE ${AccountsTable.colId} = ?
              ''', [amount, DateTime.now().toIso8601String(), accId]);
            }
            continue;
          }

          // 2. Heal transactions where merchant was mistakenly recorded as a phone number or dispute footer number
          if (RegExp(r'^\+?[\d\s\-]{5,}$').hasMatch(currentMerchant.trim()) ||
              RegExp(r'^\d+$').hasMatch(currentMerchant.trim()) ||
              currentMerchant.toLowerCase().contains('download') ||
              currentMerchant.toLowerCase().contains('receipt')) {
            final tType = typeStr.toUpperCase() == 'INCOME' ? TransactionType.INCOME : TransactionType.EXPENSE;
            final healed = EngineBRegexParser.extractMerchantOnly(rawText, tType);
            if (healed != null && healed.isNotEmpty && healed != 'Unknown Merchant') {
              await db.update(
                TransactionsTable.tableName,
                {
                  TransactionsTable.colMerchant: healed,
                },
                where: '${TransactionsTable.colId} = ?',
                whereArgs: [id],
              );
            }
          }
        }
      } catch (_) {}
    }
    if (oldVersion < 10) {
      try {
        // A. Purge false income transactions from Airtel / telecom / bill receipts
        final rows = await db.query(TransactionsTable.tableName);
        for (final row in rows) {
          final rawText = row[TransactionsTable.colRawText] as String? ?? '';
          final id = row[TransactionsTable.colId] as int?;
          final typeStr = row[TransactionsTable.colType] as String? ?? 'EXPENSE';
          final amount = (row[TransactionsTable.colAmount] as num?)?.toDouble() ?? 0.0;
          final accId = row[TransactionsTable.colAccountId] as int?;

          if (id == null || rawText.isEmpty) continue;

          final lower = rawText.toLowerCase();
          final isBogusReceiptIncome = typeStr.toUpperCase() == 'INCOME' &&
              (lower.contains('e-receipt') ||
               lower.contains('airtel number') ||
               lower.contains('jio number') ||
               lower.contains('vi number') ||
               lower.contains('airtel thanks') ||
               lower.contains('received the payment') ||
               (lower.contains('credited to your') && (lower.contains('airtel') || lower.contains('account within'))));

          if (isBogusReceiptIncome) {
            await db.delete(
              TransactionsTable.tableName,
              where: '${TransactionsTable.colId} = ?',
              whereArgs: [id],
            );

            // Heal account balance by deducting this false income
            if (accId != null && amount > 0) {
              await db.rawUpdate('''
                UPDATE ${AccountsTable.tableName}
                SET ${AccountsTable.colBalance} = MAX(0.0, ${AccountsTable.colBalance} - ?),
                    ${AccountsTable.colUpdatedAt} = ?
                WHERE ${AccountsTable.colId} = ?
              ''', [amount, DateTime.now().toIso8601String(), accId]);
            }
          }
        }

        // B. Clean up empty unused Airtel Payments Bank account if it has no remaining transactions
        await db.rawDelete('''
          DELETE FROM ${AccountsTable.tableName}
          WHERE ${AccountsTable.colId} NOT IN (SELECT DISTINCT ${TransactionsTable.colAccountId} FROM ${TransactionsTable.tableName})
            AND ${AccountsTable.colBalance} = 0.0
            AND ${AccountsTable.colName} = 'Airtel Payments Bank'
        ''');

        // C. Deduplicate existing duplicate transactions (e.g. duplicate ADUSUMALLI NIKHIL entries)
        final allRows = await db.query(
          TransactionsTable.tableName,
          orderBy: '${TransactionsTable.colId} ASC',
        );
        final seen = <String>{};
        for (final row in allRows) {
          final id = row[TransactionsTable.colId] as int?;
          final amount = (row[TransactionsTable.colAmount] as num?)?.toDouble() ?? 0.0;
          final type = row[TransactionsTable.colType] as String? ?? '';
          final merchant = (row[TransactionsTable.colMerchant] as String? ?? '').trim().toLowerCase();
          final date = row[TransactionsTable.colDate] as String? ?? '';
          final day = date.length >= 10 ? date.substring(0, 10) : date;
          final accId = row[TransactionsTable.colAccountId] as int?;

          if (id == null) continue;

          final key = '$amount|$type|$merchant|$day';
          if (seen.contains(key)) {
            // Duplicate found! Delete it and revert the balance adjustment
            await db.delete(
              TransactionsTable.tableName,
              where: '${TransactionsTable.colId} = ?',
              whereArgs: [id],
            );
            if (accId != null && amount > 0) {
              final revertDelta = type.toUpperCase() == 'EXPENSE' ? amount : -amount;
              await db.rawUpdate('''
                UPDATE ${AccountsTable.tableName}
                SET ${AccountsTable.colBalance} = ${AccountsTable.colBalance} + ?,
                    ${AccountsTable.colUpdatedAt} = ?
                WHERE ${AccountsTable.colId} = ?
              ''', [revertDelta, DateTime.now().toIso8601String(), accId]);
            }
          } else {
            seen.add(key);
          }
        }

        // D. Re-link Axis Bank Card transactions to distinct Card accounts
        final cardRows = await db.query(
          TransactionsTable.tableName,
          where: "${TransactionsTable.colRawText} LIKE '%Axis Bank Card%'",
        );
        for (final row in cardRows) {
          final id = row[TransactionsTable.colId] as int?;
          final rawText = row[TransactionsTable.colRawText] as String? ?? '';
          if (id == null || rawText.isEmpty) continue;

          final cardMatch = RegExp(r'(?:card\s*(?:no\.?)?\s*(?:ending)?\s*[:\s]*)([xX\*]*\d{3,4})', caseSensitive: false).firstMatch(rawText);
          if (cardMatch != null && cardMatch.groupCount >= 1) {
            var cardNum = cardMatch.group(1)?.trim().toUpperCase() ?? '';
            if (cardNum.isNotEmpty && !cardNum.startsWith('XX') && !cardNum.startsWith('*')) {
              cardNum = 'XX$cardNum';
            }
            final cardAccName = 'Axis Bank Card ($cardNum)';

            // Find or create the card account
            final accRows = await db.query(
              AccountsTable.tableName,
              where: 'LOWER(${AccountsTable.colName}) = ?',
              whereArgs: [cardAccName.toLowerCase()],
              limit: 1,
            );
            int targetAccId;
            if (accRows.isNotEmpty) {
              targetAccId = accRows.first[AccountsTable.colId] as int;
            } else {
              targetAccId = await db.insert(AccountsTable.tableName, {
                AccountsTable.colName: cardAccName,
                AccountsTable.colType: 'CREDIT_CARD',
                AccountsTable.colBalance: 0.0,
                AccountsTable.colUpdatedAt: DateTime.now().toIso8601String(),
              });
            }

            await db.update(
              TransactionsTable.tableName,
              {
                TransactionsTable.colPaymentSource: cardAccName,
                TransactionsTable.colAccountId: targetAccId,
              },
              where: '${TransactionsTable.colId} = ?',
              whereArgs: [id],
            );
          }
        }
      } catch (_) {}
    }

    if (oldVersion < 11) {
      try {
        await db.execute(CategoriesTable.createTableQuery);
        await db.execute(MerchantCategoriesTable.createTableQuery);

        final now = DateTime.now().toIso8601String();
        for (final cat in CategoryRepository.defaultCategories) {
          await db.insert(
            CategoriesTable.tableName,
            {
              CategoriesTable.colName: cat,
              CategoriesTable.colIsDefault: 1,
              CategoriesTable.colCreatedAt: now,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }

        // Seed existing known merchants from past transactions into merchant_categories
        final txRows = await db.query(
          TransactionsTable.tableName,
          columns: [TransactionsTable.colMerchant, TransactionsTable.colCategory],
          where: '${TransactionsTable.colCategory} != ?',
          whereArgs: ['Other'],
        );
        for (final row in txRows) {
          final m = (row[TransactionsTable.colMerchant] as String? ?? '').trim().toLowerCase();
          final c = row[TransactionsTable.colCategory] as String? ?? '';
          if (m.isNotEmpty && m != 'unknown' && m != 'unknown merchant' && c.isNotEmpty) {
            await db.insert(
              MerchantCategoriesTable.tableName,
              {
                MerchantCategoriesTable.colMerchant: m,
                MerchantCategoriesTable.colCategory: c,
                MerchantCategoriesTable.colUpdatedAt: now,
              },
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
          }
        }
      } catch (e) {
        print('Migration v11 error: $e');
      }
    }

    if (oldVersion < 12) {
      try {
        await db.execute(
          'ALTER TABLE ${TransactionsTable.tableName} ADD COLUMN ${TransactionsTable.colStatus} TEXT NOT NULL DEFAULT "SUCCESS";',
        );
      } catch (_) {}
      try {
        await db.execute(
          'ALTER TABLE ${TransactionsTable.tableName} ADD COLUMN ${TransactionsTable.colFailureReason} TEXT;',
        );
      } catch (_) {}
      try {
        await db.execute(
          'ALTER TABLE ${TransactionsTable.tableName} ADD COLUMN ${TransactionsTable.colSupportRecourse} TEXT;',
        );
      } catch (_) {}
    }

    if (oldVersion < 13) {
      try {
        await db.execute(DeletedTransactionsTable.createTableQuery);
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_deleted_raw_text ON ${DeletedTransactionsTable.tableName} (${DeletedTransactionsTable.colRawText});',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_deleted_ref ON ${DeletedTransactionsTable.tableName} (${DeletedTransactionsTable.colReferenceNumber});',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_deleted_merchant_amt ON ${DeletedTransactionsTable.tableName} (${DeletedTransactionsTable.colMerchant}, ${DeletedTransactionsTable.colAmount});',
        );
      } catch (_) {}
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(AccountsTable.createTableQuery);
    await db.execute(BalanceSheetTable.createTableQuery);
    await db.execute(TransactionsTable.createTableQuery);
    await db.execute(BudgetsTable.createTableQuery);
    await db.execute(CategoriesTable.createTableQuery);
    await db.execute(MerchantCategoriesTable.createTableQuery);
    await db.execute(DeletedTransactionsTable.createTableQuery);
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_deleted_raw_text ON ${DeletedTransactionsTable.tableName} (${DeletedTransactionsTable.colRawText});',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_deleted_ref ON ${DeletedTransactionsTable.tableName} (${DeletedTransactionsTable.colReferenceNumber});',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_deleted_merchant_amt ON ${DeletedTransactionsTable.tableName} (${DeletedTransactionsTable.colMerchant}, ${DeletedTransactionsTable.colAmount});',
    );

    await _seedInitialData(db);
  }

  /// Clean initial setup with ZERO demo data:
  /// - Only empty default accounts with 0.00 balance
  /// - Zero demo assets
  /// - Zero demo debts
  /// - Zero demo transactions
  /// - Standard default categories
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

    // 2. Seed default categories
    for (final cat in CategoryRepository.defaultCategories) {
      await db.insert(
        CategoriesTable.tableName,
        {
          CategoriesTable.colName: cat,
          CategoriesTable.colIsDefault: 1,
          CategoriesTable.colCreatedAt: now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
