import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../../core/utils/forex_converter.dart';
import '../../data/models/parsed_transaction.dart';

class EngineAAiParser {
  static const Duration _requestTimeout = Duration(seconds: 8);

  static const String _systemPrompt = '''
You are an expert Indian and global financial transaction parser for the ArthaTrack personal finance mobile app.
Your task is to parse raw Indian and international SMS, UPI push notifications (GPay, PhonePe, Paytm, CRED), and bank emails (HDFC, SBI, ICICI, Axis, etc.).

You must output ONLY valid JSON matching this exact schema:
{
  "is_financial_transaction": true,
  "amount": 450.00,
  "type": "EXPENSE",
  "category": "Food",
  "merchant": "Swiggy",
  "payment_source": "SBI Card",
  "updated_balance": 15420.50,
  "account_snippet": "XX1234",
  "confidence": 0.98
}

Field rules:
- is_financial_transaction: boolean. Must be FALSE if:
  1) It is an upcoming bill reminder, request to pay, due notice, or marketing offer where money has NOT yet actually been debited or credited.
  2) It is a payment receipt acknowledgement confirming payment received towards a credit card, loan, EMI, or bill (e.g. "Payment of INR ... has been received towards your Axis Bank Credit Card", "Thank you for payment of Rs ... towards HDFC Credit Card", "Payment received towards your Airtel bill"). These are receipts for debts/bills already debited from bank, NOT new transactions.
  3) It is an account balance enquiry, balance summary, or balance notification (e.g. "Available balance in A/C ... is Rs 50,000", "Current balance is...", "Total balance is..."). These are status updates, NOT transactions! Money has not moved!
  Only set to TRUE if an actual completed debit/credit/payment transaction occurred.
- amount: double strictly > 0 representing the transaction amount spent, debited, credited, or transferred (e.g. 2.50 for "spend 2.50 usd"). Supports INR as well as foreign currencies (USD, EUR, GBP, AED, etc.).
  CRITICAL: NEVER confuse "available balance", "current balance", "available amount", "current amount", "clear balance", "closing balance", "ledger balance", "account balance", "remaining balance", "total balance", "outstanding balance", "avl bal", "cur bal", or "limit" with the transaction amount. For example, in "spend 2.50 usd available amount is 200000", amount MUST be 2.50 and updated_balance MUST be 200000. Balance figures must NEVER be recorded as the transaction amount!
- type: strictly "EXPENSE" or "INCOME". CRITICAL: A payment received towards a credit card or bill is NEVER "INCOME".
- category: one of ["Food", "Groceries", "Travel", "Shopping", "Bills", "Entertainment", "Health", "Investment", "Salary", "Transfer", "Other"].
- merchant: strictly the exact name of the person, shop, merchant, or service paid to or received from.
- payment_source: bank or card used if mentioned (e.g. "SBI Card", "Kotak Bank", "HDFC Bank", "Axis Bank", "ICICI Bank", "Cash", etc.) or null.
- updated_balance: double or null (e.g. 200000 for "available amount is 200000", if not mentioned then null).
- account_snippet: last digits or card ending (e.g. "XX1234") or null.
- confidence: number between 0.0 and 1.0.
''';

  /// Parses raw text using the user's BYOK LLM key (Gemini, Groq, or AWS Bedrock)
  static Future<ParsedTransaction?> parse({
    required String rawText,
    required String apiKey,
    required String provider,
    String? bedrockModel,
    String? bedrockRegion,
  }) async {
    if (apiKey.trim().isEmpty) return null;

    try {
      if (provider == AppConstants.providerGroq) {
        return await _parseWithGroq(rawText, apiKey);
      } else if (provider == AppConstants.providerBedrock) {
        return await _parseWithBedrock(
          rawText,
          apiKey,
          modelId: bedrockModel,
          region: bedrockRegion,
        );
      } else {
        return await _parseWithGemini(rawText, apiKey);
      }
    } catch (e) {
      // Any failure in Engine A bubbles down to trigger fallback to Engine B
      print('Engine A AI Parsing Error: $e');
      return null;
    }
  }

