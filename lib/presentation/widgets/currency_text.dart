import 'package:flutter/material.dart';
import '../../core/utils/currency_formatter.dart';

class CurrencyText extends StatelessWidget {
  final double amount;
  final TextStyle? style;
  final bool showSymbol;
  final bool compact;
  final bool showDecimals;
  final Color? color;

  const CurrencyText({
    super.key,
    required this.amount,
    this.style,
    this.showSymbol = true,
    this.compact = false,
    this.showDecimals = true,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final formatted = compact
        ? IndianCurrencyFormatter.formatCompact(amount, showSymbol: showSymbol)
        : IndianCurrencyFormatter.format(amount, showSymbol: showSymbol, showDecimals: showDecimals);

    final effectiveStyle = (style ?? Theme.of(context).textTheme.bodyLarge)
        ?.copyWith(color: color ?? style?.color);

    return Text(
      formatted,
      style: effectiveStyle,
    );
  }
}
