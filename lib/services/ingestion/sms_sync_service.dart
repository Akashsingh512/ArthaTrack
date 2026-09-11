import 'package:flutter/services.dart';
import '../../core/constants/indian_banking_constants.dart';
import '../../data/models/transaction_model.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../parsing/transaction_parser_pipeline.dart';

enum SmsSyncStatus {
  success,
  permissionDenied,
  error,
}

class SmsSyncResult {
  final SmsSyncStatus status;
  final int importedCount;
  final int scannedCount;
  final String? errorMessage;

  const SmsSyncResult({
    required this.status,
    required this.importedCount,
    required this.scannedCount,
    this.errorMessage,
  });
}

class SmsSyncService {
  static const MethodChannel _channel = MethodChannel('com.arthatrack.app/sms_reader');

  final TransactionParserPipeline _pipeline;
  final TransactionRepository _transactionRepo;
  final AccountRepository _accountRepo;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  SmsSyncService({
    TransactionParserPipeline? pipeline,
    TransactionRepository? transactionRepo,
    AccountRepository? accountRepo,
  })  : _pipeline = pipeline ?? TransactionParserPipeline(),
        _transactionRepo = transactionRepo ?? TransactionRepository(),
        _accountRepo = accountRepo ?? AccountRepository();

  /// Checks if the READ_SMS Android permission is granted
  Future<bool> isPermissionGranted() async {
    try {
      final bool? granted = await _channel.invokeMethod<bool>('checkSmsPermission');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Requests runtime READ_SMS permission from the user
  Future<bool> requestPermission() async {
    try {
      final bool? granted = await _channel.invokeMethod<bool>('requestSmsPermission');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the system application details settings page
  Future<void> openAppSettings() async {
    try {
      await _channel.invokeMethod('openAppSettings');
    } catch (_) {}
  }

  /// Scans recent bank and UPI SMS messages from inbox and imports valid financial transactions
  Future<SmsSyncResult> syncInbox({int limit = 150}) async {
    if (_isSyncing) {
      return const SmsSyncResult(
        status: SmsSyncStatus.error,
        importedCount: 0,
        scannedCount: 0,
        errorMessage: 'A sync is already in progress.',
      );
    }

    _isSyncing = true;

    try {
      // 1. Verify or prompt for SMS permission
      var hasPermission = await isPermissionGranted();
      if (!hasPermission) {
        hasPermission = await requestPermission();
        if (!hasPermission) {
          _isSyncing = false;
          return const SmsSyncResult(
            status: SmsSyncStatus.permissionDenied,
            importedCount: 0,
            scannedCount: 0,
            errorMessage: 'SMS permission was denied. Please grant permission to sync bank transactions.',
          );
        }
      }

      // 2. Fetch SMS messages from native Telephony Provider
      final List<dynamic>? rawMessages = await _channel.invokeMethod<List<dynamic>>(
        'readInboxSms',
        {'limit': limit},
      );

      if (rawMessages == null || rawMessages.isEmpty) {
        _isSyncing = false;
        return const SmsSyncResult(
          status: SmsSyncStatus.success,
          importedCount: 0,
          scannedCount: 0,
        );
      }

      final defaultAccount = await _accountRepo.getDefaultAccount();
      final accountId = defaultAccount?.id ?? 1;

      int importedCount = 0;
      int scannedCount = rawMessages.length;

      for (final item in rawMessages) {
        if (item is! Map) continue;
        final sender = item['sender']?.toString() ?? '';
        final body = item['body']?.toString() ?? '';
        final dateMs = item['date'];

        if (body.trim().isEmpty) continue;

        // 3. STRICT SECURITY SHIELD: Drop any OTP or verification code messages unconditionally
        if (IndianBankingConstants.otpBlocklistRegex.hasMatch(body)) {
          continue;
        }

        // 4. Duplicate Check: Skip if raw text has already been imported
        final isDuplicate = await _transactionRepo.hasDuplicateRawText(body);
        if (isDuplicate) continue;

        // 5. Parse via Dual-Engine (AI or Local Regex Heuristics)
        final parsed = await _pipeline.processText(body);
        if (parsed != null && parsed.amount > 0.0) {
          DateTime txDate;
          if (dateMs is int && dateMs > 0) {
            txDate = DateTime.fromMillisecondsSinceEpoch(dateMs);
          } else if (parsed.date != null) {
            txDate = parsed.date!;
          } else {
            txDate = DateTime.now();
          }

          final tx = TransactionModel(
            accountId: accountId,
            amount: parsed.amount,
            type: parsed.type,
            category: parsed.category,
            merchant: parsed.merchant,
            notes: sender.isNotEmpty ? 'SMS from $sender' : 'Bank SMS',
            rawText: body,
            source: 'SMS',
            referenceNumber: parsed.referenceNumber,
            date: txDate,
          );

          await _transactionRepo.insertTransaction(tx);
          importedCount++;
        }
      }

      _isSyncing = false;
      return SmsSyncResult(
        status: SmsSyncStatus.success,
        importedCount: importedCount,
        scannedCount: scannedCount,
      );
    } catch (e) {
      _isSyncing = false;
      return SmsSyncResult(
        status: SmsSyncStatus.error,
        importedCount: 0,
        scannedCount: 0,
        errorMessage: e.toString(),
      );
    }
  }
}
