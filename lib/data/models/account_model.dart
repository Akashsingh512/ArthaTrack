class AccountModel {
  final int? id;
  final String name;
  final String type; // 'SAVINGS', 'CREDIT_CARD', 'CASH'
  final double balance;
  final String updatedAt;

  AccountModel({
    this.id,
    required this.name,
    required this.type,
    required this.balance,
    required this.updatedAt,
  });

  AccountModel copyWith({
    int? id,
    String? name,
    String? type,
    double? balance,
    String? updatedAt,
  }) {
    return AccountModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'balance': balance,
      'updated_at': updatedAt,
    };
  }

  factory AccountModel.fromMap(Map<String, dynamic> map) {
    return AccountModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      type: map['type'] as String,
      balance: (map['balance'] as num).toDouble(),
      updatedAt: map['updated_at'] as String,
    );
  }

  bool get isCreditCard => type == 'CREDIT_CARD';
  bool get isSavings => type == 'SAVINGS';
  bool get isCash => type == 'CASH';
}
