import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_haptics.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/secure_storage/secure_storage_service.dart';
import '../../services/ingestion/gmail_reader_service.dart';
import '../../services/ingestion/notification_listener_channel.dart';
import '../../services/ingestion/sms_sync_service.dart';
import '../../services/parsing/engine_a_ai_parser.dart';
import '../../services/updater/app_update_service.dart';

class SettingsController extends ChangeNotifier {
  final SecureStorageService _secureStorage;
  final NotificationListenerChannel _notificationChannel;
  final GmailReaderService _gmailService;
  final SmsSyncService _smsSyncService;
  final AppUpdateService _updateService;

  bool _isLoading = false;
  ThemeMode _themeMode = ThemeMode.dark;
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

  bool _autoCheckUpdates = true;
  bool get autoCheckUpdates => _autoCheckUpdates;

  bool _isCheckingUpdate = false;
  bool get isCheckingUpdate => _isCheckingUpdate;

  UpdateInfo? _latestUpdateInfo;
  UpdateInfo? get latestUpdateInfo => _latestUpdateInfo;

  AppUpdateService get updateService => _updateService;

  SettingsController({
    SecureStorageService? secureStorage,
    NotificationListenerChannel? notificationChannel,
    GmailReaderService? gmailService,
    SmsSyncService? smsSyncService,
    AppUpdateService? updateService,
  })  : _secureStorage = secureStorage ?? SecureStorageService(),
        _notificationChannel = notificationChannel ?? NotificationListenerChannel(),
        _gmailService = gmailService ?? GmailReaderService(),
        _smsSyncService = smsSyncService ?? SmsSyncService(),
        _updateService = updateService ?? AppUpdateService();

  bool get isLoading => _isLoading;
  ThemeMode get themeMode => _themeMode;
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

  bool _hapticsEnabled = true;
  bool get hapticsEnabled => _hapticsEnabled;

  int _smsPullLimit = 50000;
  int get smsPullLimit => _smsPullLimit;

  String _smsDatePreset = 'this_month';
  String get smsDatePreset => _smsDatePreset;

  DateTime? _customStartDate;
  DateTime? get customStartDate => _customStartDate;
  DateTime? _customEndDate;
  DateTime? get customEndDate => _customEndDate;

  double _smsSyncProgress = 0.0;
  double get smsSyncProgress => _smsSyncProgress;

  int _smsSyncProcessed = 0;
  int get smsSyncProcessed => _smsSyncProcessed;

  int _smsSyncTotal = 0;
  int get smsSyncTotal => _smsSyncTotal;

  int _smsSyncImportedSoFar = 0;
  int get smsSyncImportedSoFar => _smsSyncImportedSoFar;

  Future<void> setSmsDatePreset(String preset, {DateTime? startDate, DateTime? endDate}) async {
    _smsDatePreset = preset;
    _customStartDate = startDate;
    _customEndDate = endDate;
    notifyListeners();
    await _secureStorage.setSmsDatePreset(preset);
  }

  Future<void> setSmsPullLimit(int limit) async {
    _smsPullLimit = limit > 0 ? limit : 50000;
    notifyListeners();
    await _secureStorage.setSmsPullLimit(_smsPullLimit);
  }

