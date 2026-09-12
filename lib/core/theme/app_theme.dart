import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  /// Dark Theme - Direction 2a "Quiet Ledger"
  static ThemeData get darkTheme {
    const colors = AppThemeColors.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: colors.background,
      primaryColor: colors.emerald,
      colorScheme: ColorScheme.dark(
        primary: colors.emerald,
        secondary: colors.amber,
        surface: colors.surface,
        surfaceContainer: colors.surfaceCard,
        surfaceContainerHighest: colors.surfaceElevated,
        outline: colors.border,
        outlineVariant: colors.borderSubtle,
        error: colors.ruby,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: colors.textPrimary,
        onSurfaceVariant: colors.textSecondary,
        onError: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: colors.surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.border, width: 1),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: colors.textPrimary,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        modalBackgroundColor: colors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.surface,
        selectedItemColor: colors.emerald,
        unselectedItemColor: colors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.chipBackground,
        selectedColor: colors.chipSelectedBackground,
        labelStyle: TextStyle(fontSize: 12, color: colors.textSecondary),
        secondaryLabelStyle: TextStyle(fontSize: 12, color: colors.chipSelectedText, fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide.none,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.emerald, width: 1.8),
        ),
        hintStyle: TextStyle(color: colors.textMuted, fontSize: 14),
        labelStyle: TextStyle(color: colors.textSecondary, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.emerald,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 32, letterSpacing: -1),
        displayMedium: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 26, letterSpacing: -0.5),
        titleLarge: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 20),
        titleMedium: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
        bodyLarge: TextStyle(color: colors.textPrimary, fontSize: 15),
        bodyMedium: TextStyle(color: colors.textSecondary, fontSize: 14),
        bodySmall: TextStyle(color: colors.textMuted, fontSize: 12),
      ),
    );
  }

  /// Light Theme - Direction 2d "Light Mode of 2a"
  static ThemeData get lightTheme {
    const colors = AppThemeColors.light;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: colors.background,
      primaryColor: colors.emerald,
      colorScheme: ColorScheme.light(
        primary: colors.emerald,
        secondary: colors.amber,
        surface: colors.surface,
        surfaceContainer: colors.surfaceCard,
        surfaceContainerHighest: colors.surfaceElevated,
        outline: colors.border,
        outlineVariant: colors.borderSubtle,
        error: colors.ruby,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: colors.textPrimary,
        onSurfaceVariant: colors.textSecondary,
        onError: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: colors.surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.border, width: 1),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: colors.textPrimary,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        modalBackgroundColor: colors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.surface,
        selectedItemColor: colors.emerald,
        unselectedItemColor: colors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.chipBackground,
        selectedColor: colors.chipSelectedBackground,
        labelStyle: TextStyle(fontSize: 12, color: colors.textSecondary),
        secondaryLabelStyle: TextStyle(fontSize: 12, color: colors.chipSelectedText, fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide.none,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.emerald, width: 1.8),
        ),
        hintStyle: TextStyle(color: colors.textMuted, fontSize: 14),
        labelStyle: TextStyle(color: colors.textSecondary, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.emerald,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 32, letterSpacing: -1),
        displayMedium: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 26, letterSpacing: -0.5),
        titleLarge: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 20),
        titleMedium: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
        bodyLarge: TextStyle(color: colors.textPrimary, fontSize: 15),
        bodyMedium: TextStyle(color: colors.textSecondary, fontSize: 14),
        bodySmall: TextStyle(color: colors.textMuted, fontSize: 12),
      ),
    );
  }
}

