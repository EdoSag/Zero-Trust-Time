import 'package:flutter/foundation.dart';

import 'project.dart';
import 'time_entry.dart';

/// Time on one project (or on no project) within a report.
@immutable
class ProjectTotal {
  const ProjectTotal({
    required this.project,
    required this.total,
    required this.billable,
    required this.amount,
    required this.entries,
  });

  /// Null for entries with no project, or whose project was deleted.
  final Project? project;
  final Duration total;
  final Duration billable;

  /// Billable hours times the project's rate; zero without a rate.
  final double amount;
  final int entries;
}

@immutable
class Report {
  const Report({
    required this.from,
    required this.to,
    required this.total,
    required this.billable,
    required this.amount,
    required this.byProject,
    required this.byDay,
    required this.entries,
  });

  /// Local midnight, inclusive.
  final DateTime from;

  /// Local midnight, exclusive.
  final DateTime to;
  final Duration total;
  final Duration billable;
  final double amount;

  /// Longest first.
  final List<ProjectTotal> byProject;

  /// Every day in the range, in order, including days with nothing.
  final List<(DateTime, Duration)> byDay;

  /// The entries counted, newest first.
  final List<TimeEntry> entries;
}

/// The amount [duration] is worth at [rate] an hour.
double amountFor(Duration duration, double? rate) =>
    rate == null ? 0 : duration.inSeconds / 3600 * rate;

/// Sums the entries that started in `[from, to)`. A running entry counts up
/// to [now]. Pure, so it is tested without the app.
Report buildReport({
  required Iterable<TimeEntry> entries,
  required Iterable<Project> projects,
  required DateTime from,
  required DateTime to,
  required DateTime now,
}) {
  final byId = {for (final p in projects) p.id: p};
  final days = <DateTime, Duration>{};
  for (var d = DateTime(from.year, from.month, from.day);
      d.isBefore(to);
      d = DateTime(d.year, d.month, d.day + 1)) {
    days[d] = Duration.zero;
  }
  final totals = <String?, Duration>{};
  final billables = <String?, Duration>{};
  final counts = <String?, int>{};
  final counted = <TimeEntry>[];
  var total = Duration.zero;
  var billable = Duration.zero;

  for (final e in entries) {
    if (e.start.isBefore(from) || !e.start.isBefore(to)) continue;
    final d = e.durationAt(now);
    final key = byId.containsKey(e.projectId) ? e.projectId : null;
    counted.add(e);
    total += d;
    totals[key] = (totals[key] ?? Duration.zero) + d;
    counts[key] = (counts[key] ?? 0) + 1;
    if (e.billable) {
      billable += d;
      billables[key] = (billables[key] ?? Duration.zero) + d;
    }
    days[e.day] = (days[e.day] ?? Duration.zero) + d;
  }

  final byProject = [
    for (final key in totals.keys)
      ProjectTotal(
        project: byId[key],
        total: totals[key]!,
        billable: billables[key] ?? Duration.zero,
        amount: amountFor(billables[key] ?? Duration.zero, byId[key]?.hourlyRate),
        entries: counts[key]!,
      ),
  ]..sort((a, b) {
      final byTime = b.total.compareTo(a.total);
      if (byTime != 0) return byTime;
      // Equal time: by name, "No project" last.
      if (a.project == null || b.project == null) return a.project == null ? 1 : -1;
      return a.project!.name.toLowerCase().compareTo(b.project!.name.toLowerCase());
    });
  counted.sort((a, b) => b.start.compareTo(a.start));

  return Report(
    from: from,
    to: to,
    total: total,
    billable: billable,
    amount: byProject.fold(0, (sum, p) => sum + p.amount),
    byProject: byProject,
    byDay: [for (final d in days.keys.toList()..sort()) (d, days[d]!)],
    entries: counted,
  );
}

/// Entries grouped by the day they started, newest day first, newest entry
/// first within a day.
List<(DateTime, List<TimeEntry>)> groupByDay(Iterable<TimeEntry> entries) {
  final map = <DateTime, List<TimeEntry>>{};
  for (final e in entries) {
    (map[e.day] ??= []).add(e);
  }
  final days = map.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final d in days)
      (d, map[d]!..sort((a, b) => b.start.compareTo(a.start))),
  ];
}
