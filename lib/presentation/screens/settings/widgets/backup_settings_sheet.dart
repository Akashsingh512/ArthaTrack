import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/aes_cipher_util.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/secure_storage/secure_storage_service.dart';
import '../../../../services/backup/backup_service.dart';
import '../../../controllers/dashboard_controller.dart';
import '../../../controllers/transaction_controller.dart';

class BackupSettingsSheet extends StatefulWidget {
  const BackupSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const BackupSettingsSheet(),
    );
  }

  @override
  State<BackupSettingsSheet> createState() => _BackupSettingsSheetState();
}

class _BackupSettingsSheetState extends State<BackupSettingsSheet> {
  final _secureStorage = SecureStorageService();
  late final BackupService _backupService;

  final _passphraseController = TextEditingController();
  final _webDavUrlController = TextEditingController();
  final _webDavUserController = TextEditingController();
  final _webDavPassController = TextEditingController();

  bool _isPassphraseVisible = false;
  String _selectedDestination = 'google_drive'; // 'google_drive', 'webdav', 'local'
  String _selectedInterval = 'daily'; // 'daily', 'weekly', 'disabled'
  String? _lastSyncTime;
  String? _lastStatus;
  bool _isLoading = true;
  bool _isActionRunning = false;
  String? _actionMessage;

  @override
  void initState() {
    super.initState();
    _backupService = BackupService(secureStorage: _secureStorage);
    _loadInitialData();
  }

  @override
  void dispose() {
    _passphraseController.dispose();
    _webDavUrlController.dispose();
    _webDavUserController.dispose();
    _webDavPassController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final pass = await _secureStorage.getBackupPassphrase() ?? '';
    final dest = await _secureStorage.getBackupDestination();
    final interval = await _secureStorage.getBackupAutoInterval();
    final webUrl = await _secureStorage.getBackupWebDavUrl() ?? '';
    final webUser = await _secureStorage.getBackupWebDavUser() ?? '';
    final webPass = await _secureStorage.getBackupWebDavPassword() ?? '';
    final lastSync = await _secureStorage.getBackupLastSyncTime();
    final lastStatus = await _secureStorage.getBackupLastStatus();

    if (mounted) {
      setState(() {
        _passphraseController.text = pass;
        _selectedDestination = dest;
        _selectedInterval = interval;
        _webDavUrlController.text = webUrl;
        _webDavUserController.text = webUser;
        _webDavPassController.text = webPass;
        _lastSyncTime = lastSync;
        _lastStatus = lastStatus;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    await _secureStorage.setBackupPassphrase(_passphraseController.text.trim());
    await _secureStorage.setBackupDestination(_selectedDestination);
    await _secureStorage.setBackupAutoInterval(_selectedInterval);
    await _secureStorage.setBackupWebDavUrl(_webDavUrlController.text.trim());
    await _secureStorage.setBackupWebDavUser(_webDavUserController.text.trim());
    await _secureStorage.setBackupWebDavPassword(_webDavPassController.text.trim());
  }

  void _generateNewPassphrase() {
    AppHaptics.medium();
    final generated = AesCipherUtil.generatePassphrase();
    setState(() {
      _passphraseController.text = generated;
      _isPassphraseVisible = true;
    });
    _saveSettings();

    Clipboard.setData(ClipboardData(text: generated));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Passphrase generated and copied to clipboard! Save it securely.'),
        backgroundColor: AppColors.emerald,
      ),
    );
  }

  Future<void> _runBackupNow() async {
    final pass = _passphraseController.text.trim();
    if (pass.isEmpty) {
      AppHaptics.heavy();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter or generate a backup passphrase first.'),
          backgroundColor: AppColors.ruby,
        ),
      );
      return;
    }

    AppHaptics.medium();
    await _saveSettings();

    setState(() {
      _isActionRunning = true;
      _actionMessage = 'Encrypting & syncing backup to ${_getDestinationLabel(_selectedDestination)}...';
    });

