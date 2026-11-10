import 'package:flutter/foundation.dart';

import 'package:uuid/uuid.dart';

import '../model/project.dart';
import '../model/report.dart';
import '../model/time_entry.dart';
import '../sheets/spreadsheet.dart';
import 'csv.dart';

/// The columns this app writes. The same names Toggl Track uses, so the
/// file opens in tools that read Toggl exports, and imports back here.
const timesheetHeader = [
  'Description',
  'Project',
  'Client',
  'Tags',
  'Billable',
  'Start date',
  'Start time',
  'End date',
  'End time',
  'Duration',
  'Duration (hours)',
  'Amount',
];

/// A timesheet of [entries] as a CSV text, oldest first. Running entries
/// are left out: they have no end yet.
String writeTimesheet(Iterable<TimeEntry> entries, Iterable<Project> projects) => Csv.write([
  for (final row in timesheetTable(entries, projects)) [for (final c in row) cellText(c)],
]);

/// A timesheet of [entries] as typed cells for [writeSheet], oldest first,
/// with [timesheetHeader] as the first row. Running entries are left out.
List<List<Object?>> timesheetTable(Iterable<TimeEntry> entries, Iterable<Project> projects) {
  final byId = {for (final p in projects) p.id: p};
  final sorted = [for (final e in entries) if (!e.running) e]
    ..sort((a, b) => a.start.compareTo(b.start));
  return [
    timesheetHeader,
    for (final e in sorted)
      () {
        final p = byId[e.projectId];
        final d = e.durationAt(e.end!);
        final amount = e.billable ? amountFor(d, p?.hourlyRate) : 0.0;
        return <Object?>[
          e.description,
          p?.name ?? '',
          p?.client ?? '',
          e.tags.join(', '),
          e.billable ? 'Yes' : 'No',
          SheetDate(e.start),
          SheetTime(e.start),
          SheetDate(e.end!),
          SheetTime(e.end!),
          d,
          (d.inSeconds / 36).round() / 100,
          amount == 0 ? null : (amount * 100).round() / 100,
        ];
      }(),
  ];
}

/// What importing a timesheet file would add.
@immutable
class TimesheetImport {
  const TimesheetImport({
    required this.entries,
    required this.newProjects,
    required this.skipped,
    required this.unreadable,
  });

  final List<TimeEntry> entries;
  final List<Project> newProjects;

  /// Rows already in the account (same start, end and description).
  final int skipped;

  /// Rows without a readable start and end.
  final int unreadable;

  /// Reads a CSV exported by this app, Toggl Track or Clockify. Columns are
  /// found by name, so their order doesn't matter. Throws [FormatException]
  /// when the file has no start-date column.
  static TimesheetImport build({
    required String csv,
    required Iterable<TimeEntry> existing,
    required Iterable<Project> projects,
    String Function()? newId,
  }) => fromSheets(
    sheets: [Csv.parse(csv)],
    existing: existing,
    projects: projects,
    newId: newId,
  );

  /// Reads a spreadsheet or CSV file's bytes (see [readSheets]): .xlsx from
  /// Excel or Google Sheets, .ods from LibreOffice, or CSV.
  static TimesheetImport fromFile({
    required Uint8List bytes,
    required Iterable<TimeEntry> existing,
    required Iterable<Project> projects,
    String Function()? newId,
  }) => fromSheets(
    sheets: readSheets(bytes),
    existing: existing,
    projects: projects,
    newId: newId,
  );

