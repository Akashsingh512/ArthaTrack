import 'package:flutter/foundation.dart';
import '../../core/constants/app_constants.dart';
import '../../data/secure_storage/secure_storage_service.dart';
import '../../services/ingestion/gmail_reader_service.dart';
import '../../services/ingestion/notification_listener_channel.dart';
import '../../services/parsing/engine_a_ai_parser.dart';

class SettingsController extends ChangeNotifier {
  final SecureStorageService _secureStorage;
  final NotificationListenerChannel _notificationChannel;
  final GmailReaderService _gmailService;

  bool _isLoading = false;
  String _selectedProvider = AppConstants.providerGemini;
  String _apiKey = '';
  bool _hasActiveKey = false;
  bool _isNotificationPermissionGranted = false;
  bool _isTestingKey = false;
  String? _keyTestStatus; // 'SUCCESS', 'FAILED', or null

  SettingsController({
    SecureStorageService? secureStorage,
    NotificationListenerChannel? notificationChannel,
    GmailReaderService? gmailService,
  })  : _secureStorage = secureStorage ?? SecureStorageService(),
        _notificationChannel = notificationChannel ?? NotificationListenerChannel(),
        _gmailService = gmailService ?? GmailReaderService();

  bool get isLoading => _isLoading;
  String get selectedProvider => _selectedProvider;
  String get apiKey => _apiKey;
  bool get hasActiveKey => _hasActiveKey;
  bool get isNotificationPermissionGranted => _isNotificationPermissionGranted;
  bool get isTestingKey => _isTestingKey;
  String? get keyTestStatus => _keyTestStatus;
  GmailReaderService get gmailService => _gmailService;

  // Active Engine Indicator
  String get activeEngineLabel =>
      _hasActiveKey ? 'AI Engine Active ($_selectedProvider)' : 'Local Regex Engine Active (Offline)';

  bool get isAiActive => _hasActiveKey;

  Future<void> loadSettings() async {
    _isLoading = true;
    notifyListeners();

    try {
      _selectedProvider = await _secureStorage.getAiProvider();
      final key = await _secureStorage.getActiveApiKey();
      _apiKey = key ?? '';
      _hasActiveKey = _apiKey.isNotEmpty;

      _isNotificationPermissionGranted =
          await _notificationChannel.isPermissionGranted();
    } catch (e) {
      print('Error loading settings: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setProvider(String provider) async {
    _selectedProvider = provider;
    await _secureStorage.setAiProvider(provider);
    final key = await _secureStorage.getActiveApiKey();
    _apiKey = key ?? '';
    _hasActiveKey = _apiKey.isNotEmpty;
    _keyTestStatus = null;
    notifyListeners();
  }

  Future<void> saveApiKey(String key) async {
    final trimmed = key.trim();
    if (_selectedProvider == AppConstants.providerGroq) {
      await _secureStorage.setGroqApiKey(trimmed);
    } else {
      await _secureStorage.setGeminiApiKey(trimmed);
    }
    _apiKey = trimmed;
    _hasActiveKey = trimmed.isNotEmpty;
    _keyTestStatus = null;
    notifyListeners();
  }

  Future<void> clearApiKey() async {
    await _secureStorage.clearActiveKey();
    _apiKey = '';
    _hasActiveKey = false;
    _keyTestStatus = null;
    notifyListeners();
  }

  Future<bool> testCurrentApiKey() async {
    if (_apiKey.isEmpty) return false;

    _isTestingKey = true;
    _keyTestStatus = null;
    notifyListeners();

    try {
      final success = await EngineAAiParser.testApiKey(
        provider: _selectedProvider,
        apiKey: _apiKey,
      );
      _keyTestStatus = success ? 'SUCCESS' : 'FAILED';
      _isTestingKey = false;
      notifyListeners();
      return success;
    } catch (e) {
      _keyTestStatus = 'FAILED';
      _isTestingKey = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> refreshNotificationPermission() async {
    _isNotificationPermissionGranted =
        await _notificationChannel.isPermissionGranted();
    notifyListeners();
  }

  Future<void> requestNotificationPermission() async {
    await _notificationChannel.openSettings();
    await refreshNotificationPermission();
  }
}
