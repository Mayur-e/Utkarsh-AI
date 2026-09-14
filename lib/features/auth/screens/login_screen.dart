import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/prism_card.dart';
import '../../../core/widgets/prism_inputs.dart';

import '../../../services/auth/auth_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/debug/seed_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  String  _pin = '';
  bool    _loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xxl),

              // Header
              ClipOval(
                child: Image.asset('assets/logo.png', width: 80, height: 80, fit: BoxFit.cover),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Welcome Back',
                style: TextStyle(
                  color:      AppColors.text,
                  fontSize:   AppFontSizes.xxxl,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Enter your credentials and PIN to\ndecrypt your data.',
                style: TextStyle(
                  color:    AppColors.textSecondary,
                  fontSize: AppFontSizes.md,
                  height:   1.5,
                ),
              ),

              const SizedBox(height: AppSpacing.xl),


              // Email field
              PrismTextField(
                controller:  _emailController,
                label:       'Email',
                keyboardType:    TextInputType.emailAddress,
              ),
              const SizedBox(height: AppSpacing.md),

              // Password field
              PrismTextField(
                controller: _passwordController,
                label:      'Password',
                obscureText:    true,
              ),
              const SizedBox(height: AppSpacing.xl),

              // PIN input
              const Text(
                '6-Digit Security PIN',
                style: TextStyle(
                  color:      AppColors.text,
                  fontSize:   AppFontSizes.md,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'This PIN encrypts your data locally.\nIt is never sent to any server.',
                style: TextStyle(
                  color:    AppColors.textMuted,
                  fontSize: AppFontSizes.xs,
                  height:   1.5,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              Center(
                child: PrismPinField(
                  length: 6,
                  controller: TextEditingController(text: _pin),
                  onChanged: (pin) => setState(() => _pin = pin),
                  onCompleted: () {},
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // Error message
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color:        AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border:       Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color:    AppColors.danger,
                            fontSize: AppFontSizes.sm,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Submit button
              SizedBox(
                
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading || _pin.length < 6 ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    disabledBackgroundColor: AppColors.surfaceElevated,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                            color: AppColors.white, strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize:   AppFontSizes.md,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Toggle register/login
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pushNamed('/signup'),
                  child: const Text(
                    "Don't have an account? Create one",
                    style: TextStyle(
                      color:    AppColors.primaryLight,
                      fontSize: AppFontSizes.sm,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Security note
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color:        AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('🔒', style: TextStyle(fontSize: 16)),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Your PIN is used to encrypt your data on this device. '
                        'It is never transmitted to any server. '
                        'If you forget your PIN, your encrypted data cannot be recovered.',
                        style: TextStyle(
                          color:    AppColors.textMuted,
                          fontSize: AppFontSizes.xs,
                          height:   1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // Developer Seed Button (Temporary for testing)
              Center(
                child: TextButton.icon(
                  onPressed: _seedTestUser,
                  icon: const Icon(Icons.build_rounded, size: 16, color: AppColors.primaryLight),
                  label: const Text(
                    '🔧 SEED MAYURESH TEST DATA',
                    style: TextStyle(
                      color: AppColors.primaryLight,
                      fontSize: AppFontSizes.xs,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _seedTestUser() async {
    setState(() => _loading = true);
    
    // 1. Set credentials
    _emailController.text = 'mayuresh@gmail.com';
    _passwordController.text = 'mayur123';
    
    // 2. Try Login first
    var result = await AuthService.instance.login(
      email: 'mayuresh@gmail.com',
      password: 'mayur123',
      pin: '123456',
    );
    
    // 3. Handle Zombie State or New User
    if (!result.success) {
      if (result.error!.contains('PGRST116') || result.error!.contains('0 rows')) {
        debugPrint('[Seed] 🧟 Zombie state detected (Auth exists, Meta missing). Repairing...');
        // We need to re-register the metadata for this existing user
        // Usually impossible without deleting from Auth, but we can try to force it
        // Or tell the user to use the SQL fix.
        result = await AuthService.instance.register(
          email: 'mayuresh@gmail.com',
          password: 'mayur123',
          pin: '123456',
        );
      } else {
        // Standard registration for new users
        result = await AuthService.instance.register(
          email: 'mayuresh@gmail.com',
          password: 'mayur123',
          pin: '123456',
        );
      }
    }

    if (result.success) {
      // 4. Seed history
      await SeedService.seedMayureshAccount();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Mayuresh account seeded & synced to cloud!')),
        );
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      }
    } else {
      setState(() => _error = "Seed failed: ${result.error}");
    }
    
    setState(() => _loading = false);
  }


  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });

    final result = await AuthService.instance.login(
      email:    _emailController.text.trim(),
      password: _passwordController.text,
      pin:      _pin,
    );

    setState(() => _loading = false);

    if (result.success) {
      if (mounted) {
        // Navigate to main app and clear stack
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      }
    } else {
      String userError = result.error ?? 'An unknown error occurred';
      if (userError.contains('SocketException') || 
          userError.contains('host lookup') || 
          userError.contains('ConnectException')) {
        userError = "Device offline, can't login. Please check your connection.";
      }
      setState(() => _error = userError);
    }
  }
}
