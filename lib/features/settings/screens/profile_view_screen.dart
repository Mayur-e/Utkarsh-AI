import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/user_profile.dart';
import '../../../services/storage/database_service.dart';
import '../../../services/auth/auth_service.dart';

class ProfileViewScreen extends ConsumerStatefulWidget {
  const ProfileViewScreen({super.key});

  @override
  ConsumerState<ProfileViewScreen> createState() => _ProfileViewScreenState();
}

class _ProfileViewScreenState extends ConsumerState<ProfileViewScreen> {
  UserProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = AuthService.instance.currentUser?.id;
    final map = await DatabaseService.instance.getProfile(uid);
    if (mounted && map != null) {
      setState(() {
        _profile = UserProfile.fromMap(map);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_profile == null) return const Scaffold(body: Center(child: Text('No profile found.')));

    final p = _profile!;
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Identity'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).pushReplacementNamed('/onboarding'),
          ),
        ],
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
                color: AppColors.primary.withValues(alpha: 0.11),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -80,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.06),
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
            // Header
            Center(
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.primaryLight,
                    child: Text('👤', style: TextStyle(fontSize: 40)),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    p.displayName ?? 'Utkarsh User',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.text),
                  ),
                  Text(
                    'Level: ${p.currentLevel}',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Content
            _buildSection(
              title: 'BASIC INFO',
              items: [
                _buildItem('Age', '${p.age} years'),
                _buildItem('Language', p.preferredLanguage.name.toUpperCase()),
                _buildItem('Profession', p.profession.name.replaceAll(RegExp(r'(?=[A-Z])'), ' ')),
              ],
            ),

            if (p.profession == Profession.collegeStudent && p.collegeProfile != null)
               _buildSection(
                title: 'ACADEMIC PROFILE',
                items: [
                  _buildItem('University', p.collegeProfile?.universityName ?? 'Not specified'),
                  _buildItem('Stream', p.collegeProfile?.stream ?? 'Not specified'),
                  _buildItem('Year', '${p.collegeProfile?.yearOfStudy}th Year'),
                ],
              ),

             if (p.profession == Profession.workingProfessional && p.professionalProfile != null)
               _buildSection(
                title: 'PROFESSIONAL PROFILE',
                items: [
                  _buildItem('Industry', p.professionalProfile?.industry ?? 'Not specified'),
                  _buildItem('Role', p.professionalProfile?.role ?? 'Not specified'),
                  _buildItem('Work Style', p.professionalProfile?.workStyle.capitalize() ?? 'Not specified'),
                ],
              ),

            _buildSection(
              title: 'EMERGENCY CONTACTS',
              items: p.emergencyContacts.isEmpty 
                ? [const Padding(padding: EdgeInsets.all(16), child: Text('No contacts added', style: TextStyle(color: AppColors.textMuted)))]
                : p.emergencyContacts.map((c) => _buildContactItem(c)).toList(),
            ),

            _buildSection(
              title: 'LIFESTYLE',
              items: [
                _buildItem('Sleep Schedule', '${p.wakeTimeHour}:00 - ${p.sleepTimeHour}:00'),
                _buildItem('Target Hours', '${p.dailyStudyOrWorkHours.toInt()}h daily'),
                _buildItem('Social Style', p.socialPreference.name.capitalize()),
              ],
            ),
            
            const SizedBox(height: AppSpacing.xxl),
            const Text(
              'This profile updates AI interactions to be more relevant to your life stage and current goals.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> items}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8, top: 24),
          child: Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ),
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            gradient: LinearGradient(
              colors: [
                AppColors.surface.withValues(alpha: 0.96),
                AppColors.surfaceElevated.withValues(alpha: 0.86),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.textSecondary))),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem(EmergencyContact c) {
    return ListTile(
      title: Text(c.name, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600)),
      subtitle: Text(c.number, style: const TextStyle(color: AppColors.textSecondary)),
      trailing: Text(c.relation ?? '', style: const TextStyle(color: AppColors.primary, fontSize: 12)),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
