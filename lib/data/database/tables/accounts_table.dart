class AccountsTable {
  static const String tableName = 'accounts';

  static const String colId = 'id';
  static const String colName = 'name';
  static const String colType = 'type'; // 'SAVINGS', 'CREDIT_CARD', 'CASH'
  static const String colBalance = 'balance';
  static const String colUpdatedAt = 'updated_at';

  static const String createTableQuery = '''
    CREATE TABLE $tableName (
      $colId INTEGER PRIMARY KEY AUTOINCREMENT,
      $colName TEXT NOT NULL,
      $colType TEXT NOT NULL,
      $colBalance REAL NOT NULL DEFAULT 0.0,
      $colUpdatedAt TEXT NOT NULL
    )
  ''';
}
