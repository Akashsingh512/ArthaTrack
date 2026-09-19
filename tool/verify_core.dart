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

  // Test USD Transaction with Available Amount / Balance (Issue: User got 'spend 2.50 usd available amount is 200000')
  final usdTxn1 = EngineBRegexParser.parse(
    ' spend 2.50 usd available amount is 200000',
  );
  assertTest(
    'USD debit converts 2.50 USD to Rupees (₹210.00) and extracts 200000 available balance',
    usdTxn1 != null &&
        usdTxn1.amount == 210.00 &&
        usdTxn1.originalAmount == 2.50 &&
        usdTxn1.originalCurrency == 'USD' &&
        usdTxn1.type == TransactionType.EXPENSE &&
        usdTxn1.updatedBalance == 200000.00,
    usdTxn1 != null ? 'Parsed: ${usdTxn1.toMap()}' : 'Null result',
  );

  final usdTxn2 = EngineBRegexParser.parse(
    'Available amount is Rs 200000. Spent 2.50 usd at Amazon',
  );
  assertTest(
    'Reversed order: converts 2.50 USD to ₹210.00 and preserves Amazon merchant',
    usdTxn2 != null &&
        usdTxn2.amount == 210.00 &&
        usdTxn2.originalAmount == 2.50 &&
        usdTxn2.merchant.contains('Amazon') &&
        usdTxn2.type == TransactionType.EXPENSE &&
        usdTxn2.updatedBalance == 200000.00,
    usdTxn2 != null ? 'Parsed: ${usdTxn2.toMap()}' : 'Null result',
  );

  final usdTxn3 = EngineBRegexParser.parse(
    'Debited USD 2.50 on Card XX1234. Avail amount: 200000',
  );
  assertTest(
    'Debited prefix USD 2.50 converted to ₹210.00 with Avail amount 200000',
    usdTxn3 != null &&
        usdTxn3.amount == 210.00 &&
        usdTxn3.originalAmount == 2.50 &&
        usdTxn3.type == TransactionType.EXPENSE &&
        usdTxn3.updatedBalance == 200000.00,
    usdTxn3 != null ? 'Parsed: ${usdTxn3.toMap()}' : 'Null result',
  );

  // Test USD Transaction with Current Balance
  final usdTxn4 = EngineBRegexParser.parse(
    ' spend 2.50 usd current balance is 200000',
  );
  assertTest(
    'Current balance isolated: converts 2.50 USD to ₹210.00 and tracks 200000 as balance',
    usdTxn4 != null &&
        usdTxn4.amount == 210.00 &&
        usdTxn4.updatedBalance == 200000.00,
    usdTxn4 != null ? 'Parsed: ${usdTxn4.toMap()}' : 'Null result',
  );

  // Test multiple balances in single message
  final multiBal = EngineBRegexParser.parse(
    ' spend 2.50 usd available balance is 200000, current balance is 200000',
  );
  assertTest(
    'Multiple balances masked: converts 2.50 USD to ₹210.00 and neither balance leaks into amount',
    multiBal != null &&
        multiBal.amount == 210.00 &&
        multiBal.updatedBalance == 200000.00,
    multiBal != null ? 'Parsed: ${multiBal.toMap()}' : 'Null result',
  );

  // Test INR debit with contextual balance phrases
  final inrBal1 = EngineBRegexParser.parse(
    'A/c 1234 debited for 100. Available balance in your account is Rs 50000',
  );
  assertTest(
    'Available balance in your account: amount is ₹100 and balance is ₹50000',
    inrBal1 != null &&
        inrBal1.amount == 100.00 &&
        inrBal1.updatedBalance == 50000.00,
    inrBal1 != null ? 'Parsed: ${inrBal1.toMap()}' : 'Null result',
  );

  final inrBal2 = EngineBRegexParser.parse(
    'debited with Rs 100. Current balance for A/c 1234 is Rs 50000',
  );
  assertTest(
    'Current balance for A/c: amount is ₹100 and balance is ₹50000',
    inrBal2 != null &&
        inrBal2.amount == 100.00 &&
        inrBal2.updatedBalance == 50000.00,
    inrBal2 != null ? 'Parsed: ${inrBal2.toMap()}' : 'Null result',
  );

  final clearBalTxn = EngineBRegexParser.parse(
    'Paid 100 to Uber. Clear balance: Rs 5000. Available balance: Rs 5000.',
  );
  assertTest(
    'Clear & Available balance masked: amount is ₹100, merchant is Uber',
    clearBalTxn != null &&
        clearBalTxn.amount == 100.00 &&
        clearBalTxn.merchant.contains('Uber') &&
        clearBalTxn.updatedBalance == 5000.00,
    clearBalTxn != null ? 'Parsed: ${clearBalTxn.toMap()}' : 'Null result',
  );

  // Test Pure Balance Inquiries / Updates (Must NEVER be recorded as transactions)
  print('\n--- Testing Balance Restriction Guard: Pure Balance Notices Rejection ---');
  final balEnq1 = EngineBRegexParser.parse(
    'Dear customer, available balance in your account XX1234 is INR 25,000.00',
  );
  assertTest(
    'Pure available balance notification rejected (not recorded as transaction)',
    balEnq1 == null,
    'Unexpectedly parsed: ${balEnq1?.toMap()}',
  );

  final balEnq2 = EngineBRegexParser.parse(
    'Current balance for A/C XX1234 is Rs 50,000',
  );
  assertTest(
    'Pure current balance notification rejected (not recorded as transaction)',
    balEnq2 == null,
    'Unexpectedly parsed: ${balEnq2?.toMap()}',
  );

  final balEnq3 = EngineBRegexParser.parse(
    'Available balance: Rs 200000',
  );
  assertTest(
    'Available balance only rejected (not recorded as transaction)',
    balEnq3 == null,
    'Unexpectedly parsed: ${balEnq3?.toMap()}',
  );

  final balEnq4 = EngineBRegexParser.parse(
    'Balance enquiry request received for A/C 1234. Avail bal is Rs 10000',
  );
  assertTest(
    'Balance enquiry request rejected (not recorded as transaction)',
    balEnq4 == null,
    'Unexpectedly parsed: ${balEnq4?.toMap()}',
  );

  // Test Non-financial and Bank OTP rejections (CRITICAL SECURITY)
  print('\n--- Testing Security Guard: OTP & Authentication Rejection ---');
  final otp1 = EngineBRegexParser.parse('Your login OTP is 481920. Do not share it with anyone.');
  assertTest('Standard OTP rejection', otp1 == null, 'Unexpectedly parsed: ${otp1?.toMap()}');

  final otp2 = EngineBRegexParser.parse('Your OTP for Txn of INR 500.00 at Swiggy is 481920. Do not share with anyone.');
  assertTest('Bank transaction OTP rejection', otp2 == null, 'Unexpectedly parsed: ${otp2?.toMap()}');

  final otp3 = EngineBRegexParser.parse('SBI: 839201 is your OTP for payment of Rs 1,200.00. Valid for 5 mins.');
  assertTest('SBI valid for 5 min OTP rejection', otp3 == null, 'Unexpectedly parsed: ${otp3?.toMap()}');

  final otp4 = EngineBRegexParser.parse('HDFC Bank: Never share your secret code. Verification code is 192837.');
  assertTest('Verification code rejection', otp4 == null, 'Unexpectedly parsed: ${otp4?.toMap()}');

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
