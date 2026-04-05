import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';
import '../storage/encryption_service.dart';
import 'key_derivation_service.dart';
import '../cloud/cloud_sync_service.dart';
import '../storage/database_service.dart';

/// Handles Supabase authentication and PIN-based key setup.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final _supabase = Supabase.instance.client;
  final _storage = const FlutterSecureStorage();

  static const _pinKey = 'utkarsh_auth_pin';

  // ── Registration (new user) ──────────────────────────────────────────────

  /// Register a new user with email, password, and PIN.
  /// The PIN is used to derive the local encryption key.
  /// The PIN is NEVER sent to Supabase.
  Future<AuthResult> register({
    required String email,
    required String password,
    required String pin,          // 6-digit PIN — stays on device
    String? displayName,
  }) async {
    try {
      debugPrint('[AuthService] ⏳ Starting registration for $email...');
      // 1. Create Supabase account (or check if exists)
      AuthResponse response;
      try {
        response = await _supabase.auth.signUp(
          email:    email,
          password: password,
          data: {
            'display_name': displayName,
          },
        ).timeout(const Duration(seconds: 15));
      } on AuthException catch (e) {
        if (e.message.contains('already registered')) {
          debugPrint('[AuthService] ⚠️ User already in Auth system. Attempting to repair metadata...');
          // Try to sign in to get the userId
          response = await _supabase.auth.signInWithPassword(email: email, password: password);
        } else {
          rethrow;
        }
      }

      if (response.user == null) {
        debugPrint('[AuthService] ❌ Registration/Repair failed: No user returned');
        return AuthResult.failure('Registration failed. Please try again.');
      }

      final userId = response.user!.id;
      debugPrint('[AuthService] ✅ Supabase account identified: $userId');

      // 2. Generate salt and store in Supabase
      final salt = KeyDerivationService.generateSalt();
      debugPrint('[AuthService] ⏳ Calibrating local encryption key...');

      await EncryptionService.instance.registerWithPin(
        pin:        pin,
        saltBase64: salt,
        userId:     userId,
      ).timeout(const Duration(seconds: 20)); // KDF can be slow

      debugPrint('[AuthService] ✅ Encryption key calibrated locally');

      // 3. Create a verification blob in Supabase
      final verifyBlob = await EncryptionService.instance.encryptText('IDENTITY_VERIFIED');
      debugPrint('[AuthService] ⏳ Saving user metadata to cloud...');

      await _supabase.from('user_meta').upsert({
        'user_id':         userId,
        'kdf_salt':        salt,
        'kdf_iters':       100000,
        'schema_ver':      2,
        'pin_verify_blob': verifyBlob,
      }).timeout(const Duration(seconds: 10));

      debugPrint('[AuthService] ✅ User metadata synchronized');

      // 4. MIGRATION: Fix "personal details gone" by moving local data to this new ID
      await DatabaseService.instance.migrateLocalData(userId);

      return AuthResult.success(userId: userId, salt: salt);

    } on TimeoutException {
      debugPrint('[AuthService] ⏳ Registration timed out — check your connection');
      return AuthResult.failure('Request timed out. Please check your internet connection.');
    } on AuthException catch (e) {
      debugPrint('[AuthService] ❌ Registration auth error: ${e.message}');
      return AuthResult.failure(e.message);
    } catch (e) {
      debugPrint('[AuthService] ❌ Registration unexpected error: $e');
      return AuthResult.failure('An unexpected error occurred: $e');
    }
  }

  // ── Login (existing user) ────────────────────────────────────────────────

  /// Login with email, password, and PIN.
  /// Fetches salt from Supabase and re-derives the encryption key locally.
  Future<AuthResult> login({
    required String email,
    required String password,
    required String pin,
  }) async {
    try {
      debugPrint('[AuthService] ⏳ Attempting login for $email...');
      // 1. Authenticate with Supabase
      final response = await _supabase.auth.signInWithPassword(
        email:    email,
        password: password,
      ).timeout(const Duration(seconds: 15));

      if (response.user == null) {
        debugPrint('[AuthService] ❌ Login failed: No user returned');
        return AuthResult.failure('Invalid email or password.');
      }

      final userId = response.user!.id;
      debugPrint('[AuthService] ✅ Supabase logged in: $userId');

      // 2. Fetch salt and verification blob from Supabase
      debugPrint('[AuthService] ⏳ Fetching security metadata...');
      final meta = await _supabase
          .from('user_meta')
          .select('kdf_salt, pin_verify_blob')
          .eq('user_id', userId)
          .single()
          .timeout(const Duration(seconds: 10));

      final salt       = meta['kdf_salt'] as String;
      final verifyBlob = meta['pin_verify_blob'] as String?;

      // 3. Re-derive encryption key from PIN + salt locally
      debugPrint('[AuthService] ⏳ Calibrating local encryption key...');
      final unlocked = await EncryptionService.instance.unlockWithPin(
        pin:        pin,
        saltBase64: salt,
        userId:     userId,
      ).timeout(const Duration(seconds: 20));

      bool pinIsCorrect = unlocked;

      // If we are on a new device (local pinHash null), we must verify PIN against the cloud blob
      if (pinIsCorrect && verifyBlob != null) {
        try {
          final decrypted = await EncryptionService.instance.decryptText(verifyBlob);
          if (decrypted != 'IDENTITY_VERIFIED') {
            pinIsCorrect = false;
          }
        } catch (_) {
          pinIsCorrect = false;
        }
      }

      if (!pinIsCorrect) {
        debugPrint('[AuthService] ❌ PIN verification failed');
        // Clear session if PIN is wrong to avoid inconsistent state or brute forcing attempts on device
        await _supabase.auth.signOut();
        EncryptionService.instance.lockKey(); // Ensure it is definitely locked
        return AuthResult.failure(
          'Incorrect PIN. Your data cannot be decrypted on this device.',
        );
      }

      debugPrint('[AuthService] ✅ Authentication successful locally & cloud');

      // Save PIN for subsequent auto-unlocks
      await _storage.write(key: _pinKey, value: pin);

      // 4. MIGRATION: Transfer any 'local_user' data to this account
      await DatabaseService.instance.migrateLocalData(userId);

      // RESTORE: Recover encrypted records from cloud on fresh install
      final profileCheck = await DatabaseService.instance.getProfile(userId);
      if (profileCheck == null) {
        debugPrint('[AuthService] ⏳ Profile missing locally, triggering cloud restoration...');
        await CloudSyncService.instance.restoreAll().timeout(const Duration(seconds: 30));
      }

      return AuthResult.success(userId: userId, salt: salt);

    } on TimeoutException {
      debugPrint('[AuthService] ⏳ Login timed out — check your connection');
      return AuthResult.failure('Request timed out. Please check your internet connection.');
    } on AuthException catch (e) {
      debugPrint('[AuthService] ❌ Login auth error: ${e.message}');
      return AuthResult.failure(e.message);
    } catch (e) {
      debugPrint('[AuthService] ❌ Login unexpected error: $e');
      return AuthResult.failure('Login failed: $e');
    }
  }

  // ── Auto-Unlock ─────────────────────────────────────────────────────────

  /// Attempt to re-derive the encryption key using a saved PIN.
  /// Used during app boot if the user is already logged in to Supabase.
  Future<bool> tryAutoUnlock() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final pin = await _storage.read(key: _pinKey);
      if (pin == null) return false;

      final meta = await _supabase
          .from('user_meta')
          .select('kdf_salt')
          .eq('user_id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 5));

      if (meta == null) return false;
      final salt = meta['kdf_salt'] as String;

      final result = await EncryptionService.instance.unlockWithPin(
        pin:        pin,
        saltBase64: salt,
        userId:     user.id,
      );

      if (result) {
        // Trigger background restore if profile is missing
        final profile = await DatabaseService.instance.getProfile();
        if (profile == null) {
          await CloudSyncService.instance.restoreAll().timeout(const Duration(seconds: 15));
        }
      }
      
      return result;
    } catch (_) {
      return false;
    }
  }

  /// Manually unlock using a PIN (e.g. if auto-unlock was not available)
  Future<bool> unlockManual(String pin) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final meta = await _supabase
          .from('user_meta')
          .select('kdf_salt')
          .eq('user_id', user.id)
          .maybeSingle();

      if (meta == null) return false;
      final salt = meta['kdf_salt'] as String;

      final unlocked = await EncryptionService.instance.unlockWithPin(
        pin:        pin,
        saltBase64: salt,
        userId:     user.id,
      );

      if (unlocked) {
        // Save for next time to meet the user's request
        await _storage.write(key: _pinKey, value: pin);
      }
      return unlocked;
    } catch (_) {
      return false;
    }
  }

  // ── Sign out ──────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _storage.delete(key: _pinKey);
    EncryptionService.instance.lockKey();
    await _supabase.auth.signOut();
  }

  // ── Getters ───────────────────────────────────────────────────────────────

  User? get currentUser => _supabase.auth.currentUser;
  bool get isLoggedIn   => _supabase.auth.currentUser != null;
  bool get isUnlocked   => EncryptionService.instance.isInitialized;
}

// ── Result type ────────────────────────────────────────────────────────────

class AuthResult {
  final bool    success;
  final String? error;
  final String? userId;
  final String? salt;

  const AuthResult._({
    required this.success,
    this.error,
    this.userId,
    this.salt,
  });

  factory AuthResult.success({ required String userId, required String salt }) {
    return AuthResult._(success: true, userId: userId, salt: salt);
  }

  factory AuthResult.failure(String error) {
    return AuthResult._(success: false, error: error);
  }
}
