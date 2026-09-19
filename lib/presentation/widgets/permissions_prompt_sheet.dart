import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_haptics.dart';
import '../../services/ingestion/notification_listener_channel.dart';
import '../../services/ingestion/sms_sync_service.dart';

class PermissionsPromptSheet extends StatefulWidget {
  final VoidCallback? onAllGranted;

  const PermissionsPromptSheet({
    super.key,
    this.onAllGranted,
  });

  /// Checks if any essential permissions are missing and shows the prompt sheet if so.
  static Future<bool> checkAndShow(
    BuildContext context, {
    bool force = false,
  }) async {
    final smsService = SmsSyncService();
    final notifChannel = NotificationListenerChannel();

    final isSmsGranted = await smsService.isPermissionGranted();
    final isNotifGranted = await notifChannel.isPermissionGranted();
    final isBatteryIgnored = await notifChannel.isIgnoringBatteryOptimizations();

    // If all essential permissions are already granted and not forced, skip popup
    if (!force && isSmsGranted && isNotifGranted && isBatteryIgnored) {
      return false;
    }

    if (!context.mounted) return false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      builder: (ctx) => const PermissionsPromptSheet(),
    );

    return true;
  }

  @override
  State<PermissionsPromptSheet> createState() => _PermissionsPromptSheetState();
}

