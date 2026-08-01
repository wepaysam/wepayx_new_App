import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/wallet_provider.dart';
import '../nex_tokens.dart';
import '../widgets/nex_brand.dart';
import '../widgets/nex_components.dart';
import '../widgets/nex_otp_code_field.dart';

class NexLoginOtpScreen extends StatefulWidget {
  const NexLoginOtpScreen({
    super.key,
    required this.onVerified,
    required this.onBack,
  });

  final VoidCallback onVerified;
  final VoidCallback onBack;

  @override
  State<NexLoginOtpScreen> createState() => _NexLoginOtpScreenState();
}

class _NexLoginOtpScreenState extends State<NexLoginOtpScreen> {
  static const _otpLength = 6;

  final _focus = FocusNode();
  final _otp = TextEditingController();
  bool _sending = false;
  bool _confirming = false;
  String? _error;
  int _resendIn = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _focus.dispose();
    _otp.dispose();
    super.dispose();
  }

  String get _code => _otp.text.trim();

  void _startResendCooldown([int seconds = 60]) {
    _resendTimer?.cancel();
    setState(() => _resendIn = seconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendIn <= 1) {
        timer.cancel();
        setState(() => _resendIn = 0);
      } else {
        setState(() => _resendIn -= 1);
      }
    });
  }

  Future<void> _resend() async {
    if (_sending || _resendIn > 0) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await context.read<WalletProvider>().resendLoginOtp();
      if (!mounted) return;
      _startResendCooldown();
      showNexToast(context, 'Sign-in code sent');
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _confirm() async {
    if (_confirming) return;
    if (_code.length != _otpLength) {
      setState(() => _error = 'Enter the 6-digit code from your email');
      return;
    }

    setState(() {
      _confirming = true;
      _error = null;
    });
    try {
      await context.read<WalletProvider>().confirmLoginOtp(_code);
      if (!mounted) return;
      showNexToast(context, 'Signed in');
      widget.onVerified();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
        _otp.clear();
      });
      _focus.requestFocus();
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  void _onOtpChanged(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
    final clipped = cleaned.length > _otpLength
        ? cleaned.substring(0, _otpLength)
        : cleaned;
    if (clipped != value) {
      _otp.value = TextEditingValue(
        text: clipped,
        selection: TextSelection.collapsed(offset: clipped.length),
      );
    }
    setState(() => _error = null);
    if (clipped.length == _otpLength) {
      unawaited(_confirm());
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = NexThemeScope.of(context);
    final email = context.watch<WalletProvider>().pendingLoginEmail ?? '';
    final canResend = !_sending && _resendIn == 0;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return ColoredBox(
      color: t.appBg,
      child: Column(
        children: [
          NexScreenHeader(title: 'Verify sign-in', onBack: widget.onBack),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottomInset),
              children: [
                Row(
                  children: [
                    const NexLogo(size: 40),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NEX Wallet',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: t.text,
                          ),
                        ),
                        const NexLabel('Secure. Simple. Yours.', color: nexBlue),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Check your inbox',
                  style: TextStyle(
                    color: t.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  email.isEmpty
                      ? 'Enter the 6-digit sign-in code we sent to your email.'
                      : 'We sent a 6-digit code to ${maskEmailForDisplay(email)}. Enter it below to finish signing in.',
                  style: TextStyle(color: t.text2, fontSize: 15, height: 1.45),
                ),
                const SizedBox(height: 28),
                const NexLabel('Sign-in code'),
                const SizedBox(height: 12),
                NexOtpCodeField(
                  controller: _otp,
                  focusNode: _focus,
                  error: _error,
                  onChanged: _onOtpChanged,
                  onSubmitted: _confirm,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFFF87171),
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text(
                      "Didn't get a code?",
                      style: TextStyle(color: t.muted, fontSize: 13),
                    ),
                    const SizedBox(width: 6),
                    TextButton(
                      onPressed: canResend ? _resend : null,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        _sending
                            ? 'Sending…'
                            : _resendIn > 0
                            ? 'Resend in ${_resendIn}s'
                            : 'Resend code',
                        style: TextStyle(
                          color: canResend ? t.navActive : t.muted,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: NexPrimaryButton(
              label: _confirming ? 'Verifying…' : 'Verify & sign in',
              loading: _confirming,
              onPressed: _confirming || _code.length != _otpLength
                  ? null
                  : _confirm,
            ),
          ),
        ],
      ),
    );
  }
}
