import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/user_profile.dart';
import '../../../services/storage/database_service.dart';

class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  final PageController _controller = PageController();
  int _currentPage = 0;

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

  List<Widget> get _pages => [
    _WelcomePage(onNext: _nextPage),
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
      onChanged: (prof, year, stream, univ, cls, board, events) => setState(() {
        _profession = prof;
        _yearOfStudy = year ?? _yearOfStudy;
        _stream = stream;
        _universityName = univ;
        _classNumber = cls ?? _classNumber;
        _board = board ?? _board;
        _upcomingEvents.clear();
        _upcomingEvents.addAll(events);
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
      onNext: _complete,
    ),
  ];

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
      id:                   'local_user',
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
      createdAt:             now,
      lastActiveAt:          now,
    );

    await DatabaseService.instance.saveProfile(profile.toMap());

    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
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
  final Function(Profession, int?, String?, String?, int?, String?, List<String>) onChanged;
  final VoidCallback onNext;

  const _ProfessionPage({
    required this.profession, required this.yearOfStudy, required this.stream,
    required this.university, required this.classNumber, required this.board,
    required this.upcomingEvents, required this.onChanged, required this.onNext,
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
              value: p, groupValue: profession,
              onChanged: (v) => onChanged(v!, null, null, null, null, null, []),
            ),
            onTap: () => onChanged(p, null, null, null, null, null, []),
          )),

          if (profession == Profession.collegeStudent) ...[
            const Divider(),
            TextField(
              onChanged: (v) => onChanged(profession, yearOfStudy, stream, v, classNumber, board, upcomingEvents),
              decoration: const InputDecoration(labelText: 'University Name (Optional)'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              onChanged: (v) => onChanged(profession, yearOfStudy, v, university, classNumber, board, upcomingEvents),
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
                  onSelected: (s) => onChanged(profession, y, stream, university, classNumber, board, upcomingEvents),
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
              onChanged: (v) => onChanged(profession, yearOfStudy, stream, university, v, board, upcomingEvents),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text('Board'),
            Row(
              children: ['CBSE', 'ICSE', 'State', 'IB'].map((b) => Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(b),
                  selected: board == b,
                  onSelected: (s) => onChanged(profession, yearOfStudy, stream, university, classNumber, b, upcomingEvents),
                ),
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
                  if (sel) list.add(t); else list.remove(t);
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
            value: s, groupValue: responseStyle,
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

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
