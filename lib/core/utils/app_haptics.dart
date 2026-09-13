import 'package:flutter/services.dart';

/// Centralized utility for tactile micro-haptic feedback across the application.
class AppHaptics {
  /// Subtle micro-click for chip toggles, segmented tabs, and filter pills
  static void selection() {
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// Light impact for standard buttons, icon toggles, and modal dismissals
  static void light() {
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// Medium impact for primary actions (e.g. Save, Add, Confirm, Sync)
  static void medium() {
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Heavy impact for destructive actions (e.g. Delete, Wipe data)
  static void heavy() {
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Error vibration for declined transactions or validation warnings
  static void error() {
    try {
      HapticFeedback.vibrate();
    } catch (_) {}
  }
}
