class IndianCurrencyFormatter {
  /// Formats a number in Indian Rupee format, e.g., 124500.00 -> ₹1,24,500.00
  static String format(double amount, {bool showSymbol = true, bool showDecimals = true}) {
    final isNegative = amount < 0;
    final absAmount = amount.abs();

    final parts = absAmount.toStringAsFixed(showDecimals ? 2 : 0).split('.');
    final integerPart = parts[0];
    final decimalPart = parts.length > 1 ? parts[1] : '';

    final formattedInteger = _formatIndianInteger(integerPart);

    final buffer = StringBuffer();
    if (isNegative) {
      buffer.write('-');
    }
    if (showSymbol) {
      buffer.write('₹');
    }
    buffer.write(formattedInteger);
    if (showDecimals && decimalPart.isNotEmpty) {
      buffer.write('.');
      buffer.write(decimalPart);
    }

    return buffer.toString();
  }

  /// Formats numbers into compact Indian format, e.g., ₹1.24 L or ₹2.50 Cr
  static String formatCompact(double amount, {bool showSymbol = true}) {
    final isNegative = amount < 0;
    final absAmount = amount.abs();
    final prefix = isNegative ? '-' : '';
    final symbol = showSymbol ? '₹' : '';

    if (absAmount >= 10000000) {
      // Crores
      final cr = absAmount / 10000000;
      return '$prefix$symbol${cr.toStringAsFixed(2)} Cr';
    } else if (absAmount >= 100000) {
      // Lakhs
      final l = absAmount / 100000;
      return '$prefix$symbol${l.toStringAsFixed(2)} L';
    } else if (absAmount >= 1000) {
      // Thousands
      final k = absAmount / 1000;
      return '$prefix$symbol${k.toStringAsFixed(1)} K';
    } else {
      return format(amount, showSymbol: showSymbol, showDecimals: true);
    }
  }

  static String _formatIndianInteger(String digits) {
    if (digits.length <= 3) {
      return digits;
    }

    // Extract last 3 digits
    final lastThree = digits.substring(digits.length - 3);
    final remaining = digits.substring(0, digits.length - 3);

    // Group remaining digits in pairs of 2 from right to left
    final buffer = StringBuffer();
    for (int i = 0; i < remaining.length; i++) {
      buffer.write(remaining[i]);
      final remainingLength = remaining.length - 1 - i;
      if (remainingLength > 0 && remainingLength % 2 == 0) {
        buffer.write(',');
      }
    }

    return '${buffer.toString()},$lastThree';
  }

  /// Parses an Indian or standard currency string into a double, e.g., "1,24,500.50" -> 124500.50
  static double parse(String raw) {
    final cleaned = raw.replaceAll('₹', '').replaceAll('Rs', '').replaceAll('INR', '').replaceAll(',', '').trim();
    return double.tryParse(cleaned) ?? 0.0;
  }
}

class CurrencyFormatter {
  static String formatINR(double amount) => IndianCurrencyFormatter.format(amount, showDecimals: false);
  static String format(double amount, {bool showSymbol = true, bool showDecimals = true}) =>
      IndianCurrencyFormatter.format(amount, showSymbol: showSymbol, showDecimals: showDecimals);
  static String formatCompact(double amount, {bool showSymbol = true}) =>
      IndianCurrencyFormatter.formatCompact(amount, showSymbol: showSymbol);
}

