import '../../core/constants/indian_banking_constants.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/parsed_transaction.dart';

class EngineBRegexParser {
  /// Parses raw transaction text into structured ParsedTransaction using Indian banking regex heuristics
  static ParsedTransaction? parse(String rawText, {String? packageName}) {
    if (rawText.trim().isEmpty) return null;

    final text = rawText.trim();
    final lower = text.toLowerCase();

    // 0. STRICT SECURITY GUARD: Never parse or store OTPs or verification codes
    if (IndianBankingConstants.otpBlocklistRegex.hasMatch(text)) {
      return null;
    }

    // 0.1 PROMOTIONAL & NON-TRANSACTIONAL GUARD: Drop EMI offers, loan pitches, and bill due reminders
    if (IndianBankingConstants.promotionalBlocklistRegex.hasMatch(text)) {
      return null;
    }

    // 1. Determine Type: Expense vs Income
    TransactionType type = TransactionType.EXPENSE;
    final hasIncome = IndianBankingConstants.incomeTriggerRegex.hasMatch(lower);
    final hasExpense = IndianBankingConstants.expenseTriggerRegex.hasMatch(lower);

    if (hasIncome && !hasExpense) {
      type = TransactionType.INCOME;
    } else if (hasIncome && hasExpense) {
      // Look at order of appearance if both words exist (e.g. "refund credited" vs "failed, debited")
      final incomeMatch = IndianBankingConstants.incomeTriggerRegex.firstMatch(lower);
      final expenseMatch = IndianBankingConstants.expenseTriggerRegex.firstMatch(lower);
      if (incomeMatch != null && expenseMatch != null) {
        type = (incomeMatch.start < expenseMatch.start)
            ? TransactionType.INCOME
            : TransactionType.EXPENSE;
      }
    } else {
      type = TransactionType.EXPENSE;
    }

    // 2. Extract Amount
    double amount = 0.0;
    final amountMatch = IndianBankingConstants.amountRegex.firstMatch(text);
    if (amountMatch != null && amountMatch.groupCount >= 1) {
      final rawAmountStr = amountMatch.group(1);
      if (rawAmountStr != null) {
        amount = IndianCurrencyFormatter.parse(rawAmountStr);
      }
    }

    // Fallback amount match if standard ₹/Rs./INR prefix wasn't right next to amount
    if (amount <= 0.0) {
      final fallbackMatch = IndianBankingConstants.fallbackAmountRegex.firstMatch(text);
      if (fallbackMatch != null && fallbackMatch.groupCount >= 1) {
        final rawStr = fallbackMatch.group(1);
        if (rawStr != null) {
          amount = IndianCurrencyFormatter.parse(rawStr);
        }
      }
    }

    // If still no amount found, check if it's not a financial message
    if (amount <= 0.0) {
      return null;
    }

    // 3. Extract Available Balance if present
    double? updatedBalance;
    final balMatch = IndianBankingConstants.balanceRegex.firstMatch(text);
    if (balMatch != null && balMatch.groupCount >= 1) {
      final balStr = balMatch.group(1);
      if (balStr != null) {
        updatedBalance = IndianCurrencyFormatter.parse(balStr);
      }
    }

    // 4. Extract Account Snippet (e.g. "XX1234", "**1234" -> "1234")
    String? accountSnippet;
    final acctMatch = IndianBankingConstants.accountSnippetRegex.firstMatch(text);
    if (acctMatch != null && acctMatch.groupCount >= 1) {
      accountSnippet = acctMatch.group(1)?.replaceAll(RegExp(r'^[xX\*]+'), '');
    }

    // 5. Extract Reference / UPI / Txn ID for Deduplication
    String? referenceNumber;
    final refMatch = IndianBankingConstants.referenceNumberRegex.firstMatch(text);
    if (refMatch != null && refMatch.groupCount >= 1) {
      referenceNumber = refMatch.group(1)?.trim();
    }

    // 5.1 Extract Bank or Payment Source (e.g. "SBI Card", "Kotak Bank", "Axis Bank", "HDFC Bank")
    String? paymentSource;
    if (packageName != null && IndianBankingConstants.packageBankMap.containsKey(packageName)) {
      final mapped = IndianBankingConstants.packageBankMap[packageName];
      if (mapped != null && !mapped.contains('Google') && !mapped.contains('PhonePe') && !mapped.contains('Paytm') && !mapped.contains('CRED')) {
        paymentSource = mapped;
      }
    }
    if (paymentSource == null) {
      final bankMatch = IndianBankingConstants.bankOrSourceRegex.firstMatch(text);
      if (bankMatch != null && bankMatch.groupCount >= 1) {
        final rawBank = bankMatch.group(1);
        if (rawBank != null) {
          paymentSource = IndianBankingConstants.normalizeBankName(rawBank);
        }
      }
    }

    // 6. Extract Merchant & Category
    String merchant = _extractMerchant(text, lower, packageName);
    String category = _inferCategory(lower, merchant);

    // If income and no merchant was determined, check salary/refund
    if (type == TransactionType.INCOME && (merchant == 'Unknown' || merchant.isEmpty || merchant == 'Unknown Merchant')) {
      if (lower.contains('salary') || lower.contains('payroll')) {
        merchant = 'Employer Payroll';
        category = 'Salary';
      } else if (lower.contains('refund') || lower.contains('cashback')) {
        merchant = 'Cashback / Refund';
        category = 'Other';
      } else {
        merchant = 'Bank Credit';
        category = 'Transfer';
      }
    }

    return ParsedTransaction(
      amount: amount,
      type: type,
      category: category,
      merchant: merchant,
      updatedBalance: updatedBalance,
      accountSnippet: accountSnippet,
      referenceNumber: referenceNumber,
      paymentSource: paymentSource,
      rawText: rawText,
      engine: 'OFFLINE_REGEX',
      confidence: 0.88,
      isFinancial: true,
    );
  }

