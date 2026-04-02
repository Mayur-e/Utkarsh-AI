import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';

class MessageBubble extends StatelessWidget {
  final String role;
  final String content;
  final int timestamp;

  const MessageBubble({
    super.key,
    required this.role,
    required this.content,
    required this.timestamp,
  });

  bool get isUser => role == 'user';

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('h:mm a').format(DateTime.fromMillisecondsSinceEpoch(timestamp));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser)
            Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(right: 8, bottom: 4),
              decoration: const BoxDecoration(
                color: AppColors.surfaceElevated,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🌿', style: TextStyle(fontSize: 14)),
              ),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primary : AppColors.surfaceElevated,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppRadius.lg),
                  topRight: const Radius.circular(AppRadius.lg),
                  bottomLeft: Radius.circular(isUser ? AppRadius.lg : AppRadius.xs),
                  bottomRight: Radius.circular(isUser ? AppRadius.xs : AppRadius.lg),
                ),
              ),
              child: Column(
                crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    content,
                    style: TextStyle(
                      color: isUser ? Colors.white : AppColors.text,
                      fontSize: AppFontSizes.md,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeStr,
                    style: TextStyle(
                      color: isUser ? Colors.white.withValues(alpha: 0.6) : AppColors.textMuted,
                      fontSize: AppFontSizes.xs,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
