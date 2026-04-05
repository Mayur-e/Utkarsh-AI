import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinput/pinput.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/user_profile.dart';
import '../../../services/storage/database_service.dart';
import '../../../services/auth/auth_service.dart';
import '../../../services/cloud/cloud_sync_service.dart';

class OnboardingFlow extends ConsumerStatefulWidget {
  final bool isNewUser;
  const OnboardingFlow({super.key, this.isNewUser = false});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  // Account setup fields (for new users)
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _pin = '';
  bool _isCreatingAccount = false;
  String? _authError;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // 1. Try Loading existing profile (for editing)
    final uid = AuthService.instance.currentUser?.id;
    if (uid == null) return; // Never pre-fill from 'local_user' for new accounts

    final existing = await DatabaseService.instance.getProfile(uid);
    if (existing != null) {
      final p = UserProfile.fromMap(existing);
      setState(() {
        _name = p.displayName ?? '';
        _age = p.age;
        _gender = p.gender;
        _language = p.preferredLanguage;
        _profession = p.profession;
        _universityName = p.collegeProfile?.universityName;
        _stream = p.collegeProfile?.stream;
        _yearOfStudy = p.collegeProfile?.yearOfStudy ?? 1;
        _upcomingEvents.clear();
        _upcomingEvents.addAll(p.collegeProfile?.upcomingEvents ?? []);
        _classNumber = p.schoolProfile?.classNumber ?? 10;
        _board = p.schoolProfile?.board ?? 'CBSE';
        _wakeHour = p.typicalWakeTime?.hour.toDouble() ?? 7.0;
        _sleepHour = p.typicalSleepTime?.hour.toDouble() ?? 23.0;
        _dailyHours = p.dailyStudyOrWorkHours;
        _activityLevel = p.activityLevel;
        _social = p.socialPreference;
        _stressTriggers.clear();
        _stressTriggers.addAll(p.stressTriggers);
        _responseStyle = p.responseStyle;
        _voiceEnabled = p.voiceEnabled;
        _ttsEnabled = p.ttsEnabled;
        _baselineStress = p.baselineStressLevel ?? 5;
        _baselineSleep = p.baselineSleepQuality ?? 3;
        _industry = p.professionalProfile?.industry;
        _role = p.professionalProfile?.role;
        _workStyle = p.professionalProfile?.workStyle ?? 'office';
        _emergencyContacts.clear();
        _emergencyContacts.addAll(p.emergencyContacts);
      });
      return;
    }

