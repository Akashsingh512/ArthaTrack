import '../../core/utils/currency_formatter.dart';

class NetWorthSnapshot {
  final double liquidBalances; // Bank savings + cash - credit cards
  final double totalAssets;    // Gold, Real Estate, Equity, FD
  final double totalDebts;     // Loans, dues

  NetWorthSnapshot({
    required this.liquidBalances,
    required this.totalAssets,
    required this.totalDebts,
  });

  /// Formula: (Liquid Bank Balances + Total Assets) - Total Debts
  double get netWorth => (liquidBalances + totalAssets) - totalDebts;

  String get formattedNetWorth => IndianCurrencyFormatter.format(netWorth);
  String get formattedLiquidBalances => IndianCurrencyFormatter.format(liquidBalances);
  String get formattedTotalAssets => IndianCurrencyFormatter.format(totalAssets);
  String get formattedTotalDebts => IndianCurrencyFormatter.format(totalDebts);

  String get compactNetWorth => IndianCurrencyFormatter.formatCompact(netWorth);
  String get compactLiquidBalances => IndianCurrencyFormatter.formatCompact(liquidBalances);
  String get compactTotalAssets => IndianCurrencyFormatter.formatCompact(totalAssets);
  String get compactTotalDebts => IndianCurrencyFormatter.formatCompact(totalDebts);
}

class NetWorthCalculator {
  static NetWorthSnapshot calculate({
    required double liquidBalances,
    required double totalAssets,
    required double totalDebts,
  }) {
    return NetWorthSnapshot(
      liquidBalances: liquidBalances,
      totalAssets: totalAssets,
      totalDebts: totalDebts,
    );
  }
}
