import '../../core/constants/indian_banking_constants.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/parsed_transaction.dart';

class EngineBRegexParser {
  /// Parses raw transaction text into structured ParsedTransaction using Indian banking regex heuristics (V3.0)
  static ParsedTransaction? parse(String rawText, {String? packageName, String? senderHeader}) {
    if (rawText.trim().isEmpty) return null;

    final text = rawText.trim();
    final lower = text.toLowerCase();

    // 0. STRICT SECURITY GUARD: Never parse or store OTPs or verification codes
    if (IndianBankingConstants.otpBlocklistRegex.hasMatch(text)) {
      return null;
    }

    // 0.1 PROMOTIONAL & NON-TRANSACTIONAL GUARD: Drop EMI offers, loan pitches, and bill due reminders
    // Ensure we do NOT drop valid bank fees (towards SMS Alert Charges) or actual EMIs (via NACH)
    final isActualTxn = lower.contains('towards sms alert') ||
        lower.contains('via nach') ||
        lower.contains('emi of') ||
        lower.contains('autopay') ||
        lower.contains('fastag');
    if (!isActualTxn && IndianBankingConstants.promotionalBlocklistRegex.hasMatch(text)) {
      return null;
    }

    // 0.2 PAYMENT REQUEST / COLLECT REQUEST GUARD: Never parse incoming payment requests
    if (IndianBankingConstants.collectRequestBlocklistRegex.hasMatch(text)) {
      return null;
    }

    // 0.3 EXTRACT TRAI SENDER BANK IF AVAILABLE
    String? headerBank;
    if (senderHeader != null && senderHeader.isNotEmpty) {
      headerBank = IndianBankingConstants.getBankFromHeader(senderHeader);
    }
    if (headerBank == null) {
      final headerMatch = RegExp(r'^(?:\[)?([A-Za-z]{2}-[A-Za-z]{6})(?:\])?[:\s]').firstMatch(text);
      if (headerMatch != null && headerMatch.groupCount >= 1) {
        headerBank = IndianBankingConstants.getBankFromHeader(headerMatch.group(1)!);
      }
    }

    // 1. Check for Reversal / Refund / Hold Released (Logical Inversion)
    final isReversalOrRefund = IndianBankingConstants.reversalRegex.hasMatch(lower);
    final isHoldReleased = IndianBankingConstants.holdReleasedRegex.hasMatch(lower);
    final isPreAuthHold = IndianBankingConstants.preAuthHoldRegex.hasMatch(lower) && !isHoldReleased;

    // 2. FAILED & DECLINED STATUS GUARD
    final isFailure = IndianBankingConstants.failureStatusRegex.hasMatch(lower);
    if (isFailure && !isReversalOrRefund && !isHoldReleased) {
      // Determine failure reason
      String reason = 'FAILED';
      if (lower.contains('insufficient')) {
        reason = 'INSUFFICIENT_FUNDS';
      } else if (lower.contains('incorrect upi pin') || lower.contains('incorrect pin') || lower.contains('wrong pin')) {
        reason = 'INCORRECT_PIN';
      } else if (lower.contains('declined')) {
        reason = 'DECLINED';
      }

      // Extract amount and details for user awareness banner
      double failAmount = 0.0;
      final amtMatch = IndianBankingConstants.amountRegex.firstMatch(text);
      if (amtMatch != null && amtMatch.groupCount >= 1) {
        final raw = amtMatch.group(1);
        if (raw != null) failAmount = IndianCurrencyFormatter.parse(raw);
      }

      // Universal account extraction
      String? acctTail;
      final uAcctMatch = IndianBankingConstants.universalAccountRegex.firstMatch(text);
      if (uAcctMatch != null && uAcctMatch.groupCount >= 1) {
        acctTail = uAcctMatch.group(1);
      }

      // Bank / payment source
      String? src = headerBank ?? _extractBankOrSource(text, packageName);

      // Support recourse
      String? recourse = _extractSupportRecourse(text);

      if (failAmount > 0.0) {
        return ParsedTransaction(
          amount: failAmount,
          type: TransactionType.EXPENSE,
          category: 'Failed Payment',
          merchant: 'Payment Failed ($reason)',
          accountSnippet: acctTail,
          paymentSource: src,
          supportRecourse: recourse,
          rawText: rawText,
          engine: 'OFFLINE_REGEX',
          confidence: 0.95,
          isFinancial: false, // DOES NOT alter ledger balance
          status: 'FAILED',
          failureReason: reason,
        );
      }
      return null;
    }

    // 3. Determine Type: Expense vs Income vs Refund
    TransactionType type;
    if (isReversalOrRefund || isHoldReleased) {
      type = TransactionType.REFUND;
    } else {
      final hasIncome = IndianBankingConstants.incomeTriggerRegex.hasMatch(lower);
      final hasExpense = IndianBankingConstants.expenseTriggerRegex.hasMatch(lower);

      if (!hasIncome && !hasExpense) {
        return null;
      }

      if (hasIncome && !hasExpense) {
        type = TransactionType.INCOME;
      } else if (hasIncome && hasExpense) {
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

      // Safety guard: Acknowledgments of debt/recharge receipts are NOT income
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
    }

    // 4. Extract Amount
    double amount = 0.0;
    final amountMatch = IndianBankingConstants.amountRegex.firstMatch(text);
    if (amountMatch != null && amountMatch.groupCount >= 1) {
      final rawAmountStr = amountMatch.group(1);
      if (rawAmountStr != null) {
        amount = IndianCurrencyFormatter.parse(rawAmountStr);
      }
    }

    if (amount <= 0.0) {
      final fallbackMatch = IndianBankingConstants.fallbackAmountRegex.firstMatch(text);
      if (fallbackMatch != null && fallbackMatch.groupCount >= 1) {
        final rawStr = fallbackMatch.group(1);
        if (rawStr != null) {
          amount = IndianCurrencyFormatter.parse(rawStr);
        }
      }
    }

    if (amount <= 0.0) {
      return null;
    }

    // 5. Extract Available Balance / Credit Limit / Wallet Balance if present
    double? updatedBalance;
    final balMatch = IndianBankingConstants.balanceRegex.firstMatch(text);
    if (balMatch != null && balMatch.groupCount >= 1) {
      final balStr = balMatch.group(1);
      if (balStr != null) {
        updatedBalance = IndianCurrencyFormatter.parse(balStr);
      }
    }

    // 6. Extract Account Snippet using Universal Account Regex
    String? accountSnippet;
    final uAcct = IndianBankingConstants.universalAccountRegex.firstMatch(text);
    if (uAcct != null && uAcct.groupCount >= 1) {
      accountSnippet = uAcct.group(1);
    }
    if (accountSnippet == null) {
      final acctMatch = IndianBankingConstants.accountSnippetRegex.firstMatch(text);
      if (acctMatch != null && acctMatch.groupCount >= 1) {
        accountSnippet = acctMatch.group(1)?.replaceAll(RegExp(r'^[xX\*]+'), '');
      }
    }

    // 7. Extract Reference / UPI RRN / UTR for Deduplication
    String? referenceNumber;
    final refMatch = IndianBankingConstants.referenceNumberRegex.firstMatch(text);
    if (refMatch != null && refMatch.groupCount >= 1) {
      referenceNumber = refMatch.group(1)?.trim();
    }

    // 8. Extract Bank or Payment Source
    String? paymentSource = headerBank;
    if (paymentSource == null) {
      paymentSource = _extractBankOrSource(text, packageName);
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

    // 9. Extract VPA handle if present
    String? vpaHandle;
    final vpaM = RegExp(r'[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64}').firstMatch(text);
    if (vpaM != null) {
      vpaHandle = vpaM.group(0);
    }

    // 10. Extract Support Recourse / Fraud Helpline & SMS Block
    final supportRecourse = _extractSupportRecourse(text);

    // 11. Edge Case Flags
    final isFastag = IndianBankingConstants.fastagRegex.hasMatch(lower) || lower.contains('fastag');
    final isRecurringMandate = IndianBankingConstants.autoMandateRegex.hasMatch(lower) ||
        lower.contains('autopay') ||
        lower.contains('nach') ||
        lower.contains('mandate');

    // 12. Extract Merchant & Category
    String merchant = _extractMerchant(text, lower, packageName, type);
    String category = _inferCategory(lower, merchant);

    // Override category for specific edge cases
    if (isFastag) {
      category = 'FASTag';
    } else if (IndianBankingConstants.bankFeeRegex.hasMatch(lower) || lower.contains('sms alert') || lower.contains('card fee')) {
      category = 'Bank Fees';
    } else if (isReversalOrRefund || isHoldReleased) {
      category = 'Refund';
    } else if (lower.contains('via nach') || lower.contains('emi of') || lower.contains('bajaj fin')) {
      category = 'Loan & EMI';
    } else if (lower.contains('sip of') || lower.contains('mutualfund')) {
      category = 'Investment';
    }

    // If income and no merchant was determined
    if (type == TransactionType.INCOME && (merchant == 'Unknown' || merchant.isEmpty || merchant == 'Unknown Merchant')) {
      if (lower.contains('salary') || lower.contains('payroll')) {
        merchant = 'Employer Payroll';
        category = 'Salary';
      } else if (lower.contains('refund') || lower.contains('cashback')) {
        merchant = 'Cashback / Refund';
        category = 'Refund';
      } else {
        merchant = 'Bank Credit';
        category = 'Transfer';
      }
    }

    // Status: PENDING_HOLD for pre-auth fuel/hotel holds
    final status = isPreAuthHold ? 'PENDING_HOLD' : 'SUCCESS';

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
      confidence: 0.92,
      isFinancial: true,
      status: status,
      vpa: vpaHandle,
      supportRecourse: supportRecourse,
      isRecurringMandate: isRecurringMandate,
      isFastag: isFastag,
    );
  }

  static String? _extractBankOrSource(String text, String? packageName) {
    if (packageName != null && IndianBankingConstants.packageBankMap.containsKey(packageName)) {
      final mapped = IndianBankingConstants.packageBankMap[packageName];
      if (mapped != null && !mapped.contains('Google') && !mapped.contains('PhonePe') && !mapped.contains('Paytm') && !mapped.contains('CRED')) {
        return mapped;
      }
    }
    final bankMatch = IndianBankingConstants.bankOrSourceRegex.firstMatch(text);
    if (bankMatch != null && bankMatch.groupCount >= 1) {
      final rawBank = bankMatch.group(1);
      if (rawBank != null) {
        return IndianBankingConstants.normalizeBankName(rawBank);
      }
    }
    return null;
  }

  static String? _extractSupportRecourse(String text) {
    final blockMatch = IndianBankingConstants.smsBlockRegex.firstMatch(text);
    final helplineMatch = IndianBankingConstants.disputeHelplineRegex.firstMatch(text);
    if (blockMatch != null && helplineMatch != null) {
      return '${blockMatch.group(0)?.trim()} • ${helplineMatch.group(0)?.trim()}';
    }
    if (blockMatch != null) return blockMatch.group(0)?.trim();
    if (helplineMatch != null) return helplineMatch.group(0)?.trim();
    return null;
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

    // 0.1 FASTag Toll Plaza check
    if (cleanedText.toLowerCase().contains('fastag')) {
      final tollMatch = RegExp(r'\bat\s+([A-Za-z0-9\s\.\*\-\@]+?toll\s+plaza[A-Za-z0-9\s]*?)(?:\s+(?:on|ref|wallet|avl|\.|\,|$))', caseSensitive: false).firstMatch(cleanedText);
      if (tollMatch != null && tollMatch.groupCount >= 1) {
        final candidate = _cleanMerchantString(tollMatch.group(1));
        if (candidate != null) return _capitalizeWords(candidate);
      }
    }

    // 0.2 NACH / EMI / AutoPay Mandates
    final nachMatch = RegExp(r'via\s+nach\s+for\s+([A-Za-z0-9\s\.\*\-\@]+?)(?:\s+(?:on|for|with|avl|\.|\,|$))', caseSensitive: false).firstMatch(cleanedText);
    if (nachMatch != null && nachMatch.groupCount >= 1) {
      final candidate = _cleanMerchantString(nachMatch.group(1));
      if (candidate != null) return _capitalizeWords(candidate);
    }
    final mandateMatch = RegExp(r'for\s+([A-Za-z0-9\s\.\*\-\@]+?)\s+mandate\b', caseSensitive: false).firstMatch(cleanedText);
    if (mandateMatch != null && mandateMatch.groupCount >= 1) {
      final candidate = _cleanMerchantString(mandateMatch.group(1));
      if (candidate != null) return _capitalizeWords(candidate);
    }
    if (cleanedText.toLowerCase().contains('sip of') && cleanedText.toLowerCase().contains('mutualfund')) {
      return 'Mutual Fund SIP';
    }

    // 0.3 Bank Charges / Fees / AMC
    if (cleanedText.toLowerCase().contains('sms alert charges')) {
      return 'SMS Alert Charges';
    }
    if (cleanedText.toLowerCase().contains('annual debit card fee') || cleanedText.toLowerCase().contains('debit card fee')) {
      return 'Annual Debit Card Fee';
    }
    final towardsMatch = RegExp(r'towards\s+([A-Za-z0-9\s\.\*\-\@]+?)(?:\s+(?:for|on|avl|bal|\.|\,|$))', caseSensitive: false).firstMatch(cleanedText);
    if (towardsMatch != null && towardsMatch.groupCount >= 1) {
      final candidate = _cleanMerchantString(towardsMatch.group(1));
      if (candidate != null && !candidate.toLowerCase().contains('your')) {
        return _capitalizeWords(candidate);
      }
    }

    // 0.4 ATM Cash Withdrawal
    if (cleanedText.toLowerCase().contains('cash withdrawal')) {
      final atmMatch = RegExp(r'at\s+(ATM\s+[A-Za-z0-9\s]+?)(?:\s+on|\.|\,|$)', caseSensitive: false).firstMatch(cleanedText);
      if (atmMatch != null && atmMatch.groupCount >= 1) {
        final candidate = _cleanMerchantString(atmMatch.group(1));
        if (candidate != null) return _capitalizeWords(candidate);
      }
      return 'ATM Cash Withdrawal';
    }

    // 0.5 For transaction at [Merchant] (e.g. HSBC: for transaction at FLIPKART INDIA)
    final txnAtMatch = RegExp(r'for\s+transaction\s+at\s+([A-Za-z0-9\s\.\*\-\@]+?)(?:\s+(?:on|ref|avl|bal|\.|\,|$))', caseSensitive: false).firstMatch(cleanedText);
    if (txnAtMatch != null && txnAtMatch.groupCount >= 1) {
      final candidate = _cleanMerchantString(txnAtMatch.group(1));
      if (candidate != null) return _capitalizeWords(candidate);
    }

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

    // Strip "VPA " prefix if captured (e.g. "to VPA food@swiggy" -> "food@swiggy")
    candidate = candidate.replaceFirst(RegExp(r'^vpa\s+', caseSensitive: false), '').trim();

    // Strip UPI handle suffix (e.g. swiggy@hdfcbank -> swiggy, food@swiggy -> swiggy)
    if (candidate.contains('@')) {
      final parts = candidate.split('@');
      final prefix = parts[0].trim();
      final suffix = parts[1].trim().toLowerCase();
      const knownBrands = ['swiggy', 'zomato', 'zepto', 'blinkit', 'uber', 'ola', 'amazon', 'flipkart'];
      if (knownBrands.contains(suffix)) {
        candidate = parts[1].trim();
      } else if (!RegExp(r'^\+?[\d\s\-]+$').hasMatch(prefix) && prefix.length > 2) {
        candidate = prefix.replaceAll(RegExp(r'[\._\-]'), ' ').trim();
      }
    }

    // Reject standalone order references (e.g. "order SMOVBRTOT34553" or "order")
    if (RegExp(r'^(?:your\s+)?order(?:\s+[A-Za-z0-9]+)?$', caseSensitive: false).hasMatch(candidate)) {
      return null;
    }

    // Strip trailing order ID references (e.g. "Zepto order SMOVBRTOT34553" -> "Zepto")
    candidate = candidate.replaceAll(RegExp(r'\s+order\s+[A-Za-z0-9]+.*$', caseSensitive: false), '').trim();

    // Reject date or timestamp strings (e.g. "on 12-09-2026", "12-09-2026 14:22:10")
    if (RegExp(r'\b\d{1,2}[-\/]\d{1,2}[-\/]\d{2,4}\b').hasMatch(candidate) ||
        RegExp(r'\b\d{1,2}:\d{2}(?::\d{2})?\b').hasMatch(candidate)) {
      return null;
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
