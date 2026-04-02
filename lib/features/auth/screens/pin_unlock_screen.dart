import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import '../../../services/auth/auth_service.dart';
import '../../../core/theme/app_theme.dart';

/// Shown when the app relaunches and user is already authenticated
/// in Supabase but the encryption key needs to be re-derived
/// (key is cleared from memory when app closes).
class PinUnlockScreen extends StatefulWidget {
  const PinUnlockScreen({super.key});

  @override
  State<PinUnlockScreen> createState() => _PinUnlockScreenState();
}

class _PinUnlockScreenState extends State<PinUnlockScreen> {
  bool    _loading = false;
  String? _error;
  int     _attempts = 0;

  Future<void> _onPinComplete(String pin) async {
    setState(() { _loading = true; _error = null; });

    final unlocked = await AuthService.instance.unlockManual(pin);

    setState(() => _loading = false);

    if (unlocked) {
      if (mounted) Navigator.of(context).pushReplacementNamed('/home');
    } else {
      _attempts++;
      setState(() {
        _error = _attempts >= 3
            ? 'Incorrect PIN ($_attempts attempts). Your data is protected.'
            : 'Incorrect PIN. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🔐', style: TextStyle(fontSize: 64)),
                const SizedBox(height: AppSpacing.lg),
                const Text(
                  'Enter your PIN',
                  style: TextStyle(
                    color:      AppColors.text,
                    fontSize:   AppFontSizes.xxl,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Your PIN is needed to decrypt your data',
                  style: TextStyle(
                    color:    AppColors.textSecondary,
                    fontSize: AppFontSizes.md,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xxl),

                if (_loading)
                  const CircularProgressIndicator(color: AppColors.primary)
                else
                  Pinput(
                    length:       6,
                    obscureText:  true,
                    autofocus:    true,
                    keyboardType: TextInputType.number,
                    onCompleted:  _onPinComplete,
                    defaultPinTheme: PinTheme(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      textStyle: const TextStyle(
                        color: AppColors.text,
                        fontSize: AppFontSizes.xl,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                const SizedBox(height: AppSpacing.lg),

                if (_error != null)
                  Text(
                    _error!,
                    style: const TextStyle(
                      color:    AppColors.danger,
                      fontSize: AppFontSizes.sm,
                    ),
                    textAlign: TextAlign.center,
                  ),

                const SizedBox(height: AppSpacing.xxl),

                // Sign out option
                TextButton(
                  onPressed: () async {
                    await AuthService.instance.signOut();
                    if (!context.mounted) return;
                    Navigator.of(context).pushReplacementNamed('/login');
                  },
                  child: const Text(
                    'Sign out and use a different account',
                    style: TextStyle(
                      color:    AppColors.textMuted,
                      fontSize: AppFontSizes.sm,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
