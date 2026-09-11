import 'package:flutter/material.dart';

class AppColors {
  // Backgrounds
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
  static const Color aiEngine = Color(0xFF8B5CF6);      // Purple for BYOK AI
  static const Color regexEngine = Color(0xFF06B6D4);   // Cyan for Offline Heuristics

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
}
