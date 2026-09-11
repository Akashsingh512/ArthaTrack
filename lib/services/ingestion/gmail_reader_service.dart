import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:http/http.dart' as http;
import '../../core/constants/indian_banking_constants.dart';
import '../../data/models/transaction_model.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../parsing/transaction_parser_pipeline.dart';

class GoogleHttpClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleHttpClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

class GmailScanResult {
  final int scannedCount;
  final int importedCount;
  final String? errorMessage;

  const GmailScanResult({
    required this.scannedCount,
    required this.importedCount,
    this.errorMessage,
  });
}

class GmailReaderService {
  final GoogleSignIn _googleSignIn;
  final TransactionParserPipeline _pipeline;
  final TransactionRepository _transactionRepo;
  final AccountRepository _accountRepo;
  final CategoryRepository _categoryRepo;

  GoogleSignInAccount? _currentUser;
  bool _isScanning = false;
  String? _lastError;
  int _lastScannedCount = 0;

  GmailReaderService({
    GoogleSignIn? googleSignIn,
    TransactionParserPipeline? pipeline,
    TransactionRepository? transactionRepo,
    AccountRepository? accountRepo,
    CategoryRepository? categoryRepo,
  })  : _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: [
                'https://www.googleapis.com/auth/gmail.readonly',
                'email',
              ],
            ),
        _pipeline = pipeline ?? TransactionParserPipeline(),
        _transactionRepo = transactionRepo ?? TransactionRepository(),
        _accountRepo = accountRepo ?? AccountRepository(),
        _categoryRepo = categoryRepo ?? CategoryRepository() {
    _googleSignIn.onCurrentUserChanged.listen((account) {
      _currentUser = account;
    });
  }

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;
  bool get isScanning => _isScanning;
  String? get lastError => _lastError;
  int get lastScannedCount => _lastScannedCount;

  Future<GoogleSignInAccount?> signIn() async {
    _lastError = null;
    try {
      _currentUser = await _googleSignIn.signIn();
      return _currentUser;
    } catch (e) {
      _lastError = e.toString();
      print('Google Sign-In Error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      _currentUser = null;
    } catch (e) {
      print('Google Sign-Out Error: $e');
    }
  }

  /// Scans transaction confirmation emails from Gmail (backward-compatible)
  Future<int> scanRecentEmails({int maxEmails = 100}) async {
    final result = await scanEmails(maxEmails: maxEmails);
    return result.importedCount;
  }

  /// Scans transaction confirmation emails from Gmail with pagination and concurrent batching
  Future<GmailScanResult> scanEmails({int maxEmails = 100}) async {
    if (_currentUser == null) {
      // Attempt silent sign in if possible
      _currentUser = await _googleSignIn.signInSilently();
      if (_currentUser == null) {
        throw Exception('User is not signed in with Google');
      }
    }

    _isScanning = true;
    _lastScannedCount = 0;
    int importedCount = 0;

    try {
      final authHeaders = await _currentUser!.authHeaders;
      final httpClient = GoogleHttpClient(authHeaders);
      final gmailApi = gmail.GmailApi(httpClient);

      String? pageToken;
      final List<gmail.Message> allMessageRefs = [];

      // 1. Fetch message references with pagination up to maxEmails
      while (allMessageRefs.length < maxEmails) {
        final remaining = maxEmails - allMessageRefs.length;
        final batchSize = remaining > 100 ? 100 : remaining;

        final response = await gmailApi.users.messages.list(
          'me',
          q: IndianBankingConstants.gmailTransactionQuery,
          maxResults: batchSize,
          pageToken: pageToken,
        );

        final messages = response.messages;
        if (messages == null || messages.isEmpty) {
          break;
        }

        allMessageRefs.addAll(messages);
        pageToken = response.nextPageToken;
        if (pageToken == null || pageToken.isEmpty) {
          break;
        }
      }

      if (allMessageRefs.isEmpty) {
        _isScanning = false;
        return const GmailScanResult(scannedCount: 0, importedCount: 0);
      }

      final defaultAccount = await _accountRepo.getDefaultAccount();
      final accountId = defaultAccount?.id ?? 1;

      // 2. Fetch message details in concurrent batches (chunks of 5)
      const int chunkSize = 5;
      for (int i = 0; i < allMessageRefs.length; i += chunkSize) {
        final end = (i + chunkSize < allMessageRefs.length) ? i + chunkSize : allMessageRefs.length;
        final chunk = allMessageRefs.sublist(i, end);

        final fetchedMessages = await Future.wait(
          chunk.map((gmail.Message ref) async {
            final msgId = ref.id;
            if (msgId == null) return null;
            try {
              return await gmailApi.users.messages.get(
                'me',
                msgId,
                format: 'full',
              );
            } catch (e) {
              print('Error fetching email $msgId: $e');
              return null;
            }
          }),
        );

        for (final fullMsg in fetchedMessages) {
          if (fullMsg == null) continue;
          _lastScannedCount++;

          final rawContent = _extractMessageText(fullMsg);
          if (rawContent.trim().isEmpty) continue;

          // 1. Security & Promotional Shield: Drop OTPs, promotions, and bill receipt acknowledgments
          if (IndianBankingConstants.otpBlocklistRegex.hasMatch(rawContent)) continue;
          if (IndianBankingConstants.promotionalBlocklistRegex.hasMatch(rawContent)) continue;

          // 2. Prevent duplicate processing by raw email content
          final hasRawDup = await _transactionRepo.hasDuplicateRawText(rawContent);
          if (hasRawDup) continue;

          // 3. Parse through dual-engine pipeline
          final parsed = await _pipeline.processText(rawContent);
          if (parsed != null && parsed.amount > 0.0) {
            final internalDateMs = int.tryParse(fullMsg.internalDate ?? '');
            final emailDate = (internalDateMs != null && internalDateMs > 0)
                ? DateTime.fromMillisecondsSinceEpoch(internalDateMs)
                : DateTime.now();

            // 4. Resolve payment source / bank account
            int resolvedAccountId = accountId;
            if (parsed.paymentSource != null && parsed.paymentSource!.trim().isNotEmpty) {
              final acc = await _accountRepo.getOrCreateAccountByName(parsed.paymentSource!.trim());
              resolvedAccountId = acc.id ?? accountId;
            }

            // 5. Category memory
            final rememberedCat = await _categoryRepo.getRememberedCategory(parsed.merchant)
                ?? await _transactionRepo.getCategoryForMerchant(parsed.merchant);
            final String finalCategory = (rememberedCat != null && rememberedCat.isNotEmpty)
                ? rememberedCat
                : parsed.category;

            final tx = TransactionModel.fromParsed(
              parsed: parsed.copyWith(category: finalCategory),
              accountId: resolvedAccountId,
              source: 'EMAIL',
              date: emailDate,
            );

            // 6. Cross-Channel Smart Deduplication (matches against SMS and Notifications by Ref ID, Amount, Merchant, Date)
            final isDup = await _transactionRepo.isDuplicate(tx);
            if (isDup) continue;

            await _transactionRepo.insertTransaction(tx);
            importedCount++;
          }
        }
      }

      return GmailScanResult(
        scannedCount: _lastScannedCount,
        importedCount: importedCount,
      );
    } catch (e) {
      print('Gmail scan error: $e');
      rethrow;
    } finally {
      _isScanning = false;
    }
  }

  String _extractMessageText(gmail.Message message) {
    final snippet = message.snippet ?? '';
    final buffer = StringBuffer(snippet);

    if (message.payload != null) {
      _extractPartsFromPayload(message.payload!, buffer);
    }

    return buffer.toString();
  }

  void _extractPartsFromPayload(gmail.MessagePart part, StringBuffer buffer) {
    if (part.mimeType == 'text/plain' && part.body?.data != null) {
      try {
        final decoded = utf8.decode(base64Url.decode(part.body!.data!));
        buffer.write(' ');
        buffer.write(decoded);
      } catch (_) {}
    }

    if (part.parts != null && part.parts!.isNotEmpty) {
      for (final subPart in part.parts!) {
        _extractPartsFromPayload(subPart, buffer);
      }
    }
  }
}
