import '../../core/constants/indian_banking_constants.dart';
import '../../data/models/parsed_transaction.dart';
import '../../data/secure_storage/secure_storage_service.dart';
import 'engine_a_ai_parser.dart';
import 'engine_b_regex_parser.dart';

class TransactionParserPipeline {
  final SecureStorageService _secureStorage;

  TransactionParserPipeline({SecureStorageService? secureStorage})
      : _secureStorage = secureStorage ?? SecureStorageService();

  /// Orchestrates parsing with Engine A (Primary BYOK AI) and Engine B (Fallback Offline Regex)
  Future<ParsedTransaction?> processText(String rawText, {String? packageName}) async {
    if (rawText.trim().isEmpty) return null;

    // 0. ABSOLUTE SECURITY SHIELD: Never parse or transmit any OTP or authentication message
    if (IndianBankingConstants.otpBlocklistRegex.hasMatch(rawText)) {
      return null;
    }

    // 0.1 PROMOTIONAL SHIELD: Drop non-transactional EMI offers and loan pitches
    if (IndianBankingConstants.promotionalBlocklistRegex.hasMatch(rawText)) {
      return null;
    }

    final hasApiKey = await _secureStorage.hasActiveApiKey();

    // 1. Attempt Primary: Engine A (User AI Key)
    if (hasApiKey) {
      try {
        final apiKey = await _secureStorage.getActiveApiKey();
        final provider = await _secureStorage.getAiProvider();

        if (apiKey != null && apiKey.isNotEmpty) {
          final aiParsed = await EngineAAiParser.parse(
            rawText: rawText,
            apiKey: apiKey,
            provider: provider,
            bedrockModel: await _secureStorage.getBedrockModel(),
            bedrockRegion: await _secureStorage.getBedrockRegion(),
          );

          if (aiParsed != null && aiParsed.amount > 0) {
            return aiParsed;
          }
        }
      } catch (e) {
        // Log & proceed to offline fallback
        print('Pipeline: Engine A failed, falling back to Engine B: $e');
      }
    }

    // 2. Attempt Fallback: Engine B (Offline Heuristic / Regex)
    final regexParsed = EngineBRegexParser.parse(rawText, packageName: packageName);
    return regexParsed;
  }
}
