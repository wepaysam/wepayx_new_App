/// Parse wallet addresses from QR codes, URIs, or clipboard text.
String? parseWalletAddress(String raw, {required String network}) {
  var text = raw.trim();
  if (text.isEmpty) return null;

  final colon = text.indexOf(':');
  if (colon > 0 && colon < 12) {
    final scheme = text.substring(0, colon).toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      var payload = text.substring(colon + 1);
      final q = payload.indexOf('?');
      if (q >= 0) payload = payload.substring(0, q);
      final at = payload.indexOf('@');
      if (at >= 0) payload = payload.substring(at + 1);
      text = payload.trim();
    }
  }

  text = text.replaceAll(RegExp(r'\s+'), '');
  if (text.isEmpty) return null;

  if (looksLikeNetworkAddress(text, network)) return text;
  return null;
}

bool looksLikeNetworkAddress(String address, String network) {
  final value = address.trim();
  switch (network) {
    case 'TRC20':
      return _isTronAddress(value);
    case 'ERC20':
    case 'BEP20':
      return _isEvmAddress(value);
    case 'Bitcoin':
      return _isBtcAddress(value);
    default:
      return value.length >= 12;
  }
}

bool _isEvmAddress(String value) => RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(value);

bool _isTronAddress(String value) {
  if (!value.startsWith('T') || value.length < 34 || value.length > 36) return false;
  return RegExp(r'^T[1-9A-HJ-NP-Za-km-z]{33}$').hasMatch(value);
}

bool _isBtcAddress(String value) {
  if (value.length < 26 || value.length > 90) return false;
  if (value.startsWith('bc1') || value.startsWith('tb1')) {
    return RegExp(r'^(bc1|tb1)[a-z0-9]{25,87}$').hasMatch(value);
  }
  return RegExp(r'^[13][a-km-zA-HJ-NP-Z1-9]{25,34}$').hasMatch(value);
}
