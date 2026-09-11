import '../database/tables/budgets_table.dart';

class BudgetModel {
  final int? id;
  final String category;
  final double monthlyLimit;
  final DateTime createdAt;

  BudgetModel({
    this.id,
    required this.category,
    required this.monthlyLimit,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) BudgetsTable.colId: id,
      BudgetsTable.colCategory: category,
      BudgetsTable.colMonthlyLimit: monthlyLimit,
      BudgetsTable.colCreatedAt: createdAt.toIso8601String(),
    };
  }

  factory BudgetModel.fromMap(Map<String, dynamic> map) {
    return BudgetModel(
      id: map[BudgetsTable.colId] as int?,
      category: map[BudgetsTable.colCategory] as String,
      monthlyLimit: (map[BudgetsTable.colMonthlyLimit] as num).toDouble(),
      createdAt: DateTime.parse(map[BudgetsTable.colCreatedAt] as String),
    );
  }

  BudgetModel copyWith({
    int? id,
    String? category,
    double? monthlyLimit,
    DateTime? createdAt,
  }) {
    return BudgetModel(
      id: id ?? this.id,
      category: category ?? this.category,
      monthlyLimit: monthlyLimit ?? this.monthlyLimit,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class BudgetProgress {
  final BudgetModel budget;
  final double spent;

  BudgetProgress({
    required this.budget,
    required this.spent,
  });

  double get remaining => (budget.monthlyLimit - spent).clamp(0.0, double.infinity);
  double get overspent => spent > budget.monthlyLimit ? (spent - budget.monthlyLimit) : 0.0;
  bool get isOverBudget => spent > budget.monthlyLimit;
  
  double get progressRatio {
    if (budget.monthlyLimit <= 0) return 0.0;
    return (spent / budget.monthlyLimit).clamp(0.0, 1.0);
  }

  double get progressPercentage {
    if (budget.monthlyLimit <= 0) return 0.0;
    return (spent / budget.monthlyLimit) * 100.0;
  }
}
