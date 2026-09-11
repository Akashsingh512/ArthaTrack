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

  // STRICT PROMOTIONAL, NON-TRANSACTIONAL & RECEIPT SHIELD: Filter out EMI offers, pre-approved loans, bill due reminders, and payment receipts
  static final RegExp promotionalBlocklistRegex = RegExp(
    r'\b('
    r'pay\s+(?:your\s+)?(?:bill|due|amt|amount|now|before|by)|'
    r'bill\s+(?:due|is\s+due|of\s+(?:rs|inr|₹)|generated|reminder)|'
    r'due\s+(?:date|amount|by|on)|'
    r'recharge\s+(?:now|your|before)|'
    r'avoid\s+(?:late\s+fee|disconnection)|'
    r'kindly\s+pay|please\s+pay|'
    r'payment\s+(?:of\s+.*?\s+)?(?:has\s+been\s+)?received\s+towards\s+(?:your\s+)?.*?(?:card|loan|emi|bill|mobile)|'
    r'thank\s+you\s+(?:for\s+(?:your\s+|the\s+)?payment|for\s+paying|!\s*(?:we\s+have\s+)?received)|'
    r'(?:we\s+have\s+)?received\s+(?:the\s+)?payment\s+(?:of\s+.*?\s+)?(?:via\s+.*?\s+)?(?:for|towards|on|against|to|&|\.)|'
    r'e[\s\-]receipt|'
    r'payment\s+(?:of\s+.*?\s+)?(?:has\s+been\s+)?received\s+(?:for|towards|on|against|to)|'
    r'payment\s+of\s+.*?\s+towards\s+.*?(?:card|loan|emi|bill).*?(?:has\s+been\s+)?received|'
    r'(?:has\s+been\s+)?credited\s+to\s+your\s+(?:[A-Za-z0-9]+\s+)?(?:credit\s+card|card|airtel|jio|vi|account\s+within)|'
    r'for\s+your\s+(?:airtel|jio|vi)\s+number|'
    r'download\s+(?:the\s+|your\s+)?(?:payment\s+)?receipt|'
    r'convert(?:\s+\w+)?\s+(?:to|in|into)\s+(?:flexi|easy|smart|no\s*cost)?\s*emi|'
    r'flexipay|flexi\s*emi|smartemi|easyemi|dial[\s\-]an[\s\-]emi|'
    r'pre[\s\-]approved|eligible\s+for|apply\s+now|congratulations|'
    r'avail\s+(?:instant|pre[\s\-]approved|paperless)?\s*(?:loan|credit|cash)|'
    r'limit\s+(?:increase|enhancement|upgrade)|'
    r'credit\s+card\s+offer|'
    r'(?:total|min|minimum)\s+(?:amt|amount)?\s*due|'
    r'statement\s+for\s+your\s+(?:credit\s+card|account)|'
    r'promo\s*code|coupon\s*code|flat\s+(?:rs|inr|₹|\d+%)\s+off|'
    r'win\s+(?:upto|up\s+to)?\s*(?:rs|inr|₹)'
    r')\b',
    caseSensitive: false,
  );

  // STRICT PAYMENT / COLLECT REQUEST SHIELD: Drop incoming payment requests (e.g. PhonePe/GPay request to pay)
  static final RegExp collectRequestBlocklistRegex = RegExp(
    r'\b('
    r'(?:has\s+)?requested\s+(?:a\s+)?payment|'
    r'requested\s+money|'
    r'requesting\s+(?:a\s+)?payment|'
    r'tap\s+link\s+to\s+pay|'
    r'request\s+to\s+pay|'
    r'approve\s+(?:the\s+)?collect\s+request|'
    r'collect\s+request'
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
    r'(?:debited\s+(?:by|for)|credited\s+(?:by|with)|paid|spent|sent|transferred|transfer\s+of)\s+(?:Rs\.?|INR|₹)?\s?([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  // 2. Available Balance Regex
  static final RegExp balanceRegex = RegExp(
    r'(?:Bal|Avl\s*Bal|Avl\s*Balance|Balance|Avail\s*Bal|Available\s*Balance|Total\s*Avail\.?\s*Bal|A\/c\s*Bal)[:\s]*(?:is\s+)?(?:Rs\.?|INR|₹)?\s?([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  // 3. Action Triggers
  static final RegExp expenseTriggerRegex = RegExp(
    r'\b('
    r'debited|spent|paid|withdrawn|charged|deducted|payment\s+of|payment\s+to|'
    r'nach\s+debit|debit\b(?!\s+card)|'
    r'sent\b(?!\s+you\b)|'
    r'transferred\b(?!\s+from\b)|'
    r'transfer\s+(?:of\s+.*?\s+)?to|'
    r'trf\s+to'
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

  // 5. Merchant & Sender Extraction Heuristics with strict word boundaries
  static final RegExp expenseMerchantRegex = RegExp(
    r'\b(?:to|at|towards|paid\s+to|transfer\s+to|vpa|info)\b\s+([A-Za-z0-9\s\.\*\-\@]+?)(?:\s+(?:from|on|ref|upi|avl|bal|for|with)|\.|\,|$|\n)',
    caseSensitive: false,
  );

  static final RegExp incomeMerchantRegex = RegExp(
    r'\b(?:received\s+from|transfer\s+from|from|by)\b\s+([A-Za-z0-9\s\.\*\-\@]+?)(?:\s+(?:to|on|ref|upi|avl|bal|for|with)|\.|\,|$|\n)',
    caseSensitive: false,
  );

  static final RegExp vpaOrMerchantRegex = RegExp(
    r'\b(?:to|at|vpa|info|towards|paid\s+to|transfer\s+to|transfer\s+from|received\s+from|from)\b\s+([A-Za-z0-9\s\.\*\-\@]+?)(?:\s+(?:from|on|ref|upi|avl|bal|for|with)|\.|\,|$|\n)',
    caseSensitive: false,
  );

  // Fraud, dispute, and card block security footer regex
  static final RegExp disputeFooterRegex = RegExp(
    r'(?:\b(?:not\s+you\??|if\s+(?:this\s+was\s+|it\s+was\s+)?not\s+(?:done\s+by\s+|authorized\s+by\s+)?you\b|if\s+not\s+authorized|to\s+dispute|dispute\??|sms\s+block|call\s+(?:1800|1860|\+?91)|forward\s+this\s+sms\s+to|report\s+(?:fraud|at|to)|helpdesk)\b).*$',
    caseSensitive: false,
    dotAll: true,
  );

  // Bank Card inline merchant regex (e.g. "17:34:28 IST SRI VENKATE Avl Limit: ...")
  static final RegExp cardMerchantRegex = RegExp(
    r'(?:\d{2}[:\.]\d{2}(?:[:\.]\d{2})?\s*(?:IST|AM|PM)?\s+)(.+?)(?:\s+(?:Avl\s+(?:Limit|Bal|Balance)|Total\s+Bal|Bal|Limit|Not\s+you|Ref|UPI|\n|$))',
    caseSensitive: false,
    dotAll: true,
  );

  // 5. Account Number Extraction (e.g. "a/c XX1234" or "A/C *5678")
  static final RegExp accountSnippetRegex = RegExp(
    r'(?:a\/c|acct|account|card)\s*(?:no\.?)?\s*([xX\*]*\d{3,4})',
    caseSensitive: false,
  );

  // 6. Bank & Payment Source Detection Regex
  static final RegExp bankOrSourceRegex = RegExp(
    r'\b('
    r'sbi\s*(?:card|credit\s*card)?|sbicard|'
    r'sbi\s*bank|state\s*bank\s*of\s*india|\bsbi\b|'
    r'hdfc\s*(?:bank\s*card|bank|card|credit\s*card)?|\bhdfc\b|'
    r'icici\s*(?:bank\s*card|bank|card|credit\s*card)?|\bicici\b|'
    r'axis\s*(?:bank\s*card|bank|card|credit\s*card)?|\baxis\b|'
    r'kotak\s*(?:bank|mahindra\s*bank|card)?|\bkotak\b|'
    r'indusind\s*(?:bank)?|'
    r'idfc\s*(?:first\s*bank|bank|first)?|'
    r'pnb|punjab\s*national\s*bank|'
    r'canara\s*bank|bank\s*of\s*baroda|\bbob\b|'
    r'federal\s*bank|yes\s*bank|union\s*bank|'
    r'paytm\s*(?:payments\s*bank|wallet|bank)?|'
    r'airtel\s*(?:payments\s*bank|money|bank)|'
    r'cash'
    r')\b',
    caseSensitive: false,
  );

  /// Cleans and formats bank name into a clean user-facing title
  static String normalizeBankName(String raw) {
    final lower = raw.trim().toLowerCase();
    if (lower.contains('sbi card') || lower.contains('sbi credit') || lower.contains('sbicard')) return 'SBI Card';
    if (lower.contains('sbi') || lower.contains('state bank')) return 'SBI';
    if (lower.contains('hdfc card') || lower.contains('hdfc bank card') || lower.contains('hdfc credit')) return 'HDFC Card';
    if (lower.contains('hdfc')) return 'HDFC Bank';
    if (lower.contains('icici card') || lower.contains('icici bank card') || lower.contains('icici credit')) return 'ICICI Card';
    if (lower.contains('icici')) return 'ICICI Bank';
    if (lower.contains('axis card') || lower.contains('axis bank card') || lower.contains('axis credit')) return 'Axis Card';
    if (lower.contains('axis')) return 'Axis Bank';
    if (lower.contains('kotak')) return 'Kotak Bank';
    if (lower.contains('indusind')) return 'IndusInd Bank';
    if (lower.contains('idfc')) return 'IDFC FIRST Bank';
    if (lower.contains('pnb') || lower.contains('punjab national')) return 'PNB';
    if (lower.contains('canara')) return 'Canara Bank';
    if (lower.contains('baroda') || lower == 'bob') return 'Bank of Baroda';
    if (lower.contains('federal')) return 'Federal Bank';
    if (lower.contains('yes bank')) return 'Yes Bank';
    if (lower.contains('union bank')) return 'Union Bank';
    if (lower.contains('paytm')) return 'Paytm Payments Bank';
    if (lower.contains('airtel payments') || lower.contains('airtel money') || lower.contains('airtel bank')) return 'Airtel Payments Bank';
    if (lower.contains('cash')) return 'Cash in Hand';
    return raw.trim();
  }

  // Keyword to Category heuristics for popular Indian Merchants & Services
  static const Map<String, List<String>> categoryKeywords = {
    'Food': [
      'swiggy', 'zomato', 'starbucks', 'mcdonald', 'mcdonalds', 'domino',
      'dominos', 'kfc', 'burger king', 'subway', 'eatclub', 'faasos',
      'chai point', 'chaayos', 'cafe', 'coffee', 'restaurant', 'barbeque',
      'haldiram', 'bikanervala', 'pizza', 'bakery', 'baker', 'sweet', 'sweets',
      'mithai', 'dining', 'hotel', 'dhaba', 'bhojanalaya', 'tiffin', 'mess',
      'canteen', 'darshini', 'upahar', 'bhojan', 'caterer', 'caterers', 'biryani',
      'bawarchi', 'shawarma', 'chaat', 'juice', 'tea', 'chai', 'tapri', 'kitchen',
      'diner', 'rolls', 'paratha', 'dosa', 'idli', 'snack', 'snacks', 'food court',
      'bar', 'pub', 'brewery', 'restro', 'treat', 'eats'
    ],
    'Groceries': [
      'zepto', 'blinkit', 'instamart', 'bigbasket', 'dmart', 'd-mart',
      'nature\'s basket', 'grofers', 'bbnow', 'spencer', 'more retail',
      'dairy', 'milk', 'doodh', 'supermarket', 'kirana', 'fresho', 'country delight',
      'provision', 'general store', 'store', 'bazaar', 'vegetables', 'fruits',
      'sabzi', 'mandi', 'ration', 'daily needs', 'hypermarket', 'mart'
    ],
    'Travel': [
      'uber', 'ola', 'rapido', 'makemytrip', 'irctc', 'yatra', 'indigo',
      'air india', 'fastag', 'toll', 'metro', 'vistara', 'spicejet',
      'redbus', 'abhibus', 'fuel', 'petrol', 'diesel', 'cng', 'hpcl', 'bpcl', 'iocl',
      'shell', 'gas station', 'petroleum', 'auto', 'cab', 'taxi', 'parking',
      'railway', 'bus', 'flight', 'airline', 'cleartrip', 'goibibo', 'namma metro',
      'delhi metro', 'transport', 'commute'
    ],
    'Shopping': [
      'amazon', 'flipkart', 'myntra', 'ajio', 'nykaa', 'meesho', 'zara',
      'tata cliq', 'croma', 'reliance digital', 'h&m', 'uniqlo', 'decathlon',
      'lenskart', 'purplle', 'snitch', 'max fashion', 'westside', 'pantaloons',
      'cloth', 'clothes', 'textiles', 'silks', 'garments', 'jewellers', 'jewelers',
      'jewellery', 'footwear', 'shoes', 'fashion', 'tailor', 'boutique', 'hardware',
      'mobiles', 'electronics', 'stationery', 'book store', 'books', 'opticals',
      'watches', 'mall', 'retail', 'fashions', 'apparel'
    ],
    'Bills': [
      'bescom', 'airtel', 'jio', 'vi', 'vodafone', 'electricity', 'water',
      'gas', 'broadband', 'billdesk', 'recharge', 'tata power', 'torrent',
      'mahavitaran', 'cesc', 'adani electricity', 'piped gas', 'dth', 'tata play',
      'postpaid', 'prepaid', 'cylinder', 'indane', 'bharat gas', 'hp gas',
      'wifi', 'utility', 'power', 'discom', 'cable', 'maintenance'
    ],
    'Entertainment': [
      'netflix', 'spotify', 'bookmyshow', 'prime video', 'hotstar', 'pvr',
      'inox', 'cinepolis', 'sony liv', 'zee5', 'youtube', 'apple music',
      'gaana', 'jiosaavn', 'steam', 'playstation', 'cinema', 'theatre',
      'movie', 'gaming', 'game', 'amusement', 'ticket', 'event', 'club'
    ],
    'Health': [
      'apollo', 'pharmeasy', '1mg', 'tata 1mg', 'netmeds', 'hospital',
      'clinic', 'pharmacy', 'practo', 'medplus', 'diagnostic', 'dr lal',
      'metropolis', 'max healthcare', 'fortis', 'manipal', 'medical', 'chemist',
      'pharma', 'doctor', 'dr', 'diagnostics', 'pathology', 'dental', 'eyecare',
      'optical', 'nursing', 'healthcare', 'ayurvedic', 'homeopathy', 'medicos'
    ],
    'Investment': [
      'zerodha', 'groww', 'groww invest', 'kuvera', 'angel one', 'upstox', 'mutual fund',
      'sip', 'coin', 'smallcase', 'indmoney', 'etmoney', 'motilal', 'icici direct',
      'uti', 'sbi mutual', 'hdfc mutual', 'nippon', 'stocks', 'shares', 'nse',
      'bse', 'gold', 'ppf', 'nps', 'fixed deposit', 'indian clearing corp', 'iccl',
      'nsccl', 'nach'
    ],
    'Salary': [
      'salary', 'payroll', 'stipend', 'bonus', 'salary credit',
      'infosys', 'tcs', 'wipro', 'hcl', 'cognizant', 'accenture', 'tech mahindra',
      'capgemini'
    ],
  };

  // Gmail Search Queries
  static const String gmailTransactionQuery =
      'debited OR credited OR spent OR "₹" OR "INR" OR "Rs."';
}
