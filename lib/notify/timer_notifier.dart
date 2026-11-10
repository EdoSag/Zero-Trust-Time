import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

/// Shows that a timer is running, outside the app.
abstract interface class TimerNotifier {
  /// A lasting notification with a clock counting from [start], and, when
  /// [nudgeAt] is in the future, one "still running?" reminder then.
  /// [title] is the only entry text that leaves the vault.
  Future<void> showRunning({
    required DateTime start,
    required String title,
    DateTime? nudgeAt,
  });

  Future<void> clear();

  /// Asks for notification permission. False when it is off.
  Future<bool> requestPermission();
}

/// For tests and platforms without notifications.
class NoopTimerNotifier implements TimerNotifier {
  DateTime? runningSince;
  String? title;
  DateTime? nudgeAt;

  @override
  Future<void> showRunning({
    required DateTime start,
    required String title,
    DateTime? nudgeAt,
  }) async {
    runningSince = start;
    this.title = title;
    this.nudgeAt = nudgeAt;
  }

  @override
  Future<void> clear() async {
    runningSince = null;
    title = null;
    nudgeAt = null;
  }

  @override
  Future<bool> requestPermission() async => true;
}

class LocalTimerNotifier implements TimerNotifier {
  LocalTimerNotifier([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _ready;

  static const _runningId = 1;
  static const _nudgeId = 2;

  Future<void> _init() => _ready ??= _plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      // Permission is asked when the first timer starts, not at launch.
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestSoundPermission: false,
        requestBadgePermission: false,
      ),
    ),
  );

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<bool> requestPermission() async {
    await _init();
    final android = _android;
    if (android != null) {
      return await android.requestNotificationsPermission() ?? true;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, sound: true) ?? false;
    }
    return true;
  }

  @override
  Future<void> showRunning({
    required DateTime start,
    required String title,
    DateTime? nudgeAt,
  }) async {
    await _init();
    // The live clock is an Android feature; iOS gets only the nudge.
    if (_android != null) {
      await _plugin.show(
        id: _runningId,
        title: title,
        body: 'Tap to open ZT Time',
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'timer_running',
            'Running timer',
            channelDescription: 'Shows while a timer is running',
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            autoCancel: false,
            onlyAlertOnce: true,
            playSound: false,
            showWhen: true,
            when: start.millisecondsSinceEpoch,
            usesChronometer: true,
            category: AndroidNotificationCategory.stopwatch,
            // The lock screen shows "ZT Time", not what is being tracked.
            visibility: NotificationVisibility.private,
          ),
        ),
      );
    }
    await _plugin.cancel(id: _nudgeId);
    if (nudgeAt != null && nudgeAt.isAfter(DateTime.now())) {
      await _plugin.zonedSchedule(
        id: _nudgeId,
        title: 'Timer still running',
        body: 'Your timer has been running for a while. Still working?',
        // An absolute instant, so the device's time zone doesn't matter.
        scheduledDate: tz.TZDateTime.from(nudgeAt.toUtc(), tz.UTC),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'timer_nudge',
            'Long-running timer',
            channelDescription: 'A reminder when a timer runs for hours',
            importance: Importance.defaultImportance,
            visibility: NotificationVisibility.private,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        // Close enough for a nudge, and needs no exact-alarm permission.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  @override
  Future<void> clear() async {
    await _init();
    await _plugin.cancel(id: _runningId);
    await _plugin.cancel(id: _nudgeId);
  }
}

final timerNotifierProvider = Provider<TimerNotifier>((ref) {
  if (kIsWeb ||
      !(defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    return NoopTimerNotifier();
  }
  return LocalTimerNotifier();
});