    // 2. Fallback: Pre-fill name from auth for new registration
    final user = AuthService.instance.currentUser;
    if (user != null && user.userMetadata != null) {
      setState(() {
        _name = user.userMetadata!['display_name'] ?? '';
      });
    }
  }

  // Collected data
  String  _name        = '';
  int     _age         = 20;
  String? _gender;
  PreferredLanguage _language = PreferredLanguage.english;
  Profession _profession = Profession.collegeStudent;

  // College specific
  String? _universityName;
  String? _stream;
  int _yearOfStudy = 1;
  final List<String> _upcomingEvents = [];

  // School specific
  int _classNumber = 10;
  String _board = 'CBSE';

  // Lifestyle
  double _wakeHour  = 7;
  double _sleepHour = 23;
  double _dailyHours = 6;
  ActivityLevel _activityLevel = ActivityLevel.light;
  SocialPreference _social = SocialPreference.ambivert;
  final List<StressTrigger> _stressTriggers = [];

  // Preferences
  ResponseStyle _responseStyle = ResponseStyle.warmSupportive;
  bool _voiceEnabled = false;
  bool _ttsEnabled   = true;

  // Baseline
  int _baselineStress = 5;
  int _baselineSleep  = 3;

  // Professional specific
  String? _industry;
  String? _role;
  String  _workStyle = 'office';
  final List<EmergencyContact> _emergencyContacts = [];

  List<Widget> get _pages {
    final List<Widget> pages = [];
    
    // Core signup pages (only for new users)
    if (widget.isNewUser) {
      pages.add(_WelcomePage(onNext: _nextPage));
      pages.add(_AccountSetupPage(
        emailController: _emailController,
        passwordController: _passwordController,
        pin: _pin,
        loading: _isCreatingAccount,
        error: _authError,
        onPinChanged: (v) => setState(() => _pin = v),
        onNext: _handleAccountCreation,
      ));
    }

    // Profile pages (for everyone)
    pages.addAll([
      _PersonalInfoPage(
        name: _name, age: _age, gender: _gender, language: _language,
        onChanged: (name, age, gender, lang) => setState(() {
          _name = name; _age = age; _gender = gender; _language = lang;
        }),
        onNext: _nextPage,
      ),
      _ProfessionPage(
        profession: _profession,
        yearOfStudy: _yearOfStudy, stream: _stream,
        university: _universityName,
        classNumber: _classNumber, board: _board,
        upcomingEvents: _upcomingEvents,
        industry: _industry, role: _role, workStyle: _workStyle,
        onChanged: (prof, year, stream, univ, cls, board, events, ind, rol, ws) => setState(() {
          _profession = prof;
          _yearOfStudy = year ?? _yearOfStudy;
          _stream = stream;
          _universityName = univ;
          _classNumber = cls ?? _classNumber;
          _board = board ?? _board;
          _upcomingEvents.clear();
          _upcomingEvents.addAll(events ?? []);
          _industry = ind;
          _role = rol;
          _workStyle = ws ?? _workStyle;
        }),
        onNext: _nextPage,
      ),
      _LifestylePage(
        wakeHour: _wakeHour, sleepHour: _sleepHour,
        dailyHours: _dailyHours, activityLevel: _activityLevel,
        social: _social, stressTriggers: _stressTriggers,
        onChanged: (wake, sleep, hours, activity, social, triggers) => setState(() {
          _wakeHour = wake; _sleepHour = sleep; _dailyHours = hours;
          _activityLevel = activity; _social = social;
          _stressTriggers.clear(); _stressTriggers.addAll(triggers);
        }),
        onNext: _nextPage,
      ),
      _PreferencesPage(
        responseStyle: _responseStyle,
        voiceEnabled: _voiceEnabled, ttsEnabled: _ttsEnabled,
        onChanged: (style, voice, tts) => setState(() {
          _responseStyle = style; _voiceEnabled = voice; _ttsEnabled = tts;
        }),
        onNext: _nextPage,
      ),
      _BaselinePage(
        stress: _baselineStress, sleep: _baselineSleep,
        onChanged: (s, sl) => setState(() { _baselineStress = s; _baselineSleep = sl; }),
        onNext: _nextPage,
      ),
      _EmergencyContactsPage(
        contacts: _emergencyContacts,
        onChanged: (contacts) => setState(() {
          _emergencyContacts.clear();
          _emergencyContacts.addAll(contacts);
        }),
        onNext: _complete,
      ),
    ]);
    
    return pages;
  }

  Future<void> _handleAccountCreation() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty || _pin.length < 6) {
      setState(() => _authError = 'Please fill all fields and set a 6-digit PIN');
      return;
    }

    setState(() { _isCreatingAccount = true; _authError = null; });
    final result = await AuthService.instance.register(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      pin: _pin,
      displayName: '', // Name will be collected in next step
    );
    setState(() { _isCreatingAccount = false; });
    
    if (result.success) {
      _nextPage();
    } else {
      setState(() => _authError = result.error);
    }
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentPage++);
    }
  }

  Future<void> _complete() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final profile = UserProfile(
      id:                   AuthService.instance.currentUser?.id ?? 'local_user',
      displayName:          _name,
      age:                  _age,
      gender:               _gender,
      preferredLanguage:    _language,
      profession:           _profession,
      collegeProfile: _profession == Profession.collegeStudent
          ? CollegeProfile(
              universityName: _universityName,
              stream:         _stream,
              yearOfStudy:    _yearOfStudy,
              upcomingEvents: _upcomingEvents,
            )
          : null,
      schoolProfile: _profession == Profession.schoolStudent
          ? SchoolProfile(classNumber: _classNumber, board: _board)
          : null,
      professionalProfile: _profession == Profession.workingProfessional
          ? ProfessionalProfile(industry: _industry, role: _role, workStyle: _workStyle)
          : null,
      typicalWakeTime:       TimeOfDay(hour: _wakeHour.toInt(), minute: 0),
      typicalSleepTime:      TimeOfDay(hour: _sleepHour.toInt(), minute: 0),
      dailyStudyOrWorkHours: _dailyHours,
      activityLevel:         _activityLevel,
      socialPreference:      _social,
      stressTriggers:        _stressTriggers,
      responseStyle:         _responseStyle,
      voiceEnabled:          _voiceEnabled,
      ttsEnabled:            _ttsEnabled,
      baselineStressLevel:   _baselineStress,
      baselineSleepQuality:  _baselineSleep,
      onboardingDone:        true,
      aiLearningEnabled:     true,
      emergencyContacts:     _emergencyContacts,
      createdAt:             now,
      lastActiveAt:          now,
    );

    await DatabaseService.instance.saveProfile(profile.toMap(), profile.id);

    // SYNC: Immediately sync the verified profile to the cloud
    CloudSyncService.instance.syncAll();

    if (mounted)        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: LinearProgressIndicator(
                value:            (_currentPage + 1) / _pages.length,
                backgroundColor:  AppColors.surfaceElevated,
                valueColor:       const AlwaysStoppedAnimation(AppColors.primary),
                borderRadius:     BorderRadius.circular(AppRadius.full),
              ),
            ),
            Text(
              'Step ${_currentPage + 1} of ${_pages.length}',
              style: const TextStyle(
                color:    AppColors.textMuted,
                fontSize: AppFontSizes.xs,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: PageView(
                controller:          _controller,
                physics:             const NeverScrollableScrollPhysics(),
                onPageChanged:       (i) => setState(() => _currentPage = i),
                children:            _pages,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Welcome Interior ────────────────────────────────────────────────────────

class _WelcomePage extends StatelessWidget {
  final VoidCallback onNext;
  const _WelcomePage({required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🌿', style: TextStyle(fontSize: 80)),
          const SizedBox(height: AppSpacing.xl),
          const Text(
            'Welcome to Utkarsh',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Your space for growth, stability, and peaceful productivity. Let\'s set up your personalized profile.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Get Started', style: TextStyle(color: Colors.white, fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Personal Info Interior ──────────────────────────────────────────────────

class _PersonalInfoPage extends StatelessWidget {
  final String name;
  final int age;
  final String? gender;
  final PreferredLanguage language;
  final Function(String, int, String?, PreferredLanguage) onChanged;
  final VoidCallback onNext;

  const _PersonalInfoPage({
    required this.name, required this.age, required this.gender,
    required this.language, required this.onChanged, required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('👤', style: TextStyle(fontSize: 48)),
          const SizedBox(height: AppSpacing.md),
          const Text('Tell us about yourself', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.xl),
          
          TextField(
            onChanged: (v) => onChanged(v, age, gender, language),
            decoration: const InputDecoration(
              labelText: 'Display Name',
              hintText: 'What should we call you?',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          
          const Text('Age', style: TextStyle(fontWeight: FontWeight.w600)),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: age.toDouble(),
                  min: 10, max: 80,
                  onChanged: (v) => onChanged(name, v.toInt(), gender, language),
                ),
              ),
              Text('$age', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          const Text('Preferred Language', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: PreferredLanguage.values.map((l) {
              final isSelected = language == l;
              return ChoiceChip(
                label: Text(l.name.toUpperCase()),
                selected: isSelected,
                onSelected: (s) => onChanged(name, age, gender, l),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.xxl),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: name.trim().isEmpty ? null : onNext,
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Profession Interior ─────────────────────────────────────────────────────

class _ProfessionPage extends StatelessWidget {
  final Profession profession;
  final int yearOfStudy;
  final String? stream;
  final String? university;
  final int classNumber;
  final String board;
  final List<String> upcomingEvents;
  final String? industry;
  final String? role;
  final String workStyle;
  final Function(Profession, int?, String?, String?, int?, String?, List<String>?, String?, String?, String?) onChanged;
  final VoidCallback onNext;

  const _ProfessionPage({
    required this.profession, required this.yearOfStudy, required this.stream,
    required this.university, required this.classNumber, required this.board,
    required this.upcomingEvents, required this.industry, required this.role,
    required this.workStyle, required this.onChanged, required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🎓', style: TextStyle(fontSize: 48)),
          const SizedBox(height: AppSpacing.md),
          const Text('Your current path', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.xl),

          ...Profession.values.map((p) => ListTile(
            title: Text(p.name.replaceAll(RegExp(r'(?=[A-Z])'), ' ').capitalize()),
            leading: Radio<Profession>(
              // ignore: deprecated_member_use
              value: p, groupValue: profession,
              // ignore: deprecated_member_use
              onChanged: (v) => onChanged(v!, null, null, null, null, null, null, null, null, null),
            ),
            onTap: () => onChanged(p, null, null, null, null, null, null, null, null, null),
          )),

          if (profession == Profession.collegeStudent) ...[
            const Divider(),
            TextField(
              onChanged: (v) => onChanged(profession, yearOfStudy, stream, v, classNumber, board, upcomingEvents, industry, role, workStyle),
              decoration: const InputDecoration(labelText: 'University Name (Optional)'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              onChanged: (v) => onChanged(profession, yearOfStudy, v, university, classNumber, board, upcomingEvents, industry, role, workStyle),
              decoration: const InputDecoration(labelText: 'Stream (e.g. Computer Science)'),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text('Year of Study'),
            Row(
              children: [1, 2, 3, 4, 5].map((y) => Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text('$y'),
                  selected: yearOfStudy == y,
                  onSelected: (s) => onChanged(profession, y, stream, university, classNumber, board, upcomingEvents, industry, role, workStyle),
                ),
              )).toList(),
            ),
          ],
          
          if (profession == Profession.schoolStudent) ...[
            const Divider(),
            const Text('Class'),
            DropdownButton<int>(
              value: classNumber,
              items: [6, 7, 8, 9, 10, 11, 12].map((c) => DropdownMenuItem(value: c, child: Text('Class $c'))).toList(),
              onChanged: (v) => onChanged(profession, yearOfStudy, stream, university, v, board, upcomingEvents, industry, role, workStyle),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text('Board'),
            Row(
              children: ['CBSE', 'ICSE', 'State', 'IB'].map((b) => Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(b),
                  selected: board == b,
                  onSelected: (s) => onChanged(profession, yearOfStudy, stream, university, classNumber, b, upcomingEvents, industry, role, workStyle),
                ),
              )).toList(),
            ),
          ],

          if (profession == Profession.workingProfessional) ...[
            const Divider(),
            TextFormField(
              initialValue: industry,
              onChanged: (v) => onChanged(profession, yearOfStudy, stream, university, classNumber, board, upcomingEvents, v, role, workStyle),
              decoration: const InputDecoration(labelText: 'Industry (e.g. IT, Healthcare)'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              initialValue: role,
              onChanged: (v) => onChanged(profession, yearOfStudy, stream, university, classNumber, board, upcomingEvents, industry, v, workStyle),
              decoration: const InputDecoration(labelText: 'Role (e.g. Developer, HR)'),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text('Work Style'),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: 8,
              children: ['remote', 'office', 'hybrid'].map((w) => ChoiceChip(
                label: Text(w.capitalize()),
                selected: workStyle == w,
                onSelected: (selected) {
                  if (selected) {
                    onChanged(profession, yearOfStudy, stream, university, classNumber, board, upcomingEvents, industry, role, w);
                  }
                },
              )).toList(),
            ),
          ],

          const SizedBox(height: AppSpacing.xxl),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: onNext, child: const Text('Continue')),
          ),
        ],
      ),
    );
  }
}

// ── Lifestyle Interior ──────────────────────────────────────────────────────

class _LifestylePage extends StatelessWidget {
  final double wakeHour;
  final double sleepHour;
  final double dailyHours;
  final ActivityLevel activityLevel;
  final SocialPreference social;
  final List<StressTrigger> stressTriggers;
  final Function(double, double, double, ActivityLevel, SocialPreference, List<StressTrigger>) onChanged;
  final VoidCallback onNext;

  const _LifestylePage({
    required this.wakeHour, required this.sleepHour, required this.dailyHours,
    required this.activityLevel, required this.social, required this.stressTriggers,
    required this.onChanged, required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🏃', style: TextStyle(fontSize: 48)),
          const SizedBox(height: AppSpacing.md),
          const Text('Lifestyle & Habits', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.xl),

          Text('Target Study/Work Hours: ${dailyHours.toInt()}h'),
          Slider(
            value: dailyHours, min: 1, max: 16,
            onChanged: (v) => onChanged(wakeHour, sleepHour, v, activityLevel, social, stressTriggers),
          ),
          
          const Text('Social Preference'),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: SocialPreference.values.map((s) => ChoiceChip(
              label: Text(s.name.capitalize()),
              selected: social == s,
              onSelected: (sel) => onChanged(wakeHour, sleepHour, dailyHours, activityLevel, s, stressTriggers),
            )).toList(),
          ),
          const SizedBox(height: AppSpacing.md),
          
          const Text('Stress Triggers'),
          Wrap(
            spacing: 8,
            children: StressTrigger.values.map((t) {
              final isSelected = stressTriggers.contains(t);
              return FilterChip(
                label: Text(t.name.capitalize()),
                selected: isSelected,
                onSelected: (sel) {
                  final list = List<StressTrigger>.from(stressTriggers);
                  if (sel) {
                    list.add(t);
                  } else {
                    list.remove(t);
                  }
                  onChanged(wakeHour, sleepHour, dailyHours, activityLevel, social, list);
                },
              );
            }).toList(),
          ),

          const SizedBox(height: AppSpacing.xxl),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: onNext, child: const Text('Continue')),
          ),
        ],
      ),
    );
  }
}

// ── Preferences Interior ─────────────────────────────────────────────────────

class _PreferencesPage extends StatelessWidget {
  final ResponseStyle responseStyle;
  final bool voiceEnabled;
  final bool ttsEnabled;
  final Function(ResponseStyle, bool, bool) onChanged;
  final VoidCallback onNext;

  const _PreferencesPage({
    required this.responseStyle, required this.voiceEnabled, required this.ttsEnabled,
    required this.onChanged, required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🤖', style: TextStyle(fontSize: 48)),
          const SizedBox(height: AppSpacing.md),
          const Text('AI Preferences', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.xl),

          const Text('How should Utkarsh talk to you?'),
          const SizedBox(height: AppSpacing.sm),
          ...ResponseStyle.values.map((s) => RadioListTile<ResponseStyle>(
            title: Text(s.name.replaceAll(RegExp(r'(?=[A-Z])'), ' ').capitalize()),
            // ignore: deprecated_member_use
            value: s, groupValue: responseStyle,
            // ignore: deprecated_member_use
            onChanged: (v) => onChanged(v!, voiceEnabled, ttsEnabled),
          )),
          
          const Divider(),
          SwitchListTile(
            title: const Text('Voice Input Enabled'),
            value: voiceEnabled,
            onChanged: (v) => onChanged(responseStyle, v, ttsEnabled),
          ),
          SwitchListTile(
            title: const Text('Speech Output (TTS)'),
            value: ttsEnabled,
            onChanged: (v) => onChanged(responseStyle, voiceEnabled, v),
          ),

          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: onNext, child: const Text('Continue')),
          ),
        ],
      ),
    );
  }
}

// ── Baseline Interior ────────────────────────────────────────────────────────

class _BaselinePage extends StatelessWidget {
  final int stress;
  final int sleep;
  final Function(int, int) onChanged;
  final VoidCallback onNext;

  const _BaselinePage({required this.stress, required this.sleep, required this.onChanged, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🧘', style: TextStyle(fontSize: 48)),
          const SizedBox(height: AppSpacing.md),
          const Text('Baseline Wellbeing', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.xl),

          const Text('Current Stress Level (1-10)'),
          Slider(
            value: stress.toDouble(), min: 1, max: 10,
            divisions: 9,
            label: '$stress',
            onChanged: (v) => onChanged(v.toInt(), sleep),
          ),
          
          const Text('Recent Sleep Quality (1-5)'),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) => IconButton(
              icon: Icon(i < sleep ? Icons.star : Icons.star_border, color: Colors.amber),
              onPressed: () => onChanged(stress, i + 1),
            )),
          ),

          const Spacer(),
          const Text(
            'This data is stored only on your device and helps Utkarsh track your growth over time.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: onNext, child: const Text('Complete Setup')),
          ),
        ],
      ),
    );
  }
}

