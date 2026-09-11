import 'package:flutter/foundation.dart';
import '../../data/models/account_model.dart';
import '../../data/models/balance_sheet_item_model.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/balance_sheet_repository.dart';

class BalanceSheetController extends ChangeNotifier {
  final AccountRepository _accountRepo;
  final BalanceSheetRepository _balanceSheetRepo;

  bool _isLoading = false;
  List<AccountModel> _accounts = [];
  List<BalanceSheetItemModel> _assets = [];
  List<BalanceSheetItemModel> _debts = [];

  double _totalLiquid = 0.0;
  double _totalAssets = 0.0;
  double _totalDebts = 0.0;

  BalanceSheetController({
    AccountRepository? accountRepo,
    BalanceSheetRepository? balanceSheetRepo,
  })  : _accountRepo = accountRepo ?? AccountRepository(),
        _balanceSheetRepo = balanceSheetRepo ?? BalanceSheetRepository();

  bool get isLoading => _isLoading;
  List<AccountModel> get accounts => _accounts;
  List<BalanceSheetItemModel> get assets => _assets;
  List<BalanceSheetItemModel> get debts => _debts;

  double get totalLiquid => _totalLiquid;
  double get totalAssets => _totalAssets;
  double get totalDebts => _totalDebts;
  double get netWorth => (_totalLiquid + _totalAssets) - _totalDebts;

  Future<void> loadBalanceSheet() async {
    _isLoading = true;
    notifyListeners();

    try {
      _accounts = await _accountRepo.getAllAccounts();
      _assets = await _balanceSheetRepo.getAssets();
      _debts = await _balanceSheetRepo.getDebts();

      _totalLiquid = await _accountRepo.getTotalLiquidBalance();
      _totalAssets = await _balanceSheetRepo.getTotalAssets();
      final manualDebts = await _balanceSheetRepo.getTotalDebts();
      final ccDues = await _accountRepo.getCreditCardDues();
      _totalDebts = manualDebts + ccDues;
    } catch (e) {
      print('Error loading balance sheet: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Account CRUD
  Future<void> addAccount({required String name, required String type, required double balance}) async {
    final acc = AccountModel(
      name: name,
      type: type,
      balance: balance,
      updatedAt: DateTime.now().toIso8601String(),
    );
    await _accountRepo.insertAccount(acc);
    await loadBalanceSheet();
  }

  Future<void> updateAccountBalance(int accountId, double newBalance) async {
    await _accountRepo.updateBalance(accountId, newBalance);
    await loadBalanceSheet();
  }

  Future<void> deleteAccount(int accountId) async {
    await _accountRepo.deleteAccount(accountId);
    await loadBalanceSheet();
  }

  // Asset CRUD
  Future<void> addAsset({
    required String name,
    required double amount,
    required String category,
    double interestRate = 0.0,
  }) async {
    final item = BalanceSheetItemModel(
      name: name,
      type: 'ASSET',
      amount: amount,
      category: category,
      interestRate: interestRate,
      updatedAt: DateTime.now().toIso8601String(),
    );
    await _balanceSheetRepo.insertItem(item);
    await loadBalanceSheet();
  }

  Future<void> updateAsset(BalanceSheetItemModel item) async {
    await _balanceSheetRepo.updateItem(item.copyWith(updatedAt: DateTime.now().toIso8601String()));
    await loadBalanceSheet();
  }

  Future<void> deleteAsset(int id) async {
    await _balanceSheetRepo.deleteItem(id);
    await loadBalanceSheet();
  }

  // Debt CRUD
  Future<void> addDebt({
    required String name,
    required double amount,
    required String category,
    double interestRate = 0.0,
  }) async {
    final item = BalanceSheetItemModel(
      name: name,
      type: 'DEBT',
      amount: amount,
      category: category,
      interestRate: interestRate,
      updatedAt: DateTime.now().toIso8601String(),
    );
    await _balanceSheetRepo.insertItem(item);
    await loadBalanceSheet();
  }

  Future<void> updateDebt(BalanceSheetItemModel item) async {
    await _balanceSheetRepo.updateItem(item.copyWith(updatedAt: DateTime.now().toIso8601String()));
    await loadBalanceSheet();
  }

  Future<void> deleteDebt(int id) async {
    await _balanceSheetRepo.deleteItem(id);
    await loadBalanceSheet();
  }
}
