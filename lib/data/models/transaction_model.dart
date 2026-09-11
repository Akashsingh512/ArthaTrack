import 'parsed_transaction.dart';

class TransactionModel {
  final int? id;
  final int accountId;
  final double amount;
  final String type; // 'EXPENSE' or 'INCOME'
  final String category;
  final String merchant;
  final String rawText;
  final String date;
  final String source; // 'NOTIFICATION', 'EMAIL', 'MANUAL'
  final String engine; // 'AI', 'REGEX'

  TransactionModel({
    this.id,
    required this.accountId,
    required this.amount,
    required this.type,
    required this.category,
    required this.merchant,
    required this.rawText,
    required this.date,
    this.source = 'NOTIFICATION',
    this.engine = 'REGEX',
  });

  TransactionModel copyWith({
    int? id,
    int? accountId,
    double? amount,
    String? type,
    String? category,
    String? merchant,
    String? rawText,
    String? date,
    String? source,
    String? engine,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      merchant: merchant ?? this.merchant,
      rawText: rawText ?? this.rawText,
      date: date ?? this.date,
      source: source ?? this.source,
      engine: engine ?? this.engine,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'account_id': accountId,
      'amount': amount,
      'type': type,
      'category': category,
      'merchant': merchant,
      'raw_text': rawText,
      'date': date,
      'source': source,
      'engine': engine,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as int?,
      accountId: map['account_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      type: map['type'] as String,
      category: map['category'] as String,
      merchant: map['merchant'] as String,
      rawText: map['raw_text'] as String? ?? '',
      date: map['date'] as String,
      source: map['source'] as String? ?? 'MANUAL',
      engine: map['engine'] as String? ?? 'REGEX',
    );
  }

  bool get isExpense => type == 'EXPENSE';
  bool get isIncome => type == 'INCOME';

  factory TransactionModel.fromParsed({
    required ParsedTransaction parsed,
    required int accountId,
    required String source,
    DateTime? date,
  }) {
    return TransactionModel(
      accountId: accountId,
      amount: parsed.amount,
      type: parsed.type.name,
      category: parsed.category,
      merchant: parsed.merchant,
      rawText: parsed.rawText,
      date: (date ?? DateTime.now()).toIso8601String(),
      source: source,
      engine: parsed.engine.startsWith('AI') ? 'AI' : 'REGEX',
    );
  }
}