class _EmergencyContactsPage extends StatefulWidget {
  final List<EmergencyContact> contacts;
  final Function(List<EmergencyContact>) onChanged;
  final VoidCallback onNext;

  const _EmergencyContactsPage({required this.contacts, required this.onChanged, required this.onNext});

  @override
  State<_EmergencyContactsPage> createState() => _EmergencyContactsPageState();
}

class _EmergencyContactsPageState extends State<_EmergencyContactsPage> {
  final _nameController = TextEditingController();
  final _numberController = TextEditingController();
  String? _relation;

  void _add() {
    if (_nameController.text.isNotEmpty && _numberController.text.isNotEmpty) {
      final newList = List<EmergencyContact>.from(widget.contacts);
      newList.add(EmergencyContact(
        name: _nameController.text,
        number: _numberController.text,
        relation: _relation,
      ));
      widget.onChanged(newList);
      _nameController.clear();
      _numberController.clear();
      _relation = null;
      setState(() {});
    }
  }

  void _remove(int index) {
    final newList = List<EmergencyContact>.from(widget.contacts);
    newList.removeAt(index);
    widget.onChanged(newList);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🆘', style: TextStyle(fontSize: 48)),
          const SizedBox(height: AppSpacing.md),
          const Text('Safety First', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Who should we help you contact in case of a crisis? Your safety is our priority.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Contact Name', hintText: 'e.g. Mom, Best Friend'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _numberController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone Number', hintText: 'Include country code'),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: _relation,
            decoration: const InputDecoration(labelText: 'Relationship (Optional)'),
            items: ['Family', 'Friend', 'Professional', 'Other'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
            onChanged: (v) => setState(() => _relation = v),
          ),
          const SizedBox(height: AppSpacing.lg),
          
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: const Text('Add Contact'),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          
          if (widget.contacts.isNotEmpty) ...[
            const Text('Added Contacts', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.sm),
            ...widget.contacts.asMap().entries.map((entry) => Card(
              child: ListTile(
                title: Text(entry.value.name),
                subtitle: Text('${entry.value.number}${entry.value.relation != null ? " (${entry.value.relation})" : ""}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                  onPressed: () => _remove(entry.key),
                ),
              ),
            )),
          ],

          const SizedBox(height: AppSpacing.xxl),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.onNext,
              child: Text(widget.contacts.isEmpty ? 'Skip & Finish' : 'Complete Setup'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Account Setup Interior ──────────────────────────────────────────────────

class _AccountSetupPage extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final String pin;
  final bool loading;
  final String? error;
  final ValueChanged<String> onPinChanged;
  final VoidCallback onNext;

  const _AccountSetupPage({
    required this.emailController,
    required this.passwordController,
    required this.pin,
    required this.loading,
    this.error,
    required this.onPinChanged,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🔐', style: TextStyle(fontSize: 48)),
          const SizedBox(height: AppSpacing.md),
          const Text('Create your account', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.sm),
          const Text('Your data is encrypted with your PIN. Only you can access it.', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.xl),

          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email', hintText: 'your@email.com'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password', hintText: '••••••••'),
          ),
          const SizedBox(height: AppSpacing.xl),

          const Text('6-Digit Security PIN', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.sm),
          const Text('This PIN is used to encrypt your sensitive health and personal data.', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Pinput(
              length: 6,
              obscureText: true,
              onChanged: onPinChanged,
              defaultPinTheme: PinTheme(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          if (error != null) ...[
            Text(error!, style: const TextStyle(color: AppColors.danger, fontSize: 14)),
            const SizedBox(height: AppSpacing.md),
          ],

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: loading ? null : onNext,
              child: loading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Create Account & Continue'),
            ),
          ),
        ],
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
