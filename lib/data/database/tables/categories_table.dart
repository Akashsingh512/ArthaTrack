class CategoriesTable {
  static const String tableName = 'categories';

  static const String colId = 'id';
  static const String colName = 'name';
  static const String colIcon = 'icon';
  static const String colIsDefault = 'is_default'; // 1 = default, 0 = custom user
  static const String colCreatedAt = 'created_at';

  static const String createTableQuery = '''
    CREATE TABLE $tableName (
      $colId INTEGER PRIMARY KEY AUTOINCREMENT,
      $colName TEXT UNIQUE NOT NULL,
      $colIcon TEXT,
      $colIsDefault INTEGER DEFAULT 0,
      $colCreatedAt TEXT NOT NULL
    )
  ''';
}
