import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Live NEX signup requires a unique `telegram_id`. The mobile app is not the
/// Telegram bot, so we persist a device-scoped numeric id and reuse it.
class TelegramIdStore {
  TelegramIdStore._();

  static const _key = 'nex_telegram_id';

  static Future<String> getOrCreate() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_key)?.trim() ?? '';
    if (existing.isNotEmpty) return existing;
    final id = _generate();
    await prefs.setString(_key, id);
    return id;
  }

  /// After a scheduled account delete, mint a new id so the next signup is not
  /// rejected as an already-active telegram user.
  static Future<String> rotate() async {
    final prefs = await SharedPreferences.getInstance();
    final id = _generate();
    await prefs.setString(_key, id);
    return id;
  }

  static String _generate() {
    final rand = Random.secure();
    final suffix = rand.nextInt(900000) + 100000;
    return '${DateTime.now().millisecondsSinceEpoch}$suffix';
  }
}
