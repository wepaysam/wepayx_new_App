import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/wallet_provider.dart';
import '../../services/security_service.dart';
import '../nex_layout.dart';
import '../nex_tokens.dart';
import 'nex_components.dart';
import 'nex_pin_pad.dart';

/// Mandatory first-time PIN setup after login when no app PIN exists.
class NexPinSetupScreen extends StatefulWidget {
  const NexPinSetupScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<NexPinSetupScreen> createState() => _NexPinSetupScreenState();
}

class _NexPinSetupScreenState extends State<NexPinSetupScreen> {
  _SetupStep _step = _SetupStep.intro;
  String _draftPin = '';
  String? _error;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WalletProvider>();
    final tokens = provider.isDark ? NexTokens.darkTheme() : NexTokens.lightTheme();
    final security = context.watch<SecurityService>();

    return NexThemeScope(
      tokens: tokens,
      child: PopScope(
        canPop: false,
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
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: switch (_step) {
                  _SetupStep.intro => _intro(context, tokens),
                  _SetupStep.create => _pinStep(
                      key: const ValueKey('create'),
                      tokens: tokens,
                      stepIndex: 1,
                      title: 'Create your PIN',
                      subtitle: 'Choose 4–6 digits to secure your wallet',
                    ),
                  _SetupStep.confirm => _pinStep(
                      key: const ValueKey('confirm'),
                      tokens: tokens,
                      stepIndex: 2,
                      title: 'Confirm your PIN',
                      subtitle: 'Enter the same PIN again, then tap ✓',
                    ),
                  _SetupStep.biometric => _biometricStep(context, tokens, security),
                  _SetupStep.success => _successStep(context, tokens),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _intro(BuildContext context, NexTokens t) {
    return Padding(
      key: const ValueKey('intro'),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + NexLayout.systemBottomInset(context)),
      child: Column(
        children: [
          const Spacer(flex: 2),
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  nexBlue.withValues(alpha: 0.28),
                  t.cardSoft,
                ],
              ),
              border: Border.all(color: nexBlue.withValues(alpha: 0.4)),
              boxShadow: [
                BoxShadow(
                  color: nexBlue.withValues(alpha: 0.18),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.shield_rounded, size: 42, color: nexBlue),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Protect your wallet',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: t.text, letterSpacing: -0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'A PIN keeps your funds safe if someone else picks up your phone.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: t.text2, height: 1.45),
          ),
          const SizedBox(height: 28),
          NexCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _benefitRow(t, Icons.lock_rounded, 'Lock the app when you leave'),
                const SizedBox(height: 14),
                _benefitRow(t, Icons.fingerprint_rounded, 'Optionally unlock with fingerprint'),
                const SizedBox(height: 14),
                _benefitRow(t, Icons.verified_user_rounded, 'Required before using your wallet'),
              ],
            ),
          ),
          const Spacer(flex: 3),
          NexPrimaryButton(
            label: 'Set up PIN',
            onPressed: () => setState(() {
              _step = _SetupStep.create;
              _error = null;
            }),
          ),
        ],
      ),
    );
  }

  Widget _benefitRow(NexTokens t, IconData icon, String text) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: nexBlue.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: nexBlue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: t.text)),
        ),
      ],
    );
  }

  Widget _pinStep({
    required Key key,
    required NexTokens tokens,
    required int stepIndex,
    required String title,
    required String subtitle,
  }) {
    final isConfirm = stepIndex == 2;

    return Padding(
      key: key,
      padding: EdgeInsets.fromLTRB(20, 8, 20, NexLayout.systemBottomInset(context)),
      child: NexPinPad(
        style: NexPinPadStyle.setup,
        stepIndex: stepIndex,
        stepCount: 2,
        title: title,
        subtitle: subtitle,
        errorText: _error,
        onBack: isConfirm
            ? () => setState(() {
                  _step = _SetupStep.create;
                  _draftPin = '';
                  _error = null;
                })
            : null,
        onCompleted: (pin) async {
          if (!isConfirm) {
            if (pin.length < 4) {
              setState(() => _error = 'PIN must be at least 4 digits');
              return false;
            }
            setState(() {
              _draftPin = pin;
              _error = null;
              _step = _SetupStep.confirm;
            });
            return true;
          }

          if (pin != _draftPin) {
            setState(() => _error = 'PINs do not match. Try again.');
            return false;
          }

          final ok = await SecurityService.instance.setPin(pin);
          if (!mounted) return false;
          if (!ok) {
            setState(() => _error = 'Could not save PIN. Try again.');
            return false;
          }

          final security = SecurityService.instance;
          setState(() {
            _error = null;
            _step = security.canUseBiometric ? _SetupStep.biometric : _SetupStep.success;
          });
          return true;
        },
      ),
    );
  }

  Widget _biometricStep(BuildContext context, NexTokens t, SecurityService security) {
    return Padding(
      key: const ValueKey('biometric'),
      padding: EdgeInsets.fromLTRB(24, 32, 24, 24 + NexLayout.systemBottomInset(context)),
      child: Column(
        children: [
          const Spacer(flex: 2),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: nexBlue.withValues(alpha: 0.14),
              border: Border.all(color: nexBlue.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.fingerprint_rounded, size: 52, color: nexBlue),
          ),
          const SizedBox(height: 28),
          Text(
            'Enable ${security.biometricLabel}?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: t.text),
          ),
          const SizedBox(height: 12),
          Text(
            'Unlock faster without typing your PIN every time.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: t.text2, height: 1.4),
          ),
          const Spacer(flex: 3),
          NexPrimaryButton(
            label: 'Enable ${security.biometricLabel}',
            onPressed: () async {
              final ok = await security.tryBiometricUnlock();
              if (ok) {
                await security.setBiometricEnabled(true);
              }
              if (mounted) setState(() => _step = _SetupStep.success);
            },
          ),
          const SizedBox(height: 12),
          NexSecondaryButton(
            label: 'Not now',
            onPressed: () => setState(() => _step = _SetupStep.success),
          ),
        ],
      ),
    );
  }

  Widget _successStep(BuildContext context, NexTokens t) {
    return Padding(
      key: const ValueKey('success'),
      padding: EdgeInsets.fromLTRB(24, 32, 24, 24 + NexLayout.systemBottomInset(context)),
      child: Column(
        children: [
          const Spacer(flex: 2),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF22C55E).withValues(alpha: 0.16),
              border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.35)),
            ),
            child: const Icon(Icons.check_rounded, size: 52, color: Color(0xFF22C55E)),
          ),
          const SizedBox(height: 28),
          Text(
            'You\'re all set',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: t.text),
          ),
          const SizedBox(height: 12),
          Text(
            'Your wallet is protected. You can change security settings anytime in Profile.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: t.text2, height: 1.45),
          ),
          const Spacer(flex: 3),
          NexPrimaryButton(label: 'Go to wallet', onPressed: widget.onComplete),
        ],
      ),
    );
  }
}

enum _SetupStep { intro, create, confirm, biometric, success }
