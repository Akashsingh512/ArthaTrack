import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants/app_constants.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
            );

  // AI Provider Selection
  Future<String> getAiProvider() async {
    final provider = await _storage.read(key: AppConstants.secureKeyAiProvider);
    return provider ?? AppConstants.providerGemini;
  }

  Future<void> setAiProvider(String provider) async {
    await _storage.write(key: AppConstants.secureKeyAiProvider, value: provider);
  }

  // Gemini API Key
  Future<String?> getGeminiApiKey() async {
    return await _storage.read(key: AppConstants.secureKeyGeminiApiKey);
  }

  Future<void> setGeminiApiKey(String key) async {
    await _storage.write(key: AppConstants.secureKeyGeminiApiKey, value: key.trim());
  }

  // Groq API Key
  Future<String?> getGroqApiKey() async {
    return await _storage.read(key: AppConstants.secureKeyGroqApiKey);
  }

  Future<void> setGroqApiKey(String key) async {
    await _storage.write(key: AppConstants.secureKeyGroqApiKey, value: key.trim());
  }

  // AWS Bedrock API Key / Bearer Token
  Future<String?> getBedrockApiKey() async {
    return await _storage.read(key: AppConstants.secureKeyBedrockApiKey);
  }

  Future<void> setBedrockApiKey(String key) async {
    await _storage.write(key: AppConstants.secureKeyBedrockApiKey, value: key.trim());
  }

  // AWS Bedrock Model (default: qwen.qwen3-coder-next)
  Future<String> getBedrockModel() async {
    final model = await _storage.read(key: AppConstants.secureKeyBedrockModel);
    return (model != null && model.isNotEmpty) ? model : AppConstants.defaultBedrockModel;
  }

  Future<void> setBedrockModel(String model) async {
    await _storage.write(key: AppConstants.secureKeyBedrockModel, value: model.trim());
  }

  // AWS Bedrock Region (default: us-east-1)
  Future<String> getBedrockRegion() async {
    final region = await _storage.read(key: AppConstants.secureKeyBedrockRegion);
    return (region != null && region.isNotEmpty) ? region : AppConstants.defaultBedrockRegion;
  }

  Future<void> setBedrockRegion(String region) async {
    await _storage.write(key: AppConstants.secureKeyBedrockRegion, value: region.trim());
  }

  // Active Key depending on selected provider
  Future<String?> getActiveApiKey() async {
    final provider = await getAiProvider();
    if (provider == AppConstants.providerGroq) {
      return await getGroqApiKey();
    } else if (provider == AppConstants.providerBedrock) {
      return await getBedrockApiKey();
    } else {
      return await getGeminiApiKey();
    }
  }

  Future<bool> hasActiveApiKey() async {
    final key = await getActiveApiKey();
    return key != null && key.isNotEmpty;
  }

  Future<void> clearActiveKey() async {
    final provider = await getAiProvider();
    if (provider == AppConstants.providerGroq) {
      await _storage.delete(key: AppConstants.secureKeyGroqApiKey);
    } else if (provider == AppConstants.providerBedrock) {
      await _storage.delete(key: AppConstants.secureKeyBedrockApiKey);
    } else {
      await _storage.delete(key: AppConstants.secureKeyGeminiApiKey);
    }
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
