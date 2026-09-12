import 'package:flutter_test/flutter_test.dart';
import '../../lib/data/models/parsed_transaction.dart';
import '../../lib/services/parsing/engine_b_regex_parser.dart';

void main() {
  group('EngineBRegexParser V3.0 - Spec V2.4 & V3.0 Edge Case Verification', () {
    test('1. SBI UPI Debit (VM-SBIINB)', () {
      const text =
          'Dear SBI User, your A/c ending 4321 debited by Rs 850.00 on 12Sep26 transfer to swiggy@icici Ref No 625612345678 . If not done by you, forward this SMS to 9223008333 - State Bank of India';
      final res = EngineBRegexParser.parse(text, senderHeader: 'VM-SBIINB');

      expect(res, isNotNull);
      expect(res!.amount, equals(850.00));
      expect(res.type, equals(TransactionType.EXPENSE));
      expect(res.accountSnippet, equals('4321'));
      expect(res.merchant.toLowerCase(), contains('swiggy'));
      expect(res.category, equals('Food'));
      expect(res.referenceNumber, equals('625612345678'));
      expect(res.paymentSource, equals('SBI'));
    });

    test('2. HDFC UPI Debit (AD-HDFCBK)', () {
      const text =
          'Rs.1,450.00 debited from HDFC Bank A/c **8910 on 12-SEP-26 to VPA food@swiggy (UPI Ref No 625689123456 ). Avl Bal: Rs. 24,150.20 . Report fraud: call 18002586161.';
      final res = EngineBRegexParser.parse(text, senderHeader: 'AD-HDFCBK');

      expect(res, isNotNull);
      expect(res!.amount, equals(1450.00));
      expect(res.type, equals(TransactionType.EXPENSE));
      expect(res.accountSnippet, equals('8910'));
      expect(res.merchant.toLowerCase(), contains('swiggy'));
      expect(res.category, equals('Food'));
      expect(res.referenceNumber, equals('625689123456'));
      expect(res.updatedBalance, equals(24150.20));
      expect(res.supportRecourse, contains('18002586161'));
      expect(res.paymentSource, equals('HDFC Bank'));
    });

    test('3. ICICI UPI Credit (VK-ICICIB)', () {
      const text =
          'Dear Customer, ICICI Bank Acct XX5678 credited with Rs 3,000.00 on 12-Sep-26 by account linked to UPI ID friend@oksbi. UPI Ref no 625698745123 . Avail Bal: Rs 41,200.00 .';
      final res = EngineBRegexParser.parse(text, senderHeader: 'VK-ICICIB');

      expect(res, isNotNull);
      expect(res!.amount, equals(3000.00));
      expect(res.type, equals(TransactionType.INCOME));
      expect(res.accountSnippet, equals('5678'));
      expect(res.referenceNumber, equals('625698745123'));
      expect(res.updatedBalance, equals(41200.00));
      expect(res.paymentSource, equals('ICICI Bank'));
    });

    test('4. HDFC Credit Card (BZ-HDFCCC)', () {
      const text =
          'Alert: INR 2,999.00 spent on your HDFC Bank Card ending 7890 at AMAZON INDIA on 12-SEP-26 at 15:30:12. Avl Lmt: INR 85,200.00 . Not you? SMS BLOCK CC 7890 to 5676712.';
      final res = EngineBRegexParser.parse(text, senderHeader: 'BZ-HDFCCC');

      expect(res, isNotNull);
      expect(res!.amount, equals(2999.00));
      expect(res.type, equals(TransactionType.EXPENSE));
      expect(res.accountSnippet, equals('7890'));
      expect(res.merchant.toLowerCase(), contains('amazon'));
      expect(res.category, equals('Shopping'));
      expect(res.updatedBalance, equals(85200.00));
      expect(res.supportRecourse, contains('SMS BLOCK CC 7890 to 5676712'));
    });

    test('5. SBI Card POS Retail (AX-SBICRD)', () {
      const text =
          'Rs. 1,250.00 spent on your SBI Credit Card ending 6543 at RELIANCE RETAIL on 12/09/2026. Avail Limit: Rs. 52,900.00 . If unauthorized, call 18601801290.';
      final res = EngineBRegexParser.parse(text, senderHeader: 'AX-SBICRD');

      expect(res, isNotNull);
      expect(res!.amount, equals(1250.00));
      expect(res.type, equals(TransactionType.EXPENSE));
      expect(res.accountSnippet, equals('6543'));
      expect(res.merchant.toLowerCase(), contains('reliance retail'));
      expect(res.updatedBalance, equals(52900.00));
      expect(res.supportRecourse, contains('18601801290'));
    });

    test('6. Axis Bank IMPS Transfer (JD-AXISBK)', () {
      const text =
          'Your A/c no. XX9012 has been debited for INR 10,000.00 on 12-09-2026 14:22:10 via IMPS (Ref no 625633445566 ) to RAHUL SHARMA. Avail Bal: INR 12,300.50 . Call 18604195555 if not done by you.';
      final res = EngineBRegexParser.parse(text, senderHeader: 'JD-AXISBK');

      expect(res, isNotNull);
      expect(res!.amount, equals(10000.00));
      expect(res.type, equals(TransactionType.EXPENSE));
      expect(res.accountSnippet, equals('9012'));
      expect(res.merchant.toLowerCase(), contains('rahul sharma'));
      expect(res.referenceNumber, equals('625633445566'));
      expect(res.updatedBalance, equals(12300.50));
      expect(res.supportRecourse, contains('18604195555'));
    });

    test('7. Kotak Bank ATM Cash Out (VM-KOTAKB)', () {
      const text =
          'Cash withdrawal of INR 4,000.00 done on your Kotak Bank Debit Card ending 4411 at ATM KTK001 MUMBAI on 12-Sep-2026. Avail Bal: INR 8,400.00 . Report unauthorized txn on 18602662666.';
      final res = EngineBRegexParser.parse(text, senderHeader: 'VM-KOTAKB');

      expect(res, isNotNull);
      expect(res!.amount, equals(4000.00));
      expect(res.type, equals(TransactionType.EXPENSE));
      expect(res.accountSnippet, equals('4411'));
      expect(res.merchant.toLowerCase(), contains('atm'));
      expect(res.updatedBalance, equals(8400.00));
    });

    test('8. Standard Chartered Bank UPI Debit (AD-SCBLTD)', () {
      const text =
          'INR 3,500.00 debited from SCB A/c ending 5678 on 12-Sep-2026 13:40 via UPI to ZOMATO. UPI Ref: 625611223344 . Avail Bal: INR 68,500.00 . If not you, SMS BLOCK to 9980033333.';
      final res = EngineBRegexParser.parse(text, senderHeader: 'AD-SCBLTD');

      expect(res, isNotNull);
      expect(res!.amount, equals(3500.00));
      expect(res.accountSnippet, equals('5678'));
      expect(res.merchant.toLowerCase(), contains('zomato'));
      expect(res.referenceNumber, equals('625611223344'));
      expect(res.paymentSource, equals('Standard Chartered Bank'));
      expect(res.updatedBalance, equals(68500.00));
    });

    test('9. HSBC India Card E-Commerce (VK-HSBCIN)', () {
      const text =
          'Dear Customer, INR 8,750.00 has been debited from your HSBC Account XX9988 on 12-Sep-2026 for transaction at FLIPKART INDIA. Avail Bal: INR 1,14,000.00 . For disputes, call 18002663456.';
      final res = EngineBRegexParser.parse(text, senderHeader: 'VK-HSBCIN');

      expect(res, isNotNull);
      expect(res!.amount, equals(8750.00));
      expect(res.accountSnippet, equals('9988'));
      expect(res.merchant.toLowerCase(), contains('flipkart'));
      expect(res.paymentSource, equals('HSBC India'));
      expect(res.updatedBalance, equals(114000.00));
    });

    test('10. DBS Bank IMPS Credit (VM-DBSBNK)', () {
      const text =
          'Your DBS Bank A/c ending 3321 has been credited with INR 18,500.00 on 12/09/2026 via IMPS Ref: 625699887766 . Total Balance: INR 42,100.00 . Not you? Call 18602674377 immediately.';
      final res = EngineBRegexParser.parse(text, senderHeader: 'VM-DBSBNK');

      expect(res, isNotNull);
      expect(res!.amount, equals(18500.00));
      expect(res.type, equals(TransactionType.INCOME));
      expect(res.accountSnippet, equals('3321'));
      expect(res.referenceNumber, equals('625699887766'));
      expect(res.paymentSource, equals('DBS Bank'));
      expect(res.updatedBalance, equals(42100.00));
    });

    test('11. Transaction Reversal / Refund (SBI)', () {
      const text =
          'Reversal of Rs. 499.00 processed for your A/c **4321 on 12-Sep-26. Ref: 625612. Avl Bal: Rs. 15,200.00.';
      final res = EngineBRegexParser.parse(text);

      expect(res, isNotNull);
      expect(res!.amount, equals(499.00));
      expect(res.type, equals(TransactionType.REFUND));
      expect(res.category, equals('Refund'));
      expect(res.accountSnippet, equals('4321'));
      expect(res.referenceNumber, equals('625612'));
      expect(res.updatedBalance, equals(15200.00));
    });

    test('12. Declined / Insufficient Funds (Axis Bank)', () {
      const text =
          'Txn of INR 12,000.00 on Axis Bank Card ending 7890 DECLINED due to insufficient balance on 12-Sep-26.';
      final res = EngineBRegexParser.parse(text);

      expect(res, isNotNull);
      expect(res!.status, equals('FAILED'));
      expect(res.failureReason, equals('INSUFFICIENT_FUNDS'));
      expect(res.isFinancial, isFalse);
      expect(res.amount, equals(12000.00));
      expect(res.accountSnippet, equals('7890'));
    });

    test('13. Standing AutoPay / E-Mandate (Netflix)', () {
      const text =
          'AutoPay alert: Rs. 799.00 debited from A/c XX5678 for NETFLIX INDIA mandate on 12-Sep-26. Ref: 62568899.';
      final res = EngineBRegexParser.parse(text);

      expect(res, isNotNull);
      expect(res!.amount, equals(799.00));
      expect(res.merchant.toLowerCase(), contains('netflix'));
      expect(res.category, equals('Entertainment'));
      expect(res.isRecurringMandate, isTrue);
      expect(res.referenceNumber, equals('62568899'));
    });

    test('14. Pre-Auth Fuel Hold (SCB at HPCL Petrol)', () {
      const text =
          'Hold of INR 2,500.00 placed on SCB Card 5678 at HPCL PETROL on 12-Sep-26. Avail Limit adjusted.';
      final res = EngineBRegexParser.parse(text);

      expect(res, isNotNull);
      expect(res!.status, equals('PENDING_HOLD'));
      expect(res.amount, equals(2500.00));
      expect(res.accountSnippet, equals('5678'));
      expect(res.merchant.toLowerCase(), contains('hpcl'));
    });

    test('15. Merchant Refund (HDFC)', () {
      const text =
          'Refund of Rs.1,500.00 credited to HDFC Bank A/c **8910 on 12-SEP-26. Ref: 625619874521. Avl Bal: Rs. 14,150.20.';
      final res = EngineBRegexParser.parse(text);

      expect(res, isNotNull);
      expect(res!.amount, equals(1500.00));
      expect(res.type, equals(TransactionType.REFUND));
      expect(res.category, equals('Refund'));
      expect(res.accountSnippet, equals('8910'));
      expect(res.referenceNumber, equals('625619874521'));
      expect(res.updatedBalance, equals(14150.20));
    });

    test('16. Hold Released (ICICI)', () {
      const text =
          'Hold of INR 5000.00 removed from ICICI Bank Acct XX5678. Avail Bal: INR 41,200.00. Use iMobile to check detailed statement.';
      final res = EngineBRegexParser.parse(text);

      expect(res, isNotNull);
      expect(res!.amount, equals(5000.00));
      expect(res.type, equals(TransactionType.REFUND));
      expect(res.accountSnippet, equals('5678'));
      expect(res.updatedBalance, equals(41200.00));
    });

    test('17. UPI Auth Failure Incorrect PIN (SBI)', () {
      const text =
          'UPI Txn of Rs 500.00 failed for A/c 4321 due to incorrect UPI PIN. To reset PIN, visit YONO app.';
      final res = EngineBRegexParser.parse(text);

      expect(res, isNotNull);
      expect(res!.status, equals('FAILED'));
      expect(res.failureReason, equals('INCORRECT_PIN'));
      expect(res.isFinancial, isFalse);
      expect(res.amount, equals(500.00));
      expect(res.accountSnippet, equals('4321'));
    });

    test('18. NACH / EMI Deduction (Bajaj Fin)', () {
      const text =
          'EMI of Rs 15,400.00 deducted from HDFC Bank A/c **8910 via NACH for BAJAJ FIN on 12/09/2026. Avl Bal: Rs 8,750.20.';
      final res = EngineBRegexParser.parse(text);

      expect(res, isNotNull);
      expect(res!.amount, equals(15400.00));
      expect(res.accountSnippet, equals('8910'));
      expect(res.merchant.toLowerCase(), contains('bajaj fin'));
      expect(res.category, equals('Loan & EMI'));
      expect(res.isRecurringMandate, isTrue);
      expect(res.updatedBalance, equals(8750.20));
    });

    test('19. FASTag Toll Deduction (Kherki Daula Toll Plaza)', () {
      const text =
          'Rs 150.00 deducted for FASTag XX3456 at Kherki Daula Toll Plaza on 12-Sep-26. Wallet Bal: Rs 850.00.';
      final res = EngineBRegexParser.parse(text);

      expect(res, isNotNull);
      expect(res!.amount, equals(150.00));
      expect(res.accountSnippet, equals('3456'));
      expect(res.merchant.toLowerCase(), contains('kherki daula toll plaza'));
      expect(res.category, equals('FASTag'));
      expect(res.isFastag, isTrue);
      expect(res.updatedBalance, equals(850.00));
    });

    test('20. SIP AutoPay (Kotak Mutual Fund)', () {
      const text =
          'SIP of INR 5,000.00 registered via AutoPay debited from Kotak A/c 4411. Ref: MUTUALFUND.';
      final res = EngineBRegexParser.parse(text);

      expect(res, isNotNull);
      expect(res!.amount, equals(5000.00));
      expect(res.accountSnippet, equals('4411'));
      expect(res.category, equals('Investment'));
      expect(res.isRecurringMandate, isTrue);
      expect(res.referenceNumber, equals('MUTUALFUND'));
    });

    test('21. Bank Service Charge (SBI SMS Alert Charges)', () {
      const text =
          'Rs 17.70 deducted from your A/c 4321 towards SMS Alert Charges for Q2. Avl Bal: Rs 15,182.30.';
      final res = EngineBRegexParser.parse(text);

      expect(res, isNotNull);
      expect(res!.amount, equals(17.70));
      expect(res.category, equals('Bank Fees'));
      expect(res.merchant.toLowerCase(), contains('sms alert charges'));
      expect(res.accountSnippet, equals('4321'));
      expect(res.updatedBalance, equals(15182.30));
    });

    test('22. Annual Debit Card Fee (Axis Bank AMC)', () {
      const text =
          'Annual Debit Card fee of INR 590.00 (incl GST) levied on A/c XX9012. Avail Bal: INR 12,300.50.';
      final res = EngineBRegexParser.parse(text);

      expect(res, isNotNull);
      expect(res!.amount, equals(590.00));
      expect(res.category, equals('Bank Fees'));
      expect(res.merchant.toLowerCase(), contains('annual debit card fee'));
      expect(res.accountSnippet, equals('9012'));
      expect(res.updatedBalance, equals(12300.50));
    });
  });
}
