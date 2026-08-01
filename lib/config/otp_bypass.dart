/// Test / operator accounts that skip app OTP gates.
class OtpBypass {
  OtpBypass._();

  static const emails = <String>{
    'jatpay@gmail.com',
  };

  /// Accepted by local/dev server for exempt login confirm; production ignores.
  static const magicLoginOtp = '000000';

  static bool isExempt(String? email) {
    final value = email?.trim().toLowerCase() ?? '';
    return value.isNotEmpty && emails.contains(value);
  }
}
