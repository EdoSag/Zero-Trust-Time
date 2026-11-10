import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

/// Time's own per-install settings, kept with the core's preferences.
@immutable
class TimeSettings {
  const TimeSettings({
    this.weekStart,
    this.currency = r'$',
    this.decimalHours = false,
    this.runningNotification = true,
    this.notificationText = false,
    this.nudgeAfterHours = 8,
  });

  /// [DateTime.monday] .. [DateTime.sunday], or null for the locale's.
  final int? weekStart;

  /// Shown before amounts in reports: "$", "€", "₪".
  final String currency;

  /// Report durations as 7.50 h instead of 7h 30m.
  final bool decimalHours;

  /// A notification with a live clock while a timer runs (Android).
  final bool runningNotification;

  /// The entry's description in that notification. Off: "Timer running".
  /// On, the text is handed to the phone so it shows while Time is locked.
  final bool notificationText;

  /// "Still running?" after this many hours, or null for never.
  final int? nudgeAfterHours;

  static const _unset = Object();

  TimeSettings copyWith({
    Object? weekStart = _unset,
    String? currency,
    bool? decimalHours,
    bool? runningNotification,
    bool? notificationText,
    Object? nudgeAfterHours = _unset,
  }) => TimeSettings(
    weekStart: identical(weekStart, _unset) ? this.weekStart : weekStart as int?,
    currency: currency ?? this.currency,
    decimalHours: decimalHours ?? this.decimalHours,
    runningNotification: runningNotification ?? this.runningNotification,
    notificationText: notificationText ?? this.notificationText,
    nudgeAfterHours: identical(nudgeAfterHours, _unset)
        ? this.nudgeAfterHours
        : nudgeAfterHours as int?,
  );

  Map<String, String> toPrefs() => {
    'weekStart': '${weekStart ?? 'locale'}',
    'currency': currency,
    'decimalHours': '$decimalHours',
    'runningNotification': '$runningNotification',
    'notificationText': '$notificationText',
    'nudgeAfterHours': '${nudgeAfterHours ?? 'never'}',
  };

  static TimeSettings fromPrefs(Map<String, String?> p) {
    const d = TimeSettings();
    bool b(String k, bool fallback) => p[k] == null ? fallback : p[k] == 'true';
    return TimeSettings(
      weekStart: int.tryParse(p['weekStart'] ?? ''),
      currency: p['currency'] ?? d.currency,
      decimalHours: b('decimalHours', d.decimalHours),
      runningNotification: b('runningNotification', d.runningNotification),
      notificationText: b('notificationText', d.notificationText),
      nudgeAfterHours: p['nudgeAfterHours'] == null
          ? d.nudgeAfterHours
          : int.tryParse(p['nudgeAfterHours']!),
    );
  }
}

final timeSettingsProvider = NotifierProvider<TimeSettingsController, TimeSettings>(
  TimeSettingsController.new,
);

class TimeSettingsController extends Notifier<TimeSettings> {
  static const _prefix = 'time_';
  bool _changed = false;

  @override
  TimeSettings build() {
    _load();
    return const TimeSettings();
  }

  Future<void> _load() async {
    final store = ref.read(ztPreferencesStoreProvider);
    final values = <String, String?>{};
    try {
      for (final key in const TimeSettings().toPrefs().keys) {
        values[key] = await store.read('$_prefix$key');
      }
    } on Object {
      return; // Unreadable: keep the defaults.
    }
    if (_changed) return;
    state = TimeSettings.fromPrefs(values);
  }

  Future<void> update(TimeSettings Function(TimeSettings) change) async {
    _changed = true;
    final next = change(state);
    final before = state.toPrefs();
    state = next;
    final store = ref.read(ztPreferencesStoreProvider);
    for (final e in next.toPrefs().entries) {
      if (before[e.key] != e.value) {
        try {
          await store.write('$_prefix${e.key}', e.value);
        } on Object {
          // Kept for this run only.
        }
      }
    }
  }
}
