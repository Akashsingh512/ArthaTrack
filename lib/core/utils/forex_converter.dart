import 'dart:convert';
import 'dart:io';

class ForexConverter {
  /// Default reference exchange rates to Indian Rupee (INR)
  static final Map<String, double> _ratesToInr = {
    'USD': 84.0,   // 1 USD ~ 84.00 INR
    'EUR': 91.5,   // 1 EUR ~ 91.50 INR
    'GBP': 107.0,  // 1 GBP ~ 107.00 INR
    'AED': 22.9,   // 1 AED ~ 22.90 INR
    'SGD': 63.0,   // 1 SGD ~ 63.00 INR
    'CAD': 62.0,   // 1 CAD ~ 62.00 INR
    'AUD': 55.0,   // 1 AUD ~ 55.00 INR
    'JPY': 0.56,   // 1 JPY ~ 0.56 INR
    'INR': 1.0,
  };

  /// Returns current exchange rate for [currency] against INR
  static double getRate(String currency) {
    return _ratesToInr[currency.toUpperCase().trim()] ?? 84.0;
  }

  /// Converts a foreign amount to INR
  static double convertToInr(double amount, String currency) {
    final cur = currency.toUpperCase().trim();
    if (cur == 'INR') return amount;
    final rate = getRate(cur);
    final inr = amount * rate;
    return double.parse(inr.toStringAsFixed(2));
  }

  /// Formats original foreign currency nicely for display, e.g. "$2.50 USD"
  static String formatOriginal(double amount, String currency) {
    final cur = currency.toUpperCase().trim();
    if (cur == 'USD') return '\$${amount.toStringAsFixed(2)} USD';
    if (cur == 'EUR') return '€${amount.toStringAsFixed(2)} EUR';
    if (cur == 'GBP') return '£${amount.toStringAsFixed(2)} GBP';
    return '${amount.toStringAsFixed(2)} $cur';
  }

  /// Detects foreign currency code from a text chunk or entire SMS
  static String? detectCurrency(String text) {
    final lower = text.toLowerCase();
    if (RegExp(r'\b(?:usd|dollars?)\b|\$|us\$', caseSensitive: false).hasMatch(lower)) {
      return 'USD';
    }
    if (RegExp(r'\b(?:eur|euros?)\b|€', caseSensitive: false).hasMatch(lower)) {
      return 'EUR';
    }
    if (RegExp(r'\b(?:gbp|pounds?)\b|£', caseSensitive: false).hasMatch(lower)) {
      return 'GBP';
    }
    if (RegExp(r'\b(?:aed|dirhams?)\b', caseSensitive: false).hasMatch(lower)) {
      return 'AED';
    }
    if (RegExp(r'\bsgd\b', caseSensitive: false).hasMatch(lower)) {
      return 'SGD';
    }
    if (RegExp(r'\bcad\b', caseSensitive: false).hasMatch(lower)) {
      return 'CAD';
    }
    if (RegExp(r'\baud\b', caseSensitive: false).hasMatch(lower)) {
      return 'AUD';
    }
    return null;
  }

  static bool _isUpdating = false;
  static DateTime? _lastUpdated;

  /// Optional background refresh for live exchange rates via standard dart:io
  static Future<void> refreshRates() async {
    if (_isUpdating) return;
    if (_lastUpdated != null &&
        DateTime.now().difference(_lastUpdated!) < const Duration(hours: 12)) {
      return;
    }
    _isUpdating = true;
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 3);
      final request = await client.getUrl(Uri.parse('https://open.er-api.com/v6/latest/USD'));
      final response = await request.close().timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final rates = data['rates'] as Map<String, dynamic>?;
        if (rates != null && rates.containsKey('INR')) {
          final inrPerUsd = (rates['INR'] as num).toDouble();
          _ratesToInr['USD'] = inrPerUsd;
          for (final entry in _ratesToInr.keys.toList()) {
            if (entry == 'INR' || entry == 'USD') continue;
            if (rates.containsKey(entry)) {
              final valPerUsd = (rates[entry] as num).toDouble();
              if (valPerUsd > 0) {
                _ratesToInr[entry] = inrPerUsd / valPerUsd;
              }
            }
          }
          _lastUpdated = DateTime.now();
        }
      }
      client.close();
    } catch (_) {
      // Gracefully maintain offline default rates
    } finally {
      _isUpdating = false;
    }
  }
}
