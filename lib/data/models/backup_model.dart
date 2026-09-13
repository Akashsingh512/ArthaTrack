import 'dart:convert';

/// Complete database state container for encrypted backup, phone migration, and sync.
class BackupModel {
  final int version;
  final String createdAt;
  final String appVersion;
  final int databaseVersion;
  final String devicePlatform;
  final List<Map<String, dynamic>> accounts;
  final List<Map<String, dynamic>> transactions;
  final List<Map<String, dynamic>> budgets;
  final List<Map<String, dynamic>> balanceSheet;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> merchantCategories;

  BackupModel({
    this.version = 1,
    required this.createdAt,
    this.appVersion = '1.1.0+2',
    this.databaseVersion = 12,
    this.devicePlatform = 'android',
    required this.accounts,
    required this.transactions,
    required this.budgets,
    required this.balanceSheet,
    required this.categories,
    required this.merchantCategories,
  });

  int get totalAccounts => accounts.length;
  int get totalTransactions => transactions.length;
  int get totalBudgets => budgets.length;
  int get totalBalanceItems => balanceSheet.length;
  int get totalCategories => categories.length;

  Map<String, dynamic> toJson() {
    return {
      'metadata': {
        'version': version,
        'created_at': createdAt,
        'app_version': appVersion,
        'database_version': databaseVersion,
        'device_platform': devicePlatform,
        'total_accounts': accounts.length,
        'total_transactions': transactions.length,
        'total_budgets': budgets.length,
        'total_balance_items': balanceSheet.length,
        'total_categories': categories.length,
        'total_merchants': merchantCategories.length,
      },
      'tables': {
        'accounts': accounts,
        'transactions': transactions,
        'budgets': budgets,
        'balance_sheet': balanceSheet,
        'categories': categories,
        'merchant_categories': merchantCategories,
      }
    };
  }

  String toJsonString() => jsonEncode(toJson());

  factory BackupModel.fromJson(Map<String, dynamic> json) {
    final meta = (json['metadata'] as Map<String, dynamic>?) ?? {};
    final tables = (json['tables'] as Map<String, dynamic>?) ?? {};

    List<Map<String, dynamic>> parseTable(String tableName) {
      final rawList = tables[tableName] as List<dynamic>?;
      if (rawList == null) return [];
      return rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    return BackupModel(
      version: (meta['version'] as int?) ?? 1,
      createdAt: (meta['created_at'] as String?) ?? DateTime.now().toIso8601String(),
      appVersion: (meta['app_version'] as String?) ?? '1.1.0+2',
      databaseVersion: (meta['database_version'] as int?) ?? 12,
      devicePlatform: (meta['device_platform'] as String?) ?? 'unknown',
      accounts: parseTable('accounts'),
      transactions: parseTable('transactions'),
      budgets: parseTable('budgets'),
      balanceSheet: parseTable('balance_sheet'),
      categories: parseTable('categories'),
      merchantCategories: parseTable('merchant_categories'),
    );
  }

  factory BackupModel.fromJsonString(String jsonStr) {
    final Map<String, dynamic> decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
    return BackupModel.fromJson(decoded);
  }
}
