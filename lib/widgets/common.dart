import 'package:flutter/material.dart';

import '../core/constants/assets.dart';

class CoinAvatar extends StatelessWidget {
  const CoinAvatar({
    super.key,
    required this.symbol,
    this.color,
    this.size = 40,
  });

  final String symbol;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = assetBySymbol(symbol);
    final bg = color ?? asset.color;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(color: bg.withValues(alpha: 0.35)),
      ),
      alignment: Alignment.center,
      child: Text(
        symbol.length <= 4 ? symbol : symbol.substring(0, 3),
        style: TextStyle(
          color: bg,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.28,
        ),
      ),
    );
  }
}

class NexLogo extends StatelessWidget {
  const NexLogo({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF2DA8FF), Color(0xFF6366F1)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2DA8FF).withValues(alpha: 0.35),
            blurRadius: 12,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        'N',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.45,
        ),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
          ),
    );
  }
}

void showAppSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
