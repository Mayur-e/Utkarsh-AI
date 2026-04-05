import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../storage/database_service.dart';

class SyncService {
  SyncService._();
  static final instance = SyncService._();

  Timer? _syncTimer;
  bool _isSyncing = false;

  void start() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(hours: 12), (timer) => syncContextCapsules());
    // Initial sync
    syncContextCapsules();
  }

  Future<void> syncContextCapsules() async {
    if (_isSyncing) return;
    
    final List<ConnectivityResult> connectivityResults = await Connectivity().checkConnectivity();
    if (connectivityResults.contains(ConnectivityResult.none)) return;

    _isSyncing = true;
    try {
      final capsules = await DatabaseService.instance.getPendingContextCapsules();
      if (capsules.isEmpty) return;

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      for (final capsule in capsules) {
        // Upload to 'weekly_context_capsules' table
        await Supabase.instance.client.from('weekly_context_capsules').upsert({
          'user_id': user.id,
          'id': capsule.id,
          'data': capsule.toMap(),
          'synced_at': DateTime.now().toIso8601String(),
        });

        // Trigger Edge Function for processing (simulated via RPC or just assumed)
        // await Supabase.instance.client.functions.invoke('process-weekly-review', body: {'capsule_id': capsule.id});

        await DatabaseService.instance.markContextCapsuleSynced(capsule.id);
      }
    } catch (e) {
      debugPrint('Sync Error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  void stop() {
    _syncTimer?.cancel();
  }
}

final syncService = SyncService.instance;
