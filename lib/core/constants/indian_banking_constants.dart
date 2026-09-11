class IndianBankingConstants {
  // Common Indian Bank Package Names & Senders
  static const Map<String, String> packageBankMap = {
    'net.hdfcbank.android': 'HDFC Bank',
    'com.sbi.lotusintouch': 'State Bank of India (SBI)',
    'com.sbi.upi': 'SBI UPI',
    'com.csam.icici.bank.imobile': 'ICICI Bank',
    'com.axis.mobile': 'Axis Bank',
    'com.kotak.bank': 'Kotak Mahindra Bank',
    'com.google.android.apps.nbu.paisa.user': 'Google Pay',
    'com.phonepe.app': 'PhonePe',
    'net.one97.paytm': 'Paytm',
    'com.dreamplug.androidapp': 'CRED',
  };

  // Known SMS Sender codes for Indian Banks
  static const Map<String, String> smsSenderBankMap = {
    'HDFCBK': 'HDFC Bank',
    'SBINB': 'SBI',
    'SBIPSG': 'SBI',
    'ICICIB': 'ICICI Bank',
    'AXISBK': 'Axis Bank',
    'KOTAKB': 'Kotak Bank',
    'INDUSB': 'IndusInd Bank',
    'IDFCFB': 'IDFC FIRST Bank',
    'PNBSMS': 'PNB',
    'PAYTMB': 'Paytm Payments Bank',
  };

  // STRICT SECURITY SHIELD: Unconditional OTP and Authentication Filter
  static final RegExp otpBlocklistRegex = RegExp(
    r'\b(otp|one[\s\-]time\s+password|verification\s+code|security\s+code|login\s+code|passcode|secret\s+code|auth\s+code|authentication\s+code|do\s+not\s+share|never\s+share|valid\s+for\s+\d+\s+min)\b',
    caseSensitive: false,
  );

  // STRICT PROMOTIONAL & NON-TRANSACTIONAL SHIELD: Filter out EMI offers, pre-approved loans, and bill alerts
  static final RegExp promotionalBlocklistRegex = RegExp(
    r'\b('
    r'convert(?:\s+\w+)?\s+(?:to|in|into)\s+(?:flexi|easy|smart|no\s*cost)?\s*emi|'
    r'flexipay|flexi\s*emi|smartemi|easyemi|dial[\s\-]an[\s\-]emi|'
    r'pre[\s\-]approved|eligible\s+for|apply\s+now|congratulations|'
    r'avail\s+(?:instant|pre[\s\-]approved|paperless)?\s*(?:loan|credit|cash)|'
    r'limit\s+(?:increase|enhancement|upgrade)|'
    r'credit\s+card\s+offer|'
    r'(?:total|min|minimum)\s+(?:amt|amount)?\s*due|'
    r'bill\s+(?:is\s+)?generated|'
    r'statement\s+for\s+your\s+(?:credit\s+card|account)|'
    r'promo\s*code|coupon\s*code|flat\s+(?:rs|inr|₹|\d+%)\s+off|'
    r'win\s+(?:upto|up\s+to)?\s*(?:rs|inr|₹)'
    r')\b',
    caseSensitive: false,
  );

  // 1. Amount Regex: Matches "Rs 450.00", "Rs. 1,240.50", "INR 500", "₹1,24,500.00", "₹ 200"
  static final RegExp amountRegex = RegExp(
    r'(?:Rs\.?|INR|₹)\s?([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  // Fallback Amount Regex: Matches cases like "paid 450.00" or "for 500.00"
  static final RegExp fallbackAmountRegex = RegExp(
    r'(?:debited\s+(?:by|for)|credited\s+(?:by|with)|paid|spent|transferred)\s+(?:Rs\.?|INR|₹)?\s?([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  // 2. Available Balance Regex
  static final RegExp balanceRegex = RegExp(
    r'(?:Bal|Avl Bal|Avl\sBalance|Balance|Avail\sBal|Available\sBalance)[:\s]+(?:Rs\.?|INR|₹)\s?([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  // 3. Action Triggers
  static final RegExp expenseTriggerRegex = RegExp(
    r'\b('
    r'debited|spent|paid|withdrawn|charged|deducted|payment\s+of|'
    r'transferred\s+to\s+(?!your\b)|'
    r'sent\s+to\s+(?!your\b)'
    r')\b',
    caseSensitive: false,
  );

  static final RegExp incomeTriggerRegex = RegExp(
    r'\b('
    r'credited|received|added|deposited|refunded|refund|cashback|salary|'
    r'credited\s+with|'
    r'transferred\s+from|transfer\s+from|'
    r'sent\s+you|received\s+from|'
    r'to\s+your\s+(?:a\/c|acct|account|bank)'
    r')\b',
    caseSensitive: false,
  );

  // 4. Reference Number Regex for Cross-Message Deduplication
  static final RegExp referenceNumberRegex = RegExp(
    r'(?:UPI\s*Ref(?:\s*[:\-]|(?:\s*No\.?[:\s]*))|Ref(?:\s*No\.?|Num\.?)?[:\s]*|RRN[:\s]*|Txn\s*(?:Id|ID|no\.?)?[:\s]*|IMPS\s*(?:Ref)?[:\s]*)\s*([A-Za-z0-9]{8,24})',
    caseSensitive: false,
  );

  // 5. Merchant & Sender Extraction Heuristics
  static final RegExp vpaOrMerchantRegex = RegExp(
    r'(?:to|at|vpa|info|towards|paid\s+to|transfer\s+from|from)\s+([A-Za-z0-9\s\.\*\-\@]+?)(?:\s+on|\s+ref|\s+upi|\s+avl|\s+bal|\.|\,|$)',
    caseSensitive: false,
  );

  // 5. Account Number Extraction (e.g. "a/c XX1234" or "A/C *5678")
  static final RegExp accountSnippetRegex = RegExp(
    r'(?:a\/c|acct|account|card)\s*(?:no\.?)?\s*([xX\*]*\d{3,4})',
    caseSensitive: false,
  );

  // Keyword to Category heuristics for popular Indian Merchants & Services
  static const Map<String, List<String>> categoryKeywords = {
    'Food': [
      'swiggy', 'zomato', 'starbucks', 'mcdonald', 'mcdonalds', 'domino',
      'dominos', 'kfc', 'burger king', 'subway', 'eatclub', 'faasos',
      'chai point', 'chaayos', 'cafe', 'coffee', 'restaurant', 'barbeque',
      'haldiram', 'bikanervala', 'pizza', 'bakery', 'sweet', 'dining'
    ],
    'Groceries': [
      'zepto', 'blinkit', 'instamart', 'bigbasket', 'dmart', 'd-mart',
      'nature\'s basket', 'grofers', 'bbnow', 'spencer', 'more retail',
      'dairy', 'milk', 'supermarket', 'kirana', 'fresho', 'country delight'
    ],
    'Travel': [
      'uber', 'ola', 'rapido', 'makemytrip', 'irctc', 'yatra', 'indigo',
      'air india', 'fastag', 'toll', 'metro', 'vistara', 'spicejet',
      'redbus', 'abhibus', 'fuel', 'petrol', 'diesel', 'hpcl', 'bpcl', 'iocl'
    ],
    'Shopping': [
      'amazon', 'flipkart', 'myntra', 'ajio', 'nykaa', 'meesho', 'zara',
      'tata cliq', 'croma', 'reliance digital', 'h&m', 'uniqlo', 'decathlon',
      'lenskart', 'purplle', 'snitch', 'max fashion', 'westside', 'pantaloons'
    ],
    'Bills': [
      'bescom', 'airtel', 'jio', 'vi', 'vodafone', 'electricity', 'water',
      'gas', 'broadband', 'billdesk', 'recharge', 'tata power', 'torrent',
      'mahavitaran', 'cesc', 'adani electricity', 'piped gas', 'dth', 'tata play'
    ],
    'Entertainment': [
      'netflix', 'spotify', 'bookmyshow', 'prime video', 'hotstar', 'pvr',
      'inox', 'cinepolis', 'sony liv', 'zee5', 'youtube', 'apple music',
      'gaana', 'jiosaavn', 'steam', 'playstation'
    ],
    'Health': [
      'apollo', 'pharmeasy', '1mg', 'tata 1mg', 'netmeds', 'hospital',
      'clinic', 'pharmacy', 'practo', 'medplus', 'diagnostic', 'dr lal',
      'metropolis', 'max healthcare', 'fortis', 'manipal'
    ],
    'Investment': [
      'zerodha', 'groww', 'kuvera', 'angel one', 'upstox', 'mutual fund',
      'sip', 'coin', 'smallcase', 'indmoney', 'etmoney', 'motilal', 'icici direct',
      'uti', 'sbi mutual', 'hdfc mutual', 'nippon'
    ],
    'Salary': [
      'salary', 'payroll', 'stipend', 'bonus', 'salary credit',
      'infosys', 'tcs', 'wipro', 'hcl', 'cognizant', 'accenture'
    ],
  };

  // Gmail Search Queries
  static const String gmailTransactionQuery =
      'debited OR credited OR spent OR "₹" OR "INR" OR "Rs."';
}
