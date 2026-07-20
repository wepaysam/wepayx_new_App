import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/wallet_provider.dart';
import '../../services/security_service.dart';
import '../nex_layout.dart';
import '../nex_tokens.dart';
import 'nex_brand.dart';
import 'nex_components.dart';
import 'nex_pin_pad.dart';

class NexSecuritySettingsSheet extends StatefulWidget {
  const NexSecuritySettingsSheet({
    super.key,
    this.onPasswordChanged,
  });

  final Future<void> Function()? onPasswordChanged;

  @override
  State<NexSecuritySettingsSheet> createState() => _NexSecuritySettingsSheetState();
}

class _NexSecuritySettingsSheetState extends State<NexSecuritySettingsSheet> {
  _SecurityStep _step = _SecurityStep.menu;
  String _draftPin = '';
  String? _error;
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  bool _changingPassword = false;

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _backStep() {
    setState(() {
      _error = null;
      switch (_step) {
        case _SecurityStep.setPin:
        case _SecurityStep.changePin:
        case _SecurityStep.changePassword:
          _step = _SecurityStep.menu;
        case _SecurityStep.confirmPin:
          _step = _SecurityStep.setPin;
        case _SecurityStep.changePinConfirm:
          _step = _SecurityStep.changePin;
        case _SecurityStep.removePin:
          _step = _SecurityStep.menu;
        case _SecurityStep.menu:
          break;
      }
    });
  }

