import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/wallet_provider.dart';
import '../nex_tokens.dart';
import '../widgets/nex_brand.dart';
import '../widgets/nex_components.dart';
import '../widgets/nex_otp_code_field.dart';

class NexForgotPasswordScreen extends StatefulWidget {
  const NexForgotPasswordScreen({
    super.key,
    required this.onBack,
    required this.onCodeSent,
  });

  final VoidCallback onBack;
  final void Function(String email) onCodeSent;

  @override
  State<NexForgotPasswordScreen> createState() =>
      _NexForgotPasswordScreenState();
}

class _NexForgotPasswordScreenState extends State<NexForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email address');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<WalletProvider>().requestForgotPassword(email);
      if (!mounted) return;
      showNexToast(context, 'If this email is registered, a code was sent');
      widget.onCodeSent(email);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = NexThemeScope.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return ColoredBox(
      color: t.appBg,
      child: Column(
        children: [
          NexScreenHeader(title: 'Reset password', onBack: widget.onBack),
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
                  'Forgot your password?',
                  style: TextStyle(
                    color: t.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter the email linked to your account. We’ll send a 6-digit reset code if it’s registered.',
                  style: TextStyle(color: t.text2, fontSize: 15, height: 1.45),
                ),
                const SizedBox(height: 28),
                NexField(
                  label: 'Email',
                  controller: _email,
                  placeholder: 'you@email.com',
                  keyboardType: TextInputType.emailAddress,
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
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: t.cardSoft,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: t.cardBorder),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      NexIcon('info', size: 16, color: t.navActive),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'For security, we won’t confirm whether an email exists. Check your inbox and spam folder after requesting a code.',
                          style: TextStyle(
                            color: t.text2,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: NexPrimaryButton(
              label: _loading ? 'Sending…' : 'Send reset code',
              loading: _loading,
              onPressed: _loading ? null : _submit,
            ),
          ),
        ],
      ),
    );
  }
}

class NexForgotPasswordResetScreen extends StatefulWidget {
  const NexForgotPasswordResetScreen({
    super.key,
    required this.email,
    required this.onBack,
    required this.onSuccess,
  });

  final String email;
  final VoidCallback onBack;
  final VoidCallback onSuccess;

  @override
  State<NexForgotPasswordResetScreen> createState() =>
      _NexForgotPasswordResetScreenState();
}

class _NexForgotPasswordResetScreenState
    extends State<NexForgotPasswordResetScreen> {
  static const _otpLength = 6;

  final _focus = FocusNode();
  final _otp = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _showPassword = false;
  bool _showConfirm = false;
  bool _loading = false;
  bool _resending = false;
  String? _error;
  int _resendIn = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() {});
    });
    _startResendCooldown();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _focus.dispose();
    _otp.dispose();
    _password.dispose();
    _confirm.dispose();
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
    if (_resending || _resendIn > 0) return;
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      await context.read<WalletProvider>().requestForgotPassword(widget.email);
      if (!mounted) return;
      _startResendCooldown();
      showNexToast(context, 'Reset code sent');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      });
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (_code.length != _otpLength) {
      setState(() => _error = 'Enter the 6-digit code from your email');
      return;
    }
    if (_password.text.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters');
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<WalletProvider>().confirmForgotPassword(
            email: widget.email,
            otp: _code,
            newPassword: _password.text,
          );
      if (!mounted) return;
      showNexToast(context, 'Password updated. Please sign in.');
      widget.onSuccess();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
        _otp.clear();
      });
      _focus.requestFocus();
    } finally {
      if (mounted) setState(() => _loading = false);
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
  }

  @override
  Widget build(BuildContext context) {
    final t = NexThemeScope.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final canResend = !_resending && _resendIn == 0;

    return ColoredBox(
      color: t.appBg,
      child: Column(
        children: [
          NexScreenHeader(title: 'Create new password', onBack: widget.onBack),
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
                  'We sent a 6-digit code to ${maskEmailForDisplay(widget.email)}. Enter it below, then choose a new password.',
                  style: TextStyle(color: t.text2, fontSize: 15, height: 1.45),
                ),
                const SizedBox(height: 28),
                const NexLabel('Reset code'),
                const SizedBox(height: 12),
                NexOtpCodeField(
                  controller: _otp,
                  focusNode: _focus,
                  error: _error,
                  onChanged: _onOtpChanged,
                ),
                const SizedBox(height: 16),
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
                        _resending
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
                const SizedBox(height: 24),
                NexField(
                  label: 'New password',
                  controller: _password,
                  placeholder: 'At least 8 characters',
                  obscure: !_showPassword,
                  onToggleObscure: () =>
                      setState(() => _showPassword = !_showPassword),
                ),
                const SizedBox(height: 16),
                NexField(
                  label: 'Confirm password',
                  controller: _confirm,
                  placeholder: 'Re-enter new password',
                  obscure: !_showConfirm,
                  onToggleObscure: () =>
                      setState(() => _showConfirm = !_showConfirm),
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
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: t.cardSoft,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: t.cardBorder),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      NexIcon('lock', size: 16, color: t.navActive),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'After you update your password, withdrawals and swaps stay locked for a short time. Sign in again with the new password.',
                          style: TextStyle(
                            color: t.text2,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: NexPrimaryButton(
              label: _loading ? 'Updating…' : 'Update password',
              loading: _loading,
              onPressed: _loading ? null : _submit,
            ),
          ),
        ],
      ),
    );
  }
}
