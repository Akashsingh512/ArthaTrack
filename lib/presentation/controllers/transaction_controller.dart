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

  void setSearchQuery(String query) {
    _searchQuery = query.toLowerCase().trim();
    _applyFilters();
    notifyListeners();
  }

  void _applyFilters() {
    _filteredTransactions = _allTransactions.where((tx) {
      // Filter by type
      if (_selectedType != null && tx.type != _selectedType) {
        return false;
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
        if (!matchesMerchant && !matchesCategory && !matchesRaw) {
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
    );

    await _transactionRepo.insertTransaction(tx);
    await loadTransactions();
  }

  Future<void> deleteTransaction(int id) async {
    await _transactionRepo.deleteTransaction(id);
    await loadTransactions();
  }
}
