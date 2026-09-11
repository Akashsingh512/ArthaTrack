class TransactionsTable {
  static const String tableName = 'transactions';

  static const String colId = 'id';
  static const String colAccountId = 'account_id';
  static const String colAmount = 'amount';
  static const String colType = 'type'; // 'EXPENSE' or 'INCOME'
  static const String colCategory = 'category';
  static const String colMerchant = 'merchant';
  static const String colRawText = 'raw_text';
  static const String colDate = 'date';
  static const String colSource = 'source'; // 'NOTIFICATION', 'EMAIL', 'MANUAL'
  static const String colEngine = 'engine'; // 'AI', 'REGEX'
  static const String colReferenceNumber = 'reference_number';

  static const String createTableQuery = '''
    CREATE TABLE $tableName (
      $colId INTEGER PRIMARY KEY AUTOINCREMENT,
      $colAccountId INTEGER NOT NULL,
      $colAmount REAL NOT NULL,
      $colType TEXT NOT NULL,
      $colCategory TEXT NOT NULL,
      $colMerchant TEXT NOT NULL,
      $colRawText TEXT NOT NULL,
      $colDate TEXT NOT NULL,
      $colSource TEXT NOT NULL DEFAULT 'MANUAL',
      $colEngine TEXT NOT NULL DEFAULT 'REGEX',
      $colReferenceNumber TEXT,
      FOREIGN KEY ($colAccountId) REFERENCES accounts (id) ON DELETE CASCADE
    )
  ''';
}
