import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_time/csv/csv.dart';
import 'package:zerotrust_time/csv/timesheet_csv.dart';
import 'package:zerotrust_time/model/project.dart';
import 'package:zerotrust_time/model/time_entry.dart';

void main() {
  var n = 0;
  String id() => 'id${n++}';
  setUp(() => n = 0);

  test('CSV quotes commas, quotes and line breaks, and reads them back', () {
    final rows = [
      ['a', 'b,c', 'say "hi"', 'two\nlines', ''],
      ['1', '2', '3', '4', '5'],
    ];
    final text = Csv.write(rows);
    expect(text, contains('"b,c"'));
    expect(text, contains('"say ""hi"""'));
    expect(Csv.parse(text), rows);
  });

  test('CSV reads semicolons, a byte-order mark and Windows line ends', () {
    expect(Csv.parse('﻿a;b\r\n1;2\r\n'), [
      ['a', 'b'],
      ['1', '2'],
    ]);
  });

  test('text a spreadsheet would run as a formula is made plain', () {
    expect(Csv.write([['=HYPERLINK("x")', '-5', 'ok']]), startsWith("\"'=HYPERLINK(\"\"x\"\")\",'-5,ok"));
  });

  test('dates and times from other trackers', () {
    expect(parseDateTime('2026-11-10', '14:05:09'), DateTime(2026, 11, 10, 14, 5, 9));
    expect(parseDateTime('11/10/2026', '2:05 PM'), DateTime(2026, 11, 10, 14, 5));
    expect(parseDateTime('10/11/2026', '14:05', dayFirst: true), DateTime(2026, 11, 10, 14, 5));
    expect(parseDateTime('10.11.2026', '09:00'), DateTime(2026, 11, 10, 9));
    expect(parseDateTime('11/10/26', '12:00 AM'), DateTime(2026, 11, 10));
    expect(parseDateTime('11/10/2026', '12:30 PM'), DateTime(2026, 11, 10, 12, 30));
    expect(parseDateTime('2026-11-10 14:05:00', ''), DateTime(2026, 11, 10, 14, 5));
    expect(
      parseDateTime('2026-11-10T14:05:00Z', ''),
      DateTime.utc(2026, 11, 10, 14, 5).toLocal(),
    );
    expect(parseDateTime('', '10:00'), isNull);
    expect(parseDateTime('soon', ''), isNull);
    expect(parseDateTime('2026-13-40', ''), isNull);
    expect(parseDateTime('2026-11-10', '25:00'), isNull);
  });

  test('durations', () {
    expect(parseDuration('01:30:00'), const Duration(minutes: 90));
    expect(parseDuration('1:30'), const Duration(minutes: 90));
    expect(parseDuration('1.5'), const Duration(minutes: 90));
    expect(parseDuration('1,5'), const Duration(minutes: 90));
    expect(parseDuration(''), isNull);
    expect(parseDuration('long'), isNull);
  });

  group('timesheets', () {
    const web = Project(id: 'web', name: 'Website', client: 'Acme', hourlyRate: 100);
    final start = DateTime(2026, 11, 10, 9);
    final entries = [
      TimeEntry(
        id: 'a',
        description: 'Fix header, again',
        projectId: 'web',
        tags: const ['bug', 'css'],
        billable: true,
        start: start,
        end: start.add(const Duration(minutes: 90)),
      ),
      TimeEntry(
        id: 'b',
        description: '-quick note',
        start: start.add(const Duration(hours: 3)),
        end: start.add(const Duration(hours: 3, minutes: 20, seconds: 5)),
      ),
      TimeEntry(id: 'running', start: start.add(const Duration(hours: 5))),
    ];

    test('export writes one row per finished entry, oldest first', () {
      final rows = Csv.parse(writeTimesheet(entries.reversed, const [web]));
      expect(rows.first, timesheetHeader);
      expect(rows, hasLength(3)); // The running one is left out.
      expect(rows[1], [
        'Fix header, again',
        'Website',
        'Acme',
        'bug, css',
        'Yes',
        '2026-11-10',
        '09:00:00',
        '2026-11-10',
        '10:30:00',
        '01:30:00',
        '1.50',
        '150.00',
      ]);
      expect(rows[2][9], '00:20:05');
      expect(rows[2].last, ''); // Not billable: no amount.
    });

    test('an export imports back as the same entries', () {
      final plan = TimesheetImport.build(
        csv: writeTimesheet(entries, const [web]),
        existing: const [],
        projects: const [web],
        newId: id,
      );
      expect(plan.newProjects, isEmpty); // Matched the existing project.
      expect(plan.entries, hasLength(2));
      final a = plan.entries[0];
      expect(a.description, 'Fix header, again');
      expect(a.projectId, 'web');
      expect(a.tags, ['bug', 'css']);
      expect(a.billable, isTrue);
      expect(a.start, entries[0].start);
      expect(a.end, entries[0].end);
      expect(plan.entries[1].description, '-quick note');
      expect(plan.entries[1].end, entries[1].end);
    });

    test('importing the same file twice adds nothing', () {
      final csv = writeTimesheet(entries, const [web]);
      final plan = TimesheetImport.build(
        csv: csv,
        existing: entries,
        projects: const [web],
        newId: id,
      );
      expect(plan.entries, isEmpty);
      expect(plan.skipped, 2);
    });

    test('a Toggl Track export', () {
      const csv = '''
User,Email,Client,Project,Task,Description,Billable,Start date,Start time,End date,End time,Duration,Tags,Amount (USD)
Dana,dana@example.com,Acme,Website,,Landing page,Yes,2026-11-09,09:00:00,2026-11-09,11:15:00,02:15:00,"design, web",225.00
Dana,dana@example.com,,,,Email,No,2026-11-09,11:30:00,2026-11-09,12:00:00,00:30:00,,
Dana,dana@example.com,Acme,Website,,Landing page,Yes,2026-11-09,09:00:00,2026-11-09,11:15:00,02:15:00,"design, web",225.00
''';
      final plan = TimesheetImport.build(csv: csv, existing: const [], projects: const [], newId: id);
      expect(plan.entries, hasLength(2));
      expect(plan.skipped, 1); // The repeated row.
      expect(plan.newProjects.single.name, 'Website');
      expect(plan.newProjects.single.client, 'Acme');
      expect(plan.entries[0].projectId, plan.newProjects.single.id);
      expect(plan.entries[0].tags, ['design', 'web']);
      expect(plan.entries[0].start, DateTime(2026, 11, 9, 9));
      expect(plan.entries[0].end, DateTime(2026, 11, 9, 11, 15));
      expect(plan.entries[1].projectId, isNull);
      expect(plan.entries[1].billable, isFalse);
    });

    test('a Clockify export with US dates and AM/PM', () {
      const csv = '''
"Project","Client","Description","Task","User","Group","Email","Tags","Billable","Start Date","Start Time","End Date","End Time","Duration (h)","Duration (decimal)","Billable Rate (USD)","Billable Amount (USD)"
"App","","Standup","","Dana","","dana@example.com","","No","11/09/2026","9:00 AM","11/09/2026","9:15 AM","00:15:00","0.25","0.00","0.00"
"App","","Build","","Dana","","dana@example.com","dev","Yes","11/09/2026","1:00 PM","11/09/2026","5:30 PM","04:30:00","4.50","0.00","0.00"
''';
      final plan = TimesheetImport.build(csv: csv, existing: const [], projects: const [], newId: id);
      expect(plan.entries, hasLength(2));
      expect(plan.newProjects.single.name, 'App');
      expect(plan.entries[0].start, DateTime(2026, 11, 9, 9));
      expect(plan.entries[1].start, DateTime(2026, 11, 9, 13));
      expect(plan.entries[1].end, DateTime(2026, 11, 9, 17, 30));
      expect(plan.entries[1].billable, isTrue);
    });

    test('day-first dates are recognised when a day is above 12', () {
      const csv = '''
Description,Start date,Start time,End date,End time
One,05/11/2026,09:00,05/11/2026,10:00
Two,25/11/2026,09:00,25/11/2026,10:00
''';
      final plan = TimesheetImport.build(csv: csv, existing: const [], projects: const [], newId: id);
      expect(plan.entries[0].start, DateTime(2026, 11, 5, 9));
      expect(plan.entries[1].start, DateTime(2026, 11, 25, 9));
    });

    test('a row with only a start and a duration gets its end from them', () {
      const csv = 'Description,Start date,Start time,Duration\nCall,2026-11-10,10:00,0:45\nBad,,,\n';
      final plan = TimesheetImport.build(csv: csv, existing: const [], projects: const [], newId: id);
      expect(plan.entries.single.end, DateTime(2026, 11, 10, 10, 45));
      expect(plan.unreadable, 1);
    });

    test('a file without a start-date column is refused', () {
      expect(
        () => TimesheetImport.build(csv: 'a,b\n1,2\n', existing: const [], projects: const []),
        throwsFormatException,
      );
      expect(
        () => TimesheetImport.build(csv: '', existing: const [], projects: const []),
        throwsFormatException,
      );
    });
  });
}
