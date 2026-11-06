import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// AES-256-GCM encryption for local message bodies. The key is device-bound
/// through platform secure storage. This is at-rest encryption, not E2E crypto.
class CryptoService {
  static const _keyName = 'mesh_local_aes_key_v1';
  static const _storage = FlutterSecureStorage();
  static const _cipher = AesGcm.with256bits();
  SecretKey? _key;

  Future<void> initialize() async {
    final encoded = await _storage.read(key: _keyName);
    if (encoded == null) {
      final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
      await _storage.write(key: _keyName, value: base64Encode(bytes));
      _key = SecretKey(bytes);
    } else {
      final bytes = base64Decode(encoded);
      if (bytes.length != 32) throw const FormatException('Invalid local AES key');
      _key = SecretKey(bytes);
    }
  }

  Future<Map<String, String>> encrypt(String cleartext) async {
    final key = _key;
    if (key == null) throw StateError('CryptoService is not initialized');
    final box = await _cipher.encrypt(utf8.encode(cleartext), secretKey: key);
    return {
      'nonce': base64Encode(box.nonce),
      'ciphertext': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    };
  }

  Future<String> decrypt(Map<String, String> encrypted) async {
    final key = _key;
    if (key == null) throw StateError('CryptoService is not initialized');
    final box = SecretBox(
      base64Decode(encrypted['ciphertext']!),
      nonce: base64Decode(encrypted['nonce']!),
      mac: Mac(base64Decode(encrypted['mac']!)),
    );
    return utf8.decode(await _cipher.decrypt(box, secretKey: key));
  }
}
