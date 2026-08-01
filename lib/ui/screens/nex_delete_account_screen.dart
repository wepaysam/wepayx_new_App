import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/wallet_provider.dart';
import '../nex_tokens.dart';
import '../widgets/nex_components.dart';
import '../widgets/nex_otp_code_field.dart';

class NexDeleteAccountScreen extends StatefulWidget {
  const NexDeleteAccountScreen({
    super.key,
    required this.onBack,
    required this.onDeleted,
  });

  final VoidCallback onBack;
  final VoidCallback onDeleted;

  @override
  State<NexDeleteAccountScreen> createState() => _NexDeleteAccountScreenState();
}

class _NexDeleteAccountScreenState extends State<NexDeleteAccountScreen> {
  static const _otpLength = 6;

  final _password = TextEditingController();
  final _otp = TextEditingController();
  final _otpFocus = FocusNode();
  bool _showPassword = false;
  bool _requesting = false;
  bool _deleting = false;
  String? _error;
  String? _maskedEmail;
  bool _otpSent = false;
  int _resendIn = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _password.dispose();
    _otp.dispose();
    _otpFocus.dispose();
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

  Future<void> _requestCode({bool resend = false}) async {
    if (_requesting || (resend && _resendIn > 0)) return;
    if (_password.text.isEmpty) {
      setState(() => _error = 'Enter your password to continue');
      return;
    }

    setState(() {
      _requesting = true;
      _error = null;
    });
    try {
      final masked = await context.read<WalletProvider>().requestAccountDelete(
            password: _password.text,
          );
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _maskedEmail = masked;
      });
      _startResendCooldown();
      if (resend) showNexToast(context, 'Delete code sent');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      });
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  Future<void> _confirmDelete() async {
    if (_deleting) return;
    if (!_otpSent) {
      await _requestCode();
      return;
    }
    if (_code.length != _otpLength) {
      setState(() => _error = 'Enter the 6-digit delete code from your email');
      return;
    }

    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await context.read<WalletProvider>().confirmAccountDelete(
            password: _password.text,
            otp: _code,
          );
      if (!mounted) return;
      showNexToast(context, 'Account deleted');
      widget.onDeleted();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
        _otp.clear();
      });
      _otpFocus.requestFocus();
    } finally {
      if (mounted) setState(() => _deleting = false);
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
      unawaited(_confirmDelete());
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = NexThemeScope.of(context);
    final email = context.watch<WalletProvider>().user?.email ?? '';
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final canResend = !_requesting && _resendIn == 0 && _otpSent;

    return ColoredBox(
      color: t.appBg,
      child: Column(
        children: [
          NexScreenHeader(title: 'Delete account', onBack: widget.onBack),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottomInset),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    'This permanently deletes your wallet account. You can sign up again later with the same email, but your old account cannot be recovered.',
                    style: TextStyle(color: t.text2, fontSize: 13, height: 1.45),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  email,
                  style: TextStyle(
                    color: t.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 16),
                NexField(
                  label: 'Password',
                  controller: _password,
                  placeholder: 'Current password',
                  obscure: !_showPassword,
                  onToggleObscure: () =>
                      setState(() => _showPassword = !_showPassword),
                ),
                if (_otpSent) ...[
                  const SizedBox(height: 20),
                  Text(
                    _maskedEmail == null
                        ? 'Enter the delete code from your email.'
                        : 'Enter the code sent to $_maskedEmail.',
                    style: TextStyle(color: t.text2, fontSize: 14, height: 1.45),
                  ),
                  const SizedBox(height: 12),
                  const NexLabel('Delete code'),
                  const SizedBox(height: 12),
                  NexOtpCodeField(
                    controller: _otp,
                    focusNode: _otpFocus,
                    error: _error,
                    onChanged: _onOtpChanged,
                    onSubmitted: _confirmDelete,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: canResend ? () => _requestCode(resend: true) : null,
                    child: Text(
                      _requesting
                          ? 'Sending…'
                          : _resendIn > 0
                          ? 'Resend in ${_resendIn}s'
                          : 'Resend delete code',
                      style: TextStyle(
                        color: canResend ? t.navActive : t.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFFF87171),
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: NexPrimaryButton(
              label: _otpSent
                  ? (_deleting ? 'Deleting…' : 'Confirm delete')
                  : (_requesting ? 'Sending code…' : 'Send delete code'),
              loading: _requesting || _deleting,
              onPressed: _requesting || _deleting ? null : _confirmDelete,
            ),
          ),
        ],
      ),
    );
  }
}
