import 'package:flutter/material.dart';

/// Shared layout helpers so screens adapt to different phone sizes.
class NexLayout {
  static double width(BuildContext context) => MediaQuery.sizeOf(context).width;

  static double height(BuildContext context) => MediaQuery.sizeOf(context).height;

  static double horizontalPadding(BuildContext context) {
    final w = width(context);
    if (w < 360) return 16;
    if (w < 400) return 18;
    return 20;
  }

  static EdgeInsets screenPadding(BuildContext context) {
    return EdgeInsets.symmetric(horizontal: horizontalPadding(context));
  }

  static double qrSize(BuildContext context) {
    final w = width(context);
    return (w - horizontalPadding(context) * 2 - 56).clamp(120.0, 168.0);
  }

  static double balanceFontSize(BuildContext context) {
    return (width(context) * 0.085).clamp(28.0, 36.0);
  }

  static double heroTitleFontSize(BuildContext context) {
    return (width(context) * 0.08).clamp(26.0, 34.0);
  }

  static double headerTitleSize(BuildContext context) {
    return (width(context) * 0.055).clamp(20.0, 24.0);
  }

  /// Height of the system navigation bar / home gesture area.
  static double systemBottomInset(BuildContext context) {
    return MediaQuery.paddingOf(context).bottom;
  }

  /// Bottom padding for modal sheets (system nav + keyboard).
  static EdgeInsets sheetBottomPadding(BuildContext context, {double extra = 0}) {
    final mq = MediaQuery.of(context);
    return EdgeInsets.only(bottom: extra + mq.padding.bottom + mq.viewInsets.bottom);
  }

  /// Footer padding for full-screen flows with bottom actions.
  static EdgeInsets flowFooterPadding(BuildContext context, {double bottom = 20, double horizontal = 20}) {
    return EdgeInsets.fromLTRB(horizontal, 0, horizontal, bottom + systemBottomInset(context));
  }
}