    try {
      await _backupService.performBackup();
      final nowIso = DateTime.now().toIso8601String();
      final lastStat = await _secureStorage.getBackupLastStatus();

      if (mounted) {
        setState(() {
          _isActionRunning = false;
          _lastSyncTime = nowIso;
          _lastStatus = lastStat;
        });

        AppHaptics.medium();
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surfaceElevated,
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.emerald),
                SizedBox(width: 8),
                Text('Backup Complete'),
              ],
            ),
            content: Text(
              'Your entire database (accounts, transactions, budgets, categories) was encrypted with AES-256 and uploaded successfully to ${_getDestinationLabel(_selectedDestination)}.',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Great', style: TextStyle(color: AppColors.emerald, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isActionRunning = false);
        AppHaptics.heavy();
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surfaceElevated,
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: AppColors.ruby),
                SizedBox(width: 8),
                Text('Backup Failed'),
              ],
            ),
            content: Text(
              'Failed to sync backup:\n$e',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close', style: TextStyle(color: AppColors.ruby)),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _runRestoreNow() async {
    final pass = _passphraseController.text.trim();
    if (pass.isEmpty) {
      AppHaptics.heavy();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your backup passphrase to decrypt.'),
          backgroundColor: AppColors.ruby,
        ),
      );
      return;
    }

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.ruby),
            SizedBox(width: 8),
            Text('Restore & Replace Data?'),
          ],
        ),
        content: const Text(
          'Restoring will decrypt your remote backup and replace the local database state with the recovered accounts, transactions, and categories. Continue?',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.ruby),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore Data', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (proceed != true) return;

    AppHaptics.medium();
    setState(() {
      _isActionRunning = true;
      _actionMessage = 'Downloading and decrypting backup...';
    });

    try {
      String encryptedPayload;
      if (_selectedDestination == 'google_drive') {
        encryptedPayload = await _backupService.downloadFromGoogleDrive();
      } else if (_selectedDestination == 'webdav') {
        encryptedPayload = await _backupService.downloadFromWebDav();
      } else {
        throw Exception('For local file restore, use "Import from File / Clipboard" below.');
      }

      final restoredModel = await _backupService.importEncryptedBackupString(encryptedPayload, pass);

      if (mounted) {
        Provider.of<DashboardController>(context, listen: false).loadDashboardData();
        Provider.of<TransactionController>(context, listen: false).loadTransactions();

        setState(() => _isActionRunning = false);
        AppHaptics.medium();

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surfaceElevated,
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.emerald),
                SizedBox(width: 8),
                Text('Restore Successful!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Data successfully restored to local SQLite:'),
                const SizedBox(height: 8),
                Text('• Accounts: ${restoredModel.totalAccounts}', style: const TextStyle(fontSize: 12)),
                Text('• Transactions: ${restoredModel.totalTransactions}', style: const TextStyle(fontSize: 12)),
                Text('• Budgets: ${restoredModel.totalBudgets}', style: const TextStyle(fontSize: 12)),
                Text('• Categories: ${restoredModel.totalCategories}', style: const TextStyle(fontSize: 12)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Done', style: TextStyle(color: AppColors.emerald, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isActionRunning = false);
        AppHaptics.heavy();
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surfaceElevated,
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: AppColors.ruby),
                SizedBox(width: 8),
                Text('Decryption Failed'),
              ],
            ),
            content: Text(
              'Could not restore backup:\n$e\n\nPlease ensure your passphrase is exact.',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close', style: TextStyle(color: AppColors.ruby)),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _exportToClipboard() async {
    final pass = _passphraseController.text.trim();
    if (pass.isEmpty) {
      AppHaptics.heavy();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set a backup passphrase first.'),
          backgroundColor: AppColors.ruby,
        ),
      );
      return;
    }

    AppHaptics.medium();
    setState(() {
      _isActionRunning = true;
      _actionMessage = 'Generating encrypted file payload...';
    });

    try {
      final payload = await _backupService.exportEncryptedBackupString(overridePassphrase: pass);
      await Clipboard.setData(ClipboardData(text: payload));

      if (mounted) {
        setState(() => _isActionRunning = false);
        AppHaptics.medium();
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surfaceElevated,
            title: const Row(
              children: [
                Icon(Icons.shield, color: AppColors.emerald),
                SizedBox(width: 8),
                Text('Backup Exported'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Encrypted backup payload has been copied to your clipboard. You can paste it into a file or transfer it to your new phone.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                Text(
                  'Payload size: ${(payload.length / 1024).toStringAsFixed(1)} KB',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK', style: TextStyle(color: AppColors.emerald)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isActionRunning = false);
        AppHaptics.heavy();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: AppColors.ruby),
        );
      }
    }
  }

  Future<void> _importFromClipboard() async {
    final payloadController = TextEditingController();
    final passController = TextEditingController(text: _passphraseController.text);

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Import Encrypted Backup'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste the encrypted backup JSON text below:',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: payloadController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: '{"format":"arthatrack_encrypted_backup", ...}',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Enter Passphrase:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(
                controller: passController,
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: 'Decryption passphrase',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.emerald),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Decrypt & Restore', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (proceed != true || payloadController.text.trim().isEmpty) return;

    AppHaptics.medium();
    setState(() {
      _isActionRunning = true;
      _actionMessage = 'Decrypting pasted backup...';
    });

    try {
      final restoredModel = await _backupService.importEncryptedBackupString(
        payloadController.text.trim(),
        passController.text.trim(),
      );

      if (mounted) {
        Provider.of<DashboardController>(context, listen: false).loadDashboardData();
        Provider.of<TransactionController>(context, listen: false).loadTransactions();

        setState(() => _isActionRunning = false);
        AppHaptics.medium();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully restored ${restoredModel.totalTransactions} transactions!'),
            backgroundColor: AppColors.emerald,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isActionRunning = false);
        AppHaptics.heavy();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to restore: $e'), backgroundColor: AppColors.ruby),
        );
      }
    }
  }

  String _getDestinationLabel(String dest) {
    switch (dest) {
      case 'google_drive':
        return 'Google Drive (appDataFolder)';
      case 'webdav':
        return 'WebDAV Server';
      case 'local':
        return 'Local File / Manual Share';
      default:
        return dest;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(32),
        height: 300,
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.emerald),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.emerald.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.cloud_sync, color: AppColors.emerald, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Encrypted Auto-Backup',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Effortless phone migration & disaster recovery',
                            style: TextStyle(fontSize: 11.5, color: colors.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: colors.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.emerald.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.emerald.withOpacity(0.25)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock, color: AppColors.emerald, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Client-Side Zero-Knowledge Encryption: Backups are encrypted locally with AES-256 and PBKDF2 before leaving your phone. Neither Google Drive nor WebDAV can read your financial balances.',
                        style: TextStyle(fontSize: 11, color: AppColors.emerald, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 1. Passphrase Section
              Text(
                '1. RECOVERY PASSPHRASE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: colors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passphraseController,
                obscureText: !_isPassphraseVisible,
                onChanged: (_) => _saveSettings(),
                decoration: InputDecoration(
                  hintText: 'Enter a strong secret passphrase...',
                  prefixIcon: const Icon(Icons.key, size: 20, color: AppColors.emerald),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          _isPassphraseVisible ? Icons.visibility_off : Icons.visibility,
                          size: 18,
                          color: colors.textMuted,
                        ),
                        onPressed: () => setState(() => _isPassphraseVisible = !_isPassphraseVisible),
                      ),
                      IconButton(
                        tooltip: 'Generate Secure 4-Word Passphrase',
                        icon: const Icon(Icons.auto_awesome, size: 18, color: AppColors.emerald),
                        onPressed: _generateNewPassphrase,
                      ),
                    ],
                  ),
                  filled: true,
                  fillColor: colors.surfaceElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colors.border),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _generateNewPassphrase,
                  icon: const Icon(Icons.shuffle, size: 14, color: AppColors.emerald),
                  label: const Text(
                    'Generate Random Passphrase',
                    style: TextStyle(fontSize: 11, color: AppColors.emerald, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 2. Destination Selector
              Text(
                '2. BACKUP DESTINATION',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: colors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildChoiceChip(
                      label: 'Google Drive',
                      icon: Icons.add_to_drive,
                      isSelected: _selectedDestination == 'google_drive',
                      onTap: () {
                        setState(() => _selectedDestination = 'google_drive');
                        _saveSettings();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildChoiceChip(
                      label: 'WebDAV / NAS',
                      icon: Icons.dns_outlined,
                      isSelected: _selectedDestination == 'webdav',
                      onTap: () {
                        setState(() => _selectedDestination = 'webdav');
                        _saveSettings();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildChoiceChip(
                      label: 'Local File',
                      icon: Icons.file_copy_outlined,
                      isSelected: _selectedDestination == 'local',
                      onTap: () {
                        setState(() => _selectedDestination = 'local');
                        _saveSettings();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              if (_selectedDestination == 'webdav') ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'WebDAV Connection Details (Nextcloud / ownCloud / Synology):',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _webDavUrlController,
                        onChanged: (_) => _saveSettings(),
                        decoration: const InputDecoration(
                          labelText: 'Server URL (e.g. https://cloud.org/remote.php/dav/files/user/)',
                          labelStyle: TextStyle(fontSize: 11),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _webDavUserController,
                              onChanged: (_) => _saveSettings(),
                              decoration: const InputDecoration(
                                labelText: 'Username',
                                labelStyle: TextStyle(fontSize: 11),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _webDavPassController,
                              obscureText: true,
                              onChanged: (_) => _saveSettings(),
                              decoration: const InputDecoration(
                                labelText: 'App Password',
                                labelStyle: TextStyle(fontSize: 11),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // 3. Periodic Auto-Backup Interval
              Text(
                '3. AUTO-BACKUP FREQUENCY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: colors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildChoiceChip(
                      label: 'Daily (Recommended)',
                      icon: Icons.repeat,
                      isSelected: _selectedInterval == 'daily',
                      onTap: () {
                        setState(() => _selectedInterval = 'daily');
                        _saveSettings();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildChoiceChip(
                      label: 'Weekly',
                      icon: Icons.calendar_view_week,
                      isSelected: _selectedInterval == 'weekly',
                      onTap: () {
                        setState(() => _selectedInterval = 'weekly');
                        _saveSettings();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildChoiceChip(
                      label: 'Disabled',
                      icon: Icons.cancel_outlined,
                      isSelected: _selectedInterval == 'disabled',
                      onTap: () {
                        setState(() => _selectedInterval = 'disabled');
                        _saveSettings();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Status Summary Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: colors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      _lastStatus != null && _lastStatus!.startsWith('SUCCESS')
                          ? Icons.cloud_done
                          : Icons.cloud_off,
                      color: _lastStatus != null && _lastStatus!.startsWith('SUCCESS')
                          ? AppColors.emerald
                          : colors.textMuted,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _lastSyncTime != null
                                ? 'Last Backup: ${DateFormatter.formatShort(DateFormatter.parse(_lastSyncTime!))}'
                                : 'No backup performed yet',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          if (_lastStatus != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              _lastStatus!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 10, color: colors.textMuted),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              if (_isActionRunning) ...[
                Center(
                  child: Column(
                    children: [
                      const CircularProgressIndicator(color: AppColors.emerald),
                      const SizedBox(height: 10),
                      Text(
                        _actionMessage ?? 'Processing...',
                        style: const TextStyle(fontSize: 12, color: AppColors.emerald, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.emerald,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isActionRunning ? null : _runBackupNow,
                      icon: const Icon(Icons.backup, size: 20),
                      label: const Text('Back Up Now', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.textPrimary,
                        side: BorderSide(color: colors.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isActionRunning ? null : _runRestoreNow,
                      icon: const Icon(Icons.restore, size: 20),
                      label: const Text('Restore Data', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _isActionRunning ? null : _exportToClipboard,
                      icon: const Icon(Icons.copy, size: 16, color: AppColors.royalBlue),
                      label: const Text(
                        'Copy Encrypted Payload',
                        style: TextStyle(fontSize: 11.5, color: AppColors.royalBlue, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _isActionRunning ? null : _importFromClipboard,
                      icon: const Icon(Icons.paste, size: 16, color: AppColors.royalBlue),
                      label: const Text(
                        'Paste & Decrypt Backup',
                        style: TextStyle(fontSize: 11.5, color: AppColors.royalBlue, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;
    return InkWell(
      onTap: () {
        AppHaptics.selection();
        onTap();
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.emerald.withOpacity(0.15) : colors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.emerald : colors.border,
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppColors.emerald : colors.textMuted,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.emerald : colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
