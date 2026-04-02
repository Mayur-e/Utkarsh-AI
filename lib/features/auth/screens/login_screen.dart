import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinput/pinput.dart';
import '../../../services/auth/auth_service.dart';
import '../../../core/theme/app_theme.dart';

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
  bool    _isRegister = false;

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
              const Text('🌿', style: TextStyle(fontSize: 56)),
              const SizedBox(height: AppSpacing.md),
              Text(
                _isRegister ? 'Create Account' : 'Welcome Back',
                style: const TextStyle(
                  color:      AppColors.text,
                  fontSize:   AppFontSizes.xxxl,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _isRegister
                    ? 'Your data is encrypted with your PIN.\nNot even we can read it.'
                    : 'Enter your credentials and PIN to\ndecrypt your data.',
                style: const TextStyle(
                  color:    AppColors.textSecondary,
                  fontSize: AppFontSizes.md,
                  height:   1.5,
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // Email field
              _buildTextField(
                controller:  _emailController,
                label:       'Email',
                hint:        'your@email.com',
                keyboard:    TextInputType.emailAddress,
              ),
              const SizedBox(height: AppSpacing.md),

              // Password field
              _buildTextField(
                controller: _passwordController,
                label:      'Password',
                hint:       '••••••••',
                obscure:    true,
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
                child: Pinput(
                  length:           6,
                  obscureText:      true,
                  keyboardType:     TextInputType.number,
                  onCompleted:      (pin) => setState(() => _pin = pin),
                  onChanged:        (pin) => setState(() => _pin = pin),
                  defaultPinTheme: PinTheme(
                    width:  52,
                    height: 52,
                    decoration: BoxDecoration(
                      color:        AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    textStyle: const TextStyle(
                      color:      AppColors.text,
                      fontSize:   AppFontSizes.xl,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  focusedPinTheme: PinTheme(
                    width:  52,
                    height: 52,
                    decoration: BoxDecoration(
                      color:  AppColors.surfaceElevated,
                      border: Border.all(color: AppColors.primary, width: 2),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    textStyle: const TextStyle(
                      color:      AppColors.text,
                      fontSize:   AppFontSizes.xl,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
                width: double.infinity,
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
                      : Text(
                          _isRegister ? 'Create Account' : 'Sign In',
                          style: const TextStyle(
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
                  onPressed: () => setState(() {
                    _isRegister = !_isRegister;
                    _error      = null;
                  }),
                  child: Text(
                    _isRegister
                         ? 'Already have an account? Sign In'
                        : "Don't have an account? Create one",
                    style: const TextStyle(
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboard = TextInputType.text,
    bool obscure = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color:      AppColors.text,
            fontSize:   AppFontSizes.sm,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller:   controller,
          keyboardType: keyboard,
          obscureText:  obscure,
          style:        const TextStyle(color: AppColors.text),
          decoration: InputDecoration(
            hintText:    hint,
            hintStyle:   const TextStyle(color: AppColors.textMuted),
            filled:      true,
            fillColor:   AppColors.surfaceElevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide:   BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide:   const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });

    final AuthResult result;

    if (_isRegister) {
      result = await AuthService.instance.register(
        email:    _emailController.text.trim(),
        password: _passwordController.text,
        pin:      _pin,
      );
    } else {
      result = await AuthService.instance.login(
        email:    _emailController.text.trim(),
        password: _passwordController.text,
        pin:      _pin,
      );
    }

    setState(() => _loading = false);

    if (result.success) {
      if (mounted) {
        // Navigate to main app
        Navigator.of(context).pushReplacementNamed('/home');
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
