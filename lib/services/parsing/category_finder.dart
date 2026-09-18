import '../../core/constants/indian_banking_constants.dart';

/// Centralized Category Finder that maps Indian retail shops, merchants,
/// brand handles, and payment descriptions into standardized financial categories.
class CategoryFinder {
  /// Comprehensive mapping of brand identifiers to standardized category names.
  /// Keys are stored in lower-case with no whitespace or punctuation for robust matching.
  static const Map<String, String> brandToCategory = {
    // --- Food & Dining ---
    'biteandbrew': 'Food',
    'brewandbite': 'Food',
    'brew': 'Food',
    'bite': 'Food',
    'ayodhyapalace': 'Food',
    'palace': 'Food',
    'themumbaicafe': 'Food',
    '1966themumbaicafe': 'Food',
    'mumbaicafe': 'Food',
    'thesnugcuppa': 'Food',
    'snugcuppa': 'Food',
    'cuppa': 'Food',
    'smcondiments': 'Food',
    'smcondimentsandjuic': 'Food',
    'condiment': 'Food',
    'condiments': 'Food',
    'ganeshfruitjuice': 'Food',
    'sriganeshfruitjui': 'Food',
    'fruitjuice': 'Food',
    'juice': 'Food',
    'setimomos': 'Food',
    'hotmomos': 'Food',
    'momo': 'Food',
    'momos': 'Food',
    'munchmart': 'Food',
    'munchmarttechnologies': 'Food',
    'paymunchma': 'Food',
    'sumeruhotel': 'Food',
    'sumeruhote': 'Food',
    'samosapoint': 'Food',
    'samosa': 'Food',
    'srikrishnabakery': 'Food',
    'srilakshmibakery': 'Food',
    'krishnabakery': 'Food',
    'lakshmibakery': 'Food',
    'bakery': 'Food',
    'baker': 'Food',
    'cafevishala': 'Food',
    'btrbangalore': 'Food',
    'btrbangaloretiffinro': 'Food',
    'bangaloretiffin': 'Food',
    'tiffin': 'Food',
    'avighnafastfoods': 'Food',
    'fastfoods': 'Food',
    'fastfood': 'Food',
    'navabharathfoods': 'Food',
    'swish': 'Food',
    'jainsweets': 'Food',
    'sweets': 'Food',
    'sweet': 'Food',
    'bikanervala': 'Food',
    'haldiram': 'Food',
    'haldirams': 'Food',
    'eatclub': 'Food',
    'faasos': 'Food',
    'kamathsnaturalretail': 'Food',
    'naturalicecream': 'Food',
    'naturals': 'Food',
    'swiggy': 'Food',
    'zomato': 'Food',
    'starbucks': 'Food',
    'mcdonald': 'Food',
    'mcdonalds': 'Food',
    'domino': 'Food',
    'dominos': 'Food',
    'kfc': 'Food',
    'burgerking': 'Food',
    'subway': 'Food',
    'chaipoint': 'Food',
    'chaayos': 'Food',
    'cafe': 'Food',
    'coffee': 'Food',
    'restaurant': 'Food',
    'hotel': 'Food',
    'dhaba': 'Food',
    'bhojanalaya': 'Food',
    'biryani': 'Food',
    'shawarma': 'Food',
    'chaat': 'Food',
    'panipuri': 'Food',
    'tea': 'Food',
    'chai': 'Food',

    // --- Shopping & Fashion ---
    'zudio': 'Shopping',
    'sufitraders': 'Shopping',
    'krishnastationery': 'Shopping',
    'stationery': 'Shopping',
    'lovable': 'Shopping',
    'westside': 'Shopping',
    'pantaloons': 'Shopping',
    'trends': 'Shopping',
    'reliancetrends': 'Shopping',
    'maxfashion': 'Shopping',
    'snitch': 'Shopping',
    'lenskart': 'Shopping',
    'ekart': 'Shopping',
    'meesho': 'Shopping',
    'decathlon': 'Shopping',
    'croma': 'Shopping',
    'reliancedigital': 'Shopping',
    'vijaysales': 'Shopping',
    'zara': 'Shopping',
    'hm': 'Shopping',
    'uniqlo': 'Shopping',
    'amazon': 'Shopping',
    'flipkart': 'Shopping',
    'myntra': 'Shopping',
    'ajio': 'Shopping',
    'nykaa': 'Shopping',
    'purplle': 'Shopping',
    'tatacliq': 'Shopping',
    'cloth': 'Shopping',
    'clothes': 'Shopping',
    'textiles': 'Shopping',
    'garments': 'Shopping',
    'jewellers': 'Shopping',
    'jewellery': 'Shopping',
    'footwear': 'Shopping',
    'shoes': 'Shopping',
    'boutique': 'Shopping',
    'apparel': 'Shopping',

    // --- Groceries & Daily Needs ---
    'ratnadeep': 'Groceries',
    'ratnadeepsupermarket': 'Groceries',
    'kpn': 'Groceries',
    'kpnfarmfresh': 'Groceries',
    'kpnff3029hsrlayout': 'Groceries',
    'neeladri': 'Groceries',
    'neeladrivegetablesand': 'Groceries',
    'neeladrivegetable': 'Groceries',
    'shreemuthahalli': 'Groceries',
    'hasiruthota': 'Groceries',
    'venkateshfriutssho': 'Groceries',
    'ayushhypermarket': 'Groceries',
    'ayushhypermarket6': 'Groceries',
    'hypermarket': 'Groceries',
    'kumudamart': 'Groceries',
    'mamatamark': 'Groceries',
    'mahabazaar': 'Groceries',
    'sriganeshprovision': 'Groceries',
    'sriganeshprovisionst': 'Groceries',
    'provision': 'Groceries',
    'supermarket': 'Groceries',
    'mart': 'Groceries',
    'zepto': 'Groceries',
    'zeptonow': 'Groceries',
    'zeptomarketplace': 'Groceries',
    'blinkit': 'Groceries',
    'instamart': 'Groceries',
    'bigbasket': 'Groceries',
    'bbnow': 'Groceries',
    'dmart': 'Groceries',
    'vegetables': 'Groceries',
    'vegetable': 'Groceries',
    'fruits': 'Groceries',
    'fruit': 'Groceries',
    'kirana': 'Groceries',
    'dairy': 'Groceries',
    'milk': 'Groceries',
    'doodh': 'Groceries',

    // --- Travel & Commute ---
    'uber': 'Travel',
    'uberindia': 'Travel',
    'uberindiasystem': 'Travel',
    'uberindiasystems': 'Travel',
    'ptmuberin': 'Travel',
    'yulu': 'Travel',
    'yulubikes': 'Travel',
    'yulubikesprivatelimi': 'Travel',
    'bmtc': 'Travel',
    'mybmtc': 'Travel',
    'mybmtcdqr': 'Travel',
    'bmrc': 'Travel',
    'englishbmrc': 'Travel',
    'dmrc': 'Travel',
    'dmrcupi': 'Travel',
    'nammametro': 'Travel',
    'delhimetro': 'Travel',
    'metro': 'Travel',
    'chandrasekharauto': 'Travel',
    'auto': 'Travel',
    'cab': 'Travel',
    'taxi': 'Travel',
    'rickshaw': 'Travel',
    'ola': 'Travel',
    'rapido': 'Travel',
    'irctc': 'Travel',
    'redbus': 'Travel',
    'abhibus': 'Travel',
    'makemytrip': 'Travel',
    'yatra': 'Travel',
    'goibibo': 'Travel',
    'cleartrip': 'Travel',
    'fastag': 'Travel',
    'toll': 'Travel',
    'petrol': 'Travel',
    'diesel': 'Travel',
    'fuel': 'Travel',
    'hpcl': 'Travel',
    'bpcl': 'Travel',
    'iocl': 'Travel',
    'shell': 'Travel',

    // --- Entertainment & Subscriptions ---
    'youtube': 'Entertainment',
    'youtube1': 'Entertainment',
    'playstore': 'Entertainment',
    'playstore1': 'Entertainment',
    'googleplay': 'Entertainment',
    'netflix': 'Entertainment',
    'netflixupi': 'Entertainment',
    'spotify': 'Entertainment',
    'gaana': 'Entertainment',
    'jiosaavn': 'Entertainment',
    'applemusic': 'Entertainment',
    'cinephile': 'Entertainment',
    'bookmyshow': 'Entertainment',
    'pvr': 'Entertainment',
    'inox': 'Entertainment',
    'cinepolis': 'Entertainment',
    'hotstar': 'Entertainment',
    'primevideo': 'Entertainment',
    'sonyliv': 'Entertainment',
    'zee5': 'Entertainment',
    'steam': 'Entertainment',
    'playstation': 'Entertainment',

    // --- Bills & Utilities ---
    'airtel': 'Bills',
    'airtelprepaid': 'Bills',
    'airtel2': 'Bills',
    'mbbpayairtelprep': 'Bills',
    'jio': 'Bills',
    'vi': 'Bills',
    'vodafone': 'Bills',
    'bescom': 'Bills',
    'tatapower': 'Bills',
    'broadband': 'Bills',
    'electricity': 'Bills',
    'water': 'Bills',
    'gas': 'Bills',
    'recharge': 'Bills',
    'bhimrecharge': 'Bills',
    'navircbprecharge': 'Bills',
    'cheq': 'Bills',
    'cred': 'Bills',

    // --- Health & Medical ---
    'yashchemist': 'Health',
    'yashchemists': 'Health',
    'chemist': 'Health',
    'chemists': 'Health',
    'healthians': 'Health',
    'swamymedicals': 'Health',
    'sriswamymedicals': 'Health',
    'medical': 'Health',
    'medicals': 'Health',
    'pharmacy': 'Health',
    'hospital': 'Health',
    'clinic': 'Health',
    'apollo': 'Health',
    'pharmeasy': 'Health',
    '1mg': 'Health',
    'tata1mg': 'Health',
    'netmeds': 'Health',
    'medplus': 'Health',
    'diagnostics': 'Health',
    'pathology': 'Health',

    // --- Investments & Savings ---
    'groww': 'Investment',
    'growwinvest': 'Investment',
    'growwinvesttech': 'Investment',
    'achdrgroww': 'Investment',
    'zerodha': 'Investment',
    'clearingcorp': 'Investment',
    'indianclearingcorp': 'Investment',
    'iccl': 'Investment',
    'nsccl': 'Investment',
    'ksec': 'Investment',
    'kotaksecurities': 'Investment',
    'tradingaccount': 'Investment',
    'gullak': 'Investment',
    'gullaktechnologies': 'Investment',
    'angelone': 'Investment',
    'upstox': 'Investment',
    'smallcase': 'Investment',
    'kuvera': 'Investment',
    'mutualfund': 'Investment',
    'sip': 'Investment',
  };

