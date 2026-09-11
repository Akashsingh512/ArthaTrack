import '../../core/constants/indian_banking_constants.dart';
import '../../services/parsing/engine_b_regex_parser.dart';
import 'parsed_transaction.dart';

class TransactionModel {
  final int? id;
  final int accountId;
  final double amount;
  final String type; // 'EXPENSE' or 'INCOME'
  final String category;
  final String merchant;
  final String rawText;
  final String date;
  final String source; // 'NOTIFICATION', 'EMAIL', 'MANUAL'
  final String engine; // 'AI', 'REGEX'
  final String? referenceNumber;
  final String? paymentSource;

  TransactionModel({
    this.id,
    required this.accountId,
    required this.amount,
    required this.type,
    required this.category,
    required this.merchant,
    required this.rawText,
    required this.date,
    this.source = 'NOTIFICATION',
    this.engine = 'REGEX',
    this.referenceNumber,
    this.paymentSource,
  });

  TransactionModel copyWith({
    int? id,
    int? accountId,
    double? amount,
    String? type,
    String? category,
    String? merchant,
    String? rawText,
    String? date,
    String? source,
    String? engine,
    String? referenceNumber,
    String? paymentSource,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      merchant: merchant ?? this.merchant,
      rawText: rawText ?? this.rawText,
      date: date ?? this.date,
      source: source ?? this.source,
      engine: engine ?? this.engine,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      paymentSource: paymentSource ?? this.paymentSource,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'account_id': accountId,
      'amount': amount,
      'type': type,
      'category': category,
      'merchant': merchant,
      'raw_text': rawText,
      'date': date,
      'source': source,
      'engine': engine,
      'reference_number': referenceNumber,
      'payment_source': paymentSource,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    String? source = map['payment_source'] as String?;
    final raw = map['raw_text'] as String? ?? '';
    String merch = map['merchant'] as String? ?? 'Unknown';
    String cat = map['category'] as String? ?? 'Other';

    // Auto-heal missing or generic payment_source from rawText
    if ((source == null || source.isEmpty || source == 'Primary Bank Account') && raw.isNotEmpty) {
      final bankMatch = IndianBankingConstants.bankOrSourceRegex.firstMatch(raw);
      if (bankMatch != null && bankMatch.groupCount >= 1) {
        final rawBank = bankMatch.group(1);
        if (rawBank != null) {
          source = IndianBankingConstants.normalizeBankName(rawBank);
        }
      }
    }

    // Auto-heal generic bank name to specific Card account if card number is present in raw_text
    final isCard = RegExp(r'\b(?:card\s*(?:no\.?|ending)|credit\s*card|spent\s+on.*?card|cardholder|avl\s*limit)\b', caseSensitive: false).hasMatch(raw);
    if (isCard && raw.isNotEmpty) {
      final cardNumMatch = RegExp(r'(?:card\s*(?:no\.?)?\s*(?:ending)?\s*[:\s]*)([xX\*]*\d{3,4})', caseSensitive: false).firstMatch(raw);
      if (cardNumMatch != null && cardNumMatch.groupCount >= 1) {
        var cardSnippet = cardNumMatch.group(1)?.trim().toUpperCase();
        if (cardSnippet != null && !cardSnippet.startsWith('XX') && !cardSnippet.startsWith('*')) {
          cardSnippet = 'XX$cardSnippet';
        }
        if (cardSnippet != null) {
          final baseSource = source ?? 'Bank';
          if (!baseSource.contains(cardSnippet)) {
            if (baseSource.toLowerCase().contains('card')) {
              source = '$baseSource ($cardSnippet)';
            } else {
              source = '$baseSource Card ($cardSnippet)';
            }
          }
        }
      }
    }

    // Auto-heal false 'Vi' merchant caused by 'via UPI' in earlier builds
    if (merch.toLowerCase() == 'vi' && raw.isNotEmpty) {
      final textWithoutVia = raw.replaceAll(RegExp(r'\bvia\b', caseSensitive: false), '');
      final hasRealVi = RegExp(r'\bvi\b', caseSensitive: false).hasMatch(textWithoutVia);
      if (!hasRealVi) {
        final vpaMatch = IndianBankingConstants.vpaOrMerchantRegex.firstMatch(raw);
        if (vpaMatch != null && vpaMatch.groupCount >= 1) {
          var cand = vpaMatch.group(1)?.trim();
          if (cand != null &&
              cand.isNotEmpty &&
              !cand.toLowerCase().contains('your') &&
              !cand.toLowerCase().contains('a/c') &&
              !cand.toLowerCase().contains('account') &&
              !cand.toLowerCase().contains('bank')) {
            cand = cand.replaceAll(RegExp(r'\s+(?:via|on|ref|upi|avl|bal|ending|dispute|trxn).*$', caseSensitive: false), '').trim();
            cand = cand.replaceAll(RegExp(r'[\.\,\:\-]+$'), '').trim();
            if (cand.isNotEmpty && cand.length > 1) {
              merch = cand;
              if (cat.toLowerCase() == 'bills' || cat.toLowerCase() == 'travel') {
                cat = 'Other';
              }
            }
          }
        }
      }
    }

    // Auto-heal phone number / helpdesk merchant mistakenly parsed from dispute footers (e.g. 919951860002)
    if ((RegExp(r'^\+?[\d\s\-]{5,}$').hasMatch(merch.trim()) || RegExp(r'^\d+$').hasMatch(merch.trim())) && raw.isNotEmpty) {
      final tType = (map['type'] as String? ?? 'EXPENSE').toUpperCase() == 'INCOME'
          ? TransactionType.INCOME
          : TransactionType.EXPENSE;
      final healed = EngineBRegexParser.extractMerchantOnly(raw, tType);
      if (healed != null && healed.isNotEmpty && healed != 'Unknown Merchant') {
        merch = healed;
        if (cat.toLowerCase() == 'travel' || cat.toLowerCase() == 'bills') {
          cat = 'Other';
        }
      }
    }

    return TransactionModel(
      id: map['id'] as int?,
      accountId: map['account_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      type: map['type'] as String,
      category: cat,
      merchant: merch,
      rawText: raw,
      date: map['date'] as String,
      source: map['source'] as String? ?? 'MANUAL',
      engine: map['engine'] as String? ?? 'REGEX',
      referenceNumber: map['reference_number'] as String?,
      paymentSource: source,
    );
  }

  bool get isExpense => type.toUpperCase() == 'EXPENSE';
  bool get isIncome => type.toUpperCase() == 'INCOME';

  /// Clean payment source label for UI display with automatic inference fallback
  String get displayPaymentSource {
    if (paymentSource != null &&
        paymentSource!.trim().isNotEmpty &&
        paymentSource != 'Primary Bank Account') {
      return paymentSource!;
    }
    if (rawText.isNotEmpty) {
      final bankMatch = IndianBankingConstants.bankOrSourceRegex.firstMatch(rawText);
      if (bankMatch != null && bankMatch.groupCount >= 1) {
        final rawBank = bankMatch.group(1);
        if (rawBank != null) {
          final norm = IndianBankingConstants.normalizeBankName(rawBank);
          final isCard = RegExp(r'\b(?:card\s*(?:no\.?|ending)|credit\s*card|spent\s+on.*?card|cardholder|avl\s*limit)\b', caseSensitive: false).hasMatch(rawText);
          final cardNumMatch = RegExp(r'(?:card\s*(?:no\.?)?\s*(?:ending)?\s*[:\s]*)([xX\*]*\d{3,4})', caseSensitive: false).firstMatch(rawText);
          if (isCard && cardNumMatch != null && cardNumMatch.groupCount >= 1) {
            var cnum = cardNumMatch.group(1)?.trim().toUpperCase() ?? '';
            if (cnum.isNotEmpty && !cnum.startsWith('XX') && !cnum.startsWith('*')) cnum = 'XX$cnum';
            return norm.toLowerCase().contains('card') ? '$norm ($cnum)' : '$norm Card ($cnum)';
          }
          return norm;
        }
      }
    }
    return paymentSource ?? 'Primary Bank Account';
  }

  factory TransactionModel.fromParsed({
    required ParsedTransaction parsed,
    required int accountId,
    required String source,
    DateTime? date,
  }) {
    return TransactionModel(
      accountId: accountId,
      amount: parsed.amount,
      type: parsed.type.name,
      category: parsed.category,
      merchant: parsed.merchant,
      rawText: parsed.rawText,
      date: (date ?? DateTime.now()).toIso8601String(),
      source: source,
      engine: parsed.engine.startsWith('AI') ? 'AI' : 'REGEX',
      referenceNumber: parsed.referenceNumber,
      paymentSource: parsed.paymentSource,
    );
  }
}
