import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class EngineBadge extends StatelessWidget {
  final String engine;
  final bool compact;

  const EngineBadge({
    super.key,
    required this.engine,
    this.compact = false,
  });

  bool get isAi => engine.toUpperCase().startsWith('AI');

  @override
  Widget build(BuildContext context) {
    final color = isAi ? AppColors.aiEngine : AppColors.regexEngine;
    final label = isAi
        ? (engine.contains('GROQ') ? 'AI • Groq' : 'AI • Gemini')
        : 'Offline • Regex';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAi ? Icons.auto_awesome : Icons.bolt,
            size: compact ? 10 : 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
