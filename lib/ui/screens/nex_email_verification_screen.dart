import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/wallet_provider.dart';
import '../nex_tokens.dart';
import '../widgets/nex_brand.dart';
import '../widgets/nex_components.dart';

/// Required after signup: enter the email OTP before trusted wallet actions.
class NexEmailVerificationScreen extends StatefulWidget {
  const NexEmailVerificationScreen({
    super.key,
    required this.onVerified,
    this.onBack,
  });

  final VoidCallback onVerified;
  final VoidCallback? onBack;

  @override
  State<NexEmailVerificationScreen> createState() =>
      _NexEmailVerificationScreenState();
}

class _NexEmailVerificationScreenState
    extends State<NexEmailVerificationScreen> {
  static const _otpLength = 6;

  final _focus = FocusNode();
  final _otp = TextEditingController();
  bool _sending = false;
  bool _confirming = false;
  String? _error;
  int _resendIn = 0;
  Timer? _resendTimer;
  bool _requestedOnce = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_requestedOnce) {
        _requestedOnce = true;
        unawaited(_requestCode(auto: true));
      }
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

  String _maskEmail(String email) {
    final at = email.indexOf('@');
    if (at <= 1) return email;
    final name = email.substring(0, at);
    final domain = email.substring(at);
    if (name.length <= 2) return '${name[0]}***$domain';
    return '${name.substring(0, 2)}***$domain';
  }

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

  Future<void> _requestCode({bool auto = false}) async {
    if (_sending || (!auto && _resendIn > 0)) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await context.read<WalletProvider>().requestSignupEmailVerification();
      if (!mounted) return;
      _startResendCooldown();
      if (!auto) showNexToast(context, 'Verification code sent');
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      setState(() => _error = message);
      if (!auto) showNexToast(context, message);
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
      await context.read<WalletProvider>().confirmSignupEmailVerification(_code);
      if (!mounted) return;
      showNexToast(context, 'Email verified');
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
    final email = context.watch<WalletProvider>().user?.email ?? '';
    final canResend = !_sending && _resendIn == 0;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return ColoredBox(
      color: t.appBg,
      child: Column(
        children: [
          NexScreenHeader(title: 'Verify email', onBack: widget.onBack),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottomInset),
              children: [
                Row(
                  children: [
                    ClipRect(
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: const NexLogo(size: 40),
                      ),
                    ),
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
                      ? 'Enter the 6-digit verification code we sent to your email.'
                      : 'We sent a 6-digit code to ${_maskEmail(email)}. Enter it below to unlock Send, Receive, and Swap.',
                  style: TextStyle(color: t.text2, fontSize: 15, height: 1.45),
                ),
                const SizedBox(height: 28),
                const NexLabel('Verification code'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 54,
                  child: Stack(
                    children: [
                      Row(
                        children: List.generate(_otpLength, (index) {
                          final filled = index < _code.length;
                          final active = _focus.hasFocus &&
                              (index == _code.length ||
                                  (_code.length == _otpLength &&
                                      index == _otpLength - 1));
                          final char = filled ? _code[index] : '';
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: index == _otpLength - 1 ? 0 : 8,
                              ),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: t.inputFill,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _error != null
                                        ? const Color(0xFFF87171)
                                        : active
                                        ? t.navActive
                                        : t.inputBorder,
                                    width: active || _error != null ? 1.4 : 1,
                                  ),
                                ),
                                child: Text(
                                  char,
                                  style: TextStyle(
                                    color: t.text,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      // Full-area field so taps reliably open the keyboard.
                      Positioned.fill(
                        child: TextField(
                          controller: _otp,
                          focusNode: _focus,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          autofocus: true,
                          showCursor: false,
                          cursorColor: Colors.transparent,
                          style: const TextStyle(
                            color: Colors.transparent,
                            fontSize: 1,
                            height: 0.01,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(_otpLength),
                          ],
                          onTap: () {
                            _focus.requestFocus();
                            SystemChannels.textInput.invokeMethod('TextInput.show');
                          },
                          onChanged: _onOtpChanged,
                          onSubmitted: (_) => unawaited(_confirm()),
                          decoration: const InputDecoration(
                            counterText: '',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: true,
                            fillColor: Colors.transparent,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
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
                      onPressed: canResend ? () => _requestCode() : null,
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
                          'Send, Receive, and Swap stay locked until your email is verified.',
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
              label: _confirming ? 'Verifying…' : 'Verify & continue',
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
