import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/saved_address.dart';

/// Local-only address book. Nothing is synced to the backend.
class AddressBookService extends ChangeNotifier {
  AddressBookService._();

  static final AddressBookService instance = AddressBookService._();

  static const _storageKey = 'nex_local_address_book_v1';

  List<SavedAddress> _entries = const [];
  bool _loaded = false;

  List<SavedAddress> get entries => List.unmodifiable(_entries);
  bool get isLoaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      _entries = const [];
      _loaded = true;
      notifyListeners();
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        _entries = const [];
      } else {
        _entries = decoded
            .whereType<Map>()
            .map((item) => SavedAddress.fromJson(Map<String, dynamic>.from(item)))
            .where((item) => item.id.isNotEmpty && item.address.isNotEmpty)
            .toList()
          ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
      }
    } catch (e) {
      debugPrint('AddressBookService: load failed: $e');
      _entries = const [];
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(_entries.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, payload);
    notifyListeners();
  }

  List<SavedAddress> forNetwork(String network) {
    final n = network.trim().toLowerCase();
    return _entries
        .where((item) => item.network.trim().toLowerCase() == n)
        .toList();
  }

  SavedAddress? findByAddress(String address, {String? network}) {
    final target = address.trim().toLowerCase();
    if (target.isEmpty) return null;
    for (final item in _entries) {
      if (item.address.trim().toLowerCase() != target) continue;
      if (network != null &&
          network.isNotEmpty &&
          item.network.trim().toLowerCase() != network.trim().toLowerCase()) {
        continue;
      }
      return item;
    }
    return null;
  }

  Future<SavedAddress> save({
    required String title,
    required String address,
    required String network,
    String assetHint = '',
    String? id,
  }) async {
    if (!_loaded) await load();

    final cleanedTitle = title.trim();
    final cleanedAddress = address.trim();
    final cleanedNetwork = network.trim();
    if (cleanedTitle.isEmpty) {
      throw Exception('Enter a title for this address');
    }
    if (cleanedAddress.length < 12) {
      throw Exception('Enter a valid wallet address');
    }
    if (cleanedNetwork.isEmpty) {
      throw Exception('Network is required');
    }

    final existingSame = findByAddress(cleanedAddress, network: cleanedNetwork);
    if (existingSame != null && existingSame.id != id) {
      throw Exception('This address is already saved for $cleanedNetwork');
    }

    if (id != null && id.isNotEmpty) {
      final index = _entries.indexWhere((item) => item.id == id);
      if (index < 0) throw Exception('Saved address not found');
      final updated = _entries[index].copyWith(
        title: cleanedTitle,
        address: cleanedAddress,
        network: cleanedNetwork,
        assetHint: assetHint,
      );
      _entries = [
        ..._entries.sublist(0, index),
        updated,
        ..._entries.sublist(index + 1),
      ];
      await _persist();
      return updated;
    }

    final entry = SavedAddress(
      id: 'addr_${DateTime.now().microsecondsSinceEpoch}',
      title: cleanedTitle,
      address: cleanedAddress,
      network: cleanedNetwork,
      assetHint: assetHint.trim(),
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    _entries = [entry, ..._entries];
    await _persist();
    return entry;
  }

  Future<void> delete(String id) async {
    if (!_loaded) await load();
    _entries = _entries.where((item) => item.id != id).toList();
    await _persist();
  }
}