  /// Sanitizes a merchant or query string for matching:
  /// Converts to lower case, removes technical prefixes, whitespace, and special characters.
  static String normalizeKey(String input) {
    var s = input.toLowerCase().trim();
    // Strip technical UPI / IMPS routing prefixes
    s = s.replaceFirst(RegExp(r'^(?:upi|imps)\/(?:p2m|p2a)\/(?:\d+\/)?', caseSensitive: false), '');
    s = s.replaceFirst(RegExp(r'^ach[\s\-]dr[\s\-]+', caseSensitive: false), '');
    s = s.replaceFirst(RegExp(r'^vpa\s+', caseSensitive: false), '');
    s = s.replaceFirst(RegExp(r'^(?:towards|from)\s+', caseSensitive: false), '');
    s = s.replaceFirst(RegExp(r'^www[\.\s]+', caseSensitive: false), '');
    // Remove all non-alphanumeric characters
    s = s.replaceAll(RegExp(r'[^a-z0-9]'), '');
    return s;
  }

  /// Finds the best matching category for a merchant name, query, or raw text.
  /// Returns [defaultCategory] ('Other') if no specific match is determined.
  static String findCategory(String merchantOrText, {String? lowerText, String defaultCategory = 'Other'}) {
    final trimmed = merchantOrText.trim();
    if (trimmed.isEmpty) return defaultCategory;

    final lower = trimmed.toLowerCase();
    final normalized = normalizeKey(trimmed);

    // 0. Specific Business & Overrides
    if (normalized.contains('ksec') || normalized.contains('tradingaccount')) {
      return 'Investment';
    }
    if (normalized.contains('creditcardpayment') || normalized.contains('crdpmnt')) {
      return 'Bills';
    }
    if (normalized.contains('facebook') || normalized.contains('meta') || normalized.contains('googlead') || normalized.contains('googleindia')) {
      return 'Other'; // Business / Ads
    }

    // 1. Direct and Substring Brand Matching from Directory
    for (final entry in brandToCategory.entries) {
      final brandKey = entry.key;

      // Special guards for short keywords that could appear in unrelated words
      if (brandKey == 'cred') {
        if (RegExp(r'\bcred\b').hasMatch(lower) || normalized.contains('credclub') || normalized.contains('dreamplug')) {
          return entry.value;
        }
        continue;
      }
      if (brandKey == 'brew' || brandKey == 'bite') {
        if (normalized.contains('biteandbrew') || normalized.contains('brewandbite') || RegExp(r'\b(brew|bite)\b').hasMatch(lower)) {
          return entry.value;
        }
        continue;
      }
      if (brandKey == 'tea') {
        if (RegExp(r'\btea\b').hasMatch(lower) || normalized.contains('chaipoint') || normalized.contains('chaayos')) {
          return entry.value;
        }
        continue;
      }

      // Check substring in normalized key or lower merchant
      if (normalized.contains(brandKey) || lower.contains(brandKey)) {
        return entry.value;
      }
    }

    // 2. Word Boundary Matching with IndianBankingConstants.categoryKeywords
    for (final entry in IndianBankingConstants.categoryKeywords.entries) {
      final category = entry.key;
      final keywords = entry.value;

      for (final kw in keywords) {
        if (kw.length <= 2) continue;
        final regex = RegExp(r'\b' + RegExp.escape(kw) + r'\b', caseSensitive: false);
        if (regex.hasMatch(lower)) {
          return category;
        }
      }
    }

    // 3. Optional fallback to full SMS body text if provided
    if (lowerText != null && lowerText.isNotEmpty) {
      for (final entry in IndianBankingConstants.categoryKeywords.entries) {
        final category = entry.key;
        final keywords = entry.value;

        for (final kw in keywords) {
          if (kw.length <= 2) continue;
          final regex = RegExp(r'\b' + RegExp.escape(kw) + r'\b', caseSensitive: false);
          if (regex.hasMatch(lowerText)) {
            return category;
          }
        }
      }
    }

    return defaultCategory;
  }

  /// Real-time suggestion helper for UI input fields (e.g. typing in Add Cash or Edit Transaction).
  /// Returns the detected category if high-confidence, or `null` if unknown.
  static String? suggestCategory(String query) {
    if (query.trim().length < 3) return null;
    final cat = findCategory(query);
    if (cat == 'Other') return null;
    return cat;
  }

  /// Returns user-friendly explanation of why a merchant maps to a category.
  static String getExplanation(String query) {
    final cat = findCategory(query);
    if (cat == 'Other') {
      return 'No specific shop or brand pattern detected. Defaults to Other.';
    }
    return 'Matched to "$cat" based on Indian retail and merchant directories.';
  }
}
