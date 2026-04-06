import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/storage/database_service.dart';
import '../../../services/auth/auth_service.dart';
import '../../../services/notifications/notification_service.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../services/permissions/permission_service.dart';
import '../../../state/app_state.dart';
import '../../onboarding/screens/model_setup_screen.dart';
import '../../../pipeline/layer9_response/llm_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notifs = true;
  bool _cloud = false;
  bool _aiLearning = true;
  bool _offlineReady = false;  // true when LLM model is on-device
  PermissionStatus _micStatus = PermissionStatus.denied;
  PermissionStatus _notifStatus = PermissionStatus.denied;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final p = await databaseServiceProvider.getProfile(AuthService.instance.currentUser?.id);
    final perms = await PermissionService.instance.getStatus();
    // Check if LLM model file is present on device
    final appDir = await getApplicationDocumentsDirectory();
    final llmFile = File('${appDir.path}/models/utkarsh_llm.gguf');
    final onnxFile = File('${appDir.path}/models/burnout.onnx');
    if (mounted) {
      setState(() {
        _notifs = p?['notifications_enabled'] == 1 || p?['notifications_enabled'] == true;
        _cloud = p?['online_ai_enabled'] == 1 || p?['online_ai_enabled'] == true;
        _aiLearning = p?['ai_learning_enabled'] == 1 || p?['ai_learning_enabled'] == true;
        _offlineReady = llmFile.existsSync() && onnxFile.existsSync();
        _micStatus = perms['microphone']!;
        _notifStatus = perms['notification']!;
      });
    }
  }

  Future<void> _toggleAiLearning(bool v) async {
    setState(() => _aiLearning = v);
    await databaseServiceProvider.updateProfile({'ai_learning_enabled': v ? 1 : 0}, AuthService.instance.currentUser?.id);
  }

  Future<void> _requestMic() async {
    final granted = await PermissionService.instance.requestMicrophone();
    if (mounted) {
      setState(() => _micStatus = granted ? PermissionStatus.granted : PermissionStatus.denied);
    }
  }

  Future<void> _requestNotifs() async {
    final granted = await PermissionService.instance.requestNotifications();
    if (mounted) {
      setState(() => _notifStatus = granted ? PermissionStatus.granted : PermissionStatus.denied);
    }
  }

  Future<void> _toggleNotifications(bool v) async {
    setState(() => _notifs = v);
    await databaseServiceProvider.updateProfile({'notifications_enabled': v ? 1 : 0}, AuthService.instance.currentUser?.id);
    if (v) {
      await notificationService.scheduleEveningCheckin();
    } else {
      await notificationService.cancelAll();
    }
  }

  Future<void> _toggleOnlineMode(bool v) async {
    if (v && !AuthService.instance.isLoggedIn) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('Sign In Required', style: TextStyle(color: AppColors.primary)),
            content: const Text('Online AI (Groq) mode requires an account. Please sign in first.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () { Navigator.pop(ctx); Navigator.pushNamed(context, '/login'); },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('Sign In', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
      return;
    }
    setState(() => _cloud = v);
    ref.read(isOnlineProvider.notifier).state = v;
    ref.read(aiModeProvider.notifier).state = v ? AiMode.groq : AiMode.offline;
    await databaseServiceProvider.updateProfile(
      {'online_ai_enabled': v ? 1 : 0},
      AuthService.instance.currentUser?.id,
    );
  }


  Future<void> _handleSignOut() async {
    await AuthService.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
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
              await databaseServiceProvider.factoryReset();
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
                  InkWell(
                    onTap: () => Navigator.pushNamed(context, '/profile'),
                    child: _buildRow(
                      label: 'My Utkarsh Identity',
                      sub: 'View your profile & professional context',
                      right: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.background),
                  // ── AI Mode Toggle ─────────────────────────────────────
                  _buildRow(
                    label: 'AI Mode',
                    sub: _cloud
                        ? 'Online · Groq Cloud API (faster, needs internet)'
                        : 'Offline · On-Device LLM (private, no internet)',
                    right: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _cloud ? 'Online' : 'Offline',
                          style: TextStyle(
                            color: _cloud ? AppColors.primary : AppColors.textSecondary,
                            fontSize: AppFontSizes.sm,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Switch(
                          value: _cloud,
                          onChanged: _toggleOnlineMode,
                          activeColor: AppColors.primary,
                          activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Offline AI Setup ────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
              child: Text('OFFLINE AI', style: TextStyle(color: AppColors.textSecondary, fontSize: AppFontSizes.xs, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
            Container(
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppSpacing.md)),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppSpacing.md),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ModelSetupScreen(
                        fromSettings: true,
                        onDone: () async {
                          Navigator.pop(context);
                          await LLMService.instance.reinitialize();
                          await _loadProfile(); // refresh the status badge
                        },
                      ),
                    ),
                  );
                },
                child: _buildRow(
                  label: 'Offline AI Setup',
                  sub: _offlineReady
                      ? 'All components installed · On-device LLM ready'
                      : 'Extra download required (~1.2 GB) · Not installed',
                  right: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _offlineReady
                              ? AppColors.success.withValues(alpha: 0.15)
                              : AppColors.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          _offlineReady ? 'Ready' : 'Not Installed',
                          style: TextStyle(
                            color: _offlineReady ? AppColors.success : AppColors.warning,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 18),
                    ],
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
              child: Text('SYSTEM PERMISSIONS', style: TextStyle(color: AppColors.textSecondary, fontSize: AppFontSizes.xs, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
            Container(
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppSpacing.md)),
              child: Column(
                children: [
                   _buildRow(
                    label: 'Microphone',
                    sub: 'Used for conversational voice check-ins',
                    right: TextButton(
                      onPressed: _micStatus.isGranted ? null : _requestMic,
                      child: Text(_micStatus.isGranted ? 'GRANTED' : 'REQUEST', 
                        style: TextStyle(color: _micStatus.isGranted ? AppColors.success : AppColors.primary, fontSize: 12)),
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.background),
                  _buildRow(
                    label: 'Notifications',
                    sub: 'For smart check-ins and wellbeing alerts',
                    right: TextButton(
                      onPressed: _notifStatus.isGranted ? null : _requestNotifs,
                      child: Text(_notifStatus.isGranted ? 'GRANTED' : 'REQUEST', 
                        style: TextStyle(color: _notifStatus.isGranted ? AppColors.success : AppColors.primary, fontSize: 12)),
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
                    right: Switch(
                      value: _cloud,
                      onChanged: (v) async {
                        setState(() => _cloud = v);
                        await databaseServiceProvider.updateProfile(
                          {'online_ai_enabled': v ? 1 : 0},
                          AuthService.instance.currentUser?.id,
                        );
                      },
                      activeThumbColor: AppColors.primary,
                    ),
                  ),
                  _buildRow(
                    label: 'AI Personalization',
                    sub: 'Enable AI to learn from context capsules',
                    right: Switch(value: _aiLearning, onChanged: _toggleAiLearning, activeThumbColor: AppColors.primary),
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
                  if (AuthService.instance.isLoggedIn) ...[
                    const Divider(height: 1, color: AppColors.background),
                    InkWell(
                      onTap: _handleSignOut,
                      child: const Padding(
                        padding: EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          children: [
                            Icon(Icons.logout, color: AppColors.textSecondary, size: 20),
                            SizedBox(width: AppSpacing.sm),
                            Text('Sign Out from Cloud', style: TextStyle(color: AppColors.textSecondary, fontSize: AppFontSizes.md)),
                          ],
                        ),
                      ),
                    ),
                  ],
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
