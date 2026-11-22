import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import '../model/place_rule.dart';
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

/// Start and stop by place (TM-3), kind `placeRule`.
final placeRulesCollection = ZtCollection<PlaceRule?>(
  kind: 'placeRule',
  version: 1,
  fromJson: (id, json, _) => PlaceRule.fromJson(id, json),
  toJson: (r) => r!.toJson(),
  idOf: (r) => r!.id,
);

/// Every place rule, by place name.
final placeRulesProvider = StreamProvider<List<PlaceRule>>((ref) async* {
  final store = await ref.watch(ztLocalStoreProvider.future);
  List<PlaceRule> sorted(List<PlaceRule?> list) => [
    for (final r in list) ?r,
  ]..sort((a, b) => a.place.name.toLowerCase().compareTo(b.place.name.toLowerCase()));
  if (store is ZtLocalStore) {
    yield* placeRulesCollection.watch(store).map(sorted);
  } else {
    yield sorted(await placeRulesCollection.list(store));
  }
});

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
    EntryLink? link,
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
      link: link,
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
    link: e.link,
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

  /// The newest entry linked to the same task or event, so time started
  /// from it again lands in the same project with the same tags.
  Future<TimeEntry?> lastLinkedTo(EntryLink link) async {
    TimeEntry? best;
    for (final e in await allEntries()) {
      final l = e.link;
      if (l == null || l.app != link.app || l.id != link.id) continue;
      if (best == null || e.start.isAfter(best.start)) best = e;
    }
    return best;
  }

  Future<void> savePlaceRule(PlaceRule rule) async {
    await placeRulesCollection.save(_sync, await _store, rule);
  }

  Future<void> deletePlaceRule(String id) => placeRulesCollection.delete(_sync, id);

  /// Deletes a project. Its entries stay, shown as "No project".
  Future<void> deleteProject(String id) => projectsCollection.delete(_sync, id);
}