  void _openChangePassword() {
    _currentPassword.clear();
    _newPassword.clear();
    _confirmPassword.clear();
    setState(() {
      _step = _SecurityStep.changePassword;
      _error = null;
      _showCurrentPassword = false;
      _showNewPassword = false;
      _showConfirmPassword = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = NexThemeScope.of(context);
    final security = context.watch<SecurityService>();
    return Padding(
      padding: NexLayout.sheetBottomPadding(context),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92),
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: t.muted.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: switch (_step) {
                  _SecurityStep.menu => _menu(context, t, security),
                  _SecurityStep.setPin => _setPin(context, confirm: false),
                  _SecurityStep.confirmPin => _setPin(context, confirm: true),
                  _SecurityStep.changePin => _setPin(context, confirm: false, changing: true),
                  _SecurityStep.changePinConfirm => _setPin(context, confirm: true, changing: true),
                  _SecurityStep.removePin => _removePin(context, security),
                  _SecurityStep.changePassword => _changePassword(context, t),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menu(BuildContext context, NexTokens t, SecurityService security) {
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Center(
          child: Container(
            width: 48,
            height: 6,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: t.muted.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        Text('Security', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: t.text)),
        const SizedBox(height: 8),
        Text(
          security.hasPin
              ? 'App PIN is enabled. Use fingerprint to unlock faster.'
              : 'Set a PIN to lock the app when you open it.',
          style: TextStyle(fontSize: 14, color: t.text2),
        ),
        const SizedBox(height: 20),
        NexCard(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: t.cardSoft, shape: BoxShape.circle),
              child: Center(child: NexIcon('lock', size: 18, color: t.text)),
            ),
            title: Text('Change password', style: TextStyle(color: t.text, fontWeight: FontWeight.w600)),
            subtitle: Text(
              'Update your login password',
              style: TextStyle(color: t.muted, fontSize: 12),
            ),
            trailing: NexIcon('chevR', size: 18, color: t.subtle),
            onTap: _openChangePassword,
          ),
        ),
        const SizedBox(height: 20),
        Text('App lock', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: t.muted)),
        const SizedBox(height: 10),
        if (security.hasPin) ...[
          NexCard(
            child: SwitchListTile(
              title: Text('Unlock with fingerprint', style: TextStyle(color: t.text, fontWeight: FontWeight.w500)),
              subtitle: security.canUseBiometric
                  ? Text('Use ${security.biometricLabel} instead of PIN', style: TextStyle(color: t.muted, fontSize: 12))
                  : Text('Biometrics not available on this device', style: TextStyle(color: t.muted, fontSize: 12)),
              value: security.biometricEnabled,
              onChanged: security.canUseBiometric
                  ? (v) async {
                      if (v) {
                        final ok = await security.tryBiometricUnlock();
                        if (!ok && context.mounted) {
                          showNexToast(context, 'Verify fingerprint to enable');
                          return;
                        }
                      }
                      await security.setBiometricEnabled(v);
                    }
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          NexPrimaryButton(
            label: 'Change PIN',
            onPressed: () => setState(() {
              _step = _SecurityStep.changePin;
              _draftPin = '';
              _error = null;
            }),
          ),
          const SizedBox(height: 10),
          NexPrimaryButton(
            label: 'Remove PIN',
            onPressed: () => setState(() {
              _step = _SecurityStep.removePin;
              _error = null;
            }),
          ),
        ] else
          NexPrimaryButton(
            label: 'Set app PIN',
            onPressed: () => setState(() {
              _step = _SecurityStep.setPin;
              _draftPin = '';
              _error = null;
            }),
          ),
      ],
    );
  }

  Widget _setPin(
    BuildContext context, {
    required bool confirm,
    bool changing = false,
  }) {
    final stepIndex = confirm ? 2 : 1;
    return NexPinPad(
      key: ValueKey('pin-${_step.name}'),
      style: NexPinPadStyle.sheet,
      stepIndex: stepIndex,
      stepCount: 2,
      title: confirm ? 'Confirm PIN' : (changing ? 'New PIN' : 'Create PIN'),
      subtitle: confirm
          ? 'Re-enter your PIN, then tap ✓'
          : 'Choose 4–6 digits, then tap ✓',
      errorText: _error,
      onBack: () => _backStep(),
      onCompleted: (pin) async {
        if (!confirm) {
          if (pin.length < 4) {
            setState(() => _error = 'PIN must be at least 4 digits');
            return false;
          }
          setState(() {
            _draftPin = pin;
            _error = null;
            _step = changing ? _SecurityStep.changePinConfirm : _SecurityStep.confirmPin;
          });
          return true;
        }

        if (pin != _draftPin) {
          setState(() => _error = 'PINs do not match. Try again.');
          return false;
        }

        try {
          final ok = await SecurityService.instance.setPin(pin);
          if (!mounted) return false;
          if (!ok) {
            setState(() => _error = 'Could not save PIN. Try again.');
            return false;
          }
          showNexToast(context, 'App PIN saved');
          setState(() {
            _error = null;
            _step = _SecurityStep.menu;
          });
          return true;
        } catch (_) {
          if (mounted) setState(() => _error = 'Could not save PIN. Try again.');
          return false;
        }
      },
    );
  }

  Widget _removePin(BuildContext context, SecurityService security) {
    return NexPinPad(
      key: const ValueKey('pin-remove'),
      title: 'Enter current PIN',
      subtitle: 'Required to remove app lock',
      errorText: _error,
      showBiometric: security.showBiometricUnlock,
      onBiometric: () async {
        final ok = await security.tryBiometricUnlock();
        if (ok) {
          await security.removePin();
          if (mounted) {
            showNexToast(context, 'App PIN removed');
            setState(() => _step = _SecurityStep.menu);
          }
        }
      },
      onCompleted: (pin) async {
        final ok = await security.verifyPin(pin);
        if (!ok) {
          setState(() => _error = 'Incorrect PIN');
          return false;
        }
        await security.removePin();
        if (mounted) {
          showNexToast(context, 'App PIN removed');
          setState(() => _step = _SecurityStep.menu);
        }
        return true;
      },
    );
  }

  Widget _changePassword(BuildContext context, NexTokens t) {
    Future<void> submit() async {
      final current = _currentPassword.text;
      final next = _newPassword.text;
      final confirm = _confirmPassword.text;

      if (current.isEmpty) {
        setState(() => _error = 'Enter your current password');
        return;
      }
      if (next.length < 6) {
        setState(() => _error = 'New password must be at least 6 characters');
        return;
      }
      if (next != confirm) {
        setState(() => _error = 'New passwords do not match');
        return;
      }
      if (next == current) {
        setState(() => _error = 'New password must be different');
        return;
      }

      setState(() {
        _changingPassword = true;
        _error = null;
      });
      try {
        await context.read<WalletProvider>().changePassword(
              currentPassword: current,
              newPassword: next,
            );
        if (!mounted) return;
        _currentPassword.clear();
        _newPassword.clear();
        _confirmPassword.clear();
        if (widget.onPasswordChanged != null) {
          await widget.onPasswordChanged!();
        } else {
          showNexToast(context, 'Password updated');
          setState(() => _step = _SecurityStep.menu);
        }
      } catch (e) {
        if (!mounted) return;
        final message = e.toString().replaceFirst('ApiException: ', '').replaceFirst('Exception: ', '');
        setState(() => _error = message);
      } finally {
        if (mounted) setState(() => _changingPassword = false);
      }
    }

    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Row(
          children: [
            NexIconButton(onTap: _backStep, icon: 'back', size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Change password',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: t.text),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Enter your current password and choose a new one for your NEX Wallet account.',
          style: TextStyle(fontSize: 14, color: t.text2, height: 1.45),
        ),
        const SizedBox(height: 20),
        NexField(
          label: 'Current password',
          controller: _currentPassword,
          placeholder: 'Current password',
          obscure: !_showCurrentPassword,
          onToggleObscure: () => setState(() => _showCurrentPassword = !_showCurrentPassword),
        ),
        const SizedBox(height: 16),
        NexField(
          label: 'New password',
          controller: _newPassword,
          placeholder: 'At least 6 characters',
          obscure: !_showNewPassword,
          onToggleObscure: () => setState(() => _showNewPassword = !_showNewPassword),
        ),
        const SizedBox(height: 16),
        NexField(
          label: 'Confirm new password',
          controller: _confirmPassword,
          placeholder: 'Re-enter new password',
          obscure: !_showConfirmPassword,
          onToggleObscure: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
        ],
        const SizedBox(height: 20),
        NexPrimaryButton(
          label: _changingPassword ? 'Saving...' : 'Update password',
          onPressed: _changingPassword ? null : submit,
        ),
      ],
    );
  }
}

enum _SecurityStep {
  menu,
  setPin,
  confirmPin,
  changePin,
  changePinConfirm,
  removePin,
  changePassword,
}
