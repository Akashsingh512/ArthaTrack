import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_haptics.dart';
import '../../services/updater/app_update_service.dart';

enum UpdateDownloadState {
  idle,
  downloading,
  completed,
  error,
}

class UpdateDialogSheet extends StatefulWidget {
  final UpdateInfo updateInfo;
  final AppUpdateService updateService;

  const UpdateDialogSheet({
    super.key,
    required this.updateInfo,
    required this.updateService,
  });

  static Future<void> show(BuildContext context, UpdateInfo updateInfo) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => UpdateDialogSheet(
        updateInfo: updateInfo,
        updateService: AppUpdateService(),
      ),
    );
  }

  @override
  State<UpdateDialogSheet> createState() => _UpdateDialogSheetState();
}

class _UpdateDialogSheetState extends State<UpdateDialogSheet> {
  UpdateDownloadState _state = UpdateDownloadState.idle;
  double _progress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  String? _downloadedFilePath;
  String? _errorMessage;
  bool _isCancelled = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _startDownload() async {
    AppHaptics.medium();
    setState(() {
      _state = UpdateDownloadState.downloading;
      _progress = 0.0;
      _receivedBytes = 0;
      _totalBytes = (widget.updateInfo.apkSizeMb * 1024 * 1024).toInt();
      _errorMessage = null;
      _isCancelled = false;
    });

    final filePath = await widget.updateService.downloadApk(
      downloadUrl: widget.updateInfo.apkDownloadUrl,
      onProgress: (progress, received, total) {
        if (mounted && !_isCancelled) {
          setState(() {
            _progress = progress;
            _receivedBytes = received;
            if (total > 0) _totalBytes = total;
          });
        }
      },
      isCancelled: () => _isCancelled,
    );

    if (_isCancelled) return;

    if (filePath != null && mounted) {
      AppHaptics.heavy();
      setState(() {
        _state = UpdateDownloadState.completed;
        _downloadedFilePath = filePath;
      });

      // Automatically launch native installer
      await _triggerInstall(filePath);
    } else if (mounted) {
      AppHaptics.error();
      setState(() {
        _state = UpdateDownloadState.error;
        _errorMessage =
            'In-app download could not complete. You can tap Retry or tap "Download via Browser" below to get it directly in Chrome.';
      });
    }
  }

  Future<void> _triggerInstall(String filePath) async {
    final success = await widget.updateService.installApk(filePath);
    if (!success && mounted) {
      final canInstall = await widget.updateService.canInstallPackages();
      if (!canInstall && mounted) {
        // Show guidance to enable install permission
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Please allow ArthaTrack to install unknown apps in Android settings.',
            ),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => widget.updateService.openInstallPermissionSettings(),
            ),
          ),
        );
      }
    }
  }

  void _cancelDownload() {
    AppHaptics.light();
    setState(() {
      _isCancelled = true;
      _state = UpdateDownloadState.idle;
      _progress = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final info = widget.updateInfo;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: colors.border),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textMuted.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header with badge
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.emerald.withOpacity(colors.isDark ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colors.emerald.withOpacity(0.4),
                      ),
                    ),
                    child: Icon(
                      Icons.rocket_launch_rounded,
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
                              'New Update Available!',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: colors.surfaceElevated,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: colors.border),
                              ),
                              child: Text(
                                'Build ${info.latestBuild}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: colors.emerald,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '(Current: Build ${info.currentBuild})',
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.textMuted,
                              ),
                            ),
                            if (info.apkSizeMb > 0) ...[
                              const SizedBox(width: 8),
                              Text(
                                '•  ${info.apkSizeMb} MB',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 16),

            // Release Notes / What's New
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "What's New in this Build:",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colors.surfaceElevated,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: colors.border),
                      ),
                      child: Text(
                        info.releaseNotes.isNotEmpty
                            ? info.releaseNotes
                            : '• General performance enhancements and bug fixes.\n• Offline parsing updates.\n• Data synchronization polish.',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Information Note
                    Row(
                      children: [
                        Icon(Icons.shield_outlined, size: 14, color: colors.emerald),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'All your local transactions, accounts, and settings are 100% preserved during updates.',
                            style: TextStyle(fontSize: 11, color: colors.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Progress Bar (when downloading)
            if (_state == UpdateDownloadState.downloading) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Downloading Update: ${(_progress * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: colors.emerald,
                          ),
                        ),
                        Text(
                          '${(_receivedBytes / (1024 * 1024)).toStringAsFixed(1)} / ${info.apkSizeMb > 0 ? info.apkSizeMb.toStringAsFixed(1) : (_totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _progress > 0 ? _progress : null,
                        minHeight: 7,
                        backgroundColor: colors.surfaceElevated,
                        valueColor: AlwaysStoppedAnimation<Color>(colors.emerald),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Error Message
            if (_state == UpdateDownloadState.error && _errorMessage != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.ruby.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.ruby.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, size: 16, color: colors.ruby),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(fontSize: 11, color: colors.ruby),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Success Note (when completed)
            if (_state == UpdateDownloadState.completed) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.emerald.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.emerald.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, size: 16, color: colors.emerald),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Download complete! Tap Install below if the Android installer did not open automatically.',
                          style: TextStyle(fontSize: 11, color: colors.emerald),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Bottom Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_state == UpdateDownloadState.idle || _state == UpdateDownloadState.error) ...[
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.emerald,
                        foregroundColor: colors.isDark ? Colors.black : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _startDownload,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _state == UpdateDownloadState.error ? Icons.refresh : Icons.download_rounded,
                            size: 18,
                            color: colors.isDark ? Colors.black : Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _state == UpdateDownloadState.error ? 'Retry In-App Download' : 'Download & Install Update',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.emerald,
                        side: BorderSide(color: colors.emerald.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        AppHaptics.medium();
                        widget.updateService.openInBrowser(widget.updateInfo.apkDownloadUrl);
                      },
                      icon: const Icon(Icons.open_in_browser, size: 18),
                      label: const Text(
                        'Download via Browser (Chrome)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Remind Me Later',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textMuted,
                        ),
                      ),
                    ),
                  ] else if (_state == UpdateDownloadState.downloading) ...[
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.textSecondary,
                        side: BorderSide(color: colors.border),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _cancelDownload,
                      child: const Text('Cancel Download', style: TextStyle(fontSize: 13)),
                    ),
                  ] else if (_state == UpdateDownloadState.completed) ...[
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.emerald,
                        foregroundColor: colors.isDark ? Colors.black : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        AppHaptics.medium();
                        if (_downloadedFilePath != null) {
                          _triggerInstall(_downloadedFilePath!);
                        }
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.system_update_rounded,
                            size: 18,
                            color: colors.isDark ? Colors.black : Colors.white,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Install Update Now',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
