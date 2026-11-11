import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_time/app/time_config.dart';
import 'package:zerotrust_time/data/time_store.dart';
import 'package:zerotrust_time/l10n/l10n.dart';
import 'package:zerotrust_time/model/project.dart';
import 'package:zerotrust_time/model/time_entry.dart';
import 'package:zerotrust_time/notify/timer_notifier.dart';
import 'package:zerotrust_time/ui/entry_editor_page.dart';
import 'package:zerotrust_time/ui/home_page.dart';

/// Keeps entries and projects in memory, in place of the encrypted store.
class MemoryRepository extends TimeRepository {
  MemoryRepository(super.ref, {List<TimeEntry> entries = const [], List<Project> projects = const []}) {
    for (final e in entries) {
      _entries[e.id] = e;
    }
    for (final p in projects) {
      _projects[p.id] = p;
    }
  }

  final _entries = <String, TimeEntry>{};
  final _projects = <String, Project>{};
  final _entryChanges = StreamController<List<TimeEntry>>.broadcast();
  final _projectChanges = StreamController<List<Project>>.broadcast();

  List<TimeEntry> get entries =>
      _entries.values.toList()..sort((a, b) => b.start.compareTo(a.start));
  List<Project> get projects => _projects.values.toList();

  Stream<List<TimeEntry>> watchEntries() async* {
    yield entries;
    yield* _entryChanges.stream;
  }

  Stream<List<Project>> watchProjects() async* {
    yield projects;
    yield* _projectChanges.stream;
  }

  @override
  Future<void> saveEntry(TimeEntry entry) async {
    await Future<void>.delayed(Duration.zero); // Like the real store: not instant.
    _entries[entry.id] = entry;
    _entryChanges.add(entries);
  }

  @override
  Future<void> deleteEntry(String id) async {
    _entries.remove(id);
    _entryChanges.add(entries);
  }

  @override
  Future<List<TimeEntry>> allEntries() async => entries;

  @override
  Future<List<Project>> allProjects() async => projects;

  @override
  Future<void> saveProject(Project project) async {
    _projects[project.id] = project;
    _projectChanges.add(projects);
  }

  @override
  Future<void> deleteProject(String id) async {
    _projects.remove(id);
    _projectChanges.add(projects);
  }
}

late MemoryRepository repo;

Widget app(
  Widget home, {
  List<TimeEntry> entries = const [],
  List<Project> projects = const [],
  Locale locale = ZtLanguages.english,
}) {
  return ProviderScope(
    overrides: [
      ztAppConfigProvider.overrideWithValue(timeAppConfig),
      ztPreferencesStoreProvider.overrideWithValue(InMemoryPreferencesStore()),
      timerNotifierProvider.overrideWithValue(NoopTimerNotifier()),
      timeRepositoryProvider.overrideWith(
        (ref) => repo = MemoryRepository(ref, entries: entries, projects: projects),
      ),
      entriesProvider.overrideWith(
        (ref) => (ref.watch(timeRepositoryProvider) as MemoryRepository).watchEntries(),
      ),
      projectsProvider.overrideWith(
        (ref) => (ref.watch(timeRepositoryProvider) as MemoryRepository).watchProjects(),
      ),
    ],
    child: MaterialApp(
      // The suite's real theme: its full-width buttons break rows that a
      // plain theme lets through.
      theme: ZtTheme.light(accent: timeAppConfig.accent),
      locale: locale,
      supportedLocales: ZtLanguages.supported,
      localizationsDelegates: const [AppL10n.delegate, ...ZtLanguages.delegates],
      home: home,
    ),
  );
}

