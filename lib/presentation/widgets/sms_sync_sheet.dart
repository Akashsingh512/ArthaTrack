import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  // Date Presets
  final List<Map<String, String>> _datePresets = [
    {'id': 'this_month', 'label': 'This Month'},
    {'id': 'this_week', 'label': 'This Week'},
    {'id': 'last_month', 'label': 'Last Month'},
    {'id': 'last_3_months', 'label': 'Last 3 Months'},
    {'id': 'this_year', 'label': 'This Year (2026)'},
    {'id': 'all_time', 'label': 'All Time (Full)'},
    {'id': 'custom', 'label': 'Custom Dates...'},
  ];

  late String _selectedPreset;
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  // Optional message cap: 0 means no cap
  int _selectedLimitCap = 0;
  final List<int> _limitCaps = [0, 250, 500, 1000, 5000];

  bool _saveAsDefault = true;
  bool _isSyncing = false;
  SmsSyncResult? _lastResult;

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<SettingsController>(context, listen: false);
    _selectedPreset = settings.smsDatePreset;
    _selectedLimitCap = settings.smsPullLimit;

    final now = DateTime.now();
    _customStartDate = settings.customStartDate ?? DateTime(now.year, now.month, 1);
    _customEndDate = settings.customEndDate ?? now;
  }

  DateTime? get _effectiveStartDate {
    final now = DateTime.now();
    switch (_selectedPreset) {
      case 'this_week':
        return now.subtract(const Duration(days: 7));
      case 'this_month':
        return DateTime(now.year, now.month, 1);
      case 'last_month':
        return DateTime(now.year, now.month - 1, 1);
      case 'last_3_months':
        return DateTime(now.year, now.month - 2, 1);
      case 'this_year':
        return DateTime(now.year, 1, 1);
      case 'custom':
        return _customStartDate;
      case 'all_time':
      default:
        return null;
    }
  }

  DateTime? get _effectiveEndDate {
    final now = DateTime.now();
    switch (_selectedPreset) {
      case 'last_month':
        return DateTime(now.year, now.month, 0, 23, 59, 59, 999);
      case 'custom':
        return _customEndDate != null
            ? DateTime(_customEndDate!.year, _customEndDate!.month, _customEndDate!.day, 23, 59, 59, 999)
            : null;
      default:
        return null;
    }
  }

  String _getPeriodDescription() {
    final now = DateTime.now();
    final monthFormat = DateFormat('MMMM yyyy');
    final dateFormat = DateFormat('dd MMM yyyy');

    switch (_selectedPreset) {
      case 'this_week':
        return '⚡ Pulls bank SMS from the last 7 days (today back to ${dateFormat.format(now.subtract(const Duration(days: 7)))}).';
      case 'this_month':
        return '🗓️ Pulls all bank SMS for ${monthFormat.format(now)} (1st ${DateFormat('MMM').format(now)} to today).';
      case 'last_month':
        final prev = DateTime(now.year, now.month - 1, 1);
        final prevEnd = DateTime(now.year, now.month, 0);
        return '🗓️ Pulls all bank SMS for entire ${monthFormat.format(prev)} (${dateFormat.format(prev)} to ${dateFormat.format(prevEnd)}).';
      case 'last_3_months':
        final threeAgo = DateTime(now.year, now.month - 2, 1);
        return '📊 Pulls bank SMS across the past 3 months (${dateFormat.format(threeAgo)} to today).';
      case 'this_year':
        return '📅 Pulls all bank SMS received in ${now.year} (from 1st January to today).';
      case 'all_time':
        return '🌐 Full Deep Scan. Inspects all historical bank SMS in your inbox with zero date restrictions.';
      case 'custom':
        if (_customStartDate != null && _customEndDate != null) {
          return '🎯 Pulls bank SMS received between ${dateFormat.format(_customStartDate!)} and ${dateFormat.format(_customEndDate!)}.';
        }
        return '🎯 Custom date range. Select start and end dates below.';
      default:
        return 'Pulls bank SMS for the chosen period.';
    }
  }

  String _getPeriodShortLabel() {
    switch (_selectedPreset) {
      case 'this_week':
        return 'This Week';
      case 'this_month':
        return DateFormat('MMMM').format(DateTime.now());
      case 'last_month':
        final now = DateTime.now();
        return DateFormat('MMMM').format(DateTime(now.year, now.month - 1, 1));
      case 'last_3_months':
        return 'Last 3 Months';
      case 'this_year':
        return '${DateTime.now().year}';
      case 'all_time':
        return 'All Time';
      case 'custom':
        if (_customStartDate != null && _customEndDate != null) {
          return '${DateFormat('dd MMM').format(_customStartDate!)} - ${DateFormat('dd MMM').format(_customEndDate!)}';
        }
        return 'Custom';
      default:
        return 'Selected Period';
    }
  }

  Future<void> _pickDateRange(BuildContext context) async {
    AppHaptics.light();
    final colors = context.colors;
    final now = DateTime.now();

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(
        start: _customStartDate ?? DateTime(now.year, now.month, 1),
        end: _customEndDate ?? now,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: colors.emerald,
                  onPrimary: colors.isDark ? Colors.black : Colors.white,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      AppHaptics.selection();
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = picked.end;
        _selectedPreset = 'custom';
      });
    }
  }

  Future<void> _startSync() async {
    AppHaptics.medium();
    final settings = Provider.of<SettingsController>(context, listen: false);

    final start = _effectiveStartDate;
    final end = _effectiveEndDate;

    if (_saveAsDefault) {
      await settings.setSmsDatePreset(_selectedPreset, startDate: _customStartDate, endDate: _customEndDate);
      await settings.setSmsPullLimit(_selectedLimitCap);
    }

    setState(() {
      _isSyncing = true;
      _lastResult = null;
    });

    final result = await settings.syncSmsInbox(
      limit: _selectedLimitCap,
      startDate: start,
      endDate: end,
    );

    if (!mounted) return;

    setState(() {
      _isSyncing = false;
      _lastResult = result;
    });

    if (result.status == SmsSyncStatus.success) {
      AppHaptics.success();
      final dashboard = Provider.of<DashboardController>(context, listen: false);
      final tx = Provider.of<TransactionController>(context, listen: false);
      final analytics = Provider.of<AnalyticsController>(context, listen: false);
      final balance = Provider.of<BalanceSheetController>(context, listen: false);

      await dashboard.loadDashboardData();
      await tx.loadTransactions();
      await analytics.loadAnalytics();
      await balance.loadBalanceSheet();
    } else {
      AppHaptics.error();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final dateFormat = DateFormat('dd MMM yyyy');

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
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

            // Header Row
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colors.emerald.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.date_range_rounded,
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
                        'Select which month or date range to scan',
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

            // Section: Choose Time Period (Months / Weeks / Year)
            Text(
              'SELECT TIME PERIOD',
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
              children: _datePresets.map((preset) {
                final isSelected = _selectedPreset == preset['id'];
                return ChoiceChip(
                  label: Text(
                    preset['label']!,
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
                              _selectedPreset = preset['id']!;
                            });
                            if (preset['id'] == 'custom') {
                              _pickDateRange(context);
                            }
                          }
                        },
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Custom Range Picker Card (if custom is active)
            if (_selectedPreset == 'custom') ...[
              InkWell(
                onTap: _isSyncing ? null : () => _pickDateRange(context),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: colors.surfaceCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.emerald, width: 1.2),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month, color: colors.emerald, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Custom Date Range',
                              style: TextStyle(fontSize: 11, color: colors.textMuted, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_customStartDate != null ? dateFormat.format(_customStartDate!) : "Start"}  ➔  ${_customEndDate != null ? dateFormat.format(_customEndDate!) : "End"}',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: colors.emerald.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Change',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colors.emerald),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Live Period Explanation Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Text(
                _getPeriodDescription(),
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: colors.textPrimary.withOpacity(0.85),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Optional Message Limit Cap Selector
            Row(
              children: [
                Text(
                  'MESSAGE CAP',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: colors.textMuted,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '(optional safeguard)',
                  style: TextStyle(fontSize: 10, color: colors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 8),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _limitCaps.map((cap) {
                  final isSelected = _selectedLimitCap == cap;
                  final label = cap == 0 ? 'No Limit (All msgs)' : '$cap max';
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
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
                        borderRadius: BorderRadius.circular(16),
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
                                  _selectedLimitCap = cap;
                                });
                              }
                            },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),

            // Checkbox: Remember as default
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
                        'Remember this time period as default sync setting',
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

            // Live Progressive Sync Card (when syncing)
            if (_isSyncing) ...[
              Consumer<SettingsController>(
                builder: (context, settings, _) {
                  final progress = settings.smsSyncProgress;
                  final processed = settings.smsSyncProcessed;
                  final total = settings.smsSyncTotal;
                  final imported = settings.smsSyncImportedSoFar;
                  final pct = (progress * 100).toInt();

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.surfaceElevated,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colors.emerald.withOpacity(0.35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colors.emerald,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  total > 0 ? 'Scanning Inbox: $pct%' : 'Reading Inbox Messages...',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            if (total > 0)
                              Text(
                                '$processed / $total msgs',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: colors.emerald,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: total > 0 ? progress : null,
                            minHeight: 7,
                            backgroundColor: colors.surfaceCard,
                            valueColor: AlwaysStoppedAnimation<Color>(colors.emerald),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.auto_awesome, size: 13, color: colors.emerald),
                                const SizedBox(width: 6),
                                Text(
                                  '$imported transaction${imported == 1 ? '' : 's'} detected so far',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            if (total > 0 && (total - processed) > 0)
                              Text(
                                '${total - processed} remaining',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: colors.textMuted,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
            ],

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
                          ? 'Scan Again (${_getPeriodShortLabel()})'
                          : 'Scan & Import (${_getPeriodShortLabel()})'),
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
