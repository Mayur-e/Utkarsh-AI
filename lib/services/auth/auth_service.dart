import 'package:supabase_flutter/supabase_flutter.dart';
import '../storage/encryption_service.dart';
import 'key_derivation_service.dart';

/// Handles Supabase authentication and PIN-based key setup.
/// This service coordinates between Supabase auth and local encryption.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final _supabase = Supabase.instance.client;

  // ── Registration (new user) ──────────────────────────────────────────────

  /// Register a new user with email, password, and PIN.
  /// The PIN is used to derive the local encryption key.
  /// The PIN is NEVER sent to Supabase.
  Future<AuthResult> register({
    required String email,
    required String password,
    required String pin,          // 6-digit PIN — stays on device
  }) async {
    try {
      // 1. Create Supabase account
      final response = await _supabase.auth.signUp(
        email:    email,
        password: password,
      );

      if (response.user == null) {
        return AuthResult.failure('Registration failed. Please try again.');
      }

      final userId = response.user!.id;

      // 2. Generate salt and store in Supabase
      final salt = KeyDerivationService.generateSalt();

      await _supabase.from('user_meta').upsert({
        'user_id':   userId,
        'kdf_salt':  salt,
        'kdf_iters': 100000,
        'schema_ver': 2,
      });

      // 3. Derive local encryption key from PIN + salt
      // This happens locally — Supabase never sees the key
      await EncryptionService.instance.registerWithPin(
        pin:        pin,
        saltBase64: salt,
      );

      return AuthResult.success(userId: userId, salt: salt);

    } on AuthException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
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
      // 1. Authenticate with Supabase
      final response = await _supabase.auth.signInWithPassword(
        email:    email,
        password: password,
      );

      if (response.user == null) {
        return AuthResult.failure('Invalid email or password.');
      }

      final userId = response.user!.id;

      // 2. Fetch salt from Supabase
      final meta = await _supabase
          .from('user_meta')
          .select('kdf_salt')
          .eq('user_id', userId)
          .single();

      final salt = meta['kdf_salt'] as String;

      // 3. Re-derive encryption key from PIN + salt locally
      final unlocked = await EncryptionService.instance.unlockWithPin(
        pin:        pin,
        saltBase64: salt,
      );

      if (!unlocked) {
        // Clear session if PIN is wrong to avoid inconsistent state
        await _supabase.auth.signOut();
        return AuthResult.failure(
          'Incorrect PIN. Your data cannot be decrypted.',
        );
      }

      return AuthResult.success(userId: userId, salt: salt);

    } on AuthException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      return AuthResult.failure('Login failed: $e');
    }
  }

  // ── PIN-only unlock (already logged in) ───────────────────────────────────

  /// When the app relaunches and user is already authenticated in Supabase
  /// but the key was cleared from memory (app was closed), ask for PIN only.
  Future<bool> unlockWithPinOnly(String pin) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      // Fetch fresh salt from Supabase
      final meta = await _supabase
          .from('user_meta')
          .select('kdf_salt')
          .eq('user_id', user.id)
          .single();

      final salt = meta['kdf_salt'] as String;

      return EncryptionService.instance.unlockWithPin(
        pin:        pin,
        saltBase64: salt,
      );
    } catch (_) {
      return false;
    }
  }

  // ── Sign out ──────────────────────────────────────────────────────────────

  Future<void> signOut() async {
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
