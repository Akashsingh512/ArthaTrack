import 'package:flutter/services.dart';
import '../../core/constants/indian_banking_constants.dart';
import '../../data/models/transaction_model.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/category_repository.dart';
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
  final CategoryRepository _categoryRepo;

  static bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  SmsSyncService({
    TransactionParserPipeline? pipeline,
    TransactionRepository? transactionRepo,
    AccountRepository? accountRepo,
    CategoryRepository? categoryRepo,
  })  : _pipeline = pipeline ?? TransactionParserPipeline(),
        _transactionRepo = transactionRepo ?? TransactionRepository(),
        _accountRepo = accountRepo ?? AccountRepository(),
        _categoryRepo = categoryRepo ?? CategoryRepository();

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
  Future<SmsSyncResult> syncInbox({int limit = 100}) async {
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
      final seenAccountsWithBalance = <int>{};

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

        // 3.05 MANDATE PRE-DEBIT & REGISTRATION SHIELD: Drop informational mandate notices (0 money moved)
        if (IndianBankingConstants.mandateNoticeBlocklistRegex.hasMatch(body)) {
          continue;
        }

        // 3.1 PROMOTIONAL & EMI SHIELD: Drop non-transactional marketing and EMI pitches
        if (IndianBankingConstants.promotionalBlocklistRegex.hasMatch(body)) {
          continue;
        }

        // 3.2 TRANSACTION PRE-FILTER: Drop non-financial chat, delivery, and notice messages
        final lower = body.toLowerCase();
        if (!IndianBankingConstants.incomeTriggerRegex.hasMatch(lower) &&
            !IndianBankingConstants.expenseTriggerRegex.hasMatch(lower)) {
          continue;
        }

        // 4. Parse via Dual-Engine (AI or Local Regex Heuristics)
        final parsed = await _pipeline.processText(body, packageName: sender);
        if (parsed != null && parsed.amount > 0.0) {
          DateTime? txDate;
          if (dateMs is int && dateMs > 0) {
            txDate = DateTime.fromMillisecondsSinceEpoch(dateMs);
          }

          int resolvedAccountId = accountId;
          if (parsed.paymentSource != null && parsed.paymentSource!.trim().isNotEmpty) {
            final acc = await _accountRepo.getOrCreateAccountByName(parsed.paymentSource!.trim());
            resolvedAccountId = acc.id ?? accountId;
          }

          final rememberedCat = await _categoryRepo.getRememberedCategory(parsed.merchant)
              ?? await _transactionRepo.getCategoryForMerchant(parsed.merchant);
          final String finalCategory = (rememberedCat != null && rememberedCat.isNotEmpty)
              ? rememberedCat
              : parsed.category;

          final tx = TransactionModel.fromParsed(
            parsed: parsed.copyWith(category: finalCategory),
            accountId: resolvedAccountId,
            source: 'SMS',
            date: txDate,
          );

          // 4.1 Update Account Balance from Bank SMS if available balance is present (Savings / Bank accounts only)
          if (parsed.updatedBalance != null && parsed.updatedBalance! > 0) {
            final acc = await _accountRepo.getAccountById(resolvedAccountId);
            if (acc != null && !acc.isCreditCard) {
              if (!seenAccountsWithBalance.contains(resolvedAccountId)) {
                seenAccountsWithBalance.add(resolvedAccountId);
                await _accountRepo.updateBalance(resolvedAccountId, parsed.updatedBalance!);
              }
            }
          }

          // 5. Smart Deduplication: Drop if exact, matching UPI ref, or within time window
          final isDup = await _transactionRepo.isDuplicate(tx);
          if (isDup) continue;

          await _transactionRepo.insertTransaction(tx);
          importedCount++;
        }
      }

      return SmsSyncResult(
        status: SmsSyncStatus.success,
        importedCount: importedCount,
        scannedCount: scannedCount,
      );
    } catch (e) {
      return SmsSyncResult(
        status: SmsSyncStatus.error,
        importedCount: 0,
        scannedCount: 0,
        errorMessage: e.toString(),
      );
    } finally {
      _isSyncing = false;
    }
  }
}
