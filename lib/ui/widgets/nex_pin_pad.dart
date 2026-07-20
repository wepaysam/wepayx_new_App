import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../nex_tokens.dart';
import 'nex_brand.dart';

enum NexPinPadStyle { sheet, lock, setup }

class NexPinPad extends StatefulWidget {
  const NexPinPad({
    super.key,
    required this.title,
    this.subtitle,
    required this.onCompleted,
    this.onBiometric,
    this.onBack,
    this.showBiometric = false,
    this.errorText,
    this.length = 6,
    this.autoSubmitAtLength = false,
    this.style = NexPinPadStyle.sheet,
    this.stepIndex,
    this.stepCount,
  });

  final String title;
  final String? subtitle;
  final Future<bool> Function(String pin) onCompleted;
  final VoidCallback? onBiometric;
  final VoidCallback? onBack;
  final bool showBiometric;
  final String? errorText;
  final int length;
  final bool autoSubmitAtLength;
  final NexPinPadStyle style;
  final int? stepIndex;
  final int? stepCount;

  @override
  State<NexPinPad> createState() => _NexPinPadState();
}

class _NexPinPadState extends State<NexPinPad> {
  String _pin = '';
  String? _error;
  bool _busy = false;

  @override
  void didUpdateWidget(covariant NexPinPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.errorText != oldWidget.errorText) {
      setState(() {
        _error = widget.errorText;
        if (widget.errorText != null) _busy = false;
      });
    }
  }

  bool get _canSubmit => _pin.length >= 4 && !_busy;
  bool get _isLock => widget.style == NexPinPadStyle.lock;
  bool get _isSetup => widget.style == NexPinPadStyle.setup;
  bool get _isFullScreen => _isLock || _isSetup;
  double get _keySize => _isFullScreen ? 76 : 72;

  Future<void> _addDigit(String digit) async {
    if (_busy || _pin.length >= widget.length) return;
    HapticFeedback.lightImpact();
    setState(() {
      _pin += digit;
      _error = null;
    });
    if (widget.autoSubmitAtLength && _pin.length == widget.length) {
      await _submit();
    }
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await widget.onCompleted(_pin);
      if (!mounted) return;
      if (ok) {
        setState(() => _busy = false);
        return;
      }
      setState(() {
        _busy = false;
        _pin = '';
        _error = widget.errorText ?? 'Incorrect PIN. Try again.';
      });
      HapticFeedback.heavyImpact();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _pin = '';
        _error = 'Something went wrong. Try again.';
      });
      HapticFeedback.heavyImpact();
    }
  }

  void _backspace() {
    if (_pin.isEmpty || _busy) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isFullScreen) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          return Column(
            children: [
              if (widget.onBack != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: widget.onBack,
                    icon: NexIcon('back', size: 20, color: NexThemeScope.of(context).text),
                  ),
                ),
              if (widget.stepIndex != null && widget.stepCount != null) ...[
                _stepProgress(context),
                const SizedBox(height: 8),
              ],
              SizedBox(height: h * 0.03),
              _header(),
              SizedBox(height: h * 0.04),
              _pinDots(),
              _statusArea(),
              const Spacer(),
              _keypadSection(),
              if (widget.showBiometric && widget.onBiometric != null) _biometricButton(),
              SizedBox(height: h * 0.03),
            ],
          );
        },
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.onBack != null)
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: widget.onBack,
              icon: NexIcon('back', size: 20, color: NexThemeScope.of(context).text),
            ),
          ),
        if (widget.stepIndex != null && widget.stepCount != null) ...[
          _stepProgress(context),
          const SizedBox(height: 4),
        ],
        _header(),
        const SizedBox(height: 24),
        _pinDots(),
        _statusArea(),
        const SizedBox(height: 12),
        _keypadSection(),
        if (widget.showBiometric && widget.onBiometric != null) _biometricButton(),
      ],
    );
  }

  Widget _stepProgress(BuildContext context) {
    final t = NexThemeScope.of(context);
    final current = widget.stepIndex!;
    final total = widget.stepCount!;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(total, (i) {
            final active = i < current;
            final currentStep = i == current - 1;
            return Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
                decoration: BoxDecoration(
                  color: active
                      ? (currentStep ? nexBlue : nexBlue.withValues(alpha: 0.55))
                      : t.divider,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        Text(
          'Step $current of $total',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.muted, letterSpacing: 0.4),
        ),
      ],
    );
  }

  Widget _header() {
    final t = NexThemeScope.of(context);
    final iconSize = _isFullScreen ? 72.0 : 60.0;
    final logoSize = _isFullScreen ? 36.0 : 32.0;

    return Column(
      children: [
        Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                nexBlue.withValues(alpha: 0.22),
                t.cardSoft,
              ],
            ),
            border: Border.all(color: nexBlue.withValues(alpha: 0.35)),
            boxShadow: _isFullScreen
                ? [
                    BoxShadow(
                      color: nexBlue.withValues(alpha: 0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: (_isSetup || widget.stepIndex != null)
                ? const Icon(Icons.shield_rounded, size: 34, color: nexBlue)
                : NexLogo(size: logoSize),
          ),
        ),
        SizedBox(height: _isFullScreen ? 24 : 20),
        Text(
          widget.title,
          style: TextStyle(
            fontSize: _isFullScreen ? 26 : 22,
            fontWeight: FontWeight.w800,
            color: t.text,
            letterSpacing: -0.3,
          ),
          textAlign: TextAlign.center,
        ),
        if (widget.subtitle != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              widget.subtitle!,
              style: TextStyle(fontSize: 15, color: t.text2, height: 1.35),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }

  Widget _pinDots() {
    final t = NexThemeScope.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.length, (i) {
        final filled = i < _pin.length;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: filled ? 13 : 11,
          height: filled ? 13 : 11,
          margin: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? nexBlue : Colors.transparent,
            border: Border.all(
              color: filled ? nexBlue : t.muted.withValues(alpha: 0.55),
              width: filled ? 0 : 1.8,
            ),
            boxShadow: filled
                ? [BoxShadow(color: nexBlue.withValues(alpha: 0.35), blurRadius: 8)]
                : null,
          ),
        );
      }),
    );
  }

  Widget _statusArea() {
    final displayError = _error ?? widget.errorText;
    if (_busy) {
      return const Padding(
        padding: EdgeInsets.only(top: 24),
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }
    if (displayError == null) {
      return SizedBox(height: _isFullScreen ? 28 : 20);
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16, left: 24, right: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.25)),
        ),
        child: Text(
          displayError,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFF87171), fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _keypadSection() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _isFullScreen ? 16 : 4),
      child: _keypad(),
    );
  }

  Widget _keypad() {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['✓', '0', '⌫'],
    ];

    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map(_keyCell).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _keyCell(String key) {
    final t = NexThemeScope.of(context);
    final isBack = key == '⌫';
    final isSubmit = key == '✓';
    final enabled = !_busy && (isSubmit ? _canSubmit : true);
    final gap = _isFullScreen ? 12.0 : 8.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: gap),
      child: _PinKeyButton(
        size: _keySize,
        enabled: enabled,
        isSubmit: isSubmit,
        isSubmitActive: isSubmit && _canSubmit,
        onTap: !enabled
            ? null
            : isBack
                ? _backspace
                : isSubmit
                    ? _submit
                    : () => _addDigit(key),
        onLongPress: isBack && !_busy ? () => setState(() => _pin = '') : null,
        child: isSubmit
            ? Icon(
                Icons.check_rounded,
                size: 30,
                color: _canSubmit ? Colors.white : t.muted.withValues(alpha: 0.45),
              )
            : isBack
                ? Icon(Icons.backspace_outlined, size: 24, color: enabled ? t.text : t.muted)
                : Text(
                    key,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      color: enabled ? t.text : t.muted,
                      height: 1,
                    ),
                  ),
      ),
    );
  }

  Widget _biometricButton() {
    final t = NexThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Material(
        color: t.cardSoft,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: _busy ? null : widget.onBiometric,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.fingerprint_rounded, color: nexBlue, size: 26),
                const SizedBox(width: 8),
                Text(
                  'Use fingerprint',
                  style: TextStyle(color: t.text, fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PinKeyButton extends StatelessWidget {
  const _PinKeyButton({
    required this.size,
    required this.enabled,
    required this.isSubmit,
    required this.isSubmitActive,
    required this.onTap,
    this.onLongPress,
    required this.child,
  });

  final double size;
  final bool enabled;
  final bool isSubmit;
  final bool isSubmitActive;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = NexThemeScope.of(context);

    Color bg;
    Border? border;
    if (isSubmit && isSubmitActive) {
      bg = nexBlue;
      border = null;
    } else if (isSubmit) {
      bg = t.cardSoft.withValues(alpha: 0.55);
      border = Border.all(color: t.divider);
    } else {
      bg = t.cardSoft.withValues(alpha: t.dark ? 0.85 : 1);
      border = Border.all(color: t.dark ? t.divider : t.cardBorder.withValues(alpha: 0.6));
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        onLongPress: onLongPress,
        splashColor: nexBlue.withValues(alpha: 0.12),
        highlightColor: nexBlue.withValues(alpha: 0.06),
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: enabled ? bg : bg.withValues(alpha: 0.45),
            border: border,
            boxShadow: isSubmit && isSubmitActive
                ? [
                    BoxShadow(
                      color: nexBlue.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : t.dark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}