class _PermissionsPromptSheetState extends State<PermissionsPromptSheet>
    with WidgetsBindingObserver {
  final _smsService = SmsSyncService();
  final _notifChannel = NotificationListenerChannel();

  bool _smsGranted = false;
  bool _notifListenerGranted = false;
  bool _batteryIgnored = false;
  bool _postNotifGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAllPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAllPermissions();
    }
  }

  Future<void> _checkAllPermissions() async {
    final sms = await _smsService.isPermissionGranted();
    final notif = await _notifChannel.isPermissionGranted();
    final battery = await _notifChannel.isIgnoringBatteryOptimizations();
    final postNotif = await _notifChannel.checkPostNotificationPermission();

    if (mounted) {
      setState(() {
        _smsGranted = sms;
        _notifListenerGranted = notif;
        _batteryIgnored = battery;
        _postNotifGranted = postNotif;
      });

      if (_smsGranted && _notifListenerGranted && _batteryIgnored) {
        widget.onAllGranted?.call();
      }
    }
  }

  bool get _allCriticalGranted =>
      _smsGranted && _notifListenerGranted && _batteryIgnored;

  Future<void> _requestSms() async {
    AppHaptics.medium();
    final granted = await _smsService.requestPermission();
    if (!granted && mounted) {
      // If system dialog was rejected or suppressed, offer direct App Info settings
      await _smsService.openAppSettings();
    }
    await _checkAllPermissions();
  }

  Future<void> _openSpecialSmsSettings() async {
    AppHaptics.medium();
    await _smsService.openAppSettings();
    await _checkAllPermissions();
  }

  Future<void> _requestNotifListener() async {
    AppHaptics.medium();
    await _notifChannel.openSettings();
    await _checkAllPermissions();
  }

  Future<void> _requestBatteryOptimization() async {
    AppHaptics.medium();
    await _notifChannel.requestIgnoreBatteryOptimizations();
    await _checkAllPermissions();
  }

  Future<void> _requestPostNotification() async {
    AppHaptics.medium();
    await _notifChannel.requestPostNotificationPermission();
    await _checkAllPermissions();
  }

  Future<void> _grantAllRemaining() async {
    AppHaptics.heavy();
    if (!_smsGranted) {
      final granted = await _smsService.requestPermission();
      if (!granted && mounted) {
        await _smsService.openAppSettings();
        return;
      }
    }
    if (!_notifListenerGranted && mounted) {
      await _notifChannel.openSettings();
      return;
    }
    if (!_batteryIgnored && mounted) {
      await _notifChannel.requestIgnoreBatteryOptimizations();
      return;
    }
    await _checkAllPermissions();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final size = MediaQuery.of(context).size;

    return Container(
      constraints: BoxConstraints(maxHeight: size.height * 0.90),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: colors.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: colors.textMuted.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            // Header Section
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colors.emerald.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colors.emerald.withOpacity(0.3),
                      ),
                    ),
                    child: Icon(
                      Icons.security_rounded,
                      color: colors.emerald,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Permissions Setup',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: colors.textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: colors.surfaceElevated,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: colors.border),
                              ),
                              child: Text(
                                '100% OFFLINE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: colors.emerald,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'To automatically detect transactions without cloud servers, ArthaTrack needs these on-device permissions.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: colors.textMuted,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Permission Items List
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Column(
                  children: [
                    // All Granted Banner
                    if (_allCriticalGranted) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: colors.emerald.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: colors.emerald.withOpacity(0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              color: colors.emerald,
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'All Critical Permissions Active!',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: colors.emerald,
                                    ),
                                  ),
                                  Text(
                                    'Automatic bank and UPI tracking is fully operational.',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // 1. Bank SMS Permission Card
                    _buildPermissionCard(
                      context,
                      icon: Icons.sms_rounded,
                      iconColor: colors.emerald,
                      title: 'Bank & UPI SMS Access',
                      badgeText: 'CRITICAL',
                      description:
                          'Detects debit & credit SMS from HDFC, SBI, ICICI, Axis, Paytm, and other banks. OTPs are unconditionally rejected.',
                      isGranted: _smsGranted,
                      primaryActionLabel: 'Grant SMS Permission',
                      onPrimaryAction: _requestSms,
                      specialActionLabel:
                          'Special SMS Permission / App Settings',
                      specialActionHint:
                          'On Xiaomi (MIUI/HyperOS), Vivo, Oppo, Realme, or Android 13+, tap here -> Permissions -> Allow SMS / Service SMS if restricted.',
                      onSpecialAction: _openSpecialSmsSettings,
                    ),

                    const SizedBox(height: 12),

                    // 2. Notification Listener (Push-Only UPI)
                    _buildPermissionCard(
                      context,
                      icon: Icons.notifications_active_rounded,
                      iconColor: colors.amber,
                      title: 'UPI Notification Listener',
                      badgeText: 'CRITICAL FOR GPAY/PHONEPE',
                      description:
                          'Captures real-time push payments from Google Pay, PhonePe, Paytm, and CRED when banks do not send an SMS.',
                      isGranted: _notifListenerGranted,
                      primaryActionLabel: 'Enable Notification Access',
                      onPrimaryAction: _requestNotifListener,
                    ),

                    const SizedBox(height: 12),

                    // 3. Battery Saver Exemption
                    _buildPermissionCard(
                      context,
                      icon: Icons.battery_charging_full_rounded,
                      iconColor: colors.royalBlue,
                      title: 'Battery Saver Exemption',
                      badgeText: 'RECOMMENDED FOR UPTIME',
                      description:
                          'Prevents Android OEM task-killers from terminating the notification listener when your screen is locked.',
                      isGranted: _batteryIgnored,
                      primaryActionLabel: 'Allow Unrestricted Background',
                      onPrimaryAction: _requestBatteryOptimization,
                    ),

                    const SizedBox(height: 12),

                    // 4. Notification Posting (Android 13+)
                    _buildPermissionCard(
                      context,
                      icon: Icons.notifications_outlined,
                      iconColor: colors.textSecondary,
                      title: 'Transaction Banners (Alerts)',
                      badgeText: 'OPTIONAL',
                      description:
                          'Displays instant actionable alerts so you can categorize UPI transactions right when they happen.',
                      isGranted: _postNotifGranted,
                      primaryActionLabel: 'Allow Alerts',
                      onPrimaryAction: _requestPostNotification,
                    ),
                  ],
                ),
              ),
            ),

            const Divider(height: 1),

            // Footer Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: Column(
                children: [
                  if (!_allCriticalGranted) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.emerald,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _grantAllRemaining,
                        icon: const Icon(Icons.flash_on_rounded, size: 20),
                        label: const Text(
                          'Grant Remaining Permissions',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: colors.textMuted,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        AppHaptics.light();
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        _allCriticalGranted
                            ? 'Done • Enter ArthaTrack'
                            : "I'll do this later • Continue to App",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _allCriticalGranted
                              ? colors.emerald
                              : colors.textMuted,
                        ),
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

  Widget _buildPermissionCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String badgeText,
    required String description,
    required bool isGranted,
    required String primaryActionLabel,
    required VoidCallback onPrimaryAction,
    String? specialActionLabel,
    String? specialActionHint,
    VoidCallback? onSpecialAction,
  }) {
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGranted
              ? colors.emerald.withOpacity(0.35)
              : colors.border,
          width: isGranted ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: isGranted ? colors.emerald : colors.amber,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isGranted
                      ? colors.emerald.withOpacity(0.15)
                      : colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isGranted
                          ? Icons.check_circle_rounded
                          : Icons.pending_rounded,
                      size: 13,
                      color: isGranted ? colors.emerald : colors.amber,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isGranted ? 'ACTIVE' : 'ACTION REQUIRED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isGranted ? colors.emerald : colors.amber,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            description,
            style: TextStyle(
              fontSize: 11.5,
              color: colors.textSecondary,
              height: 1.35,
            ),
          ),

          if (!isGranted) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: iconColor,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: onPrimaryAction,
                child: Text(
                  primaryActionLabel,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            // Special OEM SMS Permission Button & Guidance
            if (specialActionLabel != null && onSpecialAction != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 34,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.textPrimary,
                    side: BorderSide(color: colors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: onSpecialAction,
                  icon: const Icon(Icons.settings_outlined, size: 14),
                  label: Text(
                    specialActionLabel,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (specialActionHint != null) ...[
                const SizedBox(height: 5),
                Text(
                  specialActionHint,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: colors.textMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }
}
