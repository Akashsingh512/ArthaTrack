import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../data/models/parsed_transaction.dart';
import '../../../../services/ingestion/notification_listener_channel.dart';
import '../../../../services/parsing/transaction_parser_pipeline.dart';
import '../../../controllers/dashboard_controller.dart';
import '../../../controllers/transaction_controller.dart';
import '../../../widgets/engine_badge.dart';

class RawSmsTestSandbox extends StatefulWidget {
  const RawSmsTestSandbox({super.key});

  @override
  State<RawSmsTestSandbox> createState() => _RawSmsTestSandboxState();
}

class _RawSmsTestSandboxState extends State<RawSmsTestSandbox> {
  final _textController = TextEditingController();
  final _pipeline = TransactionParserPipeline();
  final _notificationChannel = NotificationListenerChannel();

  bool _isProcessing = false;
  ParsedTransaction? _parsedResult;

  final List<Map<String, String>> _sampleTemplates = [
    {
      'title': 'HDFC Debited (Swiggy)',
      'text': 'HDFC Bank: Rs 460.00 debited from a/c **1234 on 10-09-26 to SWIGGY. Avl bal Rs 15,240.50',
    },
    {
      'title': 'SBI Credited (Salary)',
      'text': 'Dear SBI User, your A/C 9876 credited by INR 75,000.00 on 01-09-26 by SALARY. Bal: INR 88,500.00',
    },
    {
      'title': 'PhonePe Push (Starbucks)',
      'text': 'Paid ₹350 to Starbucks on PhonePe',
    },
    {
      'title': 'ICICI Bank (Amazon Shopping)',
      'text': 'ICICI Bank: Acct XX4321 debited for INR 1,299.00 on 05-Sep-26 by Amazon. Bal: INR 4,320.00',
    },
    {
      'title': 'GPay Push (Zepto Groceries)',
      'text': 'You paid ₹480 to Zepto using Google Pay',
    },
    {
      'title': 'Axis Card (Uber Transit)',
      'text': 'Axis Bank: INR 320.00 spent on your Card XX9900 at Uber India on 08-09-2026. Avail Bal: INR 12,000.00',
    },
  ];

  @override
  void initState() {
    super.initState();
    _textController.text = _sampleTemplates[0]['text']!;
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _runParse() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _parsedResult = null;
    });

    try {
      final result = await _pipeline.processText(text);
      setState(() {
        _parsedResult = result;
      });
    } catch (e) {
      print('Parse error: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _ingestIntoDatabase() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    await _notificationChannel.simulateNotification(rawText: text);
    if (mounted) {
      Provider.of<DashboardController>(context, listen: false).loadDashboardData();
      Provider.of<TransactionController>(context, listen: false).loadTransactions();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction successfully ingested into SQLite database!'),
          backgroundColor: AppColors.emerald,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF334155),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Row(
              children: [
                Icon(Icons.science, color: AppColors.aiEngine, size: 22),
                SizedBox(width: 8),
                Text(
                  'Transaction Parser Sandbox',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Test how ArthaTrack parses banking SMS and push notifications using Dual-Engine (BYOK AI with Regex fallback).',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 14),

            // Sample Selector Chips
            const Text(
              'Select Sample Indian Bank SMS / Push:',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _sampleTemplates.map((template) {
                final isSelected = _textController.text == template['text'];
                return ActionChip(
                  label: Text(template['title']!),
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.black : AppColors.textPrimary,
                  ),
                  backgroundColor: isSelected ? AppColors.emerald : AppColors.surfaceElevated,
                  onPressed: () {
                    setState(() {
                      _textController.text = template['text']!;
                      _parsedResult = null;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Raw Text Input
            TextField(
              controller: _textController,
              maxLines: 3,
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
              decoration: const InputDecoration(
                labelText: 'Raw SMS / Notification Text',
                hintText: 'Paste any Indian Bank SMS or UPI notification...',
              ),
            ),
            const SizedBox(height: 14),

            // Parse Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _runParse,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Icon(Icons.play_arrow, size: 18),
                label: Text(_isProcessing ? 'Parsing with Dual Engine...' : 'Run Dual-Engine Parser'),
              ),
            ),
            const SizedBox(height: 16),

            // Parsed Result Card
            if (_parsedResult != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'PARSED TRANSACTION',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        EngineBadge(engine: _parsedResult!.engine),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _parsedResult!.merchant,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${_parsedResult!.isIncome ? '+' : '-'}${IndianCurrencyFormatter.format(_parsedResult!.amount)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _parsedResult!.isIncome ? AppColors.income : AppColors.expense,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _ResultRow(label: 'Type', value: _parsedResult!.type.name),
                    _ResultRow(label: 'Category', value: _parsedResult!.category),
                    if (_parsedResult!.updatedBalance != null)
                      _ResultRow(
                        label: 'Updated Balance',
                        value: IndianCurrencyFormatter.format(_parsedResult!.updatedBalance!),
                      ),
                    if (_parsedResult!.accountSnippet != null)
                      _ResultRow(label: 'Account Extracted', value: _parsedResult!.accountSnippet!),
                    _ResultRow(
                      label: 'Confidence Score',
                      value: '${(_parsedResult!.confidence * 100).toInt()}%',
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.emerald),
                        ),
                        onPressed: _ingestIntoDatabase,
                        icon: const Icon(Icons.save_alt, color: AppColors.emerald, size: 18),
                        label: const Text(
                          'Save & Ingest into Account',
                          style: TextStyle(color: AppColors.emerald, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (!_isProcessing && _textController.text.isNotEmpty) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Tap "Run Dual-Engine Parser" above to view extraction details.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;

  const _ResultRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
