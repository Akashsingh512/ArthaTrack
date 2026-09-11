class BalanceSheetTable {
  static const String tableName = 'balance_sheet';

  static const String colId = 'id';
  static const String colName = 'name';
  static const String colType = 'type'; // 'ASSET' or 'DEBT'
  static const String colAmount = 'amount';
  static const String colInterestRate = 'interest_rate';
  static const String colCategory = 'category';
  static const String colUpdatedAt = 'updated_at';

  static const String createTableQuery = '''
    CREATE TABLE $tableName (
      $colId INTEGER PRIMARY KEY AUTOINCREMENT,
      $colName TEXT NOT NULL,
      $colType TEXT NOT NULL,
      $colAmount REAL NOT NULL DEFAULT 0.0,
      $colInterestRate REAL DEFAULT 0.0,
      $colCategory TEXT NOT NULL DEFAULT 'General',
      $colUpdatedAt TEXT NOT NULL
    )
  ''';
}
