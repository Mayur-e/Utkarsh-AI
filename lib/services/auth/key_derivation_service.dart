import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart' as pkg_crypto;
import 'package:cryptography/cryptography.dart';

/// Derives a deterministic AES-256 key from a user PIN and salt.
/// Same PIN + same salt = same key, every time, on every device.
/// The salt is stored in Supabase. The PIN never leaves the device.
class KeyDerivationService {
  KeyDerivationService._();

  static const int _iterations  = 100000;
  static const int _keyLength   = 32;      // 256 bits
  static const int _saltLength  = 32;      // 256 bits

  /// Generate a new random salt for a new user registration.
  static String generateSalt() {
    final random = Random.secure();
    final bytes  = Uint8List.fromList(
      List.generate(_saltLength, (_) => random.nextInt(256)),
    );
    return base64Encode(bytes);
  }

  /// Parameters for Isolate execution
  static Future<Uint8List> _doDerive(Map<String, String> params) async {
    final pin = params['pin']!;
    final saltBase64 = params['saltBase64']!;
    
    final pbkdf2    = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations:   _iterations,
      bits:         _keyLength * 8,
    );

    final saltBytes = base64Decode(saltBase64);

    final secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(pin)),
      nonce:     saltBytes,
    );

    final keyBytes = await secretKey.extractBytes();
    return Uint8List.fromList(keyBytes);
  }

  /// Derive a 32-byte AES key from PIN + salt using PBKDF2-HMAC-SHA256.
  /// Runs on a separate Isolate to prevent UI thread blocking.
  static Future<Uint8List> deriveKey({
    required String pin,
    required String saltBase64,
  }) async {
    // Offload to Isolate (compute) to keep UI responsive
    return compute(_doDerive, {
      'pin': pin,
      'saltBase64': saltBase64,
    });
  }

  /// Compute SHA-256 checksum of plaintext for integrity verification.
  static String computeChecksum(String plaintext) {
    final bytes  = utf8.encode(plaintext);
    final digest = pkg_crypto.sha256.convert(bytes);
    return digest.toString();
  }

  /// Verify that decrypted data matches its checksum.
  static bool verifyChecksum(String plaintext, String expectedChecksum) {
    return computeChecksum(plaintext) == expectedChecksum;
  }
}
