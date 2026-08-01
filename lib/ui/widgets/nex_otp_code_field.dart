import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../nex_tokens.dart';

/// Six-digit OTP input with a full-size transparent field for reliable keyboard focus.
class NexOtpCodeField extends StatelessWidget {
  const NexOtpCodeField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.onSubmitted,
    this.length = 6,
    this.error,
    this.autofocus = true,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback? onSubmitted;
  final int length;
  final String? error;
  final bool autofocus;

  String get _code => controller.text.trim();

  @override
  Widget build(BuildContext context) {
    final t = NexThemeScope.of(context);

    return SizedBox(
      height: 54,
      child: Stack(
        children: [
          Row(
            children: List.generate(length, (index) {
              final filled = index < _code.length;
              final active = focusNode.hasFocus &&
                  (index == _code.length ||
                      (_code.length == length && index == length - 1));
              final char = filled ? _code[index] : '';
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: index == length - 1 ? 0 : 8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: t.inputFill,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: error != null
                            ? const Color(0xFFF87171)
                            : active
                            ? t.navActive
                            : t.inputBorder,
                        width: active || error != null ? 1.4 : 1,
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
          Positioned.fill(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              autofocus: autofocus,
              showCursor: false,
              cursorColor: Colors.transparent,
              style: const TextStyle(
                color: Colors.transparent,
                fontSize: 1,
                height: 0.01,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(length),
              ],
              onTap: () {
                focusNode.requestFocus();
                SystemChannels.textInput.invokeMethod('TextInput.show');
              },
              onChanged: onChanged,
              onSubmitted: (_) => onSubmitted?.call(),
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
    );
  }
}

String maskEmailForDisplay(String email) {
  final at = email.indexOf('@');
  if (at <= 1) return email;
  final name = email.substring(0, at);
  final domain = email.substring(at);
  if (name.length <= 2) return '${name[0]}***$domain';
  return '${name.substring(0, 2)}***$domain';
}