  static String _extractMerchant(String originalText, String lower, String? packageName) {
    // 1. Check known popular Indian merchants first for high accuracy
    for (final entry in IndianBankingConstants.categoryKeywords.entries) {
      for (final keyword in entry.value) {
        if (lower.contains(keyword)) {
          // Capitalize nicely
          return _capitalizeWords(keyword);
        }
      }
    }

    // 2. Try VPA / to / at regex extraction
    final vpaMatch = IndianBankingConstants.vpaOrMerchantRegex.firstMatch(originalText);
    if (vpaMatch != null && vpaMatch.groupCount >= 1) {
      var candidate = vpaMatch.group(1)?.trim();
      if (candidate != null &&
          candidate.isNotEmpty &&
          !candidate.toLowerCase().contains('your') &&
          !candidate.toLowerCase().contains('a/c') &&
          !candidate.toLowerCase().contains('account') &&
          !candidate.toLowerCase().contains('bank')) {
        // Strip trailing qualifiers: "via", "on", "ref", "upi", "avl", "bal"
        candidate = candidate.replaceAll(RegExp(r'\s+(?:via|on|ref|upi|avl|bal|ending).*$', caseSensitive: false), '').trim();
        // Remove trailing punctuation
        candidate = candidate.replaceAll(RegExp(r'[\.\,\:\-]+$'), '').trim();
        if (candidate.isNotEmpty && candidate.length > 1) {
          return _capitalizeWords(candidate);
        }
      }
    }

    return 'Unknown Merchant';
  }

  static String _inferCategory(String lowerText, String merchant) {
    final lowerMerchant = merchant.toLowerCase();

    for (final entry in IndianBankingConstants.categoryKeywords.entries) {
      final category = entry.key;
      final keywords = entry.value;

      for (final kw in keywords) {
        if (lowerMerchant.contains(kw) || lowerText.contains(kw)) {
          return category;
        }
      }
    }

    return 'Other';
  }

  static String _capitalizeWords(String str) {
    if (str.isEmpty) return str;
    return str.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }
}
