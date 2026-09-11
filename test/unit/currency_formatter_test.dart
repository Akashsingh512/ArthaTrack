import 'package:test/test.dart';
import '../../lib/core/utils/currency_formatter.dart';

void main() {
  group('IndianCurrencyFormatter Tests', () {
    test('Formats zero correctly', () {
      expect(IndianCurrencyFormatter.format(0.0), equals('₹0.00'));
    });

    test('Formats hundreds correctly', () {
      expect(IndianCurrencyFormatter.format(450.50), equals('₹450.50'));
    });

    test('Formats thousands correctly (3 digit rule)', () {
      expect(IndianCurrencyFormatter.format(1500.00), equals('₹1,500.00'));
      expect(IndianCurrencyFormatter.format(9999.99), equals('₹9,999.99'));
    });

    test('Formats Lakhs correctly with Indian 2-digit grouping (₹1,24,500.00)', () {
      expect(IndianCurrencyFormatter.format(124500.00), equals('₹1,24,500.00'));
      expect(IndianCurrencyFormatter.format(500000.00), equals('₹5,00,000.00'));
      expect(IndianCurrencyFormatter.format(9876543.21), equals('₹98,76,543.21'));
    });

    test('Formats Crores correctly with Indian grouping (₹1,24,50,000.00)', () {
      expect(IndianCurrencyFormatter.format(12450000.00), equals('₹1,24,50,000.00'));
      expect(IndianCurrencyFormatter.format(100000000.00), equals('₹10,00,00,000.00'));
    });

    test('Formats negative numbers correctly', () {
      expect(IndianCurrencyFormatter.format(-12500.00), equals('-₹12,500.00'));
    });

    test('Formats compact Indian representation (K, L, Cr)', () {
      expect(IndianCurrencyFormatter.formatCompact(45000.0), equals('₹45.0 K'));
      expect(IndianCurrencyFormatter.formatCompact(125000.0), equals('₹1.25 L'));
      expect(IndianCurrencyFormatter.formatCompact(25000000.0), equals('₹2.50 Cr'));
    });

    test('Parses formatted Indian currency strings accurately', () {
      expect(IndianCurrencyFormatter.parse('₹1,24,500.00'), equals(124500.00));
      expect(IndianCurrencyFormatter.parse('Rs. 450.50'), equals(450.50));
      expect(IndianCurrencyFormatter.parse('INR 25,000'), equals(25000.00));
    });
  });
}
