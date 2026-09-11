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

    // 0.2 FAILED & DECLINED STATUS GUARD: Discard failed, declined, or cancelled transactions
    if (RegExp(r'\b(?:failed|declined|unsuccessful|cancelled|timed\s*out)\b', caseSensitive: false).hasMatch(lower)) {
      if (!lower.contains('auto-reversed') && !lower.contains('refunded') && !lower.contains('reversed to') && !lower.contains('refund')) {
        return null;
      }
    }

    // 1. Determine Type: Expense vs Income
    final hasIncome = IndianBankingConstants.incomeTriggerRegex.hasMatch(lower);
    final hasExpense = IndianBankingConstants.expenseTriggerRegex.hasMatch(lower);

    // If NEITHER income nor expense trigger is present, NO completed transaction occurred!
    // (e.g. bill payment reminders, due notices, marketing) -> Drop immediately!
    if (!hasIncome && !hasExpense) {
      return null;
    }

    TransactionType type;
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
      } else {
        type = TransactionType.EXPENSE;
      }
    } else {
      type = TransactionType.EXPENSE;
    }

    // Safety guard: Acknowledgments of debt, card bill payments, or telecom/utility biller receipt confirmations are NOT income!
    if (type == TransactionType.INCOME) {
      if (lower.contains('credit card') ||
          lower.contains('received payment') ||
          lower.contains('received the payment') ||
          lower.contains('payment receipt') ||
          lower.contains('e-receipt') ||
          lower.contains('airtel number') ||
          lower.contains('jio number') ||
          lower.contains('vi number') ||
          lower.contains('airtel thanks') ||
          (lower.contains('payment of') && (lower.contains('card') || lower.contains('bill') || lower.contains('bbps') || lower.contains('airtel') || lower.contains('jio'))) ||
          (lower.contains('towards') && (lower.contains('card') || lower.contains('bill') || lower.contains('loan') || lower.contains('emi'))) ||
          (lower.contains('credited to your') && (lower.contains('card') || lower.contains('airtel') || lower.contains('jio') || lower.contains('account within')))) {
        return null;
      }
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

    // Check if this transaction was made via a Bank Credit / Debit Card
    final isCard = RegExp(r'\b(?:card\s*(?:no\.?|ending)|credit\s*card|spent\s+on.*?card|cardholder|avl\s*limit)\b', caseSensitive: false).hasMatch(text);
    final cardNumMatch = RegExp(r'(?:card\s*(?:no\.?)?\s*(?:ending)?\s*[:\s]*)([xX\*]*\d{3,4})', caseSensitive: false).firstMatch(text);
    String? cardSnippet;
    if (cardNumMatch != null && cardNumMatch.groupCount >= 1) {
      cardSnippet = cardNumMatch.group(1)?.trim().toUpperCase();
      if (cardSnippet != null && !cardSnippet.startsWith('XX') && !cardSnippet.startsWith('*')) {
        cardSnippet = 'XX$cardSnippet';
      }
    }

    if (isCard && paymentSource != null) {
      if (paymentSource.toLowerCase().contains('card')) {
        if (cardSnippet != null && !paymentSource.contains(cardSnippet)) {
          paymentSource = '$paymentSource ($cardSnippet)';
        }
      } else {
        paymentSource = cardSnippet != null
            ? '$paymentSource Card ($cardSnippet)'
            : '$paymentSource Card';
      }
    }

    // 6. Extract Merchant & Category
    String merchant = _extractMerchant(text, lower, packageName, type);
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

  /// Standalone helper to re-extract merchant name from raw SMS text
  static String? extractMerchantOnly(String rawText, TransactionType type) {
    final lower = rawText.toLowerCase();
    final res = _extractMerchant(rawText, lower, null, type);
    if (res == 'Unknown Merchant' || res.isEmpty) return null;
    return res;
  }

  static String _extractMerchant(String originalText, String lower, String? packageName, TransactionType type) {
    // 0. Remove dispute / fraud / card block footer so numbers like 919951860002 are never treated as payees
    final cleanedText = originalText.replaceAll(IndianBankingConstants.disputeFooterRegex, '').trim();

    // 1. Multi-line Card SMS check (e.g. Axis Bank card SMS with standalone merchant line)
    if (cleanedText.contains('\n')) {
      final lines = cleanedText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      for (final line in lines) {
        final lLow = line.toLowerCase();
        // Skip spent/amount lines
        if (RegExp(r'\b(?:spent|debited|credited|paid|withdrawn|transaction|charged|deducted)\b').hasMatch(lLow) ||
            RegExp(r'(?:inr|rs|₹)\s?[\d,]+').hasMatch(lLow)) {
          continue;
        }
        // Skip card/bank/account lines
        if (RegExp(r'\b(?:card|a\/c|acct|account|bank)\b').hasMatch(lLow)) {
          continue;
        }
        // Skip timestamp / date lines
        if (RegExp(r'\b\d{1,2}[-\/]\d{1,2}[-\/]\d{2,4}\b|\b\d{1,2}:\d{2}(?::\d{2})?\b').hasMatch(lLow)) {
          continue;
        }
        // Skip balance / limit lines
        if (RegExp(r'\b(?:avl|bal|balance|limit|total)\b').hasMatch(lLow)) {
          continue;
        }
        // Skip security / dispute / helpdesk lines
        if (RegExp(r'\b(?:not\s+you|dispute|block|call|report|forward|helpdesk)\b').hasMatch(lLow)) {
          continue;
        }
        final candidate = _cleanMerchantString(line);
        if (candidate != null) {
          return _capitalizeWords(candidate);
        }
      }
    }

    // 2. Inline Card SMS pattern (e.g. "17:34:28 IST SRI VENKATE Avl Limit: ...")
    final cardMatch = IndianBankingConstants.cardMerchantRegex.firstMatch(cleanedText);
    if (cardMatch != null && cardMatch.groupCount >= 1) {
      final candidate = _cleanMerchantString(cardMatch.group(1));
      if (candidate != null) {
        return _capitalizeWords(candidate);
      }
    }

    // 3. Prioritize explicit payee/merchant extraction based on transaction type
    final primaryRegex = type == TransactionType.EXPENSE
        ? IndianBankingConstants.expenseMerchantRegex
        : IndianBankingConstants.incomeMerchantRegex;

    for (final match in primaryRegex.allMatches(cleanedText)) {
      final candidate = _cleanMerchantMatch(match);
      if (candidate != null) {
        return _capitalizeWords(candidate);
      }
    }

    // 4. Fallback to general vpaOrMerchantRegex if primary regex didn't match a valid payee
    for (final match in IndianBankingConstants.vpaOrMerchantRegex.allMatches(cleanedText)) {
      final candidate = _cleanMerchantMatch(match);
      if (candidate != null) {
        return _capitalizeWords(candidate);
      }
    }

    // 5. Check known popular Indian merchants using WHOLE-WORD boundaries (\b)
    // Never use substring matching which falsely matches "via" as "vi"
    for (final entry in IndianBankingConstants.categoryKeywords.entries) {
      for (final keyword in entry.value) {
        final regex = RegExp(r'\b' + RegExp.escape(keyword) + r'\b', caseSensitive: false);
        if (regex.hasMatch(lower)) {
          return _capitalizeWords(keyword);
        }
      }
    }

    return 'Unknown Merchant';
  }

  static String? _cleanMerchantString(String? rawCandidate) {
    if (rawCandidate == null) return null;
    var candidate = rawCandidate.trim();
    if (candidate.isEmpty) return null;

    // Strip UPI handle suffix (e.g. swiggy@hdfcbank -> swiggy, seti.momos@paytm -> seti momos)
    if (candidate.contains('@')) {
      final parts = candidate.split('@');
      final prefix = parts[0].trim();
      if (!RegExp(r'^\+?[\d\s\-]+$').hasMatch(prefix) && prefix.length > 2) {
        candidate = prefix.replaceAll(RegExp(r'[\._\-]'), ' ').trim();
      }
    }

    final lowerCand = candidate.toLowerCase();
    if (lowerCand.contains('your') ||
        lowerCand.contains('a/c') ||
        lowerCand.contains('account') ||
        lowerCand.contains('bank') ||
        lowerCand.contains('card') ||
        lowerCand.contains('receipt') ||
        lowerCand.contains('download') ||
        lowerCand.contains('click') ||
        lowerCand.contains('http') ||
        lowerCand.contains('www') ||
        lowerCand.contains('billdesk')) {
      return null;
    }
    // Reject purely numeric strings, shortcodes, or phone numbers (e.g. 919951860002, 18002584455, 7876)
    if (RegExp(r'^\+?[\d\s\-]{5,}$').hasMatch(candidate) ||
        RegExp(r'^\d+$').hasMatch(candidate)) {
      return null;
    }
    // Strip trailing qualifiers: "via", "on", "ref", "upi", "avl", "bal", "ending", "dispute", "trxn"
    candidate = candidate.replaceAll(RegExp(r'\s+(?:via|on|ref|upi|avl|bal|ending|dispute|trxn).*$', caseSensitive: false), '').trim();
    // Remove trailing punctuation
    candidate = candidate.replaceAll(RegExp(r'[\.\,\:\-]+$'), '').trim();
    return (candidate.isNotEmpty && candidate.length > 1) ? candidate : null;
  }

  static String? _cleanMerchantMatch(RegExpMatch match) {
    if (match.groupCount < 1) return null;
    return _cleanMerchantString(match.group(1));
  }

  static String _inferCategory(String lowerText, String merchant) {
    final lowerMerchant = merchant.toLowerCase().trim();

    // 1. Check merchant name first with category keywords (highest accuracy)
    if (lowerMerchant.isNotEmpty && lowerMerchant != 'unknown' && lowerMerchant != 'unknown merchant') {
      for (final entry in IndianBankingConstants.categoryKeywords.entries) {
        final category = entry.key;
        final keywords = entry.value;

        for (final kw in keywords) {
          final regex = RegExp(r'\b' + RegExp.escape(kw) + r'\b', caseSensitive: false);
          if (regex.hasMatch(lowerMerchant)) {
            return category;
          }
        }
      }
    }

    // 2. Check full SMS text with category keywords
    for (final entry in IndianBankingConstants.categoryKeywords.entries) {
      final category = entry.key;
      final keywords = entry.value;

      for (final kw in keywords) {
        final regex = RegExp(r'\b' + RegExp.escape(kw) + r'\b', caseSensitive: false);
        if (regex.hasMatch(lowerText)) {
          return category;
        }
      }
    }

    // 3. Person-to-Person (P2P) transfer heuristic:
    // Individual names (e.g. Adusumalli Nikhil) without commercial suffixes are Transfers!
    if (_isPersonName(merchant)) {
      return 'Transfer';
    }

    return 'Other';
  }

  static bool _isPersonName(String merchant) {
    final trimmed = merchant.trim();
    if (trimmed.isEmpty || trimmed == 'Unknown' || trimmed == 'Unknown Merchant') return false;
    final lower = trimmed.toLowerCase();

    // Not a person if it contains commercial/store/utility keywords
    final businessWords = RegExp(
      r'\b(?:store|shop|mart|supermarket|hotel|cafe|restaurant|dhaba|baker|bakery|'
      r'enterprise|enterprises|associates|agency|agencies|solutions|infotech|'
      r'pharma|pharmacy|chemist|medical|hospital|clinic|diagnostics|dental|'
      r'petrol|fuel|cng|service|services|centre|center|point|bazaar|sweets|'
      r'pvt|ltd|limited|corp|corporation|bank|cards|telecom|broadband|recharge|'
      r'club|bar|hub|station|plaza|market|bhojan|canteen|paratha|dosa|fast\s*food)\b',
      caseSensitive: false,
    );
    if (businessWords.hasMatch(lower)) return false;

    // Check if it's 2 or 3 words containing only letters/dots (e.g. "Adusumalli Nikhil", "Ramesh Kumar")
    final words = trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length >= 2 && words.length <= 4) {
      final isAllAlpha = words.every((w) => RegExp(r'^[a-zA-Z\.]+$').hasMatch(w));
      if (isAllAlpha) return true;
    }

    return false;
  }

  static String _capitalizeWords(String str) {
    if (str.isEmpty) return str;
    return str.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }
}
