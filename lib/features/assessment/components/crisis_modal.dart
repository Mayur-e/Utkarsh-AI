import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';

const _kHelplines = [
  (name: 'iCall (TISS Mumbai)', number: '9152987821', hours: 'Mon–Sat, 8am–10pm'),
  (name: 'Vandrevala Foundation', number: '18602662345', hours: '24×7 · Free'),
  (name: 'NIMHANS Helpline', number: '08046110007', hours: '24×7'),
  (name: 'National Helpline', number: '9820466627', hours: '24×7'),
];

class CrisisModal extends StatefulWidget {
  final VoidCallback onSafeConfirmed;

  const CrisisModal({super.key, required this.onSafeConfirmed});

  @override
  State<CrisisModal> createState() => _CrisisModalState();
}

class _CrisisModalState extends State<CrisisModal> {
  bool _callMade = false;

  Future<void> _makeCall(String number) async {
    setState(() => _callMade = true);
    final Uri url = Uri.parse('tel:$number');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    // WillPopScope equivalent: prevent back navigation
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A1520),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xxl),
                const Text(
                  '💚',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 72),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  "You matter. We're here.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppFontSizes.xxl,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  "You mentioned some difficult thoughts. That takes courage to share.\nPlease reach out to someone who can help right now — it is free and confidential.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppFontSizes.md,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                const Text(
                  "📞 Free Crisis Support — India",
                  style: TextStyle(
                    fontSize: AppFontSizes.lg,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ..._kHelplines.map((h) => _buildHelplineCard(h)),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(AppSpacing.sm),
                    border: const Border(
                        left: BorderSide(color: AppColors.success, width: 4)),
                  ),
                  child: const Text(
                    "These feelings are temporary, even when they don't feel that way. A trained counsellor is available right now who understands exactly what you are going through.",
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: AppFontSizes.sm,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  _callMade
                      ? "Thank you for reaching out. Please continue when you feel ready."
                      : "Please tap a helpline above before continuing.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: AppFontSizes.sm,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ElevatedButton(
                  onPressed: widget.onSafeConfirmed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.sm),
                    ),
                  ),
                  child: const Text(
                    "I am safe right now and want to continue",
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: AppFontSizes.md,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const Text.rich(
                  TextSpan(
                    text: "Immediate danger? Call ",
                    children: [
                      TextSpan(
                        text: "112 (Emergency Services)",
                        style: TextStyle(
                            color: AppColors.danger,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: AppFontSizes.sm,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  "Utkarsh is not a substitute for professional mental health care.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHelplineCard(
      ({String hours, String name, String number}) helpline) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppSpacing.md),
        title: Text(
          helpline.name,
          style: const TextStyle(
              color: AppColors.text,
              fontSize: AppFontSizes.md,
              fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              helpline.number,
              style: const TextStyle(
                  color: AppColors.success,
                  fontSize: AppFontSizes.lg,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              helpline.hours,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: AppFontSizes.xs),
            ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () => _makeCall(helpline.number),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: AppColors.white,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: 0),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4)),
            minimumSize: const Size(60, 40),
          ),
          child: const Text('CALL',
              style: TextStyle(fontSize: AppFontSizes.sm, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
