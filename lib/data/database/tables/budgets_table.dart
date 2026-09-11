class BudgetsTable {
  static const String tableName = 'budgets';

  static const String colId = 'id';
  static const String colCategory = 'category';
  static const String colMonthlyLimit = 'monthly_limit';
  static const String colCreatedAt = 'created_at';

  static const String createTableQuery = '''
    CREATE TABLE $tableName (
      $colId INTEGER PRIMARY KEY AUTOINCREMENT,
      $colCategory TEXT NOT NULL UNIQUE,
      $colMonthlyLimit REAL NOT NULL,
      $colCreatedAt TEXT NOT NULL
    )
  ''';
}
