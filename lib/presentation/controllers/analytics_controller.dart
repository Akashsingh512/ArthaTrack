import 'package:flutter/foundation.dart';
import '../../data/models/transaction_model.dart';
import '../../data/repositories/transaction_repository.dart';

enum AnalyticsTimeRange {
  thisMonth,
  lastMonth,
  last3Months,
  allTime,
}

class MerchantSpendSummary {
  final String merchant;
  final String category;
  final double totalAmount;
  final int transactionCount;
  final double percentageOfTotal;

  MerchantSpendSummary({
    required this.merchant,
    required this.category,
    required this.totalAmount,
    required this.transactionCount,
    required this.percentageOfTotal,
  });
}

class DailySpendEntry {
  final int day;
  final DateTime date;
  final double amount;
  final int transactionCount;
  final bool isWeekend;

  DailySpendEntry({
    required this.day,
    required this.date,
    required this.amount,
    required this.transactionCount,
    required this.isWeekend,
  });
}

class AnalyticsController extends ChangeNotifier {
  final TransactionRepository _transactionRepo;

  bool _isLoading = false;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  AnalyticsTimeRange _selectedRange = AnalyticsTimeRange.thisMonth;

  List<TransactionModel> _filteredTransactions = [];
  Map<String, double> _categoryExpenses = {};
  Map<String, double> _categoryPercentages = {};
  Map<int, DailySpendEntry> _dailyExpenses = {};
  List<MerchantSpendSummary> _topMerchants = [];
  Map<String, double> _paymentModeBreakdown = {};

  double _totalExpense = 0.0;
  double _totalIncome = 0.0;
  double _netSavings = 0.0;
  double _savingsRate = 0.0;
  double _averageDailySpend = 0.0;
  int? _highestSpendDay;
  double _highestSpendAmount = 0.0;

  String? _inspectedCategory;
  int? _inspectedDay;

  AnalyticsController({TransactionRepository? transactionRepo})
      : _transactionRepo = transactionRepo ?? TransactionRepository();

  bool get isLoading => _isLoading;
  DateTime get selectedMonth => _selectedMonth;
  AnalyticsTimeRange get selectedRange => _selectedRange;

  List<TransactionModel> get filteredTransactions => _filteredTransactions;
  Map<String, double> get categoryExpenses => _categoryExpenses;
  Map<String, double> get categoryPercentages => _categoryPercentages;
  Map<int, DailySpendEntry> get dailyExpenses => _dailyExpenses;
  List<MerchantSpendSummary> get topMerchants => _topMerchants;
  Map<String, double> get paymentModeBreakdown => _paymentModeBreakdown;

  double get totalExpense => _totalExpense;
  double get totalIncome => _totalIncome;
  double get netSavings => _netSavings;
  double get savingsRate => _savingsRate;
  double get averageDailySpend => _averageDailySpend;
  int? get highestSpendDay => _highestSpendDay;
  double get highestSpendAmount => _highestSpendAmount;

  String? get inspectedCategory => _inspectedCategory;
  int? get inspectedDay => _inspectedDay;

  void selectCategoryForInspection(String? category) {
    if (_inspectedCategory == category) {
      _inspectedCategory = null;
    } else {
      _inspectedCategory = category;
    }
    notifyListeners();
  }

  void selectDayForInspection(int? day) {
    if (_inspectedDay == day) {
      _inspectedDay = null;
    } else {
      _inspectedDay = day;
    }
    notifyListeners();
  }

  void setMonth(DateTime month) {
    _selectedMonth = DateTime(month.year, month.month);
    _selectedRange = AnalyticsTimeRange.thisMonth;
    _inspectedCategory = null;
    _inspectedDay = null;
    loadAnalytics();
  }

  void setTimeRange(AnalyticsTimeRange range) {
    _selectedRange = range;
    _inspectedCategory = null;
    _inspectedDay = null;
    loadAnalytics();
  }

