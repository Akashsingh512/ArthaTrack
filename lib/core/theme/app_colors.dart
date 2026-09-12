import 'package:flutter/material.dart';

/// Semantic colors for a specific brightness mode (Dark or Light)
class AppThemeColors {
  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color surfaceCard;
  final Color surfaceElevated;
  final Color border;
  final Color borderSubtle;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color emerald;
  final Color primary;
  final Color ruby;
  final Color amber;
  final Color royalBlue;
  final Color indigo;
  final Color aiEngine;
  final Color regexEngine;
  final Color income;
  final Color expense;
  final Color asset;
  final Color debt;
  final Color liquid;
  final Color badgeBackground;
  final Color chipBackground;
  final Color chipSelectedBackground;
  final Color chipSelectedText;

  const AppThemeColors({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceCard,
    required this.surfaceElevated,
    required this.border,
    required this.borderSubtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.emerald,
    required this.primary,
    required this.ruby,
    required this.amber,
    required this.royalBlue,
    required this.indigo,
    required this.aiEngine,
    required this.regexEngine,
    required this.income,
    required this.expense,
    required this.asset,
    required this.debt,
    required this.liquid,
    required this.badgeBackground,
    required this.chipBackground,
    required this.chipSelectedBackground,
    required this.chipSelectedText,
  });

  bool get isDark => brightness == Brightness.dark;

  /// Dark Mode Palette - Direction 2a "Quiet Ledger"
  static const AppThemeColors dark = AppThemeColors(
    brightness: Brightness.dark,
    background: Color(0xFF0B0F19),
    surface: Color(0xFF131D2F),
    surfaceCard: Color(0xFF152033),
    surfaceElevated: Color(0xFF1E293B),
    border: Color(0xFF1E293B),
    borderSubtle: Color(0xFF172338),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFF94A3B8),
    textMuted: Color(0xFF64748B),
    emerald: Color(0xFF10B981),
    primary: Color(0xFF10B981),
    ruby: Color(0xFFF43F5E),
    amber: Color(0xFFF59E0B),
    royalBlue: Color(0xFF3B82F6),
    indigo: Color(0xFF6366F1),
    aiEngine: Color(0xFF8B5CF6),
    regexEngine: Color(0xFF06B6D4),
    income: Color(0xFF10B981),
    expense: Color(0xFFF43F5E),
    asset: Color(0xFFF59E0B),
    debt: Color(0xFFE11D48),
    liquid: Color(0xFF38BDF8),
    badgeBackground: Color(0xFF1E293B),
    chipBackground: Color(0xFF1A2438),
    chipSelectedBackground: Color(0xFF10B981),
    chipSelectedText: Color(0xFF000000),
  );

  /// Light Mode Palette - Direction 2d "Light Mode of 2a"
  static const AppThemeColors light = AppThemeColors(
    brightness: Brightness.light,
    background: Color(0xFFF8FAFC),
    surface: Color(0xFFFFFFFF),
    surfaceCard: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFF1F5F9),
    border: Color(0xFFE2E8F0),
    borderSubtle: Color(0xFFF8FAFC),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    textMuted: Color(0xFF94A3B8),
    emerald: Color(0xFF059669),
    primary: Color(0xFF059669),
    ruby: Color(0xFFE11D48),
    amber: Color(0xFFD97706),
    royalBlue: Color(0xFF2563EB),
    indigo: Color(0xFF4F46E5),
    aiEngine: Color(0xFF7C3AED),
    regexEngine: Color(0xFF0891B2),
    income: Color(0xFF059669),
    expense: Color(0xFFE11D48),
    asset: Color(0xFFD97706),
    debt: Color(0xFFBE123C),
    liquid: Color(0xFF0284C7),
    badgeBackground: Color(0xFFF1F5F9),
    chipBackground: Color(0xFFE2E8F0),
    chipSelectedBackground: Color(0xFF059669),
    chipSelectedText: Color(0xFFFFFFFF),
  );
}

/// Helper extension on BuildContext for quick access to theme colors
extension ThemeContextExtension on BuildContext {
  AppThemeColors get colors => AppColors.of(this);
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}

class AppColors {
  // Backward compatibility static constants (Dark mode defaults)
  static const Color background = Color(0xFF0B0F19);
  static const Color surface = Color(0xFF151D2F);
  static const Color surfaceElevated = Color(0xFF1E293B);
  static const Color surfaceCard = Color(0xFF1A2338);

  // Brand Accents
  static const Color emerald = Color(0xFF10B981);
  static const Color primary = Color(0xFF10B981);
  static const Color saffron = Color(0xFFF59E0B);
  static const Color amber = Color(0xFFF59E0B);
  static const Color ruby = Color(0xFFEF4444);
  static const Color royalBlue = Color(0xFF3B82F6);
  static const Color indigo = Color(0xFF6366F1);

  // Engine Badges
  static const Color aiEngine = Color(0xFF8B5CF6);
  static const Color regexEngine = Color(0xFF06B6D4);

  // Text Colors
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Financial Semantics
  static const Color income = Color(0xFF10B981);
  static const Color incomeGreen = Color(0xFF10B981);
  static const Color expense = Color(0xFFF43F5E);
  static const Color expenseRed = Color(0xFFF43F5E);
  static const Color asset = Color(0xFFF59E0B);
  static const Color debt = Color(0xFFE11D48);
  static const Color liquid = Color(0xFF38BDF8);

  // Category Colors
  static const Map<String, Color> categoryColors = {
    'Food': Color(0xFFF97316),
    'Groceries': Color(0xFF10B981),
    'Travel': Color(0xFF06B6D4),
    'Shopping': Color(0xFFEC4899),
    'Bills': Color(0xFFEAB308),
    'Entertainment': Color(0xFF8B5CF6),
    'Health': Color(0xFF14B8A6),
    'Investment': Color(0xFF3B82F6),
    'Salary': Color(0xFF22C55E),
    'Transfer': Color(0xFF64748B),
    'Other': Color(0xFF94A3B8),
  };

  /// Returns the appropriate AppThemeColors based on context's brightness
  static AppThemeColors of(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? AppThemeColors.dark : AppThemeColors.light;
  }
}