  /// Parses using Google Gemini API
  static Future<ParsedTransaction?> _parseWithGemini(String rawText, String apiKey) async {
    const modelsToTry = [
      'gemini-flash-latest',
      'gemini-flash-lite-latest',
      'gemini-2.5-flash',
    ];

    final payload = {
      "contents": [
        {
          "parts": [
            {
              "text": "$_systemPrompt\n\nParse this raw Indian transaction notification text:\n\"$rawText\""
            }
          ]
        }
      ],
      "generationConfig": {
        "response_mime_type": "application/json",
        "temperature": 0.1,
      }
    };

    for (final model in modelsToTry) {
      try {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
        );

        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            )
            .timeout(_requestTimeout);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final candidates = data['candidates'] as List?;
          if (candidates == null || candidates.isEmpty) continue;

          final content = candidates[0]['content']['parts'][0]['text'] as String;
          final parsed = _parseJsonOutput(content, rawText, 'AI_GEMINI');
          if (parsed != null) return parsed;
        }
      } catch (e) {
        print('Gemini attempt with model $model failed: $e');
      }
    }

    return null;
  }

  /// Parses using Groq API (OpenAI-compatible)
  static Future<ParsedTransaction?> _parseWithGroq(String rawText, String apiKey) async {
    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

    final payload = {
      "model": AppConstants.defaultGroqModel,
      "messages": [
        {"role": "system", "content": _systemPrompt},
        {"role": "user", "content": "Parse this transaction:\n\"$rawText\""}
      ],
      "response_format": {"type": "json_object"},
      "temperature": 0.1,
    };

    final response = await http
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode(payload),
        )
        .timeout(_requestTimeout);

    if (response.statusCode != 200) {
      throw Exception('Groq API returned status ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) return null;

    final content = choices[0]['message']['content'] as String;
    return _parseJsonOutput(content, rawText, 'AI_GROQ');
  }

  /// Parses using AWS Bedrock Converse API (e.g. qwen.qwen3-coder-next in us-east-1)
  static Future<ParsedTransaction?> _parseWithBedrock(
    String rawText,
    String apiKey, {
    String? modelId,
    String? region,
  }) async {
    final cleanKey = apiKey.trim();
    final authHeader = cleanKey.toLowerCase().startsWith('bearer ') ? cleanKey : 'Bearer $cleanKey';
    final targetRegion = (region != null && region.isNotEmpty) ? region : AppConstants.defaultBedrockRegion;
    final targetModel = (modelId != null && modelId.isNotEmpty) ? modelId : AppConstants.defaultBedrockModel;

    final url = Uri.parse(
      'https://bedrock-runtime.$targetRegion.amazonaws.com/model/$targetModel/converse',
    );

    final payload = {
      "system": [
        {"text": _systemPrompt}
      ],
      "messages": [
        {
          "role": "user",
          "content": [
            {"text": "Parse this raw Indian transaction notification text:\n\"$rawText\""}
          ]
        }
      ],
      "inferenceConfig": {
        "temperature": 0.1,
        "maxTokens": 1000,
      },
      "additionalModelRequestFields": {},
      "performanceConfig": {
        "latency": "standard",
      }
    };

    final response = await http
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': authHeader,
          },
          body: jsonEncode(payload),
        )
        .timeout(_requestTimeout);

    if (response.statusCode != 200) {
      throw Exception('AWS Bedrock returned status ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final output = data['output'] as Map<String, dynamic>?;
    final message = output?['message'] as Map<String, dynamic>?;
    final contentList = message?['content'] as List?;
    if (contentList == null || contentList.isEmpty) return null;

    final firstContent = contentList[0] as Map<String, dynamic>?;
    final text = firstContent?['text'] as String?;
    if (text == null || text.trim().isEmpty) return null;

    return _parseJsonOutput(text, rawText, 'AI_BEDROCK');
  }

  static ParsedTransaction? _parseJsonOutput(String jsonString, String rawText, String engine) {
    try {
      var cleanJson = jsonString.trim();
      // Strip markdown code fences like ```json ... ``` or ``` ... ```
      if (cleanJson.startsWith('```')) {
        cleanJson = cleanJson.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
        cleanJson = cleanJson.replaceFirst(RegExp(r'\s*```$'), '');
        cleanJson = cleanJson.trim();
      }

      final map = jsonDecode(cleanJson) as Map<String, dynamic>;
      final isFinancial = map['is_financial_transaction'] as bool? ?? true;
      if (!isFinancial) return null;

      var amount = (map['amount'] as num?)?.toDouble() ?? 0.0;
      if (amount <= 0.0) return null;

      double? originalAmount;
      final originalCurrency = map['original_currency'] as String? ??
          map['currency'] as String? ??
          ForexConverter.detectCurrency(rawText);

      // If the transaction is in foreign currency (e.g. USD) and message has no direct INR amount, convert to INR
      if (originalCurrency != null &&
          originalCurrency != 'INR' &&
          !rawText.toLowerCase().contains('inr') &&
          !rawText.toLowerCase().contains('rs.')) {
        originalAmount = amount;
        amount = ForexConverter.convertToInr(amount, originalCurrency);
      }

      final typeStr = (map['type'] as String? ?? 'EXPENSE').toUpperCase();
      final type = typeStr == 'INCOME' ? TransactionType.INCOME : TransactionType.EXPENSE;
      final category = map['category'] as String? ?? 'Other';
      var merchant = map['merchant'] as String? ?? 'Unknown';
      if (originalAmount != null &&
          originalCurrency != null &&
          originalCurrency != 'INR') {
        final origTag = ForexConverter.formatOriginal(
          originalAmount,
          originalCurrency,
        );
        if (!merchant.contains(origTag)) {
          merchant = '$merchant ($origTag)';
        }
      }
      final updatedBalance = (map['updated_balance'] as num?)?.toDouble();

      // Guard: If AI mistakenly confused updated balance with the transaction amount in a balance-only notification
      if (updatedBalance != null &&
          (amount == updatedBalance ||
              (originalAmount != null && originalAmount == updatedBalance))) {
        final rawLower = rawText.toLowerCase();
        final hasAction = rawLower.contains('debited') ||
            rawLower.contains('spent') ||
            rawLower.contains('spend') ||
            rawLower.contains('credited') ||
            rawLower.contains('paid') ||
            rawLower.contains('withdrawn') ||
            rawLower.contains('transferred');
        if (!hasAction) return null;
      }

      final accountSnippet = map['account_snippet'] as String?;
      final paymentSource = map['payment_source'] as String?;
      final referenceNumber = map['reference_number'] as String?;
      final confidence = (map['confidence'] as num?)?.toDouble() ?? 0.95;

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
        engine: engine,
        confidence: confidence,
        isFinancial: true,
        originalAmount: originalAmount,
        originalCurrency: originalCurrency,
      );
    } catch (e) {
      print('Failed to decode AI JSON output: $e');
      return null;
    }
  }

  /// Verifies if a user-supplied API key is valid
  static Future<bool> testApiKey({required String provider, required String apiKey}) async {
    try {
      final sample = 'HDFC Bank: Rs 100.00 debited for test on 10-09-26. Avl bal Rs 5000.00';
      final result = await parse(rawText: sample, apiKey: apiKey, provider: provider);
      return result != null && result.amount == 100.0;
    } catch (_) {
      return false;
    }
  }
}
