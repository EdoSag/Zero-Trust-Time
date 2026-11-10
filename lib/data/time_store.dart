import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import '../model/project.dart';
import '../model/time_entry.dart';

/// Entries are items with `kind: entry`, projects `kind: project`.
final entriesCollection = ZtCollection<TimeEntry>(
  kind: 'entry',
  version: 1,
  fromJson: (id, json, updatedAt) =>
      TimeEntry.fromJson(id, json, updatedAt) ??
      TimeEntry(
        // Unreadable times: keep it visible (as zero length) rather than
        // drop it.
        id: id,
        description: (json['description'] as String?) ?? '',
        start: updatedAt.toLocal(),
        end: updatedAt.toLocal(),
      ),
  toJson: (e) => e.toJson(),
  idOf: (e) => e.id,
);

final projectsCollection = ZtCollection<Project>(
  kind: 'project',
  version: 1,
  fromJson: (id, json, _) => Project.fromJson(id, json),
  toJson: (p) => p.toJson(),
  idOf: (p) => p.id,
);

/// Every entry in the account, newest first.
final entriesProvider = StreamProvider<List<TimeEntry>>((ref) async* {
  final store = await ref.watch(ztLocalStoreProvider.future);
  List<TimeEntry> sorted(List<TimeEntry> list) =>
      [...list]..sort((a, b) => b.start.compareTo(a.start));
  if (store is ZtLocalStore) {
    yield* entriesCollection.watch(store).map(sorted);
  } else {
    yield sorted(await entriesCollection.list(store));
  }
});

/// Every project, archived ones included, by name.
final projectsProvider = StreamProvider<List<Project>>((ref) async* {
  final store = await ref.watch(ztLocalStoreProvider.future);
  List<Project> sorted(List<Project> list) => [...list]
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  if (store is ZtLocalStore) {
    yield* projectsCollection.watch(store).map(sorted);
  } else {
    yield sorted(await projectsCollection.list(store));
  }
});

/// The running timers, newest first. Normally one or none; two devices that
/// both started one offline leave two until one is stopped.
final runningProvider = Provider<List<TimeEntry>>((ref) {
  final entries = ref.watch(entriesProvider).value ?? const <TimeEntry>[];
  return [for (final e in entries) if (e.running) e];
});

final timeRepositoryProvider = Provider<TimeRepository>((ref) => TimeRepository(ref));

/// Saves and deletes through the shared sync controller, so every edit is
/// encrypted, stored locally and pushed to the account's other devices.
class TimeRepository {
  TimeRepository(this._ref);
  final Ref _ref;

  static const _uuid = Uuid();

  SyncController get _sync => _ref.read(ztSyncControllerProvider.notifier);
  Future<LocalItemStore> get _store => _ref.read(ztLocalStoreProvider.future);

  static String newId() => _uuid.v4();

  Future<void> saveEntry(TimeEntry entry) async {
    final withCreated = entry.createdAt == null
        ? entry.copyWith(createdAt: DateTime.now())
        : entry;
    await entriesCollection.save(_sync, await _store, withCreated);
  }

  Future<void> deleteEntry(String id) => entriesCollection.delete(_sync, id);

  Future<List<TimeEntry>> allEntries() async => entriesCollection.list(await _store);

  Future<List<Project>> allProjects() async => projectsCollection.list(await _store);

  /// The last start or stop, so the next one waits for it.
  Future<void> _turn = Future.value();

  /// Runs [action] after every start and stop asked for before it. Two
  /// quick taps on Start would otherwise both find nothing running and
  /// leave two timers.
  Future<T> _inTurn<T>(Future<T> Function() action) {
    final result = _turn.then((_) => action());
    _turn = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  /// Starts a timer now, stopping any that is running: one thing at a time.
  Future<TimeEntry> start({
    String description = '',
    String? projectId,
    List<String> tags = const [],
    bool billable = false,
    DateTime? at,
  }) => _inTurn(() async {
    final now = at ?? DateTime.now();
    await _stopAll(now);
    final entry = TimeEntry(
      id: newId(),
      description: description.trim(),
      projectId: projectId,
      tags: tags,
      billable: billable,
      start: now,
    );
    await saveEntry(entry);
    return entry;
  });

  /// Starts a new timer with the same description, project and tags.
  Future<TimeEntry> continueEntry(TimeEntry e) => start(
    description: e.description,
    projectId: e.projectId,
    tags: e.tags,
    billable: e.billable,
  );

  Future<void> stop(TimeEntry entry, {DateTime? at}) =>
      _inTurn(() => _stop(entry, at ?? DateTime.now()));

  Future<void> stopAll({DateTime? at}) => _inTurn(() => _stopAll(at ?? DateTime.now()));

  Future<void> _stop(TimeEntry entry, DateTime now) async {
    if (!entry.running) return;
    await saveEntry(entry.copyWith(end: now.isBefore(entry.start) ? entry.start : now));
  }

  Future<void> _stopAll(DateTime now) async {
    for (final e in await allEntries()) {
      if (e.running) await _stop(e, now);
    }
  }

  Future<void> saveProject(Project project) async {
    await projectsCollection.save(_sync, await _store, project);
  }

  /// Deletes a project. Its entries stay, shown as "No project".
  Future<void> deleteProject(String id) => projectsCollection.delete(_sync, id);
}
