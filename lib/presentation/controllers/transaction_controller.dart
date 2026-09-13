import 'package:flutter/foundation.dart';
import '../../data/models/account_model.dart';
import '../../data/models/transaction_model.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/transaction_repository.dart';

class TransactionController extends ChangeNotifier {
  final TransactionRepository _transactionRepo;
  final AccountRepository _accountRepo;

  bool _isLoading = false;
  List<TransactionModel> _allTransactions = [];
  List<TransactionModel> _filteredTransactions = [];
  List<AccountModel> _accounts = [];

  String? _selectedType; // 'ALL', 'EXPENSE', 'INCOME'
  String? _selectedCategory;
  String _searchQuery = '';
  DateTime? _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  bool _isMultiSelectMode = false;
  final Set<int> _selectedTransactionIds = {};

  TransactionController({
    TransactionRepository? transactionRepo,
    AccountRepository? accountRepo,
  })  : _transactionRepo = transactionRepo ?? TransactionRepository(),
        _accountRepo = accountRepo ?? AccountRepository();

  bool get isLoading => _isLoading;
  List<TransactionModel> get transactions => _filteredTransactions;
  List<AccountModel> get accounts => _accounts;
  String? get selectedType => _selectedType;
  String? get selectedCategory => _selectedCategory;
  DateTime? get selectedMonth => _selectedMonth;

  bool get isMultiSelectMode => _isMultiSelectMode;
  Set<int> get selectedTransactionIds => _selectedTransactionIds;
  int get selectedCount => _selectedTransactionIds.length;

  bool get hasFailedTransactions => _allTransactions.any((t) => t.isFailed);
  int get failedCount => _allTransactions.where((t) => t.isFailed).length;

  double get filteredIncome => _filteredTransactions
      .where((t) => t.isCredit && !t.isFailed)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get filteredExpense => _filteredTransactions
      .where((t) => t.isExpense && !t.isFailed)
      .fold(0.0, (sum, t) => sum + t.amount);

  /// Returns distinct months present in all loaded transactions, newest first
  List<DateTime> get availableMonths {
    final months = <DateTime>{};
    for (final tx in _allTransactions) {
      final dt = DateTime.tryParse(tx.date);
      if (dt != null) {
        months.add(DateTime(dt.year, dt.month));
      }
    }
    // Also include current month if not present
    final now = DateTime.now();
    months.add(DateTime(now.year, now.month));

    final sorted = months.toList()..sort((a, b) => b.compareTo(a));
    return sorted;
  }

  Future<void> loadTransactions() async {
    _isLoading = true;
    notifyListeners();

    try {
      _allTransactions = await _transactionRepo.getAllTransactions();
      _accounts = await _accountRepo.getAllAccounts();
      _applyFilters();
    } catch (e) {
      print('Error loading transactions: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setTypeFilter(String? type) {
    _selectedType = (type == 'ALL') ? null : type;
    _applyFilters();
    notifyListeners();
  }

  void setCategoryFilter(String? category) {
    _selectedCategory = (category == 'ALL') ? null : category;
    _applyFilters();
    notifyListeners();
  }

  void setMonthFilter(DateTime? month) {
    _selectedMonth = month;
    _applyFilters();
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query.toLowerCase().trim();
    _applyFilters();
    notifyListeners();
  }

  void _applyFilters() {
    _filteredTransactions = _allTransactions.where((tx) {
      // Filter by month
      if (_selectedMonth != null) {
        final txDate = DateTime.tryParse(tx.date);
        if (txDate != null &&
            (txDate.year != _selectedMonth!.year || txDate.month != _selectedMonth!.month)) {
          return false;
        }
      }
      // Filter by type
      if (_selectedType != null) {
        if (_selectedType == 'FAILED') {
          if (!tx.isFailed) return false;
        } else if (_selectedType == 'EXPENSE') {
          if (!tx.isExpense || tx.isFailed) return false;
        } else if (_selectedType == 'INCOME') {
          if (!tx.isCredit || tx.isFailed) return false;
        } else if (tx.type != _selectedType) {
          return false;
        }
      }
      // Filter by category
      if (_selectedCategory != null && tx.category != _selectedCategory) {
        return false;
      }
      // Filter by search query
      if (_searchQuery.isNotEmpty) {
        final matchesMerchant = tx.merchant.toLowerCase().contains(_searchQuery);
        final matchesCategory = tx.category.toLowerCase().contains(_searchQuery);
        final matchesRaw = tx.rawText.toLowerCase().contains(_searchQuery);
        final matchesSource = (tx.paymentSource ?? '').toLowerCase().contains(_searchQuery);
        if (!matchesMerchant && !matchesCategory && !matchesRaw && !matchesSource) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Future<void> addCashTransaction({
    required double amount,
    required String type,
    required String category,
    required String merchant,
    required int accountId,
    required DateTime date,
  }) async {
    final tx = TransactionModel(
      accountId: accountId,
      amount: amount,
      type: type,
      category: category,
      merchant: merchant,
      rawText: 'Manual cash entry: $merchant ($category)',
      date: date.toIso8601String(),
      source: 'MANUAL',
      engine: 'REGEX',
      paymentSource: 'Cash in Hand',
    );

    await _transactionRepo.insertTransaction(tx);
    await loadTransactions();
  }

  Future<void> updateTransaction(TransactionModel updatedTx, {int? previousAccountId, String? previousType}) async {
    await _transactionRepo.updateTransaction(
      updatedTx,
      previousAccountId: previousAccountId,
      previousType: previousType,
    );
    await loadTransactions();
  }

  Future<void> deleteTransaction(int id) async {
    await _transactionRepo.deleteTransaction(id);
    await loadTransactions();
  }

  // --- Multi-Select Bulk Actions ---

  void enterMultiSelectMode([int? initialId]) {
    _isMultiSelectMode = true;
    _selectedTransactionIds.clear();
    if (initialId != null) {
      _selectedTransactionIds.add(initialId);
    }
    notifyListeners();
  }

  void exitMultiSelectMode() {
    _isMultiSelectMode = false;
    _selectedTransactionIds.clear();
    notifyListeners();
  }

  void toggleTransactionSelection(int id) {
    if (_selectedTransactionIds.contains(id)) {
      _selectedTransactionIds.remove(id);
      if (_selectedTransactionIds.isEmpty) {
        _isMultiSelectMode = false;
      }
    } else {
      _selectedTransactionIds.add(id);
    }
    notifyListeners();
  }

  void selectAllFiltered() {
    for (final t in _filteredTransactions) {
      if (t.id != null) _selectedTransactionIds.add(t.id!);
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedTransactionIds.clear();
    notifyListeners();
  }

  Future<int> bulkCategorize(String newCategory) async {
    if (_selectedTransactionIds.isEmpty) return 0;
    final ids = _selectedTransactionIds.toList();
    final count = await _transactionRepo.bulkUpdateCategory(ids, newCategory);
    exitMultiSelectMode();
    await loadTransactions();
    return count;
  }
}
