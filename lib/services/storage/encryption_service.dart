import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cryptography/cryptography.dart';
import '../auth/key_derivation_service.dart';

/// AES-256-GCM encryption service.
/// Key is derived from user PIN + salt using PBKDF2.
/// Key is cached in memory during the session only.
/// Never stored on disk.
class EncryptionService {
  EncryptionService._();

  static final EncryptionService instance = EncryptionService._();

  static const _storage    = FlutterSecureStorage();
  static const _saltKey    = 'utkarsh_kdf_salt_v2';
  static const _pinHashKey = 'utkarsh_pin_hash_v2'; // Only a hash, not the PIN

  // AES-GCM is better than AES-CBC — provides authentication as well
  final _aesGcm = AesGcm.with256bits();

  // In-memory key cache — cleared when app goes to background
  Uint8List? _derivedKey;
  bool _initialized = false;

  /// First-time setup: register with a new PIN.
  /// Call this during onboarding when user creates their PIN.
  Future<void> registerWithPin({
    required String pin,
    required String saltBase64,
  }) async {
    _derivedKey   = await KeyDerivationService.deriveKey(
      pin:         pin,
      saltBase64:  saltBase64,
    );

    // Store only a hash of PIN locally for PIN verification on re-open
    final pinHash = KeyDerivationService.computeChecksum(pin + saltBase64);
    await _storage.write(key: _pinHashKey, value: pinHash);
    await _storage.write(key: _saltKey,    value: saltBase64);

    _initialized = true;
  }

  /// Unlock on subsequent opens: verify PIN and re-derive key.
  Future<bool> unlockWithPin({
    required String pin,
    required String saltBase64,
  }) async {
    final storedHash = await _storage.read(key: _pinHashKey);
    final inputHash  = KeyDerivationService.computeChecksum(pin + saltBase64);

    if (storedHash != inputHash) return false;   // Wrong PIN

    _derivedKey  = await KeyDerivationService.deriveKey(
      pin:        pin,
      saltBase64: saltBase64,
    );
    _initialized = true;
    return true;
  }

  /// Get the locally stored salt (null if first install).
  Future<String?> getLocalSalt() async {
    return _storage.read(key: _saltKey);
  }

  /// Clear key from memory (call when app goes to background).
  void lockKey() {
    _derivedKey  = null;
    _initialized = false;
  }

  void _check() {
    if (!_initialized || _derivedKey == null) {
      throw StateError(
        'EncryptionService not unlocked. '
        'Call registerWithPin() or unlockWithPin() first.',
      );
    }
  }

  /// Encrypt plaintext using AES-256-GCM.
  /// Returns "nonce_base64:ciphertext_base64:mac_base64"
  Future<String> encryptText(String plaintext) async {
    _check();

    final secretKey = SecretKey(_derivedKey!);
    final nonce     = _aesGcm.newNonce();

    final sealed = await _aesGcm.encrypt(
      utf8.encode(plaintext),
      secretKey: secretKey,
      nonce:     nonce,
    );

    final nonceB64      = base64Encode(nonce);
    final cipherB64     = base64Encode(sealed.cipherText);
    final macB64        = base64Encode(sealed.mac.bytes);

    return '$nonceB64:$cipherB64:$macB64';
  }

  /// Decrypt a string produced by encrypt().
  Future<String> decryptText(String encrypted) async {
    _check();

    final parts = encrypted.split(':');
    if (parts.length != 3) {
      throw const FormatException('Invalid encrypted format: expected nonce:cipher:mac');
    }

    final nonce      = base64Decode(parts[0]);
    final cipherText = base64Decode(parts[1]);
    final mac        = Mac(base64Decode(parts[2]));

    final secretKey  = SecretKey(_derivedKey!);

    final decrypted = await _aesGcm.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: mac),
      secretKey: secretKey,
    );

    return utf8.decode(decrypted);
  }

  Future<String> encryptJson(Object obj) async {
    return encryptText(jsonEncode(obj));
  }

  Future<T> decryptJson<T>(String encrypted) async {
    final plaintext = await decryptText(encrypted);
    return jsonDecode(plaintext) as T;
  }

  bool get isInitialized => _initialized;

  // Placeholder for backward compatibility if needed by other services
  Future<void> initialize() async {}
}

final encryptionService = EncryptionService.instance;
