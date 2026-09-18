import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Centralized utility for tactile micro-haptic feedback across the application.
class AppHaptics {
  static const MethodChannel _channel = MethodChannel('com.arthatrack.app/haptics');
  static bool isEnabled = true;

  static void _trigger(String type, VoidCallback flutterFallback) {
    if (!isEnabled) return;
    try {
      _channel.invokeMethod('haptic', {'type': type}).catchError((_) {
        try {
          flutterFallback();
        } catch (_) {}
      });
    } catch (_) {
      try {
        flutterFallback();
      } catch (_) {}
    }
  }

  /// Subtle micro-click for chip toggles, segmented tabs, and filter pills
  static void selection() {
    _trigger('selection', () => HapticFeedback.lightImpact());
  }

  /// Light impact for standard buttons, icon toggles, and modal dismissals
  static void light() {
    _trigger('light', () => HapticFeedback.lightImpact());
  }

  /// Medium impact for primary actions (e.g. Save, Add, Confirm, Sync)
  static void medium() {
    _trigger('medium', () => HapticFeedback.mediumImpact());
  }

  /// Heavy impact for destructive actions (e.g. Delete, Wipe data)
  static void heavy() {
    _trigger('heavy', () => HapticFeedback.heavyImpact());
  }

  /// Success vibration for completed sync or saved transaction
  static void success() {
    _trigger('medium', () => HapticFeedback.mediumImpact());
  }

  /// Error vibration for declined transactions or validation warnings
  static void error() {
    _trigger('error', () => HapticFeedback.vibrate());
  }
}