  Future<void> setHapticsEnabled(bool enabled) async {
    _hapticsEnabled = enabled;
    AppHaptics.isEnabled = enabled;
    notifyListeners();
    await _secureStorage.setHapticsEnabled(enabled);
    if (enabled) {
      AppHaptics.medium();
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final modeStr = mode == ThemeMode.light
        ? 'light'
        : (mode == ThemeMode.system ? 'system' : 'dark');
    await _secureStorage.setThemeMode(modeStr);
  }

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
      final themeStr = await _secureStorage.getThemeMode();
      if (themeStr == 'light') {
        _themeMode = ThemeMode.light;
      } else if (themeStr == 'system') {
        _themeMode = ThemeMode.system;
      } else {
        _themeMode = ThemeMode.dark;
      }

      _hapticsEnabled = await _secureStorage.getHapticsEnabled();
      AppHaptics.isEnabled = _hapticsEnabled;

      _selectedProvider = await _secureStorage.getAiProvider();
      final key = await _secureStorage.getActiveApiKey();
      _apiKey = key ?? '';
      _hasActiveKey = _apiKey.isNotEmpty;
      _bedrockModel = await _secureStorage.getBedrockModel();
      _bedrockRegion = await _secureStorage.getBedrockRegion();

      _smsPullLimit = await _secureStorage.getSmsPullLimit();
      _smsDatePreset = await _secureStorage.getSmsDatePreset();
      _autoCheckUpdates = await _secureStorage.getAutoCheckUpdates();

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

  DateTime? getCalculatedStartDate(String preset, {DateTime? customStart}) {
    final now = DateTime.now();
    switch (preset) {
      case 'this_week':
        return now.subtract(const Duration(days: 7));
      case 'this_month':
        return DateTime(now.year, now.month, 1);
      case 'last_month':
        return DateTime(now.year, now.month - 1, 1);
      case 'last_3_months':
        return DateTime(now.year, now.month - 2, 1);
      case 'last_6_months':
        return DateTime(now.year, now.month - 5, 1);
      case 'this_year':
        return DateTime(now.year, 1, 1);
      case 'custom':
        return customStart ?? _customStartDate;
      case 'all_time':
      default:
        return null;
    }
  }

  DateTime? getCalculatedEndDate(String preset, {DateTime? customEnd}) {
    final now = DateTime.now();
    switch (preset) {
      case 'last_month':
        return DateTime(now.year, now.month, 0, 23, 59, 59, 999);
      case 'custom':
        final end = customEnd ?? _customEndDate;
        return end != null ? DateTime(end.year, end.month, end.day, 23, 59, 59, 999) : null;
      default:
        return null;
    }
  }

  Future<SmsSyncResult> syncSmsInbox({
    int? limit,
    DateTime? startDate,
    DateTime? endDate,
    bool explicitDateFilter = false,
  }) async {
    _isSmsSyncing = true;
    _smsSyncProgress = 0.0;
    _smsSyncProcessed = 0;
    _smsSyncTotal = 0;
    _smsSyncImportedSoFar = 0;
    notifyListeners();

    try {
      final actualLimit = limit ?? (_smsPullLimit > 0 ? _smsPullLimit : 0);
      final effectiveStart = explicitDateFilter ? startDate : (startDate ?? getCalculatedStartDate(_smsDatePreset));
      final effectiveEnd = explicitDateFilter ? endDate : (endDate ?? getCalculatedEndDate(_smsDatePreset));

      final result = await _smsSyncService.syncInbox(
        limit: actualLimit,
        startDate: effectiveStart,
        endDate: effectiveEnd,
        onProgress: (current, total, imported) {
          _smsSyncProcessed = current;
          _smsSyncTotal = total;
          _smsSyncImportedSoFar = imported;
          _smsSyncProgress = total > 0 ? (current / total).clamp(0.0, 1.0) : 0.0;
          notifyListeners();
        },
      );
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

  Future<String?> exportTransactionsCsv({bool includeRawMessage = false}) async {
    _isExporting = true;
    notifyListeners();

    try {
      final txRepo = TransactionRepository();
      final transactions = await txRepo.getAllTransactions();

      final buffer = StringBuffer();
      final fileName = includeRawMessage
          ? 'arthatrack_transactions_with_sms.csv'
          : 'arthatrack_transactions.csv';

      if (includeRawMessage) {
        // Full CSV Header including Raw SMS for debugging and verification
        buffer.writeln('ID,Date,Type,Amount,Category,Merchant,Account,Payment Source,Reference Number,Source,Engine,Status,Failure Reason,Raw Message');
        for (final tx in transactions) {
          final row = [
            tx.id?.toString() ?? '',
            _escapeCsv(tx.date),
            _escapeCsv(tx.type),
            tx.amount.toStringAsFixed(2),
            _escapeCsv(tx.category),
            _escapeCsv(tx.merchant),
            _escapeCsv(tx.displayPaymentSource),
            _escapeCsv(tx.paymentSource ?? ''),
            _escapeCsv(tx.referenceNumber ?? ''),
            _escapeCsv(tx.source),
            _escapeCsv(tx.engine),
            _escapeCsv(tx.status),
            _escapeCsv(tx.failureReason ?? ''),
            _escapeCsv(tx.rawText),
          ];
          buffer.writeln(row.join(','));
        }
      } else {
        // Standard clean CSV Header
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
      }

      final csvContent = buffer.toString();
      String? savedPath;

      // 1. Primary: Save directly to Android Public Downloads via native MediaStore API
      try {
        const platform = MethodChannel('com.arthatrack.app/sms_reader');
        savedPath = await platform.invokeMethod<String>('saveFileToDownloads', {
          'fileName': fileName,
          'content': csvContent,
        });
      } catch (e) {
        print('Native MediaStore save error: $e');
      }

      // 2. Secondary fallback: Direct file write to /storage/emulated/0/Download/
      if (savedPath == null || savedPath.isEmpty) {
        try {
          final publicDownloadDir = Directory('/storage/emulated/0/Download');
          if (await publicDownloadDir.exists()) {
            final pubFile = File('${publicDownloadDir.path}/$fileName');
            await pubFile.writeAsString(csvContent);
            savedPath = pubFile.path;
          }
        } catch (e) {
          print('Direct download folder write error: $e');
        }
      }

      // 3. Guaranteed Internal Backup: Always write to app documents directory
      try {
        final dir = await getApplicationDocumentsDirectory();
        final internalFile = File('${dir.path}/$fileName');
        await internalFile.writeAsString(csvContent);
        savedPath ??= internalFile.path;
      } catch (e) {
        print('Internal doc write error: $e');
      }

      return savedPath;
    } catch (e) {
      print('CSV Export error: $e');
      return null;
    } finally {
      _isExporting = false;
      notifyListeners();
    }
  }

  /// Returns the full CSV text string so user can copy to clipboard
  Future<String> getTransactionsCsvString({bool includeRawMessage = false}) async {
    final txRepo = TransactionRepository();
    final transactions = await txRepo.getAllTransactions();

    final buffer = StringBuffer();
    if (includeRawMessage) {
      buffer.writeln('ID,Date,Type,Amount,Category,Merchant,Account,Payment Source,Reference Number,Source,Engine,Status,Failure Reason,Raw Message');
      for (final tx in transactions) {
        final row = [
          tx.id?.toString() ?? '',
          _escapeCsv(tx.date),
          _escapeCsv(tx.type),
          tx.amount.toStringAsFixed(2),
          _escapeCsv(tx.category),
          _escapeCsv(tx.merchant),
          _escapeCsv(tx.displayPaymentSource),
          _escapeCsv(tx.paymentSource ?? ''),
          _escapeCsv(tx.referenceNumber ?? ''),
          _escapeCsv(tx.source),
          _escapeCsv(tx.engine),
          _escapeCsv(tx.status),
          _escapeCsv(tx.failureReason ?? ''),
          _escapeCsv(tx.rawText),
        ];
        buffer.writeln(row.join(','));
      }
    } else {
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
    }
    return buffer.toString();
  }

  String _escapeCsv(String val) {
    if (val.contains(',') || val.contains('"') || val.contains('\n') || val.contains('\r')) {
      return '"${val.replaceAll('"', '""')}"';
    }
    return val;
  }

  Future<void> setAutoCheckUpdates(bool enabled) async {
    _autoCheckUpdates = enabled;
    await _secureStorage.setAutoCheckUpdates(enabled);
    notifyListeners();
  }

  Future<UpdateInfo> checkForUpdates({bool force = true}) async {
    _isCheckingUpdate = true;
    notifyListeners();
    try {
      final info = await _updateService.checkForUpdate(force: force);
      _latestUpdateInfo = info;
      return info;
    } finally {
      _isCheckingUpdate = false;
      notifyListeners();
    }
  }
}
