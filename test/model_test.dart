import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_time/app/time_settings.dart';
import 'package:zerotrust_time/model/project.dart';
import 'package:zerotrust_time/model/report.dart';
import 'package:zerotrust_time/model/time_entry.dart';
import 'package:zerotrust_time/ui/reports_tab.dart';
import 'package:zerotrust_time/util/format.dart';

void main() {
  final nine = DateTime(2026, 11, 10, 9);

  test('an entry survives a round trip through JSON', () {
    final e = TimeEntry(
      id: 'a',
      description: 'Design review',
      projectId: 'p1',
      tags: const ['meeting', 'design'],
      billable: true,
      start: nine,
      end: nine.add(const Duration(minutes: 90)),
      createdAt: nine,
    );
    final back = TimeEntry.fromJson('a', e.toJson(), DateTime.utc(2026, 11, 10))!;
    expect(back.description, 'Design review');
    expect(back.projectId, 'p1');
    expect(back.tags, ['meeting', 'design']);
    expect(back.billable, isTrue);
    expect(back.start, nine);
    expect(back.end, nine.add(const Duration(minutes: 90)));
    expect(back.running, isFalse);
    // Stored in UTC, so another time zone reads the same instant.
    expect(e.toJson()['start'], nine.toUtc().toIso8601String());
  });

  test('a running entry has no end and counts up to now', () {
    final e = TimeEntry(id: 'r', start: nine);
    expect(e.running, isTrue);
    expect(e.toJson()['end'], isNull);
    expect(e.durationAt(nine.add(const Duration(minutes: 5))), const Duration(minutes: 5));
    // A clock that moved back never gives negative time.
    expect(e.durationAt(nine.subtract(const Duration(minutes: 5))), Duration.zero);
    expect(TimeEntry.fromJson('r', e.toJson(), DateTime.utc(2026))!.running, isTrue);
  });

  test('an entry without a start is not readable', () {
    expect(TimeEntry.fromJson('x', {'description': 'hi'}, DateTime.utc(2026)), isNull);
  });

  test('copyWith can clear the project and the end', () {
    final e = TimeEntry(id: 'a', start: nine, end: nine, projectId: 'p');
    expect(e.copyWith(projectId: null).projectId, isNull);
    expect(e.copyWith(end: null).running, isTrue);
    expect(e.copyWith(description: 'x').projectId, 'p');
  });

  test('a project survives a round trip through JSON', () {
    const p = Project(
      id: 'p',
      name: 'Website',
      client: 'Acme',
      color: 0xFF10B981,
      hourlyRate: 80,
      billable: true,
      archived: true,
    );
    final back = Project.fromJson('p', p.toJson());
    expect(back.name, 'Website');
    expect(back.client, 'Acme');
    expect(back.color, 0xFF10B981);
    expect(back.hourlyRate, 80);
    expect(back.billable, isTrue);
    expect(back.archived, isTrue);
    expect(p.copyWith(hourlyRate: null).hourlyRate, isNull);
  });

  group('reports', () {
    const web = Project(id: 'web', name: 'Website', hourlyRate: 100);
    const app = Project(id: 'app', name: 'App');
    final monday = DateTime(2026, 11, 9);
    TimeEntry entry(String id, DateTime start, int minutes, {String? project, bool billable = false}) =>
        TimeEntry(
          id: id,
          start: start,
          end: start.add(Duration(minutes: minutes)),
          projectId: project,
          billable: billable,
        );

    final entries = [
      entry('1', monday.add(const Duration(hours: 9)), 120, project: 'web', billable: true),
      entry('2', monday.add(const Duration(hours: 13)), 30, project: 'app'),
      entry('3', monday.add(const Duration(days: 1, hours: 10)), 60, project: 'web'),
      entry('4', monday.add(const Duration(days: 2, hours: 8)), 15), // no project
      entry('5', monday.add(const Duration(days: 2, hours: 9)), 45, project: 'deleted'),
      entry('old', monday.subtract(const Duration(days: 3)), 600, project: 'web'),
      // Still running, started Wednesday 11:00.
      TimeEntry(id: 'run', start: monday.add(const Duration(days: 2, hours: 11)), projectId: 'app'),
    ];

    final report = buildReport(
      entries: entries,
      projects: const [web, app],
      from: monday,
      to: monday.add(const Duration(days: 7)),
      now: monday.add(const Duration(days: 2, hours: 11, minutes: 30)),
    );

    test('totals count the range and the running timer up to now', () {
      // 120 + 30 + 60 + 15 + 45 + 30 running.
      expect(report.total, const Duration(minutes: 300));
      expect(report.billable, const Duration(minutes: 120));
      expect(report.entries.map((e) => e.id), isNot(contains('old')));
      expect(report.entries.first.id, 'run'); // Newest first.
    });

    test('amount is billable hours at the project rate', () {
      expect(report.amount, 200);
    });

    test('projects are longest first; unknown projects count as none, last on a tie', () {
      expect(report.byProject.map((p) => p.project?.id), ['web', 'app', null]);
      expect(report.byProject[0].total, const Duration(minutes: 180));
      expect(report.byProject[0].amount, 200);
      expect(report.byProject[1].total, const Duration(minutes: 60));
      expect(report.byProject[2].total, const Duration(minutes: 60));
      expect(report.byProject[2].entries, 2);
    });

    test('every day of the range has a bar', () {
      expect(report.byDay, hasLength(7));
      expect(report.byDay[0], (monday, const Duration(minutes: 150)));
      expect(report.byDay[2].$2, const Duration(minutes: 90));
      expect(report.byDay[6].$2, Duration.zero);
    });

    test('an entry past midnight counts on the day it started', () {
      final late = entry('late', DateTime(2026, 11, 10, 23), 120);
      final r = buildReport(
        entries: [late],
        projects: const [],
        from: DateTime(2026, 11, 10),
        to: DateTime(2026, 11, 11),
        now: DateTime(2026, 11, 12),
      );
      expect(r.total, const Duration(hours: 2));
      expect(groupByDay([late]).single.$1, DateTime(2026, 11, 10));
    });

    test('groupByDay is newest day and newest entry first', () {
      final groups = groupByDay(entries.where((e) => !e.running));
      expect(groups.first.$1, monday.add(const Duration(days: 2)));
      expect(groups.first.$2.map((e) => e.id), ['5', '4']);
      expect(groups.last.$2.single.id, 'old');
    });
  });

  test('report ranges', () {
    final d = DateTime(2026, 11, 10, 15); // A Tuesday.
    expect(rangeFor(ReportPeriod.day, d, 1), (DateTime(2026, 11, 10), DateTime(2026, 11, 11)));
    expect(rangeFor(ReportPeriod.week, d, DateTime.monday), (DateTime(2026, 11, 9), DateTime(2026, 11, 16)));
    expect(rangeFor(ReportPeriod.week, d, DateTime.sunday), (DateTime(2026, 11, 8), DateTime(2026, 11, 15)));
    expect(rangeFor(ReportPeriod.month, d, 1), (DateTime(2026, 11), DateTime(2026, 12)));
    expect(rangeFor(ReportPeriod.year, d, 1), (DateTime(2026), DateTime(2027)));
    // December rolls into the next year.
    expect(rangeFor(ReportPeriod.month, DateTime(2026, 12, 31), 1).$2, DateTime(2027));
  });

  test('durations and amounts read well', () {
    expect(formatClock(const Duration(hours: 1, minutes: 5, seconds: 9)), '1:05:09');
    expect(formatClock(const Duration(seconds: 7)), '0:00:07');
    expect(formatDuration(const Duration(hours: 7, minutes: 30)), '7h 30m');
    expect(formatDuration(const Duration(minutes: 45)), '45m');
    expect(formatDuration(const Duration(hours: 2)), '2h');
    expect(formatDuration(Duration.zero), '0m');
    expect(formatDuration(const Duration(hours: 7, minutes: 30), decimal: true), '7.50 h');
    expect(formatAmount(1234.5, r'$'), r'$1,234.50');
  });

  test('settings round-trip through preferences', () {
    const s = TimeSettings(
      weekStart: DateTime.sunday,
      currency: '₪',
      decimalHours: true,
      runningNotification: false,
      notificationText: true,
      nudgeAfterHours: null,
    );
    final back = TimeSettings.fromPrefs(s.toPrefs());
    expect(back.weekStart, DateTime.sunday);
    expect(back.currency, '₪');
    expect(back.decimalHours, isTrue);
    expect(back.runningNotification, isFalse);
    expect(back.notificationText, isTrue);
    expect(back.nudgeAfterHours, isNull);
    // Nothing saved yet: the defaults.
    final fresh = TimeSettings.fromPrefs(const {});
    expect(fresh.weekStart, isNull);
    expect(fresh.nudgeAfterHours, 8);
    expect(fresh.runningNotification, isTrue);
    expect(fresh.notificationText, isFalse);
  });
}
