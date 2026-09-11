import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../controllers/dashboard_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../controllers/transaction_controller.dart';
import 'widgets/raw_sms_test_sandbox.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = Provider.of<SettingsController>(context, listen: false);
      settings.loadSettings().then((_) {
        _apiKeyController.text = settings.apiKey;
      });
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
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

                // Android Notification Listener Permission Section
                _buildNotificationPermissionSection(context, settings),
                const SizedBox(height: 20),

                // Gmail Integration Section
                _buildGmailSection(context, settings),
                const SizedBox(height: 20),

                // Interactive Test Sandbox Card
                _buildSandboxCard(context),
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
            const Text(
              'Input your free-tier Google Gemini or Groq API key. Keys are securely stored in the Android Keystore via flutter_secure_storage and never leave your device.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
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
                  child: Text('Google Gemini (gemini-1.5-flash)'),
                ),
                DropdownMenuItem(
                  value: AppConstants.providerGroq,
                  child: Text('Groq (llama-3.3-70b-versatile)'),
                ),
              ],
              onChanged: (val) {
                if (val != null) {
                  settings.setProvider(val).then((_) {
                    _apiKeyController.text = settings.apiKey;
                  });
                }
              },
            ),
            const SizedBox(height: 14),

            // Key Input
            TextField(
              controller: _apiKeyController,
              obscureText: _obscureKey,
              decoration: InputDecoration(
                labelText: '${settings.selectedProvider} API Key',
                hintText: 'Paste your secret API key here...',
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
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSignedIn ? AppColors.surfaceElevated : AppColors.royalBlue,
                      foregroundColor: isSignedIn ? AppColors.textPrimary : Colors.white,
                    ),
                    onPressed: () async {
                      if (isSignedIn) {
                        await gmail.signOut();
                        setState(() {});
                      } else {
                        await gmail.signIn();
                        setState(() {});
                      }
                    },
                    child: Text(isSignedIn ? 'Disconnect' : 'Connect Google Account'),
                  ),
                ),
                if (isSignedIn) ...[
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final dashboard = Provider.of<DashboardController>(context, listen: false);
                      final txController = Provider.of<TransactionController>(context, listen: false);

                      try {
                        final count = await gmail.scanRecentEmails();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Imported $count transactions from Gmail!'),
                            backgroundColor: AppColors.emerald,
                          ),
                        );
                        await dashboard.loadDashboardData();
                        await txController.loadTransactions();
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('Gmail Scan error: $e')),
                        );
                      }
                    },
                    child: const Text('Scan Now'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
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
