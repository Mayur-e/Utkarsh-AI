import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/storage/database_service.dart';
import '../../../services/cloud/cloud_sync_service.dart';
import '../../../services/notifications/notification_service.dart';
import '../../../state/app_state.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notifs = true;
  bool _cloud = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final p = await databaseServiceProvider.getProfile();
    if (mounted) {
      setState(() {
        _notifs = p?['notifications_on'] == 1 || p?['notifications_on'] == true;
        _cloud = p?['cloud_sync_enabled'] == 1 || p?['cloud_sync_enabled'] == true;
      });
    }
  }

  Future<void> _toggleNotifications(bool v) async {
    setState(() => _notifs = v);
    await databaseServiceProvider.updateProfile({'notifications_on': v ? 1 : 0});
    if (v) {
      await notificationService.scheduleEveningCheckin();
    } else {
      await notificationService.cancelAll();
    }
  }

  Future<void> _toggleCloud(bool v) async {
    setState(() => _cloud = v);
    cloudSyncService.setEnabled(v);
    await databaseServiceProvider.updateProfile({'cloud_sync_enabled': v ? 1 : 0});
    if (v && !cloudSyncService.isSignedIn) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Cloud Sync'),
            content: const Text('An anonymous account will be created. No personal info is sent to the server. Data is stored AES-256 encrypted.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      try {
        await cloudSyncService.signInAnonymously();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    }
  }

  void _handleClearChat() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Conversation History'),
        content: const Text('This will permanently delete all your AI chat messages. Your XP, level, and assessments will be kept intact.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.pop(ctx);
              await databaseServiceProvider.clearChatHistory();
              ref.read(chatRefreshProvider.notifier).state++;
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chat history wiped clearly.'), backgroundColor: AppColors.success));
              }
            },
            child: const Text('Delete Chats'),
          ),
        ],
      ),
    );
  }

  void _handleFactoryReset() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ Factory Reset'),
        content: const Text('WARNING: This will permanently delete ALL your local data, text history, wellbeing records, and erase all XP progress. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.pop(ctx);
              await databaseServiceProvider.clearAllData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('App has been Factory Reset.'), backgroundColor: AppColors.danger));
              }
            },
            child: const Text('Factory Reset'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleExportData() async {
    try {
      final jsonStr = await databaseServiceProvider.exportData();
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/utkarsh_wellness_export.json');
      await file.writeAsString(jsonStr);
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.md)),
            title: const Text('Export Successful 📦', style: TextStyle(color: AppColors.primary)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your wellness record has been securely exported as a JSON file.', style: TextStyle(color: AppColors.text, fontSize: AppFontSizes.sm)),
                const SizedBox(height: AppSpacing.sm),
                const Text('Path:', style: TextStyle(color: AppColors.textSecondary, fontSize: AppFontSizes.xs, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(AppSpacing.xs)),
                  child: Text(file.path, style: const TextStyle(color: AppColors.primaryLight, fontSize: 10, fontFamily: 'monospace')),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text('Tip: Use a File Explorer to copy this file to your PC for archival purposes.', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK', style: TextStyle(color: AppColors.primary)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: AppColors.danger));
      }
    }
  }

  Widget _buildRow({required String label, String? sub, required Widget right}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.surfaceElevated)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.text, fontSize: AppFontSizes.md)),
                if (sub != null) ...[
                  const SizedBox(height: 2),
                  Text(sub, style: const TextStyle(color: AppColors.textMuted, fontSize: AppFontSizes.xs)),
                ]
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          right,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final aiMode = ref.watch(aiModeProvider);
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
              child: Text('STATUS', style: TextStyle(color: AppColors.textSecondary, fontSize: AppFontSizes.xs, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
            Container(
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppSpacing.md)),
              child: Column(
                children: [
                  _buildRow(
                    label: 'Response Engine',
                    right: Text(
                        aiMode == AiMode.groq ? 'Groq API' : 'Offline templates',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: AppFontSizes.sm),
                      ),
                  ),
                ],
              ),
            ),

            // Preferences
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
              child: Text('PREFERENCES', style: TextStyle(color: AppColors.textSecondary, fontSize: AppFontSizes.xs, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
            Container(
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppSpacing.md)),
              child: Column(
                children: [
                  _buildRow(
                    label: 'Smart Notifications',
                    sub: 'Daily check-in, stress alerts',
                    right: Switch(value: _notifs, onChanged: _toggleNotifications, activeThumbColor: AppColors.primary),
                  ),
                  _buildRow(
                    label: 'Cloud Backup',
                    sub: 'Zero-knowledge encrypted sync',
                    right: Switch(value: _cloud, onChanged: _toggleCloud, activeThumbColor: AppColors.primary),
                  ),
                ],
              ),
            ),

            // Privacy
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
              child: Text('PRIVACY', style: TextStyle(color: AppColors.textSecondary, fontSize: AppFontSizes.xs, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
            Container(
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppSpacing.md)),
              child: Column(
                children: [
                  _buildRow(
                    label: 'Data Storage',
                    sub: 'AES-256 encrypted on this device',
                    right: const Text('Local only', style: TextStyle(color: AppColors.textSecondary, fontSize: AppFontSizes.sm)),
                  ),
                  _buildRow(
                    label: 'Chat Messages',
                    sub: 'Never uploaded to any server',
                    right: const Text('Private ✓', style: TextStyle(color: AppColors.success, fontSize: AppFontSizes.sm)),
                  ),
                ],
              ),
            ),

            // Danger & Data Control
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
              child: Text('DATA MANAGEMENT', style: TextStyle(color: AppColors.textSecondary, fontSize: AppFontSizes.xs, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
            Container(
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppSpacing.md)),
              child: Column(
                children: [
                  InkWell(
                    onTap: _handleExportData,
                    child: const Padding(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          Icon(Icons.download, color: AppColors.primary, size: 20),
                          SizedBox(width: AppSpacing.sm),
                          Text('Export My Data', style: TextStyle(color: AppColors.primary, fontSize: AppFontSizes.md)),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.background),
                  InkWell(
                    onTap: _handleClearChat,
                    child: const Padding(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          Icon(Icons.chat_bubble_outline, color: AppColors.warning, size: 20),
                          SizedBox(width: AppSpacing.sm),
                          Text('Clear Conversation History', style: TextStyle(color: AppColors.warning, fontSize: AppFontSizes.md)),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.background),
                  InkWell(
                    onTap: _handleFactoryReset,
                    child: const Padding(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          Icon(Icons.delete_forever, color: AppColors.danger, size: 20),
                          SizedBox(width: AppSpacing.sm),
                          Text('Factory Reset (Clear All Data)', style: TextStyle(color: AppColors.danger, fontSize: AppFontSizes.md, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),
            const Text(
              'Utkarsh V2 · Build 2.0.0 · GC15 PCCOE\nGuide: Dr. Sonali Patil',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.5),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}
