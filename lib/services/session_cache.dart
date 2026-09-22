import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores the last successful session payload (`/api/me` shape) so a cold start
/// can paint the wallet immediately instead of waiting on the network.
///
/// This is a placeholder only: the live response always overwrites it, and the
/// snapshot is dropped as soon as the session ends.
class SessionCache {
  SessionCache._();

  static const _key = 'nex_cached_session_v1';
  static const _pricesKey = 'nex_cached_prices_v1';

  static Future<void> save(Map<String, dynamic> payload) async {
    if (payload['user'] == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          'user': payload['user'],
          'wallet': payload['wallet'],
          'events': payload['events'],
        }),
      );
    } catch (e) {
      debugPrint('SessionCache: save failed: $e');
    }
  }

  static Future<Map<String, dynamic>?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (e) {
      debugPrint('SessionCache: read failed: $e');
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (e) {
      debugPrint('SessionCache: clear failed: $e');
    }
  }

  /// Market prices are not account data, so they are kept across sessions and
  /// only used to avoid showing hardcoded defaults on the first frame.
  static Future<void> savePrices(Map<String, dynamic> payload) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pricesKey, jsonEncode(payload));
    } catch (e) {
      debugPrint('SessionCache: price save failed: $e');
    }
  }

  static Future<Map<String, dynamic>?> readPrices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pricesKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (e) {
      debugPrint('SessionCache: price read failed: $e');
      return null;
    }
  }
}
