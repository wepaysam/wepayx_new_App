import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecurityService extends ChangeNotifier {
  SecurityService._();

  static final SecurityService instance = SecurityService._();

  static const _pinHashKey = 'app_pin_hash';
  static const _pinSaltKey = 'app_pin_salt';
  static const _biometricPrefKey = 'security_biometric_enabled';

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
  );
  final _auth = LocalAuthentication();

  bool _initialized = false;
  bool _unlocked = false;
  bool _hasPin = false;
  bool _biometricEnabled = false;
  bool _canUseBiometric = false;
  List<BiometricType> _biometricTypes = const [];

  bool get initialized => _initialized;
  bool get hasPin => _hasPin;
  bool get isUnlocked => !_hasPin || _unlocked;
  bool get biometricEnabled => _biometricEnabled;
  bool get canUseBiometric => _canUseBiometric;
  bool get showBiometricUnlock => _hasPin && _biometricEnabled && _canUseBiometric;

  String get biometricLabel {
    if (_biometricTypes.contains(BiometricType.face)) return 'Face ID';
    if (_biometricTypes.contains(BiometricType.fingerprint)) return 'Fingerprint';
    return 'Biometrics';
  }

  Future<void> init() async {
    if (_initialized) return;

    try {
      final hash = await _storage.read(key: _pinHashKey);
      _hasPin = hash != null && hash.isNotEmpty;
    } catch (e) {
      debugPrint('SecurityService: secure storage read failed: $e');
      _hasPin = false;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      _biometricEnabled = prefs.getBool(_biometricPrefKey) ?? false;
    } catch (e) {
      debugPrint('SecurityService: prefs read failed: $e');
      _biometricEnabled = false;
    }

    try {
      _canUseBiometric = await _auth.canCheckBiometrics;
      if (_canUseBiometric) {
        _biometricTypes = await _auth.getAvailableBiometrics();
        _canUseBiometric = _biometricTypes.isNotEmpty;
      }
    } catch (e) {
      debugPrint('SecurityService: biometrics unavailable: $e');
      _canUseBiometric = false;
      _biometricTypes = const [];
    }

    if (!_hasPin) {
      _unlocked = true;
    } else {
      _unlocked = false;
    }

    _initialized = true;
    notifyListeners();
  }

  void unlock() {
    _unlocked = true;
    notifyListeners();
  }

  void lock() {
    if (!_hasPin) return;
    _unlocked = false;
    notifyListeners();
  }

  Future<bool> setPin(String pin) async {
    if (pin.length < 4 || pin.length > 6 || !RegExp(r'^\d+$').hasMatch(pin)) {
      return false;
    }
    final saltBytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final salt = base64Encode(saltBytes);
    final hash = _hashPin(pin, salt);
    await _storage.write(key: _pinHashKey, value: hash);
    await _storage.write(key: _pinSaltKey, value: salt);
    _hasPin = true;
    _unlocked = true;
    notifyListeners();
    return true;
  }

  Future<bool> verifyPin(String pin) async {
    final storedHash = await _storage.read(key: _pinHashKey);
    final salt = await _storage.read(key: _pinSaltKey);
    if (storedHash == null || salt == null) return false;
    return storedHash == _hashPin(pin, salt);
  }

  Future<void> removePin() async {
    await _storage.delete(key: _pinHashKey);
    await _storage.delete(key: _pinSaltKey);
    await setBiometricEnabled(false);
    _hasPin = false;
    _unlocked = true;
    notifyListeners();
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    if (enabled && (!_hasPin || !_canUseBiometric)) {
      _biometricEnabled = false;
    } else {
      _biometricEnabled = enabled;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricPrefKey, _biometricEnabled);
    notifyListeners();
  }

  Future<bool> authenticateWithBiometric({required String reason}) async {
    if (!_canUseBiometric) return false;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('SecurityService: biometric auth failed: $e');
      return false;
    }
  }

  Future<bool> tryBiometricUnlock() {
    return authenticateWithBiometric(reason: 'Unlock NEX Wallet');
  }

  Future<bool> tryBiometricForTransaction() {
    return authenticateWithBiometric(reason: 'Confirm this transaction');
  }

  String _hashPin(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin');
    return sha256.convert(bytes).toString();
  }
}
