import '../lib/core/utils/currency_formatter.dart';
import '../lib/data/models/parsed_transaction.dart';
import '../lib/services/net_worth/net_worth_calculator.dart';
import '../lib/services/parsing/engine_b_regex_parser.dart';

void main() {
  print('=====================================================');
  print('   ARTHATRACK CORE ENGINE & LOGIC VERIFICATION');
  print('=====================================================\n');

  int passed = 0;
  int failed = 0;

  void assertTest(String name, bool condition, [String? details]) {
    if (condition) {
      print(' [PASS] $name');
      passed++;
    } else {
      print(' [FAIL] $name: ${details ?? "Assertion failed"}');
      failed++;
    }
  }

  // 1. Currency Formatter Tests
  print('--- Testing IndianCurrencyFormatter ---');
  assertTest('Zero format', IndianCurrencyFormatter.format(0.0) == '₹0.00');
  assertTest('Hundred format', IndianCurrencyFormatter.format(450.50) == '₹450.50');
  assertTest('Thousands format', IndianCurrencyFormatter.format(1500.00) == '₹1,500.00');
  assertTest('Lakhs format (1,24,500.00)', IndianCurrencyFormatter.format(124500.00) == '₹1,24,500.00');
  assertTest('Crores format (1,24,50,000.00)', IndianCurrencyFormatter.format(12450000.00) == '₹1,24,50,000.00');
  assertTest('Negative format', IndianCurrencyFormatter.format(-12500.00) == '-₹12,500.00');
  assertTest('Compact Thousands (45.0 K)', IndianCurrencyFormatter.formatCompact(45000.0) == '₹45.0 K');
  assertTest('Compact Lakhs (1.25 L)', IndianCurrencyFormatter.formatCompact(125000.0) == '₹1.25 L');
  assertTest('Compact Crores (2.50 Cr)', IndianCurrencyFormatter.formatCompact(25000000.0) == '₹2.50 Cr');
  assertTest('Parse Indian string', IndianCurrencyFormatter.parse('₹1,24,500.00') == 124500.00);

  // 2. Engine B Regex Parser Tests - Indian Bank SMS & Push Notifications
  print('\n--- Testing Engine B: Indian Banking Regex Parser ---');

  // Test HDFC
  final hdfc = EngineBRegexParser.parse(
    'HDFC Bank: Rs 460.00 debited from a/c **1234 on 10-09-26 to SWIGGY. Avl bal Rs 15,240.50',
  );
  assertTest(
    'HDFC Bank debited with Swiggy and Available Balance',
    hdfc != null &&
        hdfc.amount == 460.00 &&
        hdfc.type == TransactionType.EXPENSE &&
        hdfc.category == 'Food' &&
        hdfc.updatedBalance == 15240.50 &&
        hdfc.accountSnippet == '1234',
    hdfc != null ? 'Parsed: ${hdfc.toMap()}' : 'Null result',
  );

  // Test SBI Salary
  final sbi = EngineBRegexParser.parse(
    'Dear SBI User, your A/C 9876 credited by INR 75,000.00 on 01-09-26 by SALARY. Bal: INR 88,500.00',
  );
  assertTest(
    'SBI Salary credit with balance',
    sbi != null &&
        sbi.amount == 75000.00 &&
        sbi.type == TransactionType.INCOME &&
        sbi.category == 'Salary' &&
        sbi.updatedBalance == 88500.00 &&
        sbi.accountSnippet == '9876',
    sbi != null ? 'Parsed: ${sbi.toMap()}' : 'Null result',
  );

  // Test ICICI Amazon
  final icici = EngineBRegexParser.parse(
    'ICICI Bank: Acct XX4321 debited for INR 1,299.00 on 05-Sep-26 by Amazon. Bal: INR 4,320.00',
  );
  assertTest(
    'ICICI Amazon Shopping',
    icici != null &&
        icici.amount == 1299.00 &&
        icici.type == TransactionType.EXPENSE &&
        icici.category == 'Shopping' &&
        icici.updatedBalance == 4320.00 &&
        icici.accountSnippet == '4321',
    icici != null ? 'Parsed: ${icici.toMap()}' : 'Null result',
  );

  // Test PhonePe Push Notification
  final phonePe = EngineBRegexParser.parse(
    'Paid ₹350 to Starbucks on PhonePe',
    packageName: 'com.phonepe.app',
  );
  assertTest(
    'PhonePe Push to Starbucks',
    phonePe != null &&
        phonePe.amount == 350.00 &&
        phonePe.type == TransactionType.EXPENSE &&
        phonePe.category == 'Food',
    phonePe != null ? 'Parsed: ${phonePe.toMap()}' : 'Null result',
  );

  // Test Google Pay Push Notification
  final gpay = EngineBRegexParser.parse(
    'You paid ₹820 to Zepto',
    packageName: 'com.google.android.apps.nbu.paisa.user',
  );
  assertTest(
    'Google Pay Push to Zepto Groceries',
    gpay != null &&
        gpay.amount == 820.00 &&
        gpay.type == TransactionType.EXPENSE &&
        gpay.category == 'Groceries',
    gpay != null ? 'Parsed: ${gpay.toMap()}' : 'Null result',
  );

  // Test Axis Card spent on Uber
  final axis = EngineBRegexParser.parse(
    'Axis Bank: INR 320.00 spent on your Card XX9900 at Uber India on 08-09-2026. Avail Bal: INR 12,000.00',
    packageName: 'com.axis.mobile',
  );
  assertTest(
    'Axis Card spent on Uber Transit',
    axis != null &&
        axis.amount == 320.00 &&
        axis.type == TransactionType.EXPENSE &&
        axis.category == 'Travel' &&
        axis.updatedBalance == 12000.00,
    axis != null ? 'Parsed: ${axis.toMap()}' : 'Null result',
  );

  // Test Non-financial OTP rejection
  final otp = EngineBRegexParser.parse(
    'Your login OTP is 481920. Do not share it with anyone.',
  );
  assertTest(
    'Non-financial OTP rejection',
    otp == null,
    otp != null ? 'Unexpectedly parsed: ${otp.toMap()}' : null,
  );

  // 3. Net Worth Calculator Tests
  print('\n--- Testing NetWorthCalculator ---');
  final netWorthPos = NetWorthCalculator.calculate(
    liquidBalances: 54250.0,
    totalAssets: 720000.0,
    totalDebts: 185000.0,
  );
  // (54,250 + 7,20,000) - 1,85,000 = 5,89,250.00
  assertTest(
    'Positive Net Worth calculation',
    netWorthPos.netWorth == 589250.0 &&
        netWorthPos.formattedNetWorth == '₹5,89,250.00' &&
        netWorthPos.compactNetWorth == '₹5.89 L',
    'Got: ${netWorthPos.netWorth}, Formatted: ${netWorthPos.formattedNetWorth}',
  );

  final netWorthNeg = NetWorthCalculator.calculate(
    liquidBalances: 10000.0,
    totalAssets: 50000.0,
    totalDebts: 200000.0,
  );
  assertTest(
    'Deficit Net Worth calculation',
    netWorthNeg.netWorth == -140000.0 &&
        netWorthNeg.formattedNetWorth == '-₹1,40,000.00',
    'Got: ${netWorthNeg.netWorth}, Formatted: ${netWorthNeg.formattedNetWorth}',
  );

  print('\n=====================================================');
  print('Summary: $passed PASSED, $failed FAILED');
  print('=====================================================');

  if (failed > 0) {
    throw Exception('$failed assertions failed!');
  }
}
