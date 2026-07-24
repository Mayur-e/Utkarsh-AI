import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/prism_card.dart';
import '../../../pipeline/layer9_response/llm_service.dart';
import '../../../services/auth/auth_service.dart';
import '../../../services/notifications/notification_service.dart';
import '../../../services/permissions/permission_service.dart';
import '../../../services/storage/database_service.dart';
import '../../../state/app_state.dart';
import '../../onboarding/screens/model_setup_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notifs = true;
  bool _cloud = false;
  bool _aiLearning = true;
  bool _offlineReady = false;
  PermissionStatus _micStatus = PermissionStatus.denied;
  PermissionStatus _notifStatus = PermissionStatus.denied;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final p = await databaseServiceProvider.getProfile(AuthService.instance.currentUser?.id);
    final perms = await PermissionService.instance.getStatus();

    final appDir = await getApplicationDocumentsDirectory();
    final onnxFile = File('${appDir.path}/models/burnout.onnx');
    final whisperEncoder = File('${appDir.path}/models/whisper/base-encoder.int8.onnx');
    final whisperDecoder = File('${appDir.path}/models/whisper/base-decoder.int8.onnx');
    final whisperTokens = File('${appDir.path}/models/whisper/base-tokens.txt');
    await LLMService.instance.checkDiskPresence();
    final bundled = await _bundledAssets();

    if (mounted) {
      setState(() {
        _notifs = p?['notifications_enabled'] == 1 || p?['notifications_enabled'] == true;
        _cloud = p?['online_ai_enabled'] == 1 || p?['online_ai_enabled'] == true;
        _aiLearning = p?['ai_learning_enabled'] == 1 || p?['ai_learning_enabled'] == true;

        final hasLlm = LLMService.instance.isDownloaded;
        final hasOnnx = (onnxFile.existsSync() && onnxFile.lengthSync() > 1024 * 1024) ||
            bundled.contains('assets/models/burnout.onnx');
        final hasWhisper = ((whisperEncoder.existsSync() && whisperEncoder.lengthSync() > 1024 * 1024) &&
                (whisperDecoder.existsSync() && whisperDecoder.lengthSync() > 1024 * 1024) &&
                (whisperTokens.existsSync() && whisperTokens.lengthSync() > 1024)) ||
            (bundled.contains('assets/models/whisper/base-encoder.int8.onnx') &&
                bundled.contains('assets/models/whisper/base-decoder.int8.onnx') &&
                bundled.contains('assets/models/whisper/base-tokens.txt'));
        _offlineReady = hasLlm && hasOnnx && hasWhisper;

        _micStatus = perms['microphone']!;
        _notifStatus = perms['notification']!;
      });
    }
  }

  Future<Set<String>> _bundledAssets() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      return manifest.listAssets().toSet();
    } catch (_) {
      return <String>{};
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
            content: const Text('Online AI mode requires an account. Please sign in first.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(context, '/login');
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('Sign In', style: TextStyle(color: AppColors.black)),
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
        content: const Text('This permanently deletes all chat messages. XP and assessments are kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              await databaseServiceProvider.clearChatHistory();
              ref.read(chatRefreshProvider.notifier).state++;
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Chat history cleared.'), backgroundColor: AppColors.success),
                );
              }
            },
            child: const Text('Delete Chats'),
          ),
        ],
      ),
    );
  }

  void _handleResetAiData() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Reset Offline AI Files', style: TextStyle(color: AppColors.error)),
        content: const Text('This will delete local AI models from device storage.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final base = await getApplicationDocumentsDirectory();
                final dir = Directory('${base.path}/models');
                if (await dir.exists()) {
                  await dir.delete(recursive: true);
                }
                LLMService.instance.dispose();
                await LLMService.instance.checkDiskPresence();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Offline AI data cleared.'), backgroundColor: AppColors.primary),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
                  );
                }
              }
            },
            child: const Text('Clear All AI Models'),
          ),
        ],
      ),
    );
  }

  void _handleFactoryReset() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Factory Reset'),
        content: const Text('This deletes all local data and progress. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              await databaseServiceProvider.factoryReset();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('App has been factory reset.'), backgroundColor: AppColors.error),
                );
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
            title: const Text('Export Successful', style: TextStyle(color: AppColors.primary)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your wellness record has been securely exported as JSON.', style: TextStyle(color: AppColors.text, fontSize: AppFontSizes.sm)),
                const SizedBox(height: AppSpacing.sm),
                const Text('Path:', style: TextStyle(color: AppColors.textSecondary, fontSize: AppFontSizes.xs, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(AppSpacing.xs)),
                  child: Text(file.path, style: const TextStyle(color: AppColors.primaryLight, fontSize: 10, fontFamily: 'monospace')),
                ),
              ],
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK', style: TextStyle(color: AppColors.primary)))],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  Widget _buildRow({required String label, String? sub, required Widget right}) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: AppFontSizes.md,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (sub != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    sub,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: AppFontSizes.xs,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          right,
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.md),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return PrismCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }

  Widget _tabChip(int index, String label, IconData icon) {
    final selected = _selectedTab == index;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.full),
          onTap: () => setState(() => _selectedTab = index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.22)
                  : AppColors.surfaceHighlight.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(AppRadius.full),
              border: Border.all(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.48)
                    : AppColors.surfaceElevated.withValues(alpha: 0.7),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: selected ? AppColors.primary : AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? AppColors.primary : AppColors.textSecondary,
                    fontSize: AppFontSizes.xs,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSummary() {
    return SizedBox(
      width: double.infinity,
      child: PrismCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          const Text(
            'Settings & Privacy Controls',
            style: TextStyle(
              color: AppColors.text,
              fontSize: AppFontSizes.lg,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _cloud ? AppColors.success : AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _cloud ? 'Online AI mode active' : 'Offline AI mode active',
                style: TextStyle(
                  color: _cloud ? AppColors.success : AppColors.primaryLight,
                  fontSize: AppFontSizes.sm,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _offlineReady ? 'Local model setup is ready.' : 'Offline model setup is incomplete.',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: AppFontSizes.sm),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _buildInfoPill(
                icon: Icons.mic_none_rounded,
                label: _micStatus.isGranted ? 'Mic Granted' : 'Mic Pending',
                color: _micStatus.isGranted ? AppColors.success : AppColors.warning,
              ),
              _buildInfoPill(
                icon: Icons.notifications_none_rounded,
                label: _notifs ? 'Alerts On' : 'Alerts Off',
                color: _notifs ? AppColors.primaryLight : AppColors.textMuted,
              ),
              _buildInfoPill(
                icon: Icons.smart_toy_outlined,
                label: _aiLearning ? 'AI Learning On' : 'AI Learning Off',
                color: _aiLearning ? AppColors.primary : AppColors.textSecondary,
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildInfoPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: AppFontSizes.xs,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionLabel('Status'),
        _card([
          InkWell(
            onTap: () => Navigator.pushNamed(context, '/profile'),
            child: _buildRow(
              label: 'My Utkarsh Identity',
              sub: 'View your profile and professional context',
              right: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ),
          ),
          _buildRow(
            label: 'AI Mode',
            sub: _cloud ? 'Online, cloud model with internet' : 'Offline, on-device private model',
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
                  activeThumbColor: AppColors.primary,
                  activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
        ]),
        _sectionLabel('Permissions'),
        _card([
          _buildRow(
            label: 'Microphone',
            sub: 'Used for conversational voice check-ins',
            right: TextButton(
              onPressed: _micStatus.isGranted ? null : _requestMic,
              child: Text(
                _micStatus.isGranted ? 'GRANTED' : 'REQUEST',
                style: TextStyle(color: _micStatus.isGranted ? AppColors.success : AppColors.primary, fontSize: 12),
              ),
            ),
          ),
          _buildRow(
            label: 'Notifications',
            sub: 'For smart check-ins and wellbeing alerts',
            right: TextButton(
              onPressed: _notifStatus.isGranted ? null : _requestNotifs,
              child: Text(
                _notifStatus.isGranted ? 'GRANTED' : 'REQUEST',
                style: TextStyle(color: _notifStatus.isGranted ? AppColors.success : AppColors.primary, fontSize: 12),
              ),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildAiTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionLabel('Offline AI'),
        _card([
          InkWell(
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
                      await _loadProfile();
                    },
                  ),
                ),
              );
            },
            child: _buildRow(
              label: 'Offline AI Setup',
              sub: _offlineReady ? 'All components installed and ready' : 'Local setup required before offline usage',
              right: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _offlineReady ? AppColors.success.withValues(alpha: 0.15) : AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      _offlineReady ? 'Ready' : 'Missing',
                      style: TextStyle(
                        color: _offlineReady ? AppColors.success : AppColors.warning,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right, color: AppColors.onSurfaceVariant, size: 18),
                ],
              ),
            ),
          ),
          if (_offlineReady)
            InkWell(
              borderRadius: BorderRadius.circular(AppSpacing.md),
              onTap: _handleResetAiData,
              child: _buildRow(
                label: 'Reset Offline AI Data',
                sub: 'Delete local models and start fresh',
                right: const Icon(Icons.refresh_rounded, color: AppColors.error, size: 20),
              ),
            ),
        ]),
        _sectionLabel('Preferences'),
        _card([
          _buildRow(
            label: 'Smart Notifications',
            sub: 'Daily check-in and stress alerts',
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
            sub: 'Allow AI to learn from context capsules',
            right: Switch(value: _aiLearning, onChanged: _toggleAiLearning, activeThumbColor: AppColors.primary),
          ),
        ]),
      ],
    );
  }

  Widget _buildPrivacyTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionLabel('Privacy'),
        _card([
          _buildRow(
            label: 'Data Storage',
            sub: 'AES-256 encrypted on this device',
            right: const Text('Local only', style: TextStyle(color: AppColors.textSecondary, fontSize: AppFontSizes.sm)),
          ),
          _buildRow(
            label: 'Chat Messages',
            sub: 'Never uploaded to any server',
            right: const Text('Private', style: TextStyle(color: AppColors.success, fontSize: AppFontSizes.sm)),
          ),
        ]),
      ],
    );
  }

  Widget _buildDataTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionLabel('Data Management'),
        _card([
          _buildActionTile(
            icon: Icons.download_rounded,
            label: 'Export My Data',
            color: AppColors.primary,
            onTap: _handleExportData,
          ),
          _buildActionTile(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Clear Conversation History',
            color: AppColors.warning,
            onTap: _handleClearChat,
          ),
          _buildActionTile(
            icon: Icons.delete_forever_rounded,
            label: 'Factory Reset (Clear All Data)',
            color: AppColors.error,
            onTap: _handleFactoryReset,
            emphasize: true,
          ),
          if (AuthService.instance.isLoggedIn) ...[
            _buildActionTile(
              icon: Icons.logout_rounded,
              label: 'Sign Out from Cloud',
              color: AppColors.textSecondary,
              onTap: _handleSignOut,
            ),
          ],
        ]),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool emphasize = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: color.withValues(alpha: 0.24)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: AppFontSizes.md,
                      fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: color.withValues(alpha: 0.9)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget bodyForTab;
    switch (_selectedTab) {
      case 0:
        bodyForTab = _buildAccountTab();
        break;
      case 1:
        bodyForTab = _buildAiTab();
        break;
      case 2:
        bodyForTab = _buildPrivacyTab();
        break;
      case 3:
        bodyForTab = _buildDataTab();
        break;
      default:
        bodyForTab = _buildAccountTab();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: Stack(
        children: [
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -70,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.05),
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 8, AppSpacing.md, 60),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeaderSummary(),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.68),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(color: AppColors.surfaceElevated),
                  ),
                  child: Row(
                    children: [
                      _tabChip(0, 'Account', Icons.person_outline),
                      _tabChip(1, 'AI', Icons.smart_toy_outlined),
                      _tabChip(2, 'Privacy', Icons.lock_outline),
                      _tabChip(3, 'Data', Icons.storage_outlined),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                bodyForTab,
                const SizedBox(height: AppSpacing.xxl),
                const Text(
                  'Utkarsh V2 | Build 2.0.0 | GC15 PCCOE\nGuide: Dr. Sonali Patil',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
