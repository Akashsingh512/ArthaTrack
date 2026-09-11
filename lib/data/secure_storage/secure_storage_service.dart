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

  // Active Key depending on selected provider
  Future<String?> getActiveApiKey() async {
    final provider = await getAiProvider();
    if (provider == AppConstants.providerGroq) {
      return await getGroqApiKey();
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
    } else {
      await _storage.delete(key: AppConstants.secureKeyGeminiApiKey);
    }
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
