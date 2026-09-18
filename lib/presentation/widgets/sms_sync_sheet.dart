import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_haptics.dart';
import '../../services/ingestion/sms_sync_service.dart';
import '../controllers/analytics_controller.dart';
import '../controllers/balance_sheet_controller.dart';
import '../controllers/dashboard_controller.dart';
import '../controllers/settings_controller.dart';
import '../controllers/transaction_controller.dart';

class SmsSyncSheet extends StatefulWidget {
  const SmsSyncSheet({super.key});

  static Future<void> show(BuildContext context) {
    AppHaptics.medium();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SmsSyncSheet(),
    );
  }

  @override
  State<SmsSyncSheet> createState() => _SmsSyncSheetState();
}

class _SmsSyncSheetState extends State<SmsSyncSheet> {
  // Available preset limits: 0 represents "All" (no limit)
  final List<int> _presetLimits = [50, 100, 250, 500, 1000, 5000, 0];

  int _selectedLimit = 500;
  bool _isCustom = false;
  bool _saveAsDefault = true;
  bool _isSyncing = false;
  SmsSyncResult? _lastResult;
  late TextEditingController _customCountController;

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<SettingsController>(context, listen: false);
    _selectedLimit = settings.smsPullLimit;
    if (!_presetLimits.contains(_selectedLimit) && _selectedLimit > 0) {
      _isCustom = true;
      _customCountController = TextEditingController(text: _selectedLimit.toString());
    } else {
      _customCountController = TextEditingController(text: '300');
    }
  }

  @override
  void dispose() {
    _customCountController.dispose();
    super.dispose();
  }

  int get _effectiveLimit {
    if (_isCustom) {
      final val = int.tryParse(_customCountController.text.trim());
      if (val != null && val > 0) {
        return val.clamp(1, 50000);
      }
      return 500;
    }
    return _selectedLimit;
  }

  String _getLimitLabel(int limit) {
    if (limit == 0) return 'All Messages (Deep Scan)';
    if (limit >= 1000) {
      return '${(limit / 1000).toStringAsFixed(limit % 1000 == 0 ? 0 : 1)}k msgs';
    }
    return '$limit msgs';
  }

  String _getLimitDescription(int limit) {
    if (limit == 50) {
      return '⚡ Fastest scan (1-2s). Pulls latest 50 SMS to capture today\'s and yesterday\'s latest transactions.';
    } else if (limit == 100) {
      return '⚡ Quick check. Scans 100 recent messages across the last few days.';
    } else if (limit == 250) {
      return '🔍 Moderate scan. Scans up to 250 messages (typically 2-4 weeks of bank alerts).';
    } else if (limit == 500) {
      return '⭐ Recommended. Scans up to 500 messages (typically 1-3 months of banking activity).';
    } else if (limit == 1000) {
      return '📊 Extended scan. Scans up to 1,000 messages across several months of transactions.';
    } else if (limit == 5000) {
      return '🚀 Deep scan. Pulls up to 5,000 messages across recent years of inbox history.';
    } else if (limit == 0) {
      return '🌐 Full Deep Scan. Inspects every single SMS message in your phone\'s inbox with zero limit.';
    } else {
      return '🎯 Custom scan. Pulls your latest $limit SMS messages from inbox.';
    }
  }

  Future<void> _startSync() async {
    AppHaptics.medium();
    final settings = Provider.of<SettingsController>(context, listen: false);
    final limitToUse = _effectiveLimit;

    if (_saveAsDefault) {
      await settings.setSmsPullLimit(limitToUse);
    }

    setState(() {
      _isSyncing = true;
      _lastResult = null;
    });

    final result = await settings.syncSmsInbox(limit: limitToUse);

    if (!mounted) return;

    setState(() {
      _isSyncing = false;
      _lastResult = result;
    });

    if (result.status == SmsSyncStatus.success) {
      AppHaptics.success();
      // Reload all state controllers across the app
      final dashboard = Provider.of<DashboardController>(context, listen: false);
      final tx = Provider.of<TransactionController>(context, listen: false);
      final analytics = Provider.of<AnalyticsController>(context, listen: false);
      final balance = Provider.of<BalanceSheetController>(context, listen: false);

      await Future.wait([
        dashboard.loadDashboardData(),
        tx.loadTransactions(),
        analytics.loadAnalytics(),
        balance.loadBalanceSheetData(),
      ]);
    } else {
      AppHaptics.error();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final currentLimit = _effectiveLimit;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: 20 + bottomInset,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: colors.borderSubtle, width: 1),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
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

            // Header Title
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.emerald.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.sms_rounded,
                    color: colors.emerald,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pull Transactions from SMS',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Select how many messages to scan from inbox',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: colors.textMuted, size: 20),
                  onPressed: () {
                    AppHaptics.light();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Quick Limit Chips
            Text(
              'MESSAGE SCAN LIMIT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color: colors.textMuted,
              ),
            ),
            const SizedBox(height: 10),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._presetLimits.map((limit) {
                  final isSelected = !_isCustom && _selectedLimit == limit;
                  String label = limit == 0 ? 'All (Deep)' : (limit == 500 ? '500 (Rec.)' : '$limit');
                  return ChoiceChip(
                    label: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? (colors.isDark ? Colors.black : Colors.white)
                            : colors.textPrimary,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: colors.emerald,
                    backgroundColor: colors.surfaceCard,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? colors.emerald : colors.border,
                      ),
                    ),
                    onSelected: _isSyncing
                        ? null
                        : (selected) {
                            if (selected) {
                              AppHaptics.selection();
                              setState(() {
                                _isCustom = false;
                                _selectedLimit = limit;
                              });
                            }
                          },
                  );
                }),
                ChoiceChip(
                  label: Text(
                    'Custom...',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: _isCustom ? FontWeight.w700 : FontWeight.w500,
                      color: _isCustom
                          ? (colors.isDark ? Colors.black : Colors.white)
                          : colors.textPrimary,
                    ),
                  ),
                  selected: _isCustom,
                  selectedColor: colors.emerald,
                  backgroundColor: colors.surfaceCard,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: _isCustom ? colors.emerald : colors.border,
                    ),
                  ),
                  onSelected: _isSyncing
                      ? null
                      : (selected) {
                          if (selected) {
                            AppHaptics.selection();
                            setState(() {
                              _isCustom = true;
                            });
                          }
                        },
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Custom Count Input (if selected)
            if (_isCustom) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.surfaceCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.emerald, width: 1.2),
                ),
                child: Row(
                  children: [
                    Icon(Icons.edit_note, color: colors.emerald, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _customCountController,
                        keyboardType: TextInputType.number,
                        enabled: !_isSyncing,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Enter count (e.g. 150, 300, 2000)',
                          hintStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.normal),
                          suffixText: 'messages',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Dynamic Description Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Text(
                _getLimitDescription(currentLimit),
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: colors.textPrimary.withOpacity(0.85),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Checkbox: Save as Default
            InkWell(
              onTap: _isSyncing
                  ? null
                  : () {
                      AppHaptics.light();
                      setState(() {
                        _saveAsDefault = !_saveAsDefault;
                      });
                    },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _saveAsDefault,
                        activeColor: colors.emerald,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: _isSyncing
                            ? null
                            : (val) {
                                AppHaptics.light();
                                setState(() {
                                  _saveAsDefault = val ?? false;
                                });
                              },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Remember this count as my default scan limit',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Result Banner (if completed)
            if (_lastResult != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _lastResult!.status == SmsSyncStatus.success
                      ? colors.emerald.withOpacity(0.12)
                      : colors.ruby.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _lastResult!.status == SmsSyncStatus.success
                        ? colors.emerald.withOpacity(0.4)
                        : colors.ruby.withOpacity(0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _lastResult!.status == SmsSyncStatus.success
                          ? Icons.check_circle
                          : Icons.error_outline,
                      color: _lastResult!.status == SmsSyncStatus.success
                          ? colors.emerald
                          : colors.ruby,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _lastResult!.status == SmsSyncStatus.success
                            ? (_lastResult!.importedCount > 0
                                ? 'Imported ${_lastResult!.importedCount} new transactions (${_lastResult!.scannedCount} SMS scanned)!'
                                : 'All messages up to date (${_lastResult!.scannedCount} scanned, 0 new).')
                            : (_lastResult!.status == SmsSyncStatus.permissionDenied
                                ? 'SMS permission was denied. Please grant permission in Settings.'
                                : 'Error: ${_lastResult!.errorMessage}'),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _lastResult!.status == SmsSyncStatus.success
                              ? colors.emerald
                              : colors.ruby,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Action Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.emerald,
                  foregroundColor: colors.isDark ? Colors.black : Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isSyncing ? null : _startSync,
                icon: _isSyncing
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: colors.isDark ? Colors.black : Colors.white,
                        ),
                      )
                    : const Icon(Icons.cloud_download, size: 20),
                label: Text(
                  _isSyncing
                      ? 'Scanning inbox messages...'
                      : (_lastResult?.status == SmsSyncStatus.success
                          ? 'Scan Again (${_getLimitLabel(currentLimit)})'
                          : 'Scan & Import (${_getLimitLabel(currentLimit)})'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
