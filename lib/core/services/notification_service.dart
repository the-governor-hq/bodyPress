import 'dart:math';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'notification_content_service.dart';

/// Manages local notifications for BodyPress.
///
/// Two channels:
/// - **Daily Body Blog** — a scheduled daily reminder (engaging fallback).
/// - **Smart Insights** — data-driven notifications triggered from
///   background captures with real biometric data.
class NotificationService {
  static final NotificationService _instance = NotificationService._();

  factory NotificationService() => _instance;

  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialised = false;

  // ── Channel IDs ─────────────────────────────────────────────────────────

  static const _dailyChannelId = 'bodypress_daily_reminder';
  static const _dailyChannelName = 'Daily Body Blog';
  static const _dailyChannelDescription =
      'A daily reminder to check your body blog';

  static const _smartChannelId = 'bodypress_smart_insights';
  static const _smartChannelName = 'Smart Body Insights';
  static const _smartChannelDescription =
      'Data-driven notifications with your real biometrics';

  static const _dailyNotifId = 9001;
  static const _smartNotifId = 9003;

  // ── Engaging scheduled messages (emoji-rich, CTA-driven) ───────────────
  //
  // These are used by the scheduled daily reminder as a fallback when the
  // smart (data-aware) notification hasn't fired yet today.  Pick is random
  // at schedule time — still beats the old generic messages.

  static const dailyMessages = <({String title, String body})>[
    (
      title: '🧬 Your body wrote something today',
      body:
          'Steps, sleep, heart — it\'s all there. Open your body blog and see →',
    ),
    (
      title: '📖 New chapter in your body\'s diary',
      body: 'Every day tells a different story. Today\'s is waiting →',
    ),
    (
      title: '🔬 Your daily body report is in',
      body: 'Real data, real insights. Read it now →',
    ),
    (
      title: '💡 Your body dropped some knowledge',
      body:
          'Patterns you didn\'t notice, signals you missed. Check today\'s blog →',
    ),
    (
      title: '🎯 Body check-in time!',
      body:
          'Your body tracked everything. See the summary — you might be surprised →',
    ),
    (
      title: '⚡ Fresh insights from your body',
      body:
          'Heart, steps, sleep, mood — compiled into today\'s story. Don\'t miss it →',
    ),
    (
      title: '🌟 Your body\'s daily dispatch',
      body: 'No fluff, just your real biometrics as a story. Tap to read →',
    ),
    (
      title: '🧠 Your body is smarter than you think',
      body: 'It noticed things today. Check what it observed →',
    ),
    (
      title: '🫀 Pulse. Steps. Sleep. Story.',
      body:
          'Your body turned today\'s numbers into narrative. Read the latest →',
    ),
    (
      title: '📊 Data in, story out',
      body:
          'Your body collected signals all day. BodyPress turned them into insight →',
    ),
    (
      title: '🌊 Ride today\'s body wave',
      body:
          'Energy, recovery, movement — your body captured the full picture →',
    ),
    (
      title: '🔋 How\'s your body battery today?',
      body:
          'Sleep, steps, and stress all factor in. Your body blog has the answer →',
    ),
    (
      title: '💬 Your body left you a note',
      body: 'With data. And insights. Open it →',
    ),
    (
      title: '🎤 Your body has the mic today',
      body: 'Steps, rhythm, environment — all in today\'s narrative →',
    ),
    (
      title: '🪞 Mirror check: the inside edition',
      body:
          'Forget appearances — your body blog shows what\'s really happening →',
    ),
    (
      title: '📱 Your body blog just updated',
      body: 'A day of biometrics distilled into one honest page. Read it →',
    ),
    (
      title: '🏃 Your body kept moving — and writing',
      body:
          'Every step, every heartbeat logged. See what the day looked like from inside →',
    ),
    (
      title: '🫣 You haven\'t checked in yet today',
      body: 'Your body has been talking all day. Don\'t leave it on read →',
    ),
    (
      title: '🔥 Today\'s body blog is fire',
      body: 'Your biometrics told a story worth reading. Tap to see →',
    ),
    (
      title: '🧘 A moment for body awareness',
      body: 'Pause. Breathe. Your daily body snapshot is ready →',
    ),
    (
      title: '🌡️ Your body measured the day',
      body:
          'Temperature, heart rate, movement — all woven into today\'s narrative →',
    ),
    (
      title: '📝 Your body published a post',
      body:
          'First-person account of your day. Written by you — literally. Read it →',
    ),
    (
      title: '🚀 Your body has news',
      body:
          'Not just numbers — a story. Steps, rest, environment. All real. All you →',
    ),
    (
      title: '🎯 One tap. Your whole day.',
      body:
          'Your body blog summarised everything in one page. Don\'t miss today\'s →',
    ),
  ];

  // ── Lifecycle ───────────────────────────────────────────────────────────

  /// Initialise the notification plugin and create Android channels.
  ///
  /// Safe to call more than once — subsequent calls are no-ops.
  Future<void> initialize() async {
    if (_initialised) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    // Create Android notification channels (no-op on iOS).
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImpl != null) {
      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          _dailyChannelId,
          _dailyChannelName,
          description: _dailyChannelDescription,
          importance: Importance.high,
        ),
      );
      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          _smartChannelId,
          _smartChannelName,
          description: _smartChannelDescription,
          importance: Importance.high,
        ),
      );
    }

    _initialised = true;
  }

  // ── Public helpers ────────────────────────────────────────────────────

  /// Request notification permission on Android 13+ / iOS.
  Future<bool> requestPermission() async {
    // Android 13+
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }

    // iOS
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    return false;
  }

  // ── Daily reminder scheduling ─────────────────────────────────────────

  /// Schedule a daily notification at the given [hour] and [minute].
  ///
  /// Replaces any previously scheduled daily reminder. The notification
  /// picks a random message from [dailyMessages] — re-scheduled on every
  /// app launch so the message rotates.
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    await _ensureInitialised();

    // Cancel any existing daily reminder first.
    await _plugin.cancel(_dailyNotifId);

    final msg = dailyMessages[Random().nextInt(dailyMessages.length)];

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      _dailyNotifId,
      msg.title,
      msg.body,
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _dailyChannelId,
          _dailyChannelName,
          channelDescription: _dailyChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
          styleInformation: BigTextStyleInformation(''),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Cancel the daily body-blog reminder.
  Future<void> cancelDailyReminder() async {
    await _ensureInitialised();
    await _plugin.cancel(_dailyNotifId);
  }

  // ── Smart data-driven notification ──────────────────────────────────────

  /// Show a data-driven notification with real biometric content.
  ///
  /// Called from the background capture executor (once per day) with a
  /// [NotifContent] produced by [NotificationContentService].
  Future<void> showSmartNotification(NotifContent content) async {
    await _ensureInitialised();

    await _plugin.show(
      _smartNotifId,
      content.title,
      content.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _smartChannelId,
          _smartChannelName,
          channelDescription: _smartChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
          styleInformation: BigTextStyleInformation(''),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  /// Show a test daily notification immediately (for the debug panel).
  Future<void> showTestDailyReminder() async {
    await _ensureInitialised();

    final msg = dailyMessages[Random().nextInt(dailyMessages.length)];

    await _plugin.show(
      _dailyNotifId + 1,
      msg.title,
      msg.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _dailyChannelId,
          _dailyChannelName,
          channelDescription: _dailyChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  // ── Internals ─────────────────────────────────────────────────────────

  Future<void> _ensureInitialised() async {
    if (!_initialised) await initialize();
  }
}
