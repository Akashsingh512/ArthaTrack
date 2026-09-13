import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

import '../../core/utils/aes_cipher_util.dart';
import '../../data/database/app_database.dart';
import '../../data/database/tables/accounts_table.dart';
import '../../data/database/tables/transactions_table.dart';
import '../../data/database/tables/budgets_table.dart';
import '../../data/database/tables/balance_sheet_table.dart';
import '../../data/database/tables/categories_table.dart';
import '../../data/database/tables/merchant_categories_table.dart';
import '../../data/models/backup_model.dart';
import '../../data/secure_storage/secure_storage_service.dart';

class DriveHttpClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  DriveHttpClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}

class BackupService {
  static const String backupFilename = 'arthatrack_encrypted_backup.enc';
  static const String driveScope = 'https://www.googleapis.com/auth/drive.appdata';

  final AppDatabase _appDatabase;
  final SecureStorageService _secureStorage;
  final GoogleSignIn _googleSignIn;
  final http.Client _httpClient;

  BackupService({
    AppDatabase? appDatabase,
    SecureStorageService? secureStorage,
    GoogleSignIn? googleSignIn,
    http.Client? httpClient,
  })  : _appDatabase = appDatabase ?? AppDatabase.instance,
        _secureStorage = secureStorage ?? SecureStorageService(),
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: [
                driveScope,
                'email',
              ],
            ),
        _httpClient = httpClient ?? http.Client();

  /// Reads all database tables and produces an unencrypted structured [BackupModel]
  Future<BackupModel> createBackupModel() async {
    final db = await _appDatabase.database;

    final accounts = await db.query(AccountsTable.tableName);
    final transactions = await db.query(TransactionsTable.tableName);
    final budgets = await db.query(BudgetsTable.tableName);
    final balanceSheet = await db.query(BalanceSheetTable.tableName);
    final categories = await db.query(CategoriesTable.tableName);
    final merchantCategories = await db.query(MerchantCategoriesTable.tableName);

    return BackupModel(
      createdAt: DateTime.now().toIso8601String(),
      accounts: accounts.map((r) => Map<String, dynamic>.from(r)).toList(),
      transactions: transactions.map((r) => Map<String, dynamic>.from(r)).toList(),
      budgets: budgets.map((r) => Map<String, dynamic>.from(r)).toList(),
      balanceSheet: balanceSheet.map((r) => Map<String, dynamic>.from(r)).toList(),
      categories: categories.map((r) => Map<String, dynamic>.from(r)).toList(),
      merchantCategories: merchantCategories.map((r) => Map<String, dynamic>.from(r)).toList(),
    );
  }

  /// Restores entire database state from a [BackupModel] in an atomic transaction
  Future<void> restoreFromBackupModel(BackupModel model) async {
    final db = await _appDatabase.database;

    await db.transaction((txn) async {
      await txn.delete(TransactionsTable.tableName);
      await txn.delete(BudgetsTable.tableName);
      await txn.delete(BalanceSheetTable.tableName);
      await txn.delete(MerchantCategoriesTable.tableName);
      await txn.delete(CategoriesTable.tableName);
      await txn.delete(AccountsTable.tableName);

      for (final row in model.accounts) {
        await txn.insert(
          AccountsTable.tableName,
          row,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final row in model.categories) {
        await txn.insert(
          CategoriesTable.tableName,
          row,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final row in model.merchantCategories) {
        await txn.insert(
          MerchantCategoriesTable.tableName,
          row,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final row in model.balanceSheet) {
        await txn.insert(
          BalanceSheetTable.tableName,
          row,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final row in model.budgets) {
        await txn.insert(
          BudgetsTable.tableName,
          row,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final row in model.transactions) {
        await txn.insert(
          TransactionsTable.tableName,
          row,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Exports local database into an AES-256 encrypted JSON string
  Future<String> exportEncryptedBackupString({String? overridePassphrase}) async {
    final passphrase = overridePassphrase ?? await _secureStorage.getBackupPassphrase();
    if (passphrase == null || passphrase.trim().isEmpty) {
      throw ArgumentError('No backup passphrase configured. Set a passphrase first.');
    }

    final backupModel = await createBackupModel();
    final plainJson = backupModel.toJsonString();
    return AesCipherUtil.encryptBackupPayload(plainJson, passphrase.trim());
  }

  /// Restores database from an AES-256 encrypted JSON string and returns restored [BackupModel]
  Future<BackupModel> importEncryptedBackupString(String encryptedJson, String passphrase) async {
    final plainJson = AesCipherUtil.decryptBackupPayload(encryptedJson, passphrase.trim());
    final backupModel = BackupModel.fromJsonString(plainJson);
    await restoreFromBackupModel(backupModel);
    return backupModel;
  }

  // ==========================================
  // GOOGLE DRIVE SYNC (Hidden appDataFolder)
  // ==========================================

  /// Uploads encrypted backup to Google Drive's private appDataFolder
  Future<void> uploadToGoogleDrive(String encryptedData) async {
    var account = _googleSignIn.currentUser;
    account ??= await _googleSignIn.signInSilently();
    account ??= await _googleSignIn.signIn();

    if (account == null) {
      throw Exception('Google Sign-In required to back up to Google Drive');
    }

    final authHeaders = await account.authHeaders;
    final client = DriveHttpClient(authHeaders);
    final driveApi = drive.DriveApi(client);

    final fileList = await driveApi.files.list(
      spaces: 'appDataFolder',
      q: "name = '$backupFilename' and trashed = false",
    );

    final bytes = utf8.encode(encryptedData);
    final media = drive.Media(
      Stream.value(bytes),
      bytes.length,
      contentType: 'application/octet-stream',
    );

    if (fileList.files != null && fileList.files!.isNotEmpty) {
      final existingFileId = fileList.files!.first.id!;
      await driveApi.files.update(
        drive.File(),
        existingFileId,
        uploadMedia: media,
      );
    } else {
      final newFile = drive.File()
        ..name = backupFilename
        ..parents = ['appDataFolder'];
      await driveApi.files.create(
        newFile,
        uploadMedia: media,
      );
    }
  }

  /// Downloads encrypted backup from Google Drive's private appDataFolder
  Future<String> downloadFromGoogleDrive() async {
    var account = _googleSignIn.currentUser;
    account ??= await _googleSignIn.signInSilently();
    account ??= await _googleSignIn.signIn();

    if (account == null) {
      throw Exception('Google Sign-In required to download from Google Drive');
    }

    final authHeaders = await account.authHeaders;
    final client = DriveHttpClient(authHeaders);
    final driveApi = drive.DriveApi(client);

    final fileList = await driveApi.files.list(
      spaces: 'appDataFolder',
      q: "name = '$backupFilename' and trashed = false",
    );

    if (fileList.files == null || fileList.files!.isEmpty) {
      throw Exception('No ArthaTrack backup found in Google Drive');
    }

    final fileId = fileList.files!.first.id!;
    final media = await driveApi.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }

    return utf8.decode(bytes);
  }

  // ==========================================
  // WEBDAV SYNC (Nextcloud, ownCloud, NAS)
  // ==========================================

  /// Uploads encrypted backup to a WebDAV server endpoint
  Future<void> uploadToWebDav(String encryptedData) async {
    final urlStr = await _secureStorage.getBackupWebDavUrl();
    final user = await _secureStorage.getBackupWebDavUser() ?? '';
    final pass = await _secureStorage.getBackupWebDavPassword() ?? '';

    if (urlStr == null || urlStr.trim().isEmpty) {
      throw ArgumentError('WebDAV URL is not configured.');
    }

    var cleanUrl = urlStr.trim();
    if (!cleanUrl.endsWith('/')) cleanUrl += '/';
    final targetUri = Uri.parse('$cleanUrl$backupFilename');

    final authHeader = 'Basic ${base64Encode(utf8.encode('$user:$pass'))}';
    final response = await _httpClient.put(
      targetUri,
      headers: {
        'Authorization': authHeader,
        'Content-Type': 'application/octet-stream',
      },
      body: utf8.encode(encryptedData),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('WebDAV upload failed with HTTP status ${response.statusCode}: ${response.body}');
    }
  }

  /// Downloads encrypted backup from a WebDAV server endpoint
  Future<String> downloadFromWebDav() async {
    final urlStr = await _secureStorage.getBackupWebDavUrl();
    final user = await _secureStorage.getBackupWebDavUser() ?? '';
    final pass = await _secureStorage.getBackupWebDavPassword() ?? '';

    if (urlStr == null || urlStr.trim().isEmpty) {
      throw ArgumentError('WebDAV URL is not configured.');
    }

    var cleanUrl = urlStr.trim();
    if (!cleanUrl.endsWith('/')) cleanUrl += '/';
    final targetUri = Uri.parse('$cleanUrl$backupFilename');

    final authHeader = 'Basic ${base64Encode(utf8.encode('$user:$pass'))}';
    final response = await _httpClient.get(
      targetUri,
      headers: {
        'Authorization': authHeader,
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('WebDAV download failed with HTTP status ${response.statusCode}: ${response.body}');
    }

    return response.body;
  }

  // ==========================================
  // UNIFIED DISPATCHER & PERIODIC AUTO-BACKUP
  // ==========================================

  /// Performs backup according to user settings (Google Drive or WebDAV)
  Future<String> performBackup() async {
    final destination = await _secureStorage.getBackupDestination();
    final encryptedData = await exportEncryptedBackupString();

    if (destination == 'google_drive') {
      await uploadToGoogleDrive(encryptedData);
    } else if (destination == 'webdav') {
      await uploadToWebDav(encryptedData);
    }

    final nowIso = DateTime.now().toIso8601String();
    await _secureStorage.setBackupLastSyncTime(nowIso);
    await _secureStorage.setBackupLastStatus('SUCCESS ($destination) - $nowIso');
    return encryptedData;
  }

  /// Checks if periodic auto-backup should run, and executes it in the background if due
  Future<bool> checkAndTriggerAutoBackup() async {
    try {
      final interval = await _secureStorage.getBackupAutoInterval();
      if (interval == 'disabled') return false;

      final passphrase = await _secureStorage.getBackupPassphrase();
      if (passphrase == null || passphrase.isEmpty) return false;

      final lastSyncStr = await _secureStorage.getBackupLastSyncTime();
      if (lastSyncStr != null) {
        final lastSync = DateTime.tryParse(lastSyncStr);
        if (lastSync != null) {
          final now = DateTime.now();
          final diffHours = now.difference(lastSync).inHours;

          if (interval == 'daily' && diffHours < 24) {
            return false;
          } else if (interval == 'weekly' && diffHours < 168) {
            return false;
          }
        }
      }

      await performBackup();
      return true;
    } catch (e) {
      final nowIso = DateTime.now().toIso8601String();
      await _secureStorage.setBackupLastStatus('ERROR: $e ($nowIso)');
      return false;
    }
  }
}