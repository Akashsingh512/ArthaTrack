import 'package:flutter/foundation.dart';
import '../../data/models/budget_model.dart';
import '../../data/models/transaction_model.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/balance_sheet_repository.dart';
import '../../data/repositories/budget_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../services/net_worth/net_worth_calculator.dart';

class DashboardController extends ChangeNotifier {
  final AccountRepository _accountRepo;
  final BalanceSheetRepository _balanceSheetRepo;
  final TransactionRepository _transactionRepo;
  final BudgetRepository _budgetRepo;

  bool _isLoading = false;
  NetWorthSnapshot? _netWorth;
  Map<String, double> _categoryExpenses = {};
  double _totalMonthlyExpense = 0.0;
  double _totalMonthlyIncome = 0.0;
  List<TransactionModel> _recentTransactions = [];
  List<BudgetProgress> _budgetProgressList = [];

  DashboardController({
    AccountRepository? accountRepo,
    BalanceSheetRepository? balanceSheetRepo,
    TransactionRepository? transactionRepo,
    BudgetRepository? budgetRepo,
  })  : _accountRepo = accountRepo ?? AccountRepository(),
        _balanceSheetRepo = balanceSheetRepo ?? BalanceSheetRepository(),
        _transactionRepo = transactionRepo ?? TransactionRepository(),
        _budgetRepo = budgetRepo ?? BudgetRepository();

  bool get isLoading => _isLoading;
  NetWorthSnapshot? get netWorth => _netWorth;
  Map<String, double> get categoryExpenses => _categoryExpenses;
  double get totalMonthlyExpense => _totalMonthlyExpense;
  double get totalMonthlyIncome => _totalMonthlyIncome;
  double get netCashFlow => _totalMonthlyIncome - _totalMonthlyExpense;
  List<TransactionModel> get recentTransactions => _recentTransactions;
  List<BudgetProgress> get budgetProgressList => _budgetProgressList;

  Future<void> loadDashboardData() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Calculate Net Worth: (Liquid Balances + Assets) - Debts
      final liquid = await _accountRepo.getTotalLiquidBalance();
      final assets = await _balanceSheetRepo.getTotalAssets();
      final manualDebts = await _balanceSheetRepo.getTotalDebts();
      final ccDues = await _accountRepo.getCreditCardDues();
      final totalDebts = manualDebts + ccDues;

      _netWorth = NetWorthCalculator.calculate(
        liquidBalances: liquid,
        totalAssets: assets,
        totalDebts: totalDebts,
      );

      // 2. Fetch Monthly Expense Aggregation
      final now = DateTime.now();
      _totalMonthlyExpense = await _transactionRepo.getTotalMonthlyExpenses(forMonth: now);
      _totalMonthlyIncome = await _transactionRepo.getTotalMonthlyIncome(forMonth: now);
      _categoryExpenses = await _transactionRepo.getCategoryExpenses(forMonth: now);

      // 3. Fetch Budgets Progress
      _budgetProgressList = await _budgetRepo.getBudgetProgressForCurrentMonth(forMonth: now);

      // 4. Fetch Recent Transactions
      _recentTransactions = await _transactionRepo.getRecentTransactions(limit: 10);
    } catch (e) {
      print('Error loading dashboard: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setBudget(String category, double limit) async {
    await _budgetRepo.setBudget(category, limit);
    await loadDashboardData();
  }

  Future<void> deleteBudget(String category) async {
    await _budgetRepo.deleteBudget(category);
    await loadDashboardData();
  }

  Future<void> updateAccountBalance(int accountId, double newBalance) async {
    await _accountRepo.updateBalance(accountId, newBalance);
    await loadDashboardData();
  }
}