  void nextMonth() {
    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    _selectedRange = AnalyticsTimeRange.thisMonth;
    _inspectedCategory = null;
    _inspectedDay = null;
    loadAnalytics();
  }

  void previousMonth() {
    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    _selectedRange = AnalyticsTimeRange.thisMonth;
    _inspectedCategory = null;
    _inspectedDay = null;
    loadAnalytics();
  }

  Future<void> loadAnalytics() async {
    _isLoading = true;
    notifyListeners();

    try {
      final allTx = await _transactionRepo.getAllTransactions();
      _processTransactions(allTx);
    } catch (e) {
      print('Error loading analytics: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _processTransactions(List<TransactionModel> allTransactions) {
    // 1. Filter by Date Range
    final now = DateTime.now();
    DateTime rangeStart;
    DateTime rangeEnd;

    switch (_selectedRange) {
      case AnalyticsTimeRange.thisMonth:
        rangeStart = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
        rangeEnd = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
        break;
      case AnalyticsTimeRange.lastMonth:
        rangeStart = DateTime(now.year, now.month - 1, 1);
        rangeEnd = DateTime(now.year, now.month, 1);
        break;
      case AnalyticsTimeRange.last3Months:
        rangeStart = DateTime(now.year, now.month - 2, 1);
        rangeEnd = DateTime(now.year, now.month + 1, 1);
        break;
      case AnalyticsTimeRange.allTime:
        rangeStart = DateTime(2000, 1, 1);
        rangeEnd = DateTime(2100, 1, 1);
        break;
    }

    _filteredTransactions = allTransactions.where((tx) {
      if (tx.isFailed) return false;
      final txDate = DateTime.tryParse(tx.date);
      if (txDate == null) return false;
      return txDate.isAfter(rangeStart.subtract(const Duration(milliseconds: 1))) &&
          txDate.isBefore(rangeEnd);
    }).toList();

    // 2. Aggregate Cash Flow (Income vs Expense)
    _totalExpense = 0.0;
    _totalIncome = 0.0;
    final categoryTotals = <String, double>{};
    final merchantTotals = <String, _MerchantAccumulator>{};
    final paymentModes = <String, double>{
      'UPI': 0.0,
      'Credit Card': 0.0,
      'Debit Card': 0.0,
      'Net Banking': 0.0,
      'Cash / Other': 0.0,
    };

    // Calculate days in month for daily trend
    final daysInMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    final dailyMap = <int, _DailyAccumulator>{};
    for (int day = 1; day <= daysInMonth; day++) {
      final d = DateTime(_selectedMonth.year, _selectedMonth.month, day);
      dailyMap[day] = _DailyAccumulator(
        day: day,
        date: d,
        isWeekend: d.weekday == DateTime.saturday || d.weekday == DateTime.sunday,
      );
    }

    for (final tx in _filteredTransactions) {
      final dt = DateTime.tryParse(tx.date);

      if (tx.isExpense) {
        _totalExpense += tx.amount;

        // Category breakdown
        final cat = tx.category.isNotEmpty ? tx.category : 'Other';
        categoryTotals[cat] = (categoryTotals[cat] ?? 0.0) + tx.amount;

        // Daily breakdown (if single-month view)
        if (dt != null && dt.year == _selectedMonth.year && dt.month == _selectedMonth.month) {
          final acc = dailyMap[dt.day];
          if (acc != null) {
            acc.amount += tx.amount;
            acc.count += 1;
          }
        }

        // Top merchants accumulator
        final mName = tx.merchant.trim().isNotEmpty && tx.merchant != 'Unknown'
            ? tx.merchant.trim()
            : 'Unknown Merchant';
        final mAcc = merchantTotals.putIfAbsent(
          mName,
          () => _MerchantAccumulator(merchant: mName, category: cat),
        );
        mAcc.amount += tx.amount;
        mAcc.count += 1;

        // Payment Mode breakdown
        final pMode = _inferPaymentMode(tx);
        paymentModes[pMode] = (paymentModes[pMode] ?? 0.0) + tx.amount;
      } else if (tx.isCredit) {
        _totalIncome += tx.amount;
      }
    }

    // 3. Finalize Category Percentages
    _categoryExpenses = categoryTotals;
    _categoryPercentages = {};
    if (_totalExpense > 0) {
      for (final entry in _categoryExpenses.entries) {
        _categoryPercentages[entry.key] = (entry.value / _totalExpense) * 100.0;
      }
    }

    // 4. Finalize Daily Spending
    _dailyExpenses = {};
    _highestSpendDay = null;
    _highestSpendAmount = 0.0;

    for (final entry in dailyMap.entries) {
      final acc = entry.value;
      _dailyExpenses[entry.key] = DailySpendEntry(
        day: acc.day,
        date: acc.date,
        amount: acc.amount,
        transactionCount: acc.count,
        isWeekend: acc.isWeekend,
      );
      if (acc.amount > _highestSpendAmount) {
        _highestSpendAmount = acc.amount;
        _highestSpendDay = acc.day;
      }
    }

    // Average daily spend over the month
    final effectiveDays = (now.year == _selectedMonth.year && now.month == _selectedMonth.month)
        ? now.day.clamp(1, daysInMonth)
        : daysInMonth;
    _averageDailySpend = effectiveDays > 0 ? _totalExpense / effectiveDays : 0.0;

    // 5. Finalize Cash Flow & Savings
    _netSavings = _totalIncome - _totalExpense;
    if (_totalIncome > 0) {
      _savingsRate = (_netSavings / _totalIncome) * 100.0;
    } else {
      _savingsRate = _totalExpense > 0 ? -100.0 : 0.0;
    }

    // 6. Finalize Top Merchants (sorted descending)
    final sortedMerchants = merchantTotals.values.toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    _topMerchants = sortedMerchants.take(10).map((m) {
      final pct = _totalExpense > 0 ? (m.amount / _totalExpense) * 100.0 : 0.0;
      return MerchantSpendSummary(
        merchant: m.merchant,
        category: m.category,
        totalAmount: m.amount,
        transactionCount: m.count,
        percentageOfTotal: pct,
      );
    }).toList();

    // 7. Finalize Payment Mode Breakdown (prune zero entries)
    _paymentModeBreakdown = paymentModes;
  }

  String _inferPaymentMode(TransactionModel tx) {
    final lowerSource = (tx.paymentSource ?? '').toLowerCase();
    final lowerRaw = tx.rawText.toLowerCase();

    if (lowerSource.contains('credit card') ||
        lowerSource.contains('cc') ||
        lowerRaw.contains('credit card') ||
        lowerRaw.contains('card ending') ||
        lowerRaw.contains('spent on card')) {
      return 'Credit Card';
    }
    if (lowerSource.contains('upi') ||
        lowerRaw.contains('upi') ||
        lowerRaw.contains('vpa') ||
        lowerRaw.contains('@')) {
      return 'UPI';
    }
    if (lowerSource.contains('debit card') || lowerRaw.contains('debit card')) {
      return 'Debit Card';
    }
    if (lowerRaw.contains('imps') ||
        lowerRaw.contains('neft') ||
        lowerRaw.contains('rtgs') ||
        lowerRaw.contains('net banking')) {
      return 'Net Banking';
    }
    if (tx.source == 'MANUAL') {
      return 'Cash / Other';
    }
    return 'UPI';
  }
}

class _MerchantAccumulator {
  final String merchant;
  final String category;
  double amount = 0.0;
  int count = 0;

  _MerchantAccumulator({required this.merchant, required this.category});
}

class _DailyAccumulator {
  final int day;
  final DateTime date;
  final bool isWeekend;
  double amount = 0.0;
  int count = 0;

  _DailyAccumulator({required this.day, required this.date, required this.isWeekend});
}
