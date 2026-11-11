import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../model/project.dart';
import '../model/time_entry.dart';
import '../l10n/l10n.dart';

/// What the Android home screen timer widget (`TimerWidgetProvider.kt`)
/// shows. It lives outside the vault, so all of this is stored unencrypted
/// on the phone: by default only whether a timer runs and since when.
/// Descriptions, project names and recent projects only with "Show details
/// on the home screen".
@immutable
class TimerWidgetState {
  const TimerWidgetState({
    this.runningSince,
    this.title = '',
    this.color,
    this.recent = const [],
    this.signedOut = false,
  });

  /// Signed out: a lock, no buttons.
  const TimerWidgetState.signedOut() : this(signedOut: true);

  /// When the running timer started, or null when none runs.
  final DateTime? runningSince;

  /// What is being tracked, or "Timer running".
  final String title;

  /// The running entry's project colour (ARGB).
  final int? color;

  /// Up to three projects to start with one tap, most recent first.
  final List<Project> recent;
  final bool signedOut;

  static const maxRecent = 3;

  /// The widget's content for these entries (newest first, as
  /// `entriesProvider` gives them) and projects.
  static TimerWidgetState from({
    required List<TimeEntry> entries,
    required List<Project> projects,
    required bool details,
  }) {
    final byId = {for (final p in projects) p.id: p};
    TimeEntry? running;
    for (final e in entries) {
      if (e.running && (running == null || e.start.isAfter(running.start))) {
        running = e;
      }
    }
    String title = currentL10n.timerRunning;
    if (running != null && details) {
      final project = byId[running.projectId]?.name ?? '';
      final description = running.description.trim();
      title = description.isNotEmpty
          ? description
          : (project.isNotEmpty ? project : title);
    }
    final recent = <Project>[];
    if (details) {
      for (final e in entries) {
        final p = byId[e.projectId];
        if (p == null || p.archived || recent.any((r) => r.id == p.id)) {
          continue;
        }
        recent.add(p);
        if (recent.length == maxRecent) break;
      }
    }
    return TimerWidgetState(
      runningSince: running?.start,
      title: title,
      color: running == null ? null : byId[running.projectId]?.color,
      recent: recent,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TimerWidgetState &&
      other.runningSince == runningSince &&
      other.title == title &&
      other.color == color &&
      other.signedOut == signedOut &&
      listEquals(
        [for (final p in other.recent) '${p.id}|${p.name}|${p.color}'],
        [for (final p in recent) '${p.id}|${p.name}|${p.color}'],
      );

  @override
  int get hashCode =>
      Object.hash(runningSince, title, color, signedOut, recent.length);
}

/// A Start or Stop tapped on the widget, waiting for the unlocked app.
@immutable
class WidgetTimerAction {
  const WidgetTimerAction.start(this.at, [this.projectId]) : stop = false;
  const WidgetTimerAction.stop(this.at) : stop = true, projectId = null;

  final bool stop;
  final DateTime at;
  final String? projectId;

  /// One line each, as `TimerWidgetProvider.kt` writes them:
  /// `stop|<epoch ms>` or `start|<epoch ms>|<project id or empty>`.
  /// Unreadable lines are skipped.
  static List<WidgetTimerAction> parse(String? queue) {
    final out = <WidgetTimerAction>[];
    for (final line in (queue ?? '').split('\n')) {
      final parts = line.trim().split('|');
      final ms = parts.length > 1 ? int.tryParse(parts[1]) : null;
      if (ms == null) continue;
      final at = DateTime.fromMillisecondsSinceEpoch(ms);
      if (parts[0] == 'stop') out.add(WidgetTimerAction.stop(at));
      if (parts[0] == 'start') {
        final id = parts.length > 2 && parts[2].isNotEmpty ? parts[2] : null;
        out.add(WidgetTimerAction.start(at, id));
      }
    }
    return out;
  }
}

class TimerWidget {
  const TimerWidget();

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static const _provider =
      'dev.sagron.zerotrusttime.widget.TimerWidgetProvider';
  static const _queueKey = 'time_widget_pending';

  Future<void> publish(TimerWidgetState s) async {
    if (!isSupported) return;
    try {
      await HomeWidget.saveWidgetData<bool>(
        'time_widget_signed_out',
        s.signedOut,
      );
      await HomeWidget.saveWidgetData<bool>(
        'time_widget_running',
        s.runningSince != null,
      );
      // As text: the launcher side reads it as a Long.
      await HomeWidget.saveWidgetData<String>(
        'time_widget_start',
        s.runningSince?.millisecondsSinceEpoch.toString(),
      );
      await HomeWidget.saveWidgetData<String>('time_widget_title', s.title);
      await HomeWidget.saveWidgetData<String>(
        'time_widget_color',
        s.color == null ? null : _hex(s.color!),
      );
      await HomeWidget.saveWidgetData<int>(
        'time_widget_recent_count',
        s.recent.length,
      );
      for (var i = 0; i < TimerWidgetState.maxRecent; i++) {
        final p = i < s.recent.length ? s.recent[i] : null;
        await HomeWidget.saveWidgetData<String>(
          'time_widget_recent_${i}_id',
          p?.id,
        );
        await HomeWidget.saveWidgetData<String>(
          'time_widget_recent_${i}_name',
          p?.name,
        );
        await HomeWidget.saveWidgetData<String>(
          'time_widget_recent_${i}_color',
          p == null ? null : _hex(p.color),
        );
      }
      // The widget's own words, in the language picked in the app.
      final l = currentL10n;
      for (final (key, value) in [
        ('running', l.timerRunning),
        ('stop', l.widgetStopTimer),
        ('signed_out', l.widgetSignedOut),
        ('not_tracking', l.widgetNotTracking),
        ('open_to_start', l.widgetOpenToStart),
        ('tap_play', l.widgetTapPlay),
        ('open_app', l.widgetOpenApp),
        ('start', l.widgetStartTimer),
        ('start_for', l.widgetStartTimerFor('%s')),
      ]) {
        await HomeWidget.saveWidgetData<String>('time_widget_text_$key', value);
      }
      await HomeWidget.updateWidget(qualifiedAndroidName: _provider);
    } on Object catch (e) {
      debugPrint('Timer widget not updated: $e');
    }
  }

  /// Starts and stops tapped on the widget and not yet saved, oldest first,
  /// one raw line each (see [WidgetTimerAction.parse]). They stay queued
  /// until [acknowledge]d, so a tap is not lost if saving it fails.
  Future<List<String>> pendingLines() async {
    if (!isSupported) return const [];
    try {
      final queue = await HomeWidget.getWidgetData<String>(_queueKey);
      return [
        for (final line in (queue ?? '').split('\n'))
          if (line.trim().isNotEmpty) line.trim(),
      ];
    } on Object {
      return const [];
    }
  }

  /// Removes one line [pendingLines] gave, once it has been saved. Taps the
  /// widget queued meanwhile stay.
  Future<void> acknowledge(String line) async {
    if (!isSupported) return;
    final queue = await HomeWidget.getWidgetData<String>(_queueKey) ?? '';
    final lines = [
      for (final l in queue.split('\n'))
        if (l.trim().isNotEmpty) l.trim(),
    ];
    lines.remove(line);
    await HomeWidget.saveWidgetData<String>(
      _queueKey,
      lines.isEmpty ? null : lines.join('\n'),
    );
  }

  /// Forgets every queued tap, so they never reach another account.
  Future<void> discardPending() async {
    if (!isSupported) return;
    try {
      await HomeWidget.saveWidgetData<String>(_queueKey, null);
    } on Object {
      // Nothing stored.
    }
  }

  static String _hex(int argb) =>
      '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
