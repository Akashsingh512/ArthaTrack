import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:http/http.dart' as http;
import '../../core/constants/indian_banking_constants.dart';
import '../../data/models/transaction_model.dart';
import '../../data/repositories/account_repository.dart';
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

class GmailReaderService {
  final GoogleSignIn _googleSignIn;
  final TransactionParserPipeline _pipeline;
  final TransactionRepository _transactionRepo;
  final AccountRepository _accountRepo;

  GoogleSignInAccount? _currentUser;
  bool _isScanning = false;

  GmailReaderService({
    GoogleSignIn? googleSignIn,
    TransactionParserPipeline? pipeline,
    TransactionRepository? transactionRepo,
    AccountRepository? accountRepo,
  })  : _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: [
                'https://www.googleapis.com/auth/gmail.readonly',
                'email',
              ],
            ),
        _pipeline = pipeline ?? TransactionParserPipeline(),
        _transactionRepo = transactionRepo ?? TransactionRepository(),
        _accountRepo = accountRepo ?? AccountRepository() {
    _googleSignIn.onCurrentUserChanged.listen((account) {
      _currentUser = account;
    });
  }

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;
  bool get isScanning => _isScanning;

  Future<GoogleSignInAccount?> signIn() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      return _currentUser;
    } catch (e) {
      print('Google Sign-In Error: $e');
      return null;
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

  /// Scans recent transaction confirmation emails from Gmail
  Future<int> scanRecentEmails({int maxResults = 20}) async {
    if (_currentUser == null) {
      // Attempt silent sign in if possible
      _currentUser = await _googleSignIn.signInSilently();
      if (_currentUser == null) {
        throw Exception('User is not signed in with Google');
      }
    }

    _isScanning = true;
    int importedCount = 0;

    try {
      final authHeaders = await _currentUser!.authHeaders;
      final httpClient = GoogleHttpClient(authHeaders);
      final gmailApi = gmail.GmailApi(httpClient);

      final response = await gmailApi.users.messages.list(
        'me',
        q: IndianBankingConstants.gmailTransactionQuery,
        maxResults: maxResults,
      );

      final messages = response.messages;
      if (messages == null || messages.isEmpty) {
        _isScanning = false;
        return 0;
      }

      final defaultAccount = await _accountRepo.getDefaultAccount();
      final accountId = defaultAccount?.id ?? 1;

      for (final msgRef in messages) {
        if (msgRef.id == null) continue;

        final fullMsg = await gmailApi.users.messages.get(
          'me',
          msgRef.id!,
          format: 'full',
        );

        final rawContent = _extractMessageText(fullMsg);
        if (rawContent.trim().isEmpty) continue;

        // Prevent duplicate processing
        final isDuplicate = await _transactionRepo.hasDuplicateRawText(rawContent);
        if (isDuplicate) continue;

        // Parse through pipeline
        final parsed = await _pipeline.processText(rawContent);
        if (parsed != null && parsed.amount > 0.0) {
          final tx = TransactionModel.fromParsed(
            parsed: parsed,
            accountId: accountId,
            source: 'EMAIL',
          );
          await _transactionRepo.insertTransaction(tx);
          importedCount++;
        }
      }
    } catch (e) {
      print('Gmail scan error: $e');
      rethrow;
    } finally {
      _isScanning = false;
    }

    return importedCount;
  }

  String _extractMessageText(gmail.Message message) {
    // 1. First check snippet
    final snippet = message.snippet ?? '';

    // 2. Decode payload parts if available
    final parts = message.payload?.parts;
    final buffer = StringBuffer(snippet);

    if (parts != null) {
      for (final part in parts) {
        if (part.mimeType == 'text/plain' && part.body?.data != null) {
          try {
            final decoded = utf8.decode(base64Url.decode(part.body!.data!));
            buffer.write(' ');
            buffer.write(decoded);
          } catch (_) {}
        }
      }
    }

    return buffer.toString();
  }
}
