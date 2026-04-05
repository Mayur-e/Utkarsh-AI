import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../services/storage/database_service.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
        android: androidSettings, iOS: iosSettings);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
    _initialized = true;
    debugPrint('[NotificationService] Initialized ✅');
  }

  void _onNotificationTap(NotificationResponse response) {
    debugPrint('[NotificationService] Tapped: ${response.payload}');
  }

  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }

  // ── Notification channel ─────────────────────────────────────────────

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          'utkarsh_main',
          'Utkarsh Wellbeing',
          channelDescription: 'Wellbeing reminders and alerts',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: false,
        ),
      );

  // ── Instant send ─────────────────────────────────────────────────────

  Future<void> _send(int id, String title, String body,
      {String? payload, String? userId}) async {
    if (!_initialized) return;

    // 1. Check user preference
    final profile = await databaseServiceProvider.getProfile(userId);
    final enabled = profile?['notifications_enabled'] == 1 || profile?['notifications_enabled'] == true;
    if (!enabled) return;

    await _plugin.show(id, title, body, _details, payload: payload);
  }

  // ── Context-aware notifications ──────────────────────────────────────

  Future<void> sendStressAlert(double cwsScore, [String? userId]) async {
    if (cwsScore < 30) {
      await _send(
        1,
        'Utkarsh is thinking of you 💚',
        'Your wellbeing score is low today. Want to talk about it?',
        payload: 'open_chat',
        userId: userId,
      );
    }
  }

  Future<void> sendTaskReminder(String taskTitle) async {
    await _send(
      2,
      '📋 Task Reminder',
      '"$taskTitle" is due soon. You\'ve got this!',
      payload: 'open_tasks',
    );
  }

  Future<void> sendDailyCheckin() async {
    await _send(
      3,
      '🌿 Daily Check-in',
      'How was your day? Open Utkarsh and tell me.',
      payload: 'open_chat',
    );
  }

  Future<void> sendStreakReminder(int streakDays) async {
    await _send(
      4,
      '🔥 $streakDays-Day Streak',
      "Don't break your streak! Open Utkarsh to check in.",
      payload: 'open_chat',
    );
  }

  /// Schedule nightly 8 PM check-in reminder
  Future<void> scheduleEveningCheckin() async {
    if (!_initialized) return;
    await _plugin.periodicallyShow(
      5,
      '🌿 Evening Check-in',
      'How did today go? Chat with Utkarsh 💚',
      RepeatInterval.daily,
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Send overdue-task alerts for any high-priority tasks past deadline
  Future<void> checkOverdueTasks() async {
    final tasks = await databaseServiceProvider.getActiveTasks();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final t in tasks) {
      final deadline = t.deadline;
      final priority = t.priority;
      if (deadline != null && deadline < now && priority >= 3) {
        await sendTaskReminder(t.title);
        break; // send one per check
      }
    }
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}

final notificationService = NotificationService.instance;
