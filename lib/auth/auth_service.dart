import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cryptography/cryptography.dart';
import 'dart:convert';
import 'dart:math';

/// Local account gate. Password verification uses PBKDF2-HMAC-SHA256.
/// Passwords are never stored. This does not create a cloud identity or
/// portable reinstall recovery; secure storage is device-bound.
class AuthService {
  static const _storage = FlutterSecureStorage();
  static const _usernameKey = 'mesh_auth_username_v1';
  static const _saltKey = 'mesh_auth_salt_v1';
  static const _verifierKey = 'mesh_auth_verifier_v1';
  static const _kdf = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 210000, bits: 256);

  Future<bool> hasAccount() async => await _storage.read(key: _usernameKey) != null;

  Future<String?> savedUsername() => _storage.read(key: _usernameKey);

  Future<void> createAccount(String username, String password) async {
    final normalized = username.trim();
    _validate(normalized, password);
    if (await hasAccount()) throw StateError('An account already exists on this device.');
    final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final verifier = await _derive(password, salt);
    await _storage.write(key: _usernameKey, value: normalized);
    await _storage.write(key: _saltKey, value: base64Encode(salt));
    await _storage.write(key: _verifierKey, value: base64Encode(verifier));
  }

  Future<bool> verify(String username, String password) async {
    final savedName = await _storage.read(key: _usernameKey);
    final saltText = await _storage.read(key: _saltKey);
    final verifierText = await _storage.read(key: _verifierKey);
    if (savedName == null || saltText == null || verifierText == null) return false;
    if (savedName != username.trim()) return false;
    final actual = await _derive(password, base64Decode(saltText));
    final expected = base64Decode(verifierText);
    if (actual.length != expected.length) return false;
    var difference = 0;
    for (var i = 0; i < actual.length; i++) { difference |= actual[i] ^ expected[i]; }
    return difference == 0;
  }

  Future<List<int>> _derive(String password, List<int> salt) async =>
      (await _kdf.deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt)).extractBytes();

  void _validate(String username, String password) {
    if (username.length < 3 || username.length > 32) throw ArgumentError('Username must be 3–32 characters.');
    if (password.length < 10) throw ArgumentError('Password must be at least 10 characters.');
  }
}
