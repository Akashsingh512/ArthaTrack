import 'package:test/test.dart';
import '../../lib/services/net_worth/net_worth_calculator.dart';

void main() {
  group('NetWorthCalculator Tests', () {
    test('Calculates positive Net Worth correctly', () {
      // Liquid: 50,000, Assets: 5,00,000, Debts: 1,50,000
      // Net Worth: (50,000 + 5,00,000) - 1,50,000 = 4,00,000
      final snapshot = NetWorthCalculator.calculate(
        liquidBalances: 50000.0,
        totalAssets: 500000.0,
        totalDebts: 150000.0,
      );

      expect(snapshot.netWorth, equals(400000.0));
      expect(snapshot.formattedNetWorth, equals('₹4,00,000.00'));
      expect(snapshot.compactNetWorth, equals('₹4.00 L'));
    });

    test('Calculates negative Net Worth / Deficit correctly', () {
      // Liquid: 10,000, Assets: 50,000, Debts: 2,00,000
      // Net Worth: (10,000 + 50,000) - 2,00,000 = -1,40,000
      final snapshot = NetWorthCalculator.calculate(
        liquidBalances: 10000.0,
        totalAssets: 500000.0,
        totalDebts: 700000.0,
      );

      expect(snapshot.netWorth, equals(-190000.0));
      expect(snapshot.formattedNetWorth, equals('-₹1,90,000.00'));
    });
  });
}
