class MerchantCategoriesTable {
  static const String tableName = 'merchant_categories';

  static const String colMerchant = 'merchant';
  static const String colCategory = 'category';
  static const String colUpdatedAt = 'updated_at';

  static const String createTableQuery = '''
    CREATE TABLE $tableName (
      $colMerchant TEXT PRIMARY KEY,
      $colCategory TEXT NOT NULL,
      $colUpdatedAt TEXT NOT NULL
    )
  ''';
}
