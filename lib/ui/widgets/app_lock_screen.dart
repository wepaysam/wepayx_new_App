import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/wallet_provider.dart';
import '../../services/security_service.dart';
import '../nex_layout.dart';
import '../nex_tokens.dart';
import 'nex_pin_pad.dart';

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key, required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
  }

  Future<void> _tryBiometric() async {
    final security = SecurityService.instance;
    if (!security.showBiometricUnlock) return;
    final ok = await security.tryBiometricUnlock();
    if (ok && mounted) widget.onUnlocked();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WalletProvider>();
    final tokens = provider.isDark ? NexTokens.darkTheme() : NexTokens.lightTheme();
    final security = context.watch<SecurityService>();

    return NexThemeScope(
      tokens: tokens,
      child: Scaffold(
        backgroundColor: tokens.appBg,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                tokens.appBg,
                tokens.dark ? const Color(0xFF12131A) : const Color(0xFFE8EEF9),
                tokens.appBg,
              ],
              stops: const [0, 0.45, 1],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: NexPinPad(
                style: NexPinPadStyle.lock,
                title: 'Enter PIN',
                subtitle: 'Unlock your wallet',
                showBiometric: security.showBiometricUnlock,
                onBiometric: _tryBiometric,
                onCompleted: (pin) async {
                  final ok = await security.verifyPin(pin);
                  if (ok) widget.onUnlocked();
                  return ok;
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Locks the app when a PIN is set and the user backgrounds the app.
class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  bool _canLock = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) setState(() => _canLock = true);
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_canLock || !SecurityService.instance.hasPin) return;
    final user = context.read<WalletProvider>().user;
    if (user == null) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      SecurityService.instance.lock();
    }
  }

  Future<void> _onUnlocked() async {
    final security = SecurityService.instance;
    security.unlock();
    final provider = context.read<WalletProvider>();
    if (provider.user == null && provider.initialized) {
      await provider.restoreSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    final security = context.watch<SecurityService>();
    final provider = context.watch<WalletProvider>();
    final shouldLock =
        provider.user != null && security.hasPin && !security.isUnlocked;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.topLeft,
        children: [
          widget.child,
          if (shouldLock)
            Positioned.fill(
              child: AppLockScreen(onUnlocked: () => unawaited(_onUnlocked())),
            ),
        ],
      ),
    );
  }
}

Future<bool> showPinAuthSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  bool tryBiometricOnOpen = false,
}) {
  final tokens = NexThemeScope.of(context);
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    builder: (ctx) {
      return NexThemeScope(
        tokens: tokens,
        child: _PinAuthSheet(
          title: title,
          subtitle: subtitle,
          tryBiometricOnOpen: tryBiometricOnOpen,
        ),
      );
    },
  ).then((value) => value ?? false);
}

class _PinAuthSheet extends StatefulWidget {
  const _PinAuthSheet({
    required this.title,
    this.subtitle,
    this.tryBiometricOnOpen = false,
  });

  final String title;
  final String? subtitle;
  final bool tryBiometricOnOpen;

  @override
  State<_PinAuthSheet> createState() => _PinAuthSheetState();
}

class _PinAuthSheetState extends State<_PinAuthSheet> {
  @override
  void initState() {
    super.initState();
    if (widget.tryBiometricOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
    }
  }

  Future<void> _tryBiometric() async {
    final security = SecurityService.instance;
    if (!security.showBiometricUnlock || !mounted) return;
    final navigator = Navigator.of(context);
    final ok = await security.tryBiometricForTransaction();
    if (ok) navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final security = SecurityService.instance;
    final tokens = NexThemeScope.of(context);

    return Padding(
      padding: NexLayout.sheetBottomPadding(context),
      child: Container(
        decoration: BoxDecoration(
          color: tokens.cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: tokens.muted.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            NexPinPad(
              title: widget.title,
              subtitle: widget.subtitle,
              length: 6,
              showBiometric: security.showBiometricUnlock,
              onBiometric: _tryBiometric,
              onCompleted: (pin) async {
                final navigator = Navigator.of(context);
                final ok = await security.verifyPin(pin);
                if (ok) navigator.pop(true);
                return ok;
              },
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool> authenticateSensitiveAction(
  BuildContext context, {
  required String reason,
}) async {
  final security = SecurityService.instance;
  if (!security.hasPin) return true;
  if (!context.mounted) return false;

  final useBiometric = security.showBiometricUnlock;
  return showPinAuthSheet(
    context,
    title: useBiometric ? 'Confirm' : 'Enter PIN',
    subtitle: reason,
    tryBiometricOnOpen: useBiometric,
  );
}
