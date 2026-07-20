import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../nex_layout.dart';
import '../nex_tokens.dart';
import 'nex_brand.dart';

enum NexHeaderSurface { themed, light }

class NexLabel extends StatelessWidget {
  const NexLabel(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = NexThemeScope.of(context);
    return Text(
      text.toUpperCase(),
      style: nexLabelStyle.copyWith(color: color ?? t.muted),
    );
  }
}

class NexScreenHeader extends StatelessWidget {
  const NexScreenHeader({
    super.key,
    required this.title,
    this.onBack,
    this.right,
    this.surface = NexHeaderSurface.themed,
  });

  final String title;
  final VoidCallback? onBack;
  final Widget? right;
  final NexHeaderSurface surface;

  @override
  Widget build(BuildContext context) {
    final t = NexThemeScope.of(context);
    final light = surface == NexHeaderSurface.light;
    final titleColor = light ? const Color(0xFF0F172A) : t.text;
    final hPad = NexLayout.horizontalPadding(context);
    final titleSize = NexLayout.headerTitleSize(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 12),
      child: Row(
        children: [
          if (onBack != null)
            NexIconButton(
              onTap: onBack!,
              icon: 'back',
              size: 18,
              iconColor: light ? const Color(0xFF0F172A) : null,
              backgroundColor: light ? const Color(0xFFF1F5F9) : null,
            ),
          if (onBack != null) const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: titleSize,
                fontWeight: FontWeight.w800,
                color: titleColor,
              ),
            ),
          ),
          if (right != null) right!,
        ],
      ),
    );
  }
}

class NexIconButton extends StatelessWidget {
  const NexIconButton({
    super.key,
    required this.onTap,
    required this.icon,
    this.size = 18,
    this.buttonSize = 40,
    this.iconColor,
    this.backgroundColor,
  });

  final VoidCallback onTap;
  final String icon;
  final double size;
  final double buttonSize;
  final Color? iconColor;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final t = NexThemeScope.of(context);
    return Material(
      color: backgroundColor ?? t.iconBtnBg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: buttonSize,
          height: buttonSize,
          child: Center(
            child: NexIcon(icon, size: size, color: iconColor ?? t.text),
          ),
        ),
      ),
    );
  }
}

class NexCard extends StatelessWidget {
  const NexCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = NexThemeScope.of(context);
    final content = Padding(
      padding: padding ?? EdgeInsets.zero,
      child: child,
    );
    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.cardBorder),
        boxShadow: t.dark
            ? null
            : const [BoxShadow(color: Color(0x0D000000), blurRadius: 1)],
      ),
      child: content,
    );
    if (onTap == null) return box;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: box,
      ),
    );
  }
}

class NexPrimaryButton extends StatelessWidget {
  const NexPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.3),
          elevation: 0,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
          ),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(label),
      ),
    );
  }
}

class NexSecondaryButton extends StatelessWidget {
  const NexSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.06),
          foregroundColor: Colors.white.withValues(alpha: 0.75),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class NexField extends StatelessWidget {
  const NexField({
    super.key,
    required this.label,
    required this.controller,
    this.placeholder,
    this.obscure = false,
    this.keyboardType,
    this.onToggleObscure,
  });

  final String label;
  final TextEditingController controller;
  final String? placeholder;
  final bool obscure;
  final TextInputType? keyboardType;
  final VoidCallback? onToggleObscure;

  @override
  Widget build(BuildContext context) {
    final t = NexThemeScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NexLabel(label),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          style: GoogleFonts.inter(fontSize: 15, color: t.text),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: GoogleFonts.inter(
              color: t.dark ? Colors.white.withValues(alpha: 0.30) : t.muted,
            ),
            filled: true,
            fillColor: t.inputFill,
            contentPadding: EdgeInsets.fromLTRB(16, 14, onToggleObscure != null ? 48 : 16, 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: t.inputBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: nexBlue),
            ),
            suffixIcon: onToggleObscure == null
                ? null
                : IconButton(
                    onPressed: onToggleObscure,
                    icon: NexIcon(
                      obscure ? 'eyeOff' : 'eye',
                      size: 18,
                      color: t.muted,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class NetBadge extends StatelessWidget {
  const NetBadge({super.key, required this.network});

  final String network;

  static const _colors = {
    'TRC20': Color(0xFFEF4444),
    'ERC20': Color(0xFF6366F1),
    'BEP20': Color(0xFFEAB308),
    'Bitcoin': Color(0xFFF97316),
  };

  @override
  Widget build(BuildContext context) {
    final c = _colors[network] ?? const Color(0xFF888888);
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 2, 8, 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          NetworkIcon(network: network, size: 16),
          const SizedBox(width: 4),
          Text(
            network,
            style: TextStyle(
              color: c,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class NexBottomNav extends StatelessWidget {
  const NexBottomNav({
    super.key,
    required this.current,
    required this.onSelect,
  });

  final String current;
  final ValueChanged<String> onSelect;

  static const items = [
    ('home', 'home', 'Home'),
    ('markets', 'trending', 'Markets'),
    ('wallet-tab', 'wallet', 'Wallet'),
    ('activity', 'clock', 'Activity'),
    ('profile', 'settings', 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = NexThemeScope.of(context);
    final bottomInset = NexLayout.systemBottomInset(context);
    return Container(
      decoration: BoxDecoration(
        color: t.navWrap,
        border: Border(top: BorderSide(color: t.divider)),
      ),
      padding: EdgeInsets.fromLTRB(12, 10, 12, 12 + bottomInset),
      child: Row(
        children: items.map((item) {
          final active = current == item.$1;
          return Expanded(
            child: InkWell(
              onTap: () => onSelect(item.$1),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    NexIcon(
                      item.$2,
                      size: 22,
                      color: active ? t.navActive : t.navInactive,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.$3,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: active ? t.navActive : t.navInactive,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

void showNexToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const NexIcon('check', size: 16, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(
          NexLayout.horizontalPadding(context),
          0,
          NexLayout.horizontalPadding(context),
          96 + NexLayout.systemBottomInset(context),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: const Color(0xFF232325),
      ),
    );
}

void showNexError(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const NexIcon('alert', size: 16, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(
          NexLayout.horizontalPadding(context),
          0,
          NexLayout.horizontalPadding(context),
          96 + NexLayout.systemBottomInset(context),
        ),
        duration: const Duration(seconds: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: const Color(0xFFB91C1C),
      ),
    );
}

class NexNotificationBanner extends StatelessWidget {
  const NexNotificationBanner({
    super.key,
    required this.title,
    required this.body,
    required this.onClose,
  });

  final String title;
  final String body;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = NexThemeScope.of(context);
    final bg = t.dark ? const Color(0xFF232325) : Colors.white;
    final titleColor = t.dark ? Colors.white : const Color(0xFF0F172A);
    final bodyColor = t.dark ? Colors.white.withValues(alpha: 0.72) : const Color(0xFF64748B);
    final borderColor = t.dark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE2E8F0);

    return Material(
      elevation: 16,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(18),
      color: bg,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CoinLogo(symbol: 'USDT', size: 34),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: titleColor),
                  ),
                  if (body.isNotEmpty)
                    Text(body, style: TextStyle(fontSize: 13, color: bodyColor, height: 1.35)),
                ],
              ),
            ),
            IconButton(
              onPressed: onClose,
              icon: NexIcon('x', size: 15, color: bodyColor),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }
}
