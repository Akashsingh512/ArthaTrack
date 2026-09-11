import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../controllers/category_controller.dart';
import '../../controllers/dashboard_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../controllers/transaction_controller.dart';
import '../../../../services/ingestion/sms_sync_service.dart';
import 'widgets/manage_categories_sheet.dart';
import 'widgets/raw_sms_test_sandbox.dart';

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
                const SizedBox(height: 20),

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

                // Interactive Test Sandbox Card
                _buildSandboxCard(context),
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
                const Row(
                  children: [
                    Icon(Icons.mail_lock, color: AppColors.royalBlue, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Gmail Ingestion (Read-Only)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: AppColors.surfaceElevated,
                            title: const Row(
                              children: [
                                Icon(Icons.info_outline, color: AppColors.saffron),
                                SizedBox(width: 8),
                                Text('Google Sign-In Info', style: TextStyle(fontSize: 16)),
                              ],
                            ),
                            content: Text(
                              'Google Sign-In error:\n$e\n\n'
                              'Why: On Android, Google Play Services requires registering an Android OAuth Client ID in Google Cloud Console with your app SHA-1 fingerprint.\n\n'
                              'Recommendation: Use the "Bank SMS Inbox Sync" above! It works 100% offline, requires zero configuration, and directly imports bank SMS messages on your phone.',
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Got it', style: TextStyle(color: AppColors.emerald)),
                              ),
                            ],
                          ),
                        );
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

  Widget _buildSandboxCard(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: AppColors.surface,
            builder: (context) => const RawSmsTestSandbox(),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: const Padding(
          padding: EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(Icons.terminal, color: AppColors.aiEngine, size: 28),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Interactive SMS & Notification Sandbox',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Simulate HDFC, SBI, ICICI, PhonePe, and Swiggy notifications in real time.',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
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
              'Export all local transactions, merchant categories, and account records to a standard CSV spreadsheet for Excel, Google Sheets, or personal backups.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surfaceElevated,
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: settings.isExporting
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Generating CSV export...'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        final path = await settings.exportTransactionsCsv();
                        if (path != null && context.mounted) {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: AppColors.surfaceElevated,
                              title: const Row(
                                children: [
                                  Icon(Icons.check_circle, color: AppColors.emerald),
                                  SizedBox(width: 8),
                                  Text('Export Successful', style: TextStyle(fontSize: 18)),
                                ],
                              ),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Your transactions have been exported to CSV:',
                                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: SelectableText(
                                      path,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontFamily: 'monospace',
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  child: const Text('OK'),
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
                      },
                icon: settings.isExporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      )
                    : const Icon(Icons.download, size: 18),
                label: Text(
                  settings.isExporting ? 'Exporting CSV...' : 'Export Transactions to CSV',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
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
}
