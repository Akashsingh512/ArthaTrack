class BalanceSheetItemModel {
  final int? id;
  final String name;
  final String type; // 'ASSET' or 'DEBT'
  final double amount;
  final double interestRate;
  final String category; // e.g. Gold, Stocks, Real Estate, Home Loan, Credit Card Dues
  final String updatedAt;

  BalanceSheetItemModel({
    this.id,
    required this.name,
    required this.type,
    required this.amount,
    this.interestRate = 0.0,
    required this.category,
    required this.updatedAt,
  });

  BalanceSheetItemModel copyWith({
    int? id,
    String? name,
    String? type,
    double? amount,
    double? interestRate,
    String? category,
    String? updatedAt,
  }) {
    return BalanceSheetItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      interestRate: interestRate ?? this.interestRate,
      category: category ?? this.category,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'amount': amount,
      'interest_rate': interestRate,
      'category': category,
      'updated_at': updatedAt,
    };
  }

  factory BalanceSheetItemModel.fromMap(Map<String, dynamic> map) {
    return BalanceSheetItemModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      type: map['type'] as String,
      amount: (map['amount'] as num).toDouble(),
      interestRate: (map['interest_rate'] as num?)?.toDouble() ?? 0.0,
      category: map['category'] as String? ?? 'General',
      updatedAt: map['updated_at'] as String,
    );
  }

  bool get isAsset => type == 'ASSET';
  bool get isDebt => type == 'DEBT';
}
