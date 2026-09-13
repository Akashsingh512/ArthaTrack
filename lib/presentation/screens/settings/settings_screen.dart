import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../controllers/category_controller.dart';
import '../../controllers/dashboard_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../controllers/transaction_controller.dart';
import '../../../../services/ingestion/sms_sync_service.dart';
import 'widgets/backup_settings_sheet.dart';
import 'widgets/manage_categories_sheet.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _bedrockModelController = TextEditingController();
  final _bedrockRegionController = TextEditingController();
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = Provider.of<SettingsController>(context, listen: false);
      settings.loadSettings().then((_) {
        _apiKeyController.text = settings.apiKey;
        _bedrockModelController.text = settings.bedrockModel;
        _bedrockRegionController.text = settings.bedrockRegion;
      });
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _bedrockModelController.dispose();
    _bedrockRegionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsController>(
      builder: (context, settings, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Settings & Configuration'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => settings.loadSettings(),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Active Engine Banner
                _buildActiveEngineBanner(settings),
                const SizedBox(height: 16),

                // Appearance & Theme Section
                _buildThemeModeSection(context, settings),
                const SizedBox(height: 16),

                // BYOK AI Engine Configuration Section
                _buildByokSection(context, settings),
                const SizedBox(height: 20),

                // Bank SMS Inbox Sync Section
                _buildSmsPermissionSection(context, settings),
                const SizedBox(height: 20),

                // Android Notification Listener Permission Section
                _buildNotificationPermissionSection(context, settings),
                const SizedBox(height: 20),

                // Gmail Integration Section
                _buildGmailSection(context, settings),
                const SizedBox(height: 20),

                // Encrypted Auto-Backup & Phone Migration Section
                _buildEncryptedBackupSection(context),
                const SizedBox(height: 20),

                // Data Management & Export Section
                _buildDataManagementSection(context, settings),
                const SizedBox(height: 20),

                // Custom Categories Management Section
                _buildCategoryManagementSection(context),
                const SizedBox(height: 20),

                // Privacy-First Guarantee Card
                _buildPrivacyNoticeCard(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActiveEngineBanner(SettingsController settings) {
    final isAi = settings.isAiActive;
    final color = isAi ? AppColors.aiEngine : AppColors.regexEngine;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isAi ? Icons.auto_awesome : Icons.bolt,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  settings.activeEngineLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isAi
                      ? 'Transactions parsed via strict JSON schema prompt with your free-tier key.'
                      : 'Offline heuristic regex active. Zero network calls; parses entirely on-device.',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildByokSection(BuildContext context, SettingsController settings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.key, color: AppColors.aiEngine, size: 20),
                SizedBox(width: 8),
                Text(
                  'Engine A: Bring Your Own Key (BYOK)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              settings.selectedProvider == AppConstants.providerBedrock
                  ? 'AWS Bedrock Converse API active with Alibaba Cloud Qwen. Paste your Bedrock API key / Bearer token below.'
                  : 'Input your free-tier Google Gemini or Groq API key. Keys are securely stored in the Android Keystore via flutter_secure_storage and never leave your device.',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),

            // Provider Dropdown
            DropdownButtonFormField<String>(
              value: settings.selectedProvider,
              decoration: const InputDecoration(labelText: 'AI Key Provider'),
              dropdownColor: AppColors.surfaceElevated,
              items: const [
                DropdownMenuItem(
                  value: AppConstants.providerGemini,
                  child: Text('Google Gemini (gemini-flash-latest)'),
                ),
                DropdownMenuItem(
                  value: AppConstants.providerGroq,
                  child: Text('Groq (llama-3.3-70b-versatile)'),
                ),
                DropdownMenuItem(
                  value: AppConstants.providerBedrock,
                  child: Text('AWS Bedrock (qwen.qwen3-coder-next)'),
                ),
              ],
              onChanged: (val) {
                if (val != null) {
                  settings.setProvider(val).then((_) {
                    _apiKeyController.text = settings.apiKey;
                    _bedrockModelController.text = settings.bedrockModel;
                    _bedrockRegionController.text = settings.bedrockRegion;
                  });
                }
              },
            ),
            const SizedBox(height: 14),

            // Bedrock Model & Region configuration (visible when Bedrock is selected)
            if (settings.selectedProvider == AppConstants.providerBedrock) ...[
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _bedrockModelController,
                      decoration: const InputDecoration(
                        labelText: 'Bedrock Model ID',
                        hintText: 'qwen.qwen3-coder-next',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _bedrockRegionController,
                      decoration: const InputDecoration(
                        labelText: 'AWS Region',
                        hintText: 'us-east-1',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],

            // Key Input
            TextField(
              controller: _apiKeyController,
              obscureText: _obscureKey,
              decoration: InputDecoration(
                labelText: settings.selectedProvider == AppConstants.providerBedrock
                    ? 'Bedrock API Key / Bearer Token'
                    : '${settings.selectedProvider} API Key',
                hintText: settings.selectedProvider == AppConstants.providerBedrock
                    ? 'Paste your Bedrock API key here...'
                    : 'Paste your secret API key here...',
                suffixIcon: IconButton(
                  icon: Icon(_obscureKey ? Icons.visibility : Icons.visibility_off, size: 18),
                  onPressed: () => setState(() => _obscureKey = !_obscureKey),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Action Buttons Row
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await settings.saveApiKey(_apiKeyController.text);
                      if (settings.selectedProvider == AppConstants.providerBedrock) {
                        await settings.saveBedrockConfig(
                          model: _bedrockModelController.text,
                          region: _bedrockRegionController.text,
                        );
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('API Key saved securely in Keystore!'),
                            backgroundColor: AppColors.emerald,
                          ),
                        );
                      }
                    },
                    child: const Text('Save Key'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF334155)),
                    ),
                    onPressed: settings.isTestingKey
                        ? null
                        : () async {
                            await settings.saveApiKey(_apiKeyController.text);
                            if (settings.selectedProvider == AppConstants.providerBedrock) {
                              await settings.saveBedrockConfig(
                                model: _bedrockModelController.text,
                                region: _bedrockRegionController.text,
                              );
                            }
                            final success = await settings.testCurrentApiKey();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    success
                                        ? 'API Key connection test passed!'
                                        : 'API Key test failed. Check key validity and internet connection.',
                                  ),
                                  backgroundColor:
                                      success ? AppColors.emerald : AppColors.ruby,
                                ),
                              );
                            }
                          },
                    child: settings.isTestingKey
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Test Key', style: TextStyle(color: AppColors.textPrimary)),
                  ),
                ),
                if (settings.hasActiveKey) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.ruby),
                    onPressed: () async {
                      await settings.clearApiKey();
                      _apiKeyController.clear();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('API Key cleared. Reverted to Local Regex Engine.'),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmsPermissionSection(
      BuildContext context, SettingsController settings) {
    final granted = settings.isSmsPermissionGranted;
    final isSyncing = settings.isSmsSyncing;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.sms, color: AppColors.emerald, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Bank SMS Inbox Sync',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (granted ? AppColors.emerald : AppColors.saffron).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    granted ? 'ACTIVE' : 'SETUP NEEDED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: granted ? AppColors.emerald : AppColors.saffron,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Reads incoming and past bank/UPI SMS (HDFC, SBI, ICICI, Axis, Paytm, PhonePe, GPay) directly on your device. Automatically imports transactions into SQLite while unconditionally dropping OTPs.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 14),
            if (!granted)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emerald,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () async {
                    final res = await settings.requestSmsPermission();
                    if (!res && context.mounted) {
                      settings.openSmsAppSettings();
                    }
                  },
                  icon: const Icon(Icons.lock_open, size: 18),
                  label: const Text(
                    'Grant SMS Permission',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.emerald,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: isSyncing
                          ? null
                          : () => _triggerSmsSync(context, settings, limit: 5000),
                      icon: isSyncing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Icon(Icons.sync, size: 18),
                      label: const Text(
                        'Sync (5,000)',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.emerald,
                        side: const BorderSide(color: AppColors.emerald),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: isSyncing
                          ? null
                          : () => _triggerSmsSync(context, settings, limit: 0),
                      icon: const Icon(Icons.all_inclusive, size: 18),
                      label: const Text(
                        'Deep Scan (All)',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _triggerSmsSync(
    BuildContext context,
    SettingsController settings, {
    required int limit,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final dashboard = Provider.of<DashboardController>(context, listen: false);
    final txController = Provider.of<TransactionController>(context, listen: false);

    messenger.showSnackBar(
      SnackBar(
        content: Text(limit <= 0
            ? 'Deep scanning entire SMS inbox for all bank transactions...'
            : 'Scanning up to $limit bank SMS messages...'),
        duration: const Duration(seconds: 3),
      ),
    );

    final result = await settings.syncSmsInbox(limit: limit);

    if (!context.mounted) return;

    if (result.status == SmsSyncStatus.permissionDenied) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('SMS permission denied. Tap to open Settings.'),
          backgroundColor: AppColors.ruby,
          action: SnackBarAction(
            label: 'Settings',
            textColor: Colors.white,
            onPressed: () => settings.openSmsAppSettings(),
          ),
        ),
      );
    } else if (result.status == SmsSyncStatus.error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('SMS sync error: ${result.errorMessage}'),
          backgroundColor: AppColors.ruby,
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.importedCount > 0
                ? 'Imported ${result.importedCount} new bank transactions (${result.scannedCount} scanned)!'
                : 'All SMS transactions are already up to date (${result.scannedCount} scanned, 0 new).',
          ),
          backgroundColor: AppColors.emerald,
        ),
      );
      await dashboard.loadDashboardData();
      await txController.loadTransactions();
    }
  }

  Widget _buildNotificationPermissionSection(
      BuildContext context, SettingsController settings) {
    final granted = settings.isNotificationPermissionGranted;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.notifications_active, color: AppColors.saffron, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Android Notification Interceptor',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (granted ? AppColors.emerald : AppColors.saffron).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    granted ? 'ACTIVE' : 'SETUP NEEDED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: granted ? AppColors.emerald : AppColors.saffron,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'ArthaTrack uses Android\'s native NotificationListenerService in Kotlin to intercept banking and UPI notifications (GPay, PhonePe, Paytm, HDFC, SBI, ICICI, Axis).',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: granted ? AppColors.surfaceElevated : AppColors.saffron,
                  foregroundColor: granted ? AppColors.textPrimary : Colors.black,
                ),
                onPressed: () => settings.requestNotificationPermission(),
                icon: Icon(granted ? Icons.check_circle : Icons.launch, size: 18),
                label: Text(
                  granted ? 'Notification Access Enabled' : 'Grant Notification Access',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGmailSection(BuildContext context, SettingsController settings) {
    final gmail = settings.gmailService;
    final isSignedIn = gmail.isSignedIn;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.mail_lock, color: AppColors.royalBlue, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Gmail Ingestion (Read-Only)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.help_outline, color: AppColors.textMuted, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Google Cloud Setup Guide',
                      onPressed: () => _showGoogleCloudSetupDialog(context),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (isSignedIn ? AppColors.emerald : AppColors.textMuted).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isSignedIn ? 'CONNECTED' : 'DISCONNECTED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isSignedIn ? AppColors.emerald : AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Google OAuth 2.0 integration with gmail.readonly scope to scan recent transaction confirmation emails with queries matching "debited", "credited", "spent", and "₹".',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            if (isSignedIn && gmail.currentUser != null) ...[
              const SizedBox(height: 10),
              Text(
                'Connected account: ${gmail.currentUser!.email}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.emerald),
              ),
            ],
            const SizedBox(height: 14),
            if (isSignedIn) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.royalBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: settings.isGmailSyncing
                          ? null
                          : () => _triggerGmailSync(context, settings, maxEmails: 100),
                      icon: settings.isGmailSyncing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.sync, size: 18),
                      label: const Text(
                        'Sync (100)',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.royalBlue,
                        side: const BorderSide(color: AppColors.royalBlue),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: settings.isGmailSyncing
                          ? null
                          : () => _triggerGmailSync(context, settings, maxEmails: 500),
                      icon: const Icon(Icons.all_inclusive, size: 18),
                      label: const Text(
                        'Deep Scan (500)',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: settings.isGmailSyncing
                      ? null
                      : () async {
                          await gmail.signOut();
                          setState(() {});
                        },
                  icon: const Icon(Icons.logout, size: 16, color: AppColors.textMuted),
                  label: const Text(
                    'Disconnect Google Account',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.royalBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () async {
                    try {
                      final account = await gmail.signIn();
                      if (account != null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Connected to Google as ${account.email}'),
                            backgroundColor: AppColors.emerald,
                          ),
                        );
                      }
                      setState(() {});
                    } catch (e) {
                      if (context.mounted) {
                        _showGoogleCloudSetupDialog(context, e.toString());
                      }
                    }
                  },
                  icon: const Icon(Icons.login, size: 18),
                  label: const Text('Connect Google Account', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _triggerGmailSync(
    BuildContext context,
    SettingsController settings, {
    required int maxEmails,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final dashboard = Provider.of<DashboardController>(context, listen: false);
    final txController = Provider.of<TransactionController>(context, listen: false);

    messenger.showSnackBar(
      SnackBar(
        content: Text(maxEmails >= 500
            ? 'Deep scanning up to $maxEmails banking emails from Gmail...'
            : 'Scanning up to $maxEmails recent banking emails from Gmail...'),
        duration: const Duration(seconds: 3),
      ),
    );

    final result = await settings.syncGmail(maxEmails: maxEmails);

    if (!context.mounted) return;

    if (result.errorMessage != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Gmail scan notice: ${result.errorMessage}'),
          backgroundColor: AppColors.ruby,
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.importedCount > 0
                ? 'Imported ${result.importedCount} new transactions (${result.scannedCount} emails scanned)!'
                : 'All email transactions are already up to date (${result.scannedCount} scanned, 0 new).',
          ),
          backgroundColor: AppColors.emerald,
        ),
      );
      await dashboard.loadDashboardData();
      await txController.loadTransactions();
    }
  }

  void _showGoogleCloudSetupDialog(BuildContext context, [String? errorMessage]) {
    const String packageName = 'com.arthatrack.app';
    const String sha1 = '1D:F8:96:94:51:9C:8F:7C:78:65:8D:6E:44:A6:F3:06:05:DA:47:D2';
    const String sha256 = '9F:64:55:F8:E4:AE:52:96:E9:58:05:CA:A7:BF:75:C1:26:7E:52:7E:E1:51:17:30:99:35:F4:82:9C:3C:78:F9';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.royalBlue.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.cloud_sync, color: AppColors.royalBlue, size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Google Cloud Setup Guide',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.ruby.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.ruby.withOpacity(0.3)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error_outline, color: AppColors.ruby, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Google Play Services returned: ApiException 10 (DEVELOPER_ERROR).\nThis occurs when Google Cloud has not authorized your app fingerprint yet.',
                            style: TextStyle(fontSize: 11, color: AppColors.ruby, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const Text(
                  'To connect Gmail, Google requires registering your app in Google Cloud Console:',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),

                // Package Name Copy Box
                _buildCopyBox(
                  context,
                  title: 'PACKAGE NAME',
                  value: packageName,
                ),
                const SizedBox(height: 8),

                // SHA-1 Copy Box
                _buildCopyBox(
                  context,
                  title: 'PERMANENT RELEASE SHA-1 FINGERPRINT',
                  value: sha1,
                ),
                const SizedBox(height: 8),

                // SHA-256 Copy Box
                _buildCopyBox(
                  context,
                  title: 'PERMANENT RELEASE SHA-256 FINGERPRINT',
                  value: sha256,
                ),
                const SizedBox(height: 14),

                const Text(
                  '3-Step Setup on Google Cloud:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                _buildStepItem(
                  step: '1',
                  text: 'Visit console.cloud.google.com -> Create Project (or choose existing).',
                ),
                _buildStepItem(
                  step: '2',
                  text: 'Go to APIs & Services -> Credentials -> Create Credentials -> OAuth client ID -> Android. Paste the Package Name and SHA-1 above.',
                ),
                _buildStepItem(
                  step: '3',
                  text: 'Go to Enabled APIs & services -> Enable "Gmail API". In OAuth consent screen, add your email as a Test User.',
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.emerald.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.emerald.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: AppColors.emerald, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tip: Bank SMS Inbox Sync is already 100% active and works offline with zero Google Cloud setup!',
                          style: TextStyle(fontSize: 11, color: AppColors.emerald, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: AppColors.royalBlue)),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyBox(BuildContext context, {required String title, required String value}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.5),
              ),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Copied $title to clipboard!'),
                      duration: const Duration(seconds: 2),
                      backgroundColor: AppColors.emerald,
                    ),
                  );
                },
                child: const Row(
                  children: [
                    Icon(Icons.copy, size: 13, color: AppColors.royalBlue),
                    SizedBox(width: 4),
                    Text('Copy', style: TextStyle(fontSize: 11, color: AppColors.royalBlue, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem({required String step, required String text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: AppColors.royalBlue.withOpacity(0.5)),
            ),
            child: Text(step, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.royalBlue)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3)),
          ),
        ],
      ),
    );
  }


  Widget _buildEncryptedBackupSection(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF334155)),
      ),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.emerald.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.cloud_sync, color: AppColors.emerald, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Encrypted Auto-Backup & Migration',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Google Drive, WebDAV & Offline Phone Transfer',
                        style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Zero-knowledge client-side encryption using AES-256 and PBKDF2. Automatically synchronizes your accounts, transactions, and budgets to Google Drive (private appDataFolder) or your personal WebDAV NAS.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.35),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surfaceElevated,
                  foregroundColor: AppColors.emerald,
                  side: const BorderSide(color: AppColors.emerald, width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  AppHaptics.medium();
                  BackupSettingsSheet.show(context);
                },
                icon: const Icon(Icons.settings_suggest, size: 18),
                label: const Text(
                  'Configure Backup & Migration',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleExport(
    BuildContext context,
    SettingsController settings, {
    required bool includeRawMessage,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(includeRawMessage
            ? 'Generating audit CSV with raw SMS text...'
            : 'Generating standard CSV export...'),
        duration: const Duration(seconds: 2),
      ),
    );

    final path = await settings.exportTransactionsCsv(includeRawMessage: includeRawMessage);
    if (path != null && context.mounted) {
      AppHaptics.medium();
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.emerald),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  includeRawMessage ? 'Audit CSV Saved!' : 'Standard CSV Saved!',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                includeRawMessage
                    ? 'Your full audit CSV (including raw SMS messages) is saved directly in your phone\'s public Downloads folder:'
                    : 'Your CSV transaction spreadsheet is saved directly in your phone\'s public Downloads folder:',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.3),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.folder_open, color: AppColors.emerald, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        path,
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                includeRawMessage
                    ? '💡 You can share this CSV file to check whether all SMS were captured and sorted properly.'
                    : '💡 Open your phone\'s Files or Downloads app to open it in Google Sheets, Excel, or share it.',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.3),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.emerald,
                    side: const BorderSide(color: AppColors.emerald),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () async {
                    AppHaptics.light();
                    final csv = await settings.getTransactionsCsvString(includeRawMessage: includeRawMessage);
                    await Clipboard.setData(ClipboardData(text: csv));
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(includeRawMessage
                              ? 'All audit CSV data (with SMS text) copied to clipboard!'
                              : 'All CSV transaction data copied to clipboard!'),
                          backgroundColor: AppColors.emerald,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_all, size: 16),
                  label: const Text(
                    'Copy All CSV to Clipboard',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                AppHaptics.light();
                Navigator.of(ctx).pop();
              },
              child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    } else if (context.mounted) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Failed to export transactions. Please try again.'),
          backgroundColor: AppColors.ruby,
        ),
      );
    }
  }

  Widget _buildDataManagementSection(BuildContext context, SettingsController settings) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF334155)),
      ),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.table_chart, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  'Data Management & Export',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Export your transaction history to your device\'s public Downloads folder in standard CSV format or as a full audit log including the original SMS messages.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),

            // Option 1: Standard Clean CSV
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.receipt_long, color: AppColors.primary, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Standard CSV Export',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Clean spreadsheet with Date, Type, Amount, Category, Merchant, Account, and Reference. Ideal for Excel & Google Sheets.',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surfaceElevated,
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: settings.isExporting
                          ? null
                          : () => _handleExport(context, settings, includeRawMessage: false),
                      icon: settings.isExporting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                            )
                          : const Icon(Icons.file_download_outlined, size: 16),
                      label: const Text(
                        'Export Standard CSV',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Option 2: Export with Raw SMS Text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.royalBlue.withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.mark_chat_read_outlined, color: AppColors.royalBlue, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Export with Raw SMS (Audit & Verification)',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Includes all parsed columns PLUS original unparsed SMS text (Raw Message). Share this to verify if all SMS are sorted properly.',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.royalBlue.withOpacity(0.15),
                        foregroundColor: AppColors.royalBlue,
                        side: const BorderSide(color: AppColors.royalBlue),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: settings.isExporting
                          ? null
                          : () => _handleExport(context, settings, includeRawMessage: true),
                      icon: settings.isExporting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.royalBlue),
                            )
                          : const Icon(Icons.sms_outlined, size: 16),
                      label: const Text(
                        'Export with Raw SMS (Audit)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryManagementSection(BuildContext context) {
    return Consumer<CategoryController>(
      builder: (context, catController, _) {
        final totalCats = catController.categories.length;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF334155)),
          ),
          color: AppColors.surface,
          child: InkWell(
            onTap: () => ManageCategoriesSheet.show(context),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.category, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Manage Categories',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceElevated,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$totalCats Active',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Add custom categories (e.g. Fitness, Pets, Rent) for transaction tagging and budgeting.',
                          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPrivacyNoticeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: const Row(
        children: [
          Icon(Icons.shield_outlined, color: AppColors.emerald, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '100% Local-First Privacy Guarantee',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Your financial transactions, balances, and assets are stored solely on this device in SQLite. No analytics, no user tracking, and no external user-data backend.',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeModeSection(BuildContext context, SettingsController settings) {
    final colors = context.colors;
    final currentMode = settings.themeMode;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.emerald.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.palette_outlined, color: colors.emerald, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Appearance & Theme',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Select dark, light, or system appearance',
                      style: TextStyle(fontSize: 12, color: colors.textMuted),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ThemeOptionTile(
                    title: 'Dark',
                    icon: Icons.dark_mode_outlined,
                    isSelected: currentMode == ThemeMode.dark,
                    onTap: () => settings.setThemeMode(ThemeMode.dark),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ThemeOptionTile(
                    title: 'Light',
                    icon: Icons.light_mode_outlined,
                    isSelected: currentMode == ThemeMode.light,
                    onTap: () => settings.setThemeMode(ThemeMode.light),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ThemeOptionTile(
                    title: 'System',
                    icon: Icons.brightness_auto_outlined,
                    isSelected: currentMode == ThemeMode.system,
                    onTap: () => settings.setThemeMode(ThemeMode.system),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeOptionTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOptionTile({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: () {
        AppHaptics.selection();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.emerald.withOpacity(colors.isDark ? 0.2 : 0.12)
              : colors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? colors.emerald : colors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colors.emerald.withOpacity(0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? colors.emerald : colors.textSecondary,
            ),
            const SizedBox(height: 6),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? colors.emerald : colors.textSecondary,
              ),
              child: Text(title),
            ),
          ],
        ),
      ),
    );
  }
}
