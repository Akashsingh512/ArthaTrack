import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/secure_storage/secure_storage_service.dart';
import '../../services/ingestion/gmail_reader_service.dart';
import '../../services/ingestion/notification_listener_channel.dart';
import '../../services/ingestion/sms_sync_service.dart';
import '../../services/parsing/engine_a_ai_parser.dart';

class SettingsController extends ChangeNotifier {
  final SecureStorageService _secureStorage;
  final NotificationListenerChannel _notificationChannel;
  final GmailReaderService _gmailService;
  final SmsSyncService _smsSyncService;

  bool _isLoading = false;
  String _selectedProvider = AppConstants.providerGemini;
  String _apiKey = '';
  bool _hasActiveKey = false;
  bool _isNotificationPermissionGranted = false;
  bool _isSmsPermissionGranted = false;
  bool _isSmsSyncing = false;
  bool _isGmailSyncing = false;
  bool _isExporting = false;
  bool _isTestingKey = false;
  String? _keyTestStatus; // 'SUCCESS', 'FAILED', or null

  SettingsController({
    SecureStorageService? secureStorage,
    NotificationListenerChannel? notificationChannel,
    GmailReaderService? gmailService,
    SmsSyncService? smsSyncService,
  })  : _secureStorage = secureStorage ?? SecureStorageService(),
        _notificationChannel = notificationChannel ?? NotificationListenerChannel(),
        _gmailService = gmailService ?? GmailReaderService(),
        _smsSyncService = smsSyncService ?? SmsSyncService();

  bool get isLoading => _isLoading;
  String get selectedProvider => _selectedProvider;
  String get apiKey => _apiKey;
  bool get hasActiveKey => _hasActiveKey;
  bool get isNotificationPermissionGranted => _isNotificationPermissionGranted;
  bool get isSmsPermissionGranted => _isSmsPermissionGranted;
  bool get isSmsSyncing => _isSmsSyncing;
  bool get isGmailSyncing => _isGmailSyncing;
  bool get isExporting => _isExporting;
  bool get isTestingKey => _isTestingKey;
  String? get keyTestStatus => _keyTestStatus;
  GmailReaderService get gmailService => _gmailService;
  SmsSyncService get smsSyncService => _smsSyncService;

  String _bedrockModel = AppConstants.defaultBedrockModel;
  String _bedrockRegion = AppConstants.defaultBedrockRegion;

  String get bedrockModel => _bedrockModel;
  String get bedrockRegion => _bedrockRegion;

  // Active Engine Indicator
  String get activeEngineLabel {
    if (!_hasActiveKey) return 'Local Regex Engine Active (Offline)';
    if (_selectedProvider == AppConstants.providerBedrock) {
      return 'AI Engine Active (AWS Bedrock: $_bedrockModel)';
    }
    return 'AI Engine Active ($_selectedProvider)';
  }

  bool get isAiActive => _hasActiveKey;

  Future<void> loadSettings() async {
    _isLoading = true;
    notifyListeners();

    try {
      _selectedProvider = await _secureStorage.getAiProvider();
      final key = await _secureStorage.getActiveApiKey();
      _apiKey = key ?? '';
      _hasActiveKey = _apiKey.isNotEmpty;
      _bedrockModel = await _secureStorage.getBedrockModel();
      _bedrockRegion = await _secureStorage.getBedrockRegion();

      _isNotificationPermissionGranted =
          await _notificationChannel.isPermissionGranted();
      _isSmsPermissionGranted =
          await _smsSyncService.isPermissionGranted();
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
    } else if (_selectedProvider == AppConstants.providerBedrock) {
      await _secureStorage.setBedrockApiKey(trimmed);
    } else {
      await _secureStorage.setGeminiApiKey(trimmed);
    }
    _apiKey = trimmed;
    _hasActiveKey = trimmed.isNotEmpty;
    _keyTestStatus = null;
    notifyListeners();
  }

  Future<void> saveBedrockConfig({required String model, required String region}) async {
    _bedrockModel = model.trim().isNotEmpty ? model.trim() : AppConstants.defaultBedrockModel;
    _bedrockRegion = region.trim().isNotEmpty ? region.trim() : AppConstants.defaultBedrockRegion;
    await _secureStorage.setBedrockModel(_bedrockModel);
    await _secureStorage.setBedrockRegion(_bedrockRegion);
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

  Future<void> refreshSmsPermission() async {
    _isSmsPermissionGranted = await _smsSyncService.isPermissionGranted();
    notifyListeners();
  }

  Future<bool> requestSmsPermission() async {
    final granted = await _smsSyncService.requestPermission();
    _isSmsPermissionGranted = granted;
    notifyListeners();
    return granted;
  }

  Future<void> openSmsAppSettings() async {
    await _smsSyncService.openAppSettings();
    await refreshSmsPermission();
  }

  Future<SmsSyncResult> syncSmsInbox({int limit = 5000}) async {
    _isSmsSyncing = true;
    notifyListeners();

    try {
      final result = await _smsSyncService.syncInbox(limit: limit);
      _isSmsPermissionGranted = await _smsSyncService.isPermissionGranted();
      _isSmsSyncing = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isSmsSyncing = false;
      notifyListeners();
      return SmsSyncResult(
        status: SmsSyncStatus.error,
        importedCount: 0,
        scannedCount: 0,
        errorMessage: e.toString(),
      );
    }
  }

  Future<GmailScanResult> syncGmail({int maxEmails = 100}) async {
    _isGmailSyncing = true;
    notifyListeners();

    try {
      final result = await _gmailService.scanEmails(maxEmails: maxEmails);
      _isGmailSyncing = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isGmailSyncing = false;
      notifyListeners();
      return GmailScanResult(
        scannedCount: _gmailService.lastScannedCount,
        importedCount: 0,
        errorMessage: e.toString(),
      );
    }
  }

  Future<String?> exportTransactionsCsv() async {
    _isExporting = true;
    notifyListeners();

    try {
      final txRepo = TransactionRepository();
      final transactions = await txRepo.getAllTransactions();

      final buffer = StringBuffer();
      // CSV Header
      buffer.writeln('ID,Date,Type,Amount,Category,Merchant,Account,Reference Number,Source');

      for (final tx in transactions) {
        final row = [
          tx.id?.toString() ?? '',
          _escapeCsv(tx.date),
          _escapeCsv(tx.type),
          tx.amount.toStringAsFixed(2),
          _escapeCsv(tx.category),
          _escapeCsv(tx.merchant),
          _escapeCsv(tx.displayPaymentSource),
          _escapeCsv(tx.referenceNumber ?? ''),
          _escapeCsv(tx.source),
        ];
        buffer.writeln(row.join(','));
      }

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/arthatrack_transactions.csv');
      await file.writeAsString(buffer.toString());
      return file.path;
    } catch (e) {
      print('CSV Export error: $e');
      return null;
    } finally {
      _isExporting = false;
      notifyListeners();
    }
  }

  String _escapeCsv(String val) {
    if (val.contains(',') || val.contains('"') || val.contains('\n') || val.contains('\r')) {
      return '"${val.replaceAll('"', '""')}"';
    }
    return val;
  }
}
