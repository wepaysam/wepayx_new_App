import 'package:intl/intl.dart';

class Formatters {
  static final _usd = NumberFormat('#,##0.00', 'en_US');

  static String usd(num value) => _usd.format(value);

  static double parseDecimal(String text) {
    return double.tryParse(text.replaceAll(',', '').trim()) ?? 0;
  }

  static String apiAmount(num value) {
    if (value <= 0) return '0';
    var text = value.toStringAsFixed(8);
    text = text.replaceAll(RegExp(r'0+$'), '');
    if (text.endsWith('.')) {
      text = text.substring(0, text.length - 1);
    }
    return text.isEmpty ? '0' : text;
  }

  static String amount(num value) {
    if (value == 0) return '0';
    if (value < 1) {
      final text = value.toStringAsFixed(6);
      return text.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return NumberFormat('#,##0.######', 'en_US').format(value);
  }

  static String percent(num value) {
    if (!value.isFinite) return '0.00';
    return value.toStringAsFixed(2);
  }

  static String shortenAddress(String address, {int head = 8, int tail = 6}) {
    if (address.length <= head + tail + 1) return address;
    return '${address.substring(0, head)}…${address.substring(address.length - tail)}';
  }

  static String shortId(String id) {
    if (id.length <= 18) return id.isEmpty ? 'Pending' : id;
    return '${id.substring(0, 10)}…${id.substring(id.length - 8)}';
  }

  static String dateTime(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final date = DateTime.tryParse(raw);
    if (date == null) return raw;
    return DateFormat('MMMM d, yyyy h:mm a').format(date.toLocal());
  }

  static String time(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final date = DateTime.tryParse(raw);
    if (date == null) return raw;
    return DateFormat('h:mm a').format(date.toLocal());
  }
}