void main() {
  const web = Project(id: 'web', name: 'Website', client: 'Acme', hourlyRate: 100, billable: true);
  final now = DateTime.now();
  final today9 = DateTime(now.year, now.month, now.day, 9);
  final done = TimeEntry(
    id: 'done',
    description: 'Landing page',
    projectId: 'web',
    billable: true,
    start: today9.subtract(const Duration(days: 1)),
    end: today9.subtract(const Duration(days: 1)).add(const Duration(minutes: 90)),
  );

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
  }

  testWidgets('an empty account explains itself', (tester) async {
    phone(tester);
    await tester.pumpWidget(app(const HomePage()));
    await tester.pumpAndSettle();
    expect(find.text('Nothing tracked yet'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();
    expect(find.text('No projects yet'), findsOneWidget);
  });

  testWidgets('start, see it running, stop', (tester) async {
    phone(tester);
    await tester.pumpWidget(app(const HomePage(), entries: [done], projects: const [web]));
    await tester.pumpAndSettle();
    expect(find.text('Landing page'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('1:30:00'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Write tests');
    await tester.tap(find.text('Start'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Stop'), findsOneWidget);
    expect(find.text('Write tests'), findsOneWidget);
    expect(repo.entries.where((e) => e.running), hasLength(1));
    expect(find.text('Start'), findsNothing);

    await tester.tap(find.text('Stop'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Stop'), findsNothing);
    expect(find.text('Start'), findsOneWidget);
    expect(repo.entries.where((e) => e.running), isEmpty);
    expect(repo.entries, hasLength(2));
    expect(find.text('Today'), findsOneWidget);
  });

  testWidgets('"Start again" copies an entry and stops the running one', (tester) async {
    phone(tester);
    final running = TimeEntry(id: 'run', description: 'Email', start: now.subtract(const Duration(minutes: 5)));
    await tester.pumpWidget(app(const HomePage(), entries: [done, running], projects: const [web]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Email'), findsOneWidget);

    await tester.tap(find.byTooltip('Start again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final nowRunning = repo.entries.where((e) => e.running).toList();
    expect(nowRunning, hasLength(1));
    expect(nowRunning.single.description, 'Landing page');
    expect(nowRunning.single.projectId, 'web');
    expect(nowRunning.single.billable, isTrue);
    expect(repo.entries.firstWhere((e) => e.id == 'run').running, isFalse);
  });

  testWidgets('reports total the week by project', (tester) async {
    phone(tester);
    final entries = [
      TimeEntry(
        id: 'a',
        projectId: 'web',
        billable: true,
        start: today9,
        end: today9.add(const Duration(hours: 2)),
      ),
      TimeEntry(id: 'b', start: today9.add(const Duration(hours: 3)), end: today9.add(const Duration(hours: 4))),
    ];
    await tester.pumpWidget(app(const HomePage(), entries: entries, projects: const [web]));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();
    expect(find.text('3h'), findsOneWidget); // Total.
    expect(find.text('2h'), findsOneWidget); // Billable.
    expect(find.text(r'$200.00'), findsOneWidget);
    expect(find.text('Website · Acme'), findsOneWidget);
    expect(find.text('No project'), findsWidgets);
    expect(find.textContaining('67%'), findsOneWidget);

    await tester.tap(find.text('Day'));
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsWidgets);
    await tester.tap(find.byTooltip('Earlier'));
    await tester.pumpAndSettle();
    expect(find.text('No time tracked in this period'), findsOneWidget);
  });

  testWidgets('adding time by hand saves a finished entry', (tester) async {
    phone(tester);
    await tester.pumpWidget(app(const EntryEditorPage(), projects: const [web]));
    await tester.pumpAndSettle();
    expect(find.text('Add time'), findsOneWidget);
    expect(find.text('1h'), findsOneWidget); // The last hour by default.
    await tester.enterText(find.widgetWithText(TextField, 'Description'), 'Client call');
    await tester.enterText(find.widgetWithText(TextField, 'Tags'), 'meeting, #sales, meeting');
    await tester.tap(find.text('No project'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Website'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final saved = repo.entries.single;
    expect(saved.description, 'Client call');
    expect(saved.tags, ['meeting', 'sales']);
    expect(saved.projectId, 'web');
    expect(saved.billable, isTrue); // The project's default.
    expect(saved.end!.difference(saved.start), const Duration(hours: 1));
  });

  test('two starts at once still leave one timer running', () async {
    final container = ProviderContainer(
      overrides: [
        timeRepositoryProvider.overrideWith((ref) => repo = MemoryRepository(ref)),
      ],
    );
    addTearDown(container.dispose);
    final r = container.read(timeRepositoryProvider);
    await Future.wait([r.start(description: 'One'), r.start(description: 'Two')]);
    expect(repo.entries, hasLength(2));
    expect(repo.entries.where((e) => e.running), hasLength(1));
    // A failed start doesn't block the next one.
    await r.stopAll();
    expect(repo.entries.where((e) => e.running), isEmpty);
  });

  test('starting a timer stops the one already running', () async {
    final container = ProviderContainer(
      overrides: [
        timeRepositoryProvider.overrideWith((ref) => repo = MemoryRepository(ref)),
      ],
    );
    addTearDown(container.dispose);
    final r = container.read(timeRepositoryProvider);
    final t0 = DateTime(2026, 11, 10, 9);
    final first = await r.start(description: 'One', at: t0);
    final second = await r.start(description: 'Two', at: t0.add(const Duration(minutes: 30)));
    final stored = {for (final e in repo.entries) e.id: e};
    expect(stored[first.id]!.end, t0.add(const Duration(minutes: 30)));
    expect(stored[second.id]!.running, isTrue);
    // Stopping at a time before the start never gives a negative length.
    await r.stop(stored[second.id]!, at: t0);
    expect(repo.entries.firstWhere((e) => e.id == second.id).end, second.start);
  });
}
