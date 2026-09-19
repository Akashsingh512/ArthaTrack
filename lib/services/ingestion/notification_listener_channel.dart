import 'dart:async';
import 'package:flutter/services.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/transaction_model.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../parsing/transaction_parser_pipeline.dart';

class NotificationListenerChannel {
  static const EventChannel _eventChannel =
      EventChannel(AppConstants.notificationEventChannel);
  static const MethodChannel _controlChannel =
      MethodChannel(AppConstants.notificationControlChannel);

  final TransactionParserPipeline _pipeline;
  final TransactionRepository _transactionRepo;
  final AccountRepository _accountRepo;

  StreamSubscription? _subscription;
  final _onNewTransactionController = StreamController<TransactionModel>.broadcast();

  NotificationListenerChannel({
    TransactionParserPipeline? pipeline,
    TransactionRepository? transactionRepo,
    AccountRepository? accountRepo,
  })  : _pipeline = pipeline ?? TransactionParserPipeline(),
        _transactionRepo = transactionRepo ?? TransactionRepository(),
        _accountRepo = accountRepo ?? AccountRepository();

  Stream<TransactionModel> get onNewTransaction => _onNewTransactionController.stream;

  /// Checks whether Android Notification Access has been granted by user
  Future<bool> isPermissionGranted() async {
    try {
      final bool granted =
          await _controlChannel.invokeMethod('isNotificationListenerGranted') ?? false;
      return granted;
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the Android system settings page for Notification Access
  Future<bool> openSettings() async {
    try {
      final bool success =
          await _controlChannel.invokeMethod('openNotificationListenerSettings') ?? false;
      return success;
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Starts listening to the native EventChannel and drains pending notifications from native disk
  void startListening({Function(TransactionModel)? onTransactionParsed}) {
    _subscription?.cancel();

    _subscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) async {
        if (event is Map) {
          final map = Map<String, dynamic>.from(event);
          final notifId = map['id'];
          try {
            await _handleNotificationEvent(
              map,
              onTransactionParsed: onTransactionParsed,
            );
          } finally {
            if (notifId != null) {
              await markNotificationProcessed(notifId);
            }
          }
        }
      },
      onError: (dynamic error) {
        print('NotificationListener EventChannel error: $error');
      },
    );

    // Immediately drain any pending ephemeral notifications that were captured to native disk
    // while the Flutter engine was detached, killed, or sleeping
    unawaited(drainPendingNotifications(onTransactionParsed: onTransactionParsed));
    unawaited(ensureConnected());
  }

  /// Drains any unhandled notifications that were persisted to native disk
  /// while Flutter was in the background, killed, or sleeping.
  Future<int> drainPendingNotifications({
    Function(TransactionModel)? onTransactionParsed,
  }) async {
    int processedCount = 0;
    try {
      final List<dynamic>? pendingList =
          await _controlChannel.invokeMethod('getPendingNotifications');
      if (pendingList == null || pendingList.isEmpty) return 0;

      for (final item in pendingList) {
        if (item is Map) {
          final event = Map<String, dynamic>.from(item);
          final notifId = event['id'];
          try {
            final tx = await _handleNotificationEvent(
              event,
              onTransactionParsed: onTransactionParsed,
            );
            if (tx != null) {
              processedCount++;
            }
          } catch (e) {
            print('Error processing pending notification: $e');
          } finally {
            if (notifId != null) {
              await markNotificationProcessed(notifId);
            }
          }
        }
      }
    } catch (e) {
      print('Error draining pending notifications: $e');
    }
    return processedCount;
  }

  /// Acknowledges to the native SQLite journal that this notification has been processed
  Future<void> markNotificationProcessed(dynamic id) async {
    try {
      await _controlChannel.invokeMethod('markNotificationProcessed', {'id': id});
    } catch (_) {}
  }

  /// Ensures native Android NotificationListenerService is bound and active
  Future<void> ensureConnected() async {
    try {
      await _controlChannel.invokeMethod('ensureNotificationListenerConnected');
    } catch (_) {}
  }

  /// Checks whether ArthaTrack is exempt from aggressive Android battery optimizations
  Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      final bool? isIgnoring =
          await _controlChannel.invokeMethod('isIgnoringBatteryOptimizations');
      return isIgnoring ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Requests battery optimization exemption for uninterrupted push notification capture
  Future<bool> requestIgnoreBatteryOptimizations() async {
    try {
      final bool? success =
          await _controlChannel.invokeMethod('requestIgnoreBatteryOptimizations');
      return success ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Checks whether runtime notification posting permission is granted (Android 13+)
  Future<bool> checkPostNotificationPermission() async {
    try {
      final bool? granted =
          await _controlChannel.invokeMethod('checkNotificationPermission');
      return granted ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Requests runtime notification posting permission (Android 13+)
  Future<bool> requestPostNotificationPermission() async {
    try {
      final bool? granted =
          await _controlChannel.invokeMethod('requestNotificationPermission');
      return granted ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Stops listening to the EventChannel
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  Future<TransactionModel?> _handleNotificationEvent(
    Map<String, dynamic> event, {
    Function(TransactionModel)? onTransactionParsed,
  }) async {
    final title = event['title'] as String? ?? '';
    final text = event['text'] as String? ?? '';
    final bigText = event['bigText'] as String? ?? '';
    final subText = event['subText'] as String? ?? '';
    final pkgName = event['packageName'] as String?;

    // ABSOLUTE SECURITY & RECURSION SHIELD: Never parse notifications originating from ArthaTrack itself
    if (pkgName == 'com.arthatrack.app') return null;

    // Combine text fields for full context
    final fullRaw = '$title $text $bigText $subText'.trim();
    if (fullRaw.isEmpty) return null;

    // Process through dual-engine pipeline
    final parsed = await _pipeline.processText(fullRaw, packageName: pkgName);
    if (parsed == null || parsed.amount <= 0.0) return null;

    // Resolve matching account (find or create by detected paymentSource / bank name)
    int accountId = 1;
    if (parsed.paymentSource != null && parsed.paymentSource!.trim().isNotEmpty) {
      final account = await _accountRepo.getOrCreateAccountByName(parsed.paymentSource!.trim());
      accountId = account.id ?? 1;
    } else {
      final accounts = await _accountRepo.getAllAccounts();
      if (accounts.isNotEmpty) {
        if (parsed.accountSnippet != null) {
          final matched = accounts.firstWhere(
            (a) => a.name.contains(parsed.accountSnippet!),
            orElse: () => accounts.first,
          );
          accountId = matched.id ?? 1;
        } else {
          accountId = accounts.first.id ?? 1;
        }
      }
    }

    final postTime = event['postTime'] as int?;
    final txDate = (postTime != null && postTime > 0)
        ? DateTime.fromMillisecondsSinceEpoch(postTime)
        : DateTime.now();

    final rememberedCat = await CategoryRepository().getRememberedCategory(parsed.merchant)
        ?? await _transactionRepo.getCategoryForMerchant(parsed.merchant);
    final String finalCategory = (rememberedCat != null && rememberedCat.isNotEmpty)
        ? rememberedCat
        : parsed.category;

    final tx = TransactionModel.fromParsed(
      parsed: parsed.copyWith(category: finalCategory),
      accountId: accountId,
      source: 'NOTIFICATION',
      date: txDate,
    );

    // Comprehensive Smart Deduplication Check
    final isDup = await _transactionRepo.isDuplicate(tx);
    if (isDup) return null;

    final insertedId = await _transactionRepo.insertTransaction(tx);
    final savedTx = tx.copyWith(id: insertedId);

    // Update real account balance from live bank message if available (Savings / Bank accounts only)
    if (parsed.updatedBalance != null && parsed.updatedBalance! > 0) {
      final acc = await _accountRepo.getAccountById(accountId);
      if (acc != null && !acc.isCreditCard) {
        await _accountRepo.updateBalance(accountId, parsed.updatedBalance!);
      }
    }

    _onNewTransactionController.add(savedTx);
    onTransactionParsed?.call(savedTx);

    // Smart Real-time Categorization Notification:
    // Triggers ONLY for live intercepted events (e.g. user paid Mohit via UPI),
    // strictly omitting batch historical SMS sync.
    if (_shouldPromptCategorization(savedTx)) {
      await showCategorizationAlert(savedTx);
    }

    return savedTx;
  }

  /// Checks if a transaction needs user categorization or merchant details
  bool _shouldPromptCategorization(TransactionModel tx) {
    if (!tx.isExpense) return false;
    final cat = tx.category.trim().toLowerCase();
    if (cat == 'other' || cat == 'transfer' || cat.isEmpty) {
      return true;
    }
    if (tx.merchant.toLowerCase().contains('unknown') || tx.merchant.toLowerCase() == 'merchant') {
      return true;
    }
    return false;
  }

  /// Displays a local notification prompting user to categorize or add notes to a live transaction
  Future<void> showCategorizationAlert(TransactionModel tx) async {
    try {
      final merchantName = tx.merchant.trim().isNotEmpty && tx.merchant.trim() != 'Unknown'
          ? tx.merchant.trim()
          : 'Payment';

      final title = 'Categorize payment to $merchantName';
      final body = '₹${tx.amount.toStringAsFixed(0)} paid. Tap to choose category or add details.';

      await _controlChannel.invokeMethod('showCategorizationNotification', {
        'title': title,
        'body': body,
        'transactionId': tx.id ?? 0,
      });
    } catch (e) {
      print('Failed to show categorization notification: $e');
    }
  }

  /// Simulates processing a notification (useful for testing or manual simulation sandbox)
  Future<TransactionModel?> simulateNotification({
    required String rawText,
    String? packageName,
  }) async {
    final parsed = await _pipeline.processText(rawText, packageName: packageName);
    if (parsed == null || parsed.amount <= 0.0) return null;

    final defaultAccount = await _accountRepo.getDefaultAccount();
    final accountId = defaultAccount?.id ?? 1;

    final tx = TransactionModel.fromParsed(
      parsed: parsed,
      accountId: accountId,
      source: 'NOTIFICATION',
    );

    final id = await _transactionRepo.insertTransaction(tx);
    final saved = tx.copyWith(id: id);
    _onNewTransactionController.add(saved);
    return saved;
  }

  void dispose() {
    _subscription?.cancel();
    _onNewTransactionController.close();
  }
}
