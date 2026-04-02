import 'dart:convert';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class EncryptionService {
  EncryptionService._();
  static final EncryptionService instance = EncryptionService._();

  final _secureStorage = const FlutterSecureStorage();
  final _keyName = 'utkarsh_cloud_sync_key';

  bool _initialized = false;
  late Key _aesKey;

  Future<void> initialize() async {
    if (_initialized) return;

    String? keyBase64 = await _secureStorage.read(key: _keyName);
    if (keyBase64 == null) {
      // Create new AES length 32 key
      final randomBytes = Key.fromSecureRandom(32);
      keyBase64 = base64Url.encode(randomBytes.bytes);
      await _secureStorage.write(key: _keyName, value: keyBase64);
    }

    String normalized = base64Url.normalize(keyBase64);
    final bytes = base64Url.decode(normalized);
    assert(bytes.length == 32); // 256-bit
    _aesKey = Key(bytes);

    _initialized = true;
  }

  Future<String> encryptText(String text) async {
    await initialize();
    final iv = IV.fromSecureRandom(16);
    final cbcEncrypter = Encrypter(AES(_aesKey, mode: AESMode.cbc));
    final encCbc = cbcEncrypter.encrypt(text, iv: iv);
    
    final combined = iv.bytes + encCbc.bytes;
    return base64Encode(combined);
  }

  Future<String> decryptText(String encryptedText) async {
    await initialize();
    
    final combined = base64Decode(encryptedText);
    if (combined.length < 16) throw Exception('Invalid blob');
    
    final ivBytes = combined.sublist(0, 16);
    final cipherBytes = combined.sublist(16);
    
    final iv = IV(ivBytes);
    final encrypted = Encrypted(cipherBytes);
    
    final cbcEncrypter = Encrypter(AES(_aesKey, mode: AESMode.cbc));
    return cbcEncrypter.decrypt(encrypted, iv: iv);
  }

  Future<String> encryptJson(Map<String, dynamic> data) async {
    return encryptText(jsonEncode(data));
  }

  Future<Map<String, dynamic>> decryptJson(String encryptedBlob) async {
    final decryptedStr = await decryptText(encryptedBlob);
    return jsonDecode(decryptedStr);
  }
}

final encryptionService = EncryptionService.instance;
