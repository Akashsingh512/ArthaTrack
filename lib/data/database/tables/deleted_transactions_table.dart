class DeletedTransactionsTable {
  static const String tableName = 'deleted_transactions';

  static const String colId = 'id';
  static const String colRawText = 'raw_text';
  static const String colRawTextHash = 'raw_text_hash';
  static const String colReferenceNumber = 'reference_number';
  static const String colMerchant = 'merchant';
  static const String colAmount = 'amount';
  static const String colDate = 'date';
  static const String colDeletedAt = 'deleted_at';

  static const String createTableQuery = '''
    CREATE TABLE IF NOT EXISTS $tableName (
      $colId INTEGER PRIMARY KEY AUTOINCREMENT,
      $colRawText TEXT,
      $colRawTextHash TEXT,
      $colReferenceNumber TEXT,
      $colMerchant TEXT,
      $colAmount REAL,
      $colDate TEXT,
      $colDeletedAt TEXT NOT NULL
    );
  ''';
}