  /// Imports the first sheet that has a start-date column. Its header may
  /// sit below a few title rows.
  static TimesheetImport fromSheets({
    required List<List<List<String>>> sheets,
    required Iterable<TimeEntry> existing,
    required Iterable<Project> projects,
    String Function()? newId,
  }) {
    final id = newId ?? const Uuid().v4;
    if (sheets.every((s) => s.isEmpty)) throw const FormatException('The file is empty');
    List<List<String>>? rows;
    var headerAt = 0;
    find:
    for (final sheet in sheets) {
      for (var i = 0; i < sheet.length && i < 10; i++) {
        final names = {for (final h in sheet[i]) h.trim().toLowerCase()};
        if (names.contains('start date') || names.contains('start')) {
          rows = sheet;
          headerAt = i;
          break find;
        }
      }
    }
    if (rows == null) {
      throw const FormatException('No "Start date" column in this file');
    }
    final header = [for (final h in rows[headerAt]) h.trim().toLowerCase()];
    int col(List<String> names) {
      for (final n in names) {
        final i = header.indexOf(n);
        if (i >= 0) return i;
      }
      return -1;
    }

    final cDesc = col(['description']);
    final cProject = col(['project']);
    final cClient = col(['client']);
    final cTags = col(['tags', 'tag']);
    final cBillable = col(['billable']);
    final cStartDate = col(['start date', 'start']);
    final cStartTime = col(['start time']);
    final cEndDate = col(['end date', 'end', 'stop date']);
    final cEndTime = col(['end time', 'stop time']);
    final cDuration = col(['duration', 'duration (h)']);
    if (cStartDate < 0) {
      throw const FormatException('No "Start date" column in this file');
    }

    // Also undoes the apostrophe this app's export puts before = + - @, so
    // a project called "@internal" matches itself when imported back.
    final guard = RegExp(r"^'(?=[=+\-@])");
    String cell(List<String> row, int c) =>
        c < 0 || c >= row.length ? '' : row[c].trim().replaceFirst(guard, '');
    final body = rows.skip(headerAt + 1).toList();

    // 03/04/2026 is March 4 in the US and 3 April elsewhere. A file where
    // some first number is above 12 can only be day-first.
    final dayFirst = body.any((r) {
      final m = RegExp(r'^(\d{1,2})[/.](\d{1,2})[/.]\d{2,4}').firstMatch(cell(r, cStartDate));
      return m != null && int.parse(m.group(1)!) > 12;
    });

    final projectByKey = {
      for (final p in projects) _projectKey(p.name, p.client): p,
    };
    final seen = {for (final e in existing) _entryKey(e)};
    final entries = <TimeEntry>[];
    final newProjects = <Project>[];
    var skipped = 0;
    var unreadable = 0;

    for (final row in body) {
      final start = parseDateTime(cell(row, cStartDate), cell(row, cStartTime), dayFirst: dayFirst);
      var end = parseDateTime(cell(row, cEndDate), cell(row, cEndTime), dayFirst: dayFirst);
      if (start != null && end == null) {
        final d = parseDuration(cell(row, cDuration));
        if (d != null) end = start.add(d);
      }
      if (start == null || end == null || end.isBefore(start)) {
        unreadable++;
        continue;
      }
      Project? project;
      final name = cell(row, cProject);
      if (name.isNotEmpty) {
        final key = _projectKey(name, cell(row, cClient));
        project = projectByKey[key];
        if (project == null) {
          project = Project(
            id: id(),
            name: name,
            client: cell(row, cClient),
            color: projectColors[(projectByKey.length) % projectColors.length],
          );
          projectByKey[key] = project;
          newProjects.add(project);
        }
      }
      final entry = TimeEntry(
        id: id(),
        description: cell(row, cDesc),
        projectId: project?.id,
        tags: [
          for (final t in cell(row, cTags).split(RegExp('[,;]')))
            if (t.trim().isNotEmpty) t.trim().replaceFirst(guard, ''),
        ],
        billable: const {'yes', 'true', '1', 'y'}.contains(cell(row, cBillable).toLowerCase()),
        start: start,
        end: end,
      );
      if (!seen.add(_entryKey(entry))) {
        skipped++;
        continue;
      }
      entries.add(entry);
    }
    return TimesheetImport(
      entries: entries,
      // Only projects that an imported entry uses.
      newProjects: [
        for (final p in newProjects)
          if (entries.any((e) => e.projectId == p.id)) p,
      ],
      skipped: skipped,
      unreadable: unreadable,
    );
  }

  static String _projectKey(String name, String client) =>
      '${name.trim().toLowerCase()}|${client.trim().toLowerCase()}';

  static String _entryKey(TimeEntry e) =>
      '${e.start.toUtc().millisecondsSinceEpoch ~/ 1000}|'
      '${(e.end ?? e.start).toUtc().millisecondsSinceEpoch ~/ 1000}|'
      '${e.description.trim()}';
}

/// A local date and time from the text other trackers write: "2026-11-10",
/// "10/11/2026", "11/10/2026", "10.11.2026", with "14:05", "14:05:09" or
/// "2:05 PM". The date cell may also hold both ("2026-11-10T14:05:00Z").
@visibleForTesting
DateTime? parseDateTime(String date, String time, {bool dayFirst = false}) {
  date = date.trim();
  time = time.trim();
  if (date.isEmpty) return null;
  if (time.isEmpty && date.contains(RegExp('[T ]'))) {
    final iso = DateTime.tryParse(date.replaceFirst(' ', 'T'));
    if (iso != null) return iso.toLocal();
    final space = date.indexOf(' ');
    time = date.substring(space + 1);
    date = date.substring(0, space);
  }
  int? y, m, d;
  final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(date);
  final other = RegExp(r'^(\d{1,2})[/.](\d{1,2})[/.](\d{2,4})').firstMatch(date);
  if (iso != null) {
    y = int.parse(iso.group(1)!);
    m = int.parse(iso.group(2)!);
    d = int.parse(iso.group(3)!);
  } else if (other != null) {
    final a = int.parse(other.group(1)!);
    final b = int.parse(other.group(2)!);
    y = int.parse(other.group(3)!);
    if (y < 100) y += 2000;
    // Dots are always day-first (European).
    if (dayFirst || date.contains('.')) {
      d = a;
      m = b;
    } else {
      m = a;
      d = b;
    }
  } else {
    return null;
  }
  if (m < 1 || m > 12 || d < 1 || d > 31) return null;
  var hour = 0, minute = 0, second = 0;
  if (time.isNotEmpty) {
    final t = RegExp(
      r'^(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([AaPp])?\.?[Mm]?\.?$',
    ).firstMatch(time);
    if (t == null) return null;
    hour = int.parse(t.group(1)!);
    minute = int.parse(t.group(2)!);
    second = int.parse(t.group(3) ?? '0');
    final half = t.group(4)?.toLowerCase();
    if (half == 'p' && hour < 12) hour += 12;
    if (half == 'a' && hour == 12) hour = 0;
    if (hour > 23 || minute > 59 || second > 59) return null;
  }
  return DateTime(y, m, d, hour, minute, second);
}

/// "01:30:00", "1:30" or decimal hours ("1.5").
@visibleForTesting
Duration? parseDuration(String text) {
  text = text.trim();
  if (text.isEmpty) return null;
  final hms = RegExp(r'^(\d+):(\d{2})(?::(\d{2}))?$').firstMatch(text);
  if (hms != null) {
    return Duration(
      hours: int.parse(hms.group(1)!),
      minutes: int.parse(hms.group(2)!),
      seconds: int.parse(hms.group(3) ?? '0'),
    );
  }
  final hours = double.tryParse(text.replaceAll(',', '.'));
  if (hours == null || hours < 0) return null;
  return Duration(seconds: (hours * 3600).round());
}
