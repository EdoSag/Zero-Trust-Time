import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/l10n.dart';

DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// The first day of the week holding [d], weeks starting on [weekStart].
DateTime startOfWeek(DateTime d, int weekStart) {
  final offset = (d.weekday - weekStart + 7) % 7;
  return DateTime(d.year, d.month, d.day - offset);
}

/// The locale's first day of the week as [DateTime.monday] .. sunday.
int localeWeekStart(BuildContext context) {
  final index = MaterialLocalizations.of(context).firstDayOfWeekIndex; // 0=Sun
  return index == 0 ? DateTime.sunday : index;
}

String formatTime(BuildContext context, DateTime t) {
  final use24 = MediaQuery.maybeOf(context)?.alwaysUse24HourFormat ?? false;
  return MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay.fromDateTime(t),
    alwaysUse24HourFormat: use24,
  );
}

/// "Today", "Yesterday" or "Tue, Nov 10", in the app's language.
String relativeDay(DateTime d, {DateTime? now}) {
  final today = dayOf(now ?? DateTime.now());
  final diff = (dayOf(d).difference(today).inHours / 24).round();
  final l = currentL10n;
  return switch (diff) {
    0 => l.today,
    -1 => l.yesterday,
    1 => l.tomorrow,
    _ => d.year == today.year
        ? DateFormat.MMMEd().format(d)
        : DateFormat.yMMMEd().format(d),
  };
}

String _two(int n) => n.toString().padLeft(2, '0');

/// A running clock: "0:04:09", "12:30:00".
String formatClock(Duration d) {
  final s = d.isNegative ? 0 : d.inSeconds;
  return '${s ~/ 3600}:${_two(s % 3600 ~/ 60)}:${_two(s % 60)}';
}

/// A total: "7h 30m", "45m", "0m"; or "7.50 h" with [decimal].
String formatDuration(Duration d, {bool decimal = false}) {
  final s = d.isNegative ? 0 : d.inSeconds;
  final l = currentL10n;
  if (decimal) return l.durationDecimalHours((s / 3600).toStringAsFixed(2));
  final minutes = (s / 60).round();
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return l.durationMinutes(m);
  return m == 0 ? l.durationHours(h) : l.durationHoursMinutes(h, m);
}

/// "$1,234.50" with the currency sign from settings.
String formatAmount(double amount, String currency) =>
    '$currency${NumberFormat('#,##0.00').format(amount)}';
