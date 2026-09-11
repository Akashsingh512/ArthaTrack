enum TransactionType {
  EXPENSE,
  INCOME,
}

class ParsedTransaction {
  final double amount;
  final TransactionType type;
  final String category;
  final String merchant;
  final double? updatedBalance;
  final String? accountSnippet;
  final String? referenceNumber;
  final String? paymentSource;
  final String rawText;
  final String engine; // 'AI_GEMINI', 'AI_GROQ', 'OFFLINE_REGEX'
  final double confidence; // 0.0 to 1.0
  final bool isFinancial;

  ParsedTransaction({
    required this.amount,
    required this.type,
    required this.category,
    required this.merchant,
    this.updatedBalance,
    this.accountSnippet,
    this.referenceNumber,
    this.paymentSource,
    required this.rawText,
    required this.engine,
    this.confidence = 1.0,
    this.isFinancial = true,
  });

  bool get isExpense => type == TransactionType.EXPENSE;
  bool get isIncome => type == TransactionType.INCOME;

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'type': type.name,
      'category': category,
      'merchant': merchant,
      'updated_balance': updatedBalance,
      'account_snippet': accountSnippet,
      'reference_number': referenceNumber,
      'payment_source': paymentSource,
      'raw_text': rawText,
      'engine': engine,
      'confidence': confidence,
      'is_financial': isFinancial,
    };
  }

  factory ParsedTransaction.fromMap(Map<String, dynamic> map) {
    return ParsedTransaction(
      amount: (map['amount'] as num).toDouble(),
      type: (map['type'] == 'INCOME') ? TransactionType.INCOME : TransactionType.EXPENSE,
      category: map['category'] as String? ?? 'Other',
      merchant: map['merchant'] as String? ?? 'Unknown Merchant',
      updatedBalance: (map['updated_balance'] as num?)?.toDouble(),
      accountSnippet: map['account_snippet'] as String?,
      referenceNumber: map['reference_number'] as String?,
      paymentSource: map['payment_source'] as String?,
      rawText: map['raw_text'] as String? ?? '',
      engine: map['engine'] as String? ?? 'OFFLINE_REGEX',
      confidence: (map['confidence'] as num?)?.toDouble() ?? 1.0,
      isFinancial: map['is_financial'] as bool? ?? true,
    );
  }

  ParsedTransaction copyWith({
    double? amount,
    TransactionType? type,
    String? category,
    String? merchant,
    double? updatedBalance,
    String? accountSnippet,
    String? referenceNumber,
    String? paymentSource,
    String? rawText,
    String? engine,
    double? confidence,
    bool? isFinancial,
  }) {
    return ParsedTransaction(
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      merchant: merchant ?? this.merchant,
      updatedBalance: updatedBalance ?? this.updatedBalance,
      accountSnippet: accountSnippet ?? this.accountSnippet,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      paymentSource: paymentSource ?? this.paymentSource,
      rawText: rawText ?? this.rawText,
      engine: engine ?? this.engine,
      confidence: confidence ?? this.confidence,
      isFinancial: isFinancial ?? this.isFinancial,
    );
  }
}
