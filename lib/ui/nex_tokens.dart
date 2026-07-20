import 'package:flutter/material.dart';

const nexBlue = Color(0xFF2DA8FF);

class NexTokens {
  const NexTokens({
    required this.dark,
    required this.appBg,
    required this.homeBg,
    required this.cardBg,
    required this.cardBorder,
    required this.cardSoft,
    required this.text,
    required this.text2,
    required this.muted,
    required this.subtle,
    required this.inputFill,
    required this.inputBorder,
    required this.iconBtnBg,
    required this.navWrap,
    required this.navActive,
    required this.navInactive,
    required this.secondaryBg,
    required this.secondaryText,
    required this.divider,
    required this.chipBg,
    required this.pillIdleBg,
    required this.pillIdleText,
    required this.pillActiveBg,
    required this.pillActiveText,
    required this.frame,
    required this.outer,
    required this.notch,
  });

  final bool dark;
  final Color appBg;
  final Color homeBg;
  final Color cardBg;
  final Color cardBorder;
  final Color cardSoft;
  final Color text;
  final Color text2;
  final Color muted;
  final Color subtle;
  final Color inputFill;
  final Color inputBorder;
  final Color iconBtnBg;
  final Color navWrap;
  final Color navActive;
  final Color navInactive;
  final Color secondaryBg;
  final Color secondaryText;
  final Color divider;
  final Color chipBg;
  final Color pillIdleBg;
  final Color pillIdleText;
  final Color pillActiveBg;
  final Color pillActiveText;
  final Color frame;
  final Color outer;
  final Color notch;

  static NexTokens darkTheme() => NexTokens(
        dark: true,
        appBg: const Color(0xFF0A0A0A),
        homeBg: const Color(0xFF0D0D0F),
        cardBg: const Color(0xFF161618),
        cardBorder: Colors.white.withValues(alpha: 0.10),
        cardSoft: const Color(0xFF1E1E20),
        text: Colors.white,
        text2: Colors.white.withValues(alpha: 0.60),
        muted: Colors.white.withValues(alpha: 0.40),
        subtle: Colors.white.withValues(alpha: 0.25),
        inputFill: Colors.white.withValues(alpha: 0.06),
        inputBorder: Colors.white.withValues(alpha: 0.10),
        iconBtnBg: Colors.white.withValues(alpha: 0.07),
        navWrap: const Color(0xFF0A0A0A),
        navActive: Colors.white,
        navInactive: Colors.white.withValues(alpha: 0.25),
        secondaryBg: Colors.white.withValues(alpha: 0.08),
        secondaryText: Colors.white,
        divider: Colors.white.withValues(alpha: 0.06),
        chipBg: Colors.white.withValues(alpha: 0.06),
        pillIdleBg: Colors.white.withValues(alpha: 0.06),
        pillIdleText: Colors.white.withValues(alpha: 0.70),
        pillActiveBg: Colors.white,
        pillActiveText: Colors.black,
        frame: const Color(0xFF181818),
        outer: const Color(0xFF050505),
        notch: const Color(0xFF181818),
      );

  static NexTokens lightTheme() => NexTokens(
        dark: false,
        appBg: const Color(0xFFF4F7FF),
        homeBg: const Color(0xFFF4F7FF),
        cardBg: Colors.white,
        cardBorder: const Color(0xB3E2E8F0),
        cardSoft: const Color(0xFFF1F5F9),
        text: const Color(0xFF0F172A),
        text2: const Color(0xFF64748B),
        muted: const Color(0xFF94A3B8),
        subtle: const Color(0xFFCBD5E1),
        inputFill: Colors.white,
        inputBorder: const Color(0xFFE2E8F0),
        iconBtnBg: const Color(0xFFF1F5F9),
        navWrap: Colors.white,
        navActive: const Color(0xFF2563EB),
        navInactive: const Color(0xFF94A3B8),
        secondaryBg: const Color(0xFFF1F5F9),
        secondaryText: const Color(0xFF0F172A),
        divider: const Color(0xFFE2E8F0),
        chipBg: const Color(0xFFF1F5F9),
        pillIdleBg: const Color(0xFFF1F5F9),
        pillIdleText: const Color(0xFF475569),
        pillActiveBg: const Color(0xFF0F172A),
        pillActiveText: Colors.white,
        frame: const Color(0xFFD1D5DB),
        outer: const Color(0xFFCBD5E1),
        notch: const Color(0xFFD1D5DB),
      );
}

class NexThemeScope extends InheritedWidget {
  const NexThemeScope({
    super.key,
    required this.tokens,
    required super.child,
  });

  final NexTokens tokens;

  static NexTokens of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<NexThemeScope>()!.tokens;
  }

  @override
  bool updateShouldNotify(NexThemeScope oldWidget) => tokens != oldWidget.tokens;
}

const nexLabelStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w600,
  letterSpacing: 1.98,
);
