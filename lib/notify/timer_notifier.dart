import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import '../l10n/l10n.dart';

/// Shows that a timer is running, outside the app.
abstract interface class TimerNotifier {
  /// A lasting notification with a clock counting from [start] and a Stop
  /// button (Android), and, when
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

  /// The running notification, posted by the Android side.
  static const _running = MethodChannel('dev.sagron.zerotrusttime/running_notification');

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
    final l = currentL10n;
    // The live clock and its Stop button are Android only; iOS gets only
    // the nudge. Posted natively (RunningTimerNotification.kt) so that Stop
    // works while the vault is locked, like the widget's Stop.
    if (_android != null) {
      await _running.invokeMethod<void>('show', {
        'start': start.millisecondsSinceEpoch,
        'title': title,
        'body': l.tapToOpen,
        'stop': l.stop,
        'channelName': l.channelRunning,
        'channelDescription': l.channelRunningBody,
      });
    }
    await _plugin.cancel(id: _nudgeId);
    if (nudgeAt != null && nudgeAt.isAfter(DateTime.now())) {
      await _plugin.zonedSchedule(
        id: _nudgeId,
        title: l.timerStillRunning,
        body: l.timerStillRunningBody,
        // An absolute instant, so the device's time zone doesn't matter.
        scheduledDate: tz.TZDateTime.from(nudgeAt.toUtc(), tz.UTC),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'timer_nudge',
            l.channelLong,
            channelDescription: l.channelLongBody,
            importance: Importance.defaultImportance,
            visibility: NotificationVisibility.private,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        // Close enough for a nudge, and needs no exact-alarm permission.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  @override
  Future<void> clear() async {
    await _init();
    if (_android != null) {
      await _running.invokeMethod<void>('clear');
    }
    // Also one an older version posted through the plugin.
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
