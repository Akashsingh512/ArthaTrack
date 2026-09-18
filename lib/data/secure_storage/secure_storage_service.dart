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

  // Theme Mode ('dark', 'light', 'system')
  Future<String> getThemeMode() async {
    final mode = await _storage.read(key: AppConstants.secureKeyThemeMode);
    return mode ?? 'dark';
  }

  Future<void> setThemeMode(String mode) async {
    await _storage.write(key: AppConstants.secureKeyThemeMode, value: mode);
  }

  // Backup & Restore Settings
  Future<String?> getBackupPassphrase() async {
    return await _storage.read(key: AppConstants.secureKeyBackupPassphrase);
  }

  Future<void> setBackupPassphrase(String passphrase) async {
    await _storage.write(key: AppConstants.secureKeyBackupPassphrase, value: passphrase.trim());
  }

  Future<String> getBackupDestination() async {
    final dest = await _storage.read(key: AppConstants.secureKeyBackupDestination);
    return dest ?? 'google_drive'; // 'google_drive', 'webdav', 'local'
  }

  Future<void> setBackupDestination(String destination) async {
    await _storage.write(key: AppConstants.secureKeyBackupDestination, value: destination);
  }

  Future<String?> getBackupWebDavUrl() async {
    return await _storage.read(key: AppConstants.secureKeyBackupWebDavUrl);
  }

  Future<void> setBackupWebDavUrl(String url) async {
    await _storage.write(key: AppConstants.secureKeyBackupWebDavUrl, value: url.trim());
  }

  Future<String?> getBackupWebDavUser() async {
    return await _storage.read(key: AppConstants.secureKeyBackupWebDavUser);
  }

  Future<void> setBackupWebDavUser(String user) async {
    await _storage.write(key: AppConstants.secureKeyBackupWebDavUser, value: user.trim());
  }

  Future<String?> getBackupWebDavPassword() async {
    return await _storage.read(key: AppConstants.secureKeyBackupWebDavPassword);
  }

  Future<void> setBackupWebDavPassword(String pass) async {
    await _storage.write(key: AppConstants.secureKeyBackupWebDavPassword, value: pass);
  }

  Future<String> getBackupAutoInterval() async {
    final interval = await _storage.read(key: AppConstants.secureKeyBackupAutoInterval);
    return interval ?? 'daily'; // 'daily', 'weekly', 'disabled'
  }

  Future<void> setBackupAutoInterval(String interval) async {
    await _storage.write(key: AppConstants.secureKeyBackupAutoInterval, value: interval);
  }

  Future<String?> getBackupLastSyncTime() async {
    return await _storage.read(key: AppConstants.secureKeyBackupLastSyncTime);
  }

  Future<void> setBackupLastSyncTime(String timeIso) async {
    await _storage.write(key: AppConstants.secureKeyBackupLastSyncTime, value: timeIso);
  }

  Future<String?> getBackupLastStatus() async {
    return await _storage.read(key: AppConstants.secureKeyBackupLastStatus);
  }

  Future<void> setBackupLastStatus(String status) async {
    await _storage.write(key: AppConstants.secureKeyBackupLastStatus, value: status);
  }

  Future<bool> getHapticsEnabled() async {
    final val = await _storage.read(key: 'haptics_enabled');
    return val != 'false';
  }

  Future<void> setHapticsEnabled(bool enabled) async {
    await _storage.write(key: 'haptics_enabled', value: enabled.toString());
  }

  Future<int> getSmsPullLimit() async {
    final val = await _storage.read(key: 'sms_pull_limit');
    if (val != null) {
      final parsed = int.tryParse(val);
      if (parsed != null) return parsed;
    }
    return 500;
  }

  Future<void> setSmsPullLimit(int limit) async {
    await _storage.write(key: 'sms_pull_limit', value: limit.toString());
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
