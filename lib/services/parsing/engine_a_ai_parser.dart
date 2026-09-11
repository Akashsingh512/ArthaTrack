import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../../data/models/parsed_transaction.dart';

class EngineAAiParser {
  static const Duration _requestTimeout = Duration(seconds: 8);

  static const String _systemPrompt = '''
You are an expert Indian financial transaction parser for the ArthaTrack personal finance mobile app.
Your task is to parse raw Indian SMS, UPI push notifications (GPay, PhonePe, Paytm, CRED), and bank emails (HDFC, SBI, ICICI, Axis).

You must output ONLY valid JSON matching this exact schema:
{
  "is_financial_transaction": true,
  "amount": 450.00,
  "type": "EXPENSE",
  "category": "Food",
  "merchant": "Swiggy",
  "updated_balance": 15420.50,
  "account_snippet": "XX1234",
  "confidence": 0.98
}

Field rules:
- is_financial_transaction: boolean. False if it is spam, an OTP, or non-transactional alert.
- amount: double strictly > 0.
- type: strictly "EXPENSE" or "INCOME".
- category: one of ["Food", "Groceries", "Travel", "Shopping", "Bills", "Entertainment", "Health", "Investment", "Salary", "Transfer", "Other"].
- merchant: name of the entity, store, person, or service paid to/received from.
- updated_balance: double or null (if not mentioned).
- account_snippet: last digits or card ending (e.g. "XX1234") or null.
- confidence: number between 0.0 and 1.0.
''';

  /// Parses raw text using the user's BYOK LLM key (Gemini or Groq)
  static Future<ParsedTransaction?> parse({
    required String rawText,
    required String apiKey,
    required String provider,
  }) async {
    if (apiKey.trim().isEmpty) return null;

    try {
      if (provider == AppConstants.providerGroq) {
        return await _parseWithGroq(rawText, apiKey);
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

  static ParsedTransaction? _parseJsonOutput(String jsonString, String rawText, String engine) {
    try {
      final map = jsonDecode(jsonString.trim()) as Map<String, dynamic>;
      final isFinancial = map['is_financial_transaction'] as bool? ?? true;
      if (!isFinancial) return null;

      final amount = (map['amount'] as num?)?.toDouble() ?? 0.0;
      if (amount <= 0.0) return null;

      final typeStr = (map['type'] as String? ?? 'EXPENSE').toUpperCase();
      final type = typeStr == 'INCOME' ? TransactionType.INCOME : TransactionType.EXPENSE;
      final category = map['category'] as String? ?? 'Other';
      final merchant = map['merchant'] as String? ?? 'Unknown';
      final updatedBalance = (map['updated_balance'] as num?)?.toDouble();
      final accountSnippet = map['account_snippet'] as String?;
      final confidence = (map['confidence'] as num?)?.toDouble() ?? 0.95;

      return ParsedTransaction(
        amount: amount,
        type: type,
        category: category,
        merchant: merchant,
        updatedBalance: updatedBalance,
        accountSnippet: accountSnippet,
        rawText: rawText,
        engine: engine,
        confidence: confidence,
        isFinancial: true,
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
