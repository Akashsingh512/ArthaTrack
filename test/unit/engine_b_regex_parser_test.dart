import 'package:test/test.dart';
import '../../lib/data/models/parsed_transaction.dart';
import '../../lib/services/parsing/engine_b_regex_parser.dart';

void main() {
  group('EngineBRegexParser Tests - Indian Bank Formats', () {
    test('Parses HDFC Bank debit SMS with Swiggy and Available Balance', () {
      const text =
          'HDFC Bank: Rs 460.00 debited from a/c **1234 on 10-09-26 to SWIGGY. Avl bal Rs 15,240.50';
      final result = EngineBRegexParser.parse(text);

      expect(result, isNotNull);
      expect(result!.amount, equals(460.00));
      expect(result.type, equals(TransactionType.EXPENSE));
      expect(result.merchant.toLowerCase(), contains('swiggy'));
      expect(result.category, equals('Food'));
      expect(result.updatedBalance, equals(15240.50));
      expect(result.accountSnippet, equals('1234'));
      expect(result.engine, equals('OFFLINE_REGEX'));
    });

    test('Parses SBI Salary credit SMS with Balance', () {
      const text =
          'Dear SBI User, your A/C 9876 credited by INR 75,000.00 on 01-09-26 by SALARY. Bal: INR 88,500.00';
      final result = EngineBRegexParser.parse(text);

      expect(result, isNotNull);
      expect(result!.amount, equals(75000.00));
      expect(result.type, equals(TransactionType.INCOME));
      expect(result.category, equals('Salary'));
      expect(result.updatedBalance, equals(88500.00));
      expect(result.accountSnippet, equals('9876'));
    });

    test('Parses ICICI Bank debit with Amazon Shopping', () {
      const text =
          'ICICI Bank: Acct XX4321 debited for INR 1,299.00 on 05-Sep-26 by Amazon. Bal: INR 4,320.00';
      final result = EngineBRegexParser.parse(text);

      expect(result, isNotNull);
      expect(result!.amount, equals(1299.00));
      expect(result.type, equals(TransactionType.EXPENSE));
      expect(result.merchant.toLowerCase(), contains('amazon'));
      expect(result.category, equals('Shopping'));
      expect(result.updatedBalance, equals(4320.00));
    });

    test('Parses PhonePe Push Notification to Starbucks', () {
      const text = 'Paid ₹350 to Starbucks on PhonePe';
      final result = EngineBRegexParser.parse(text, packageName: 'com.phonepe.app');

      expect(result, isNotNull);
      expect(result!.amount, equals(350.00));
      expect(result.type, equals(TransactionType.EXPENSE));
      expect(result.merchant.toLowerCase(), contains('starbucks'));
      expect(result.category, equals('Food'));
    });

    test('Parses Google Pay push notification to Zepto groceries', () {
      const text = 'You paid ₹820 to Zepto';
      final result = EngineBRegexParser.parse(text, packageName: 'com.google.android.apps.nbu.paisa.user');

      expect(result, isNotNull);
      expect(result!.amount, equals(820.00));
      expect(result.type, equals(TransactionType.EXPENSE));
      expect(result.merchant.toLowerCase(), contains('zepto'));
      expect(result.category, equals('Groceries'));
    });

    test('Parses Axis Bank credit card spent on Uber transit', () {
      const text =
          'Axis Bank: INR 320.00 spent on your Card XX9900 at Uber India on 08-09-2026. Avail Bal: INR 12,000.00';
      final result = EngineBRegexParser.parse(text, packageName: 'com.axis.mobile');

      expect(result, isNotNull);
      expect(result!.amount, equals(320.00));
      expect(result.type, equals(TransactionType.EXPENSE));
      expect(result.merchant.toLowerCase(), contains('uber'));
      expect(result.category, equals('Travel'));
      expect(result.updatedBalance, equals(12000.00));
    });

    test('Ignores non-financial texts like OTPs and login alerts', () {
      const otpText = 'Your one time password (OTP) for login is 481920. Do not share it with anyone.';
      final result = EngineBRegexParser.parse(otpText);

      expect(result, isNull);
    });
  });
}
