import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_time/model/project.dart';
import 'package:zerotrust_time/model/time_entry.dart';
import 'package:zerotrust_time/widget/timer_widget.dart';

void main() {
  final t0 = DateTime(2026, 11, 10, 9);
  const web = Project(id: 'web', name: 'Website', color: 0xFF3B82F6);
  const admin = Project(id: 'admin', name: 'Admin', color: 0xFF10B981);
  const old = Project(id: 'old', name: 'Old', archived: true);

  group('timer widget content', () {
    final entries = [
      TimeEntry(
        id: '3',
        description: 'Fix header',
        projectId: 'web',
        start: t0.add(const Duration(hours: 3)),
      ),
      TimeEntry(
        id: '2',
        projectId: 'old',
        start: t0.add(const Duration(hours: 2)),
        end: t0.add(const Duration(hours: 3)),
      ),
      TimeEntry(
        id: '1',
        projectId: 'admin',
        start: t0,
        end: t0.add(const Duration(hours: 1)),
      ),
    ];

    test('details off: only that a timer runs, no names, no projects', () {
      final s = TimerWidgetState.from(
        entries: entries,
        projects: const [web, admin, old],
        details: false,
      );
      expect(s.runningSince, t0.add(const Duration(hours: 3)));
      expect(s.title, 'Timer running');
      expect(s.recent, isEmpty);
    });

    test(
      'details on: the description, and recent projects without archived ones',
      () {
        final s = TimerWidgetState.from(
          entries: entries,
          projects: const [web, admin, old],
          details: true,
        );
        expect(s.title, 'Fix header');
        expect(s.color, 0xFF3B82F6);
        expect(s.recent.map((p) => p.id), ['web', 'admin']);
      },
    );

    test('nothing running', () {
      final s = TimerWidgetState.from(
        entries: entries.skip(1).toList(),
        projects: const [web, admin],
        details: true,
      );
      expect(s.runningSince, isNull);
      expect(s.recent.map((p) => p.id), ['admin']);
    });
  });

  test('widget taps are read in order, with their times', () {
    final ms = t0.millisecondsSinceEpoch;
    final taps = WidgetTimerAction.parse(
      'start|$ms|web\nnonsense\nstop|${ms + 60000}\nstart|${ms + 120000}|',
    );
    expect(taps, hasLength(3));
    expect(taps[0].stop, isFalse);
    expect(taps[0].projectId, 'web');
    expect(taps[0].at, t0);
    expect(taps[1].stop, isTrue);
    expect(taps[2].projectId, isNull);
    expect(WidgetTimerAction.parse(null), isEmpty);
  });
}
