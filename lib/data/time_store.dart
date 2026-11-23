import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import '../model/place_rule.dart';
import '../model/project.dart';
import '../model/time_entry.dart';
import '../team/team.dart';

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

/// Where items of a workspace live: the account's own store (null) or a
/// team's shared space.
final workspaceStoreProvider = FutureProvider.family<LocalItemStore, String?>((ref, space) async {
  if (space == null) return ref.watch(ztLocalStoreProvider.future);
  final spaces = await ref.watch(ztSharedSpacesProvider.future);
  return (await spaces.open(space)).store;
});

List<TimeEntry> _newestFirst(List<TimeEntry> list) =>
    [...list]..sort((a, b) => b.start.compareTo(a.start));

List<Project> _byName(List<Project> list) =>
    [...list]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

Stream<List<T>> _watch<T>(ZtCollection<T> c, LocalItemStore store) async* {
  if (store is ZtLocalStore) {
    yield* c.watch(store);
  } else {
    yield await c.list(store);
  }
}

Stream<List<TimeEntry>> _entriesOf(Ref ref, String? space) async* {
  final store = await ref.watch(workspaceStoreProvider(space).future);
  yield* _watch(entriesCollection, store).map(
    (list) => _newestFirst(space == null ? list : [for (final e in list) e.copyWith(space: space)]),
  );
}

Stream<List<Project>> _projectsOf(Ref ref, String? space) async* {
  final store = await ref.watch(workspaceStoreProvider(space).future);
  yield* _watch(projectsCollection, store).map(
    (list) => _byName(space == null ? list : [for (final p in list) p.copyWith(space: space)]),
  );
}

/// Entries of one workspace (everyone's, in a team), newest first.
final workspaceEntriesProvider =
    StreamProvider.family<List<TimeEntry>, String?>((ref, space) => _entriesOf(ref, space));

/// Every entry of the workspace on screen (the account's own time, or a
/// team's: everyone's), newest first.
final entriesProvider = StreamProvider<List<TimeEntry>>(
  (ref) => _entriesOf(ref, ref.watch(workspaceProvider)),
);

/// Every project of the workspace on screen, archived ones included, by
/// name.
final projectsProvider = StreamProvider<List<Project>>(
  (ref) => _projectsOf(ref, ref.watch(workspaceProvider)),
);

/// Whether [e] is this account's own time: everything in its own
/// workspace, and in a team the entries it logged.
bool isMine(TimeEntry e, String? me) => e.space == null || (me != null && e.ownerId == me);

/// This account's entries in the workspace on screen (in a team, not the
/// others'), newest first. The timer tab shows these.
final myEntriesProvider = Provider<AsyncValue<List<TimeEntry>>>((ref) {
  final all = ref.watch(entriesProvider);
  if (ref.watch(workspaceProvider) == null) return all;
  final me = ref.watch(myUserIdProvider);
  return all.whenData((list) => [for (final e in list) if (isMine(e, me)) e]);
});

/// This account's running timers in every workspace, newest first.
/// Normally one or none; two devices that both started one offline leave
/// two until one is stopped.
final runningProvider = Provider<List<TimeEntry>>((ref) {
  final current = ref.watch(workspaceProvider);
  final running = <TimeEntry>[
    for (final e in ref.watch(myEntriesProvider).value ?? const <TimeEntry>[])
      if (e.running) e,
  ];
  final teams = ref.watch(teamsProvider).value ?? const <Team>[];
  if (current != null || teams.isNotEmpty) {
    final me = ref.watch(myUserIdProvider);
    for (final space in <String?>[null, for (final t in teams) if (t.ready) t.spaceId]) {
      if (space == current) continue;
      for (final e in ref.watch(workspaceEntriesProvider(space)).value ?? const <TimeEntry>[]) {
        if (e.running && isMine(e, me)) running.add(e);
      }
    }
  }
  return running..sort((a, b) => b.start.compareTo(a.start));
});

final timeRepositoryProvider = Provider<TimeRepository>((ref) => TimeRepository(ref));

/// Saves and deletes through the shared sync controller, so every edit is
/// encrypted, stored locally and pushed to the account's other devices. A
/// team's entries and projects go through its shared space instead, to the
/// team's members.
class TimeRepository {
  TimeRepository(this._ref);
  final Ref _ref;

  static const _uuid = Uuid();

  SyncController get _sync => _ref.read(ztSyncControllerProvider.notifier);
  Future<LocalItemStore> get _store => _ref.read(ztLocalStoreProvider.future);
  Future<LocalItemStore> _storeOf(String? space) =>
      space == null ? _store : _ref.read(workspaceStoreProvider(space).future);

  static String newId() => _uuid.v4();

  /// A new entry's id: in a team it names who logged it.
  String newEntryId(String? space) {
    if (space == null) return newId();
    final me = _ref.read(myUserIdProvider);
    if (me == null) throw StateError('Not signed in');
    return '${TimeEntry.teamPrefix}$me/${newId()}';
  }

  /// Saves [value] of [c] in its workspace, keeping keys a newer version
  /// wrote.
  Future<void> _save<T>(ZtCollection<T> c, String? space, T value) async {
    if (space == null) return c.save(_sync, await _store, value);
    final id = c.idOf(value);
    final previous = (await (await _storeOf(space)).get(id))?.json;
    await _ref.read(ztSpacesProvider.notifier).save(
      space,
      id,
      c.encode(value, previous: previous != null && c.owns(previous) ? previous : null),
    );
  }

  Future<void> _delete(String? space, String id) => space == null
      ? _sync.delete(id)
      : _ref.read(ztSpacesProvider.notifier).delete(space, id);

  Future<void> saveEntry(TimeEntry entry) async {
    final withCreated = entry.createdAt == null
        ? entry.copyWith(createdAt: DateTime.now())
        : entry;
    await _save(entriesCollection, entry.space, withCreated);
  }

  Future<void> deleteEntry(String id, {String? space}) => _delete(space, id);

  /// The account's own entries (not a team's).
  Future<List<TimeEntry>> allEntries() async => entriesCollection.list(await _store);

  /// The account's own projects (not a team's).
  Future<List<Project>> allProjects() async => projectsCollection.list(await _store);

  /// Projects of the workspace on screen.
  Future<List<Project>> currentProjects() async {
    final space = _ref.read(workspaceProvider);
    if (space == null) return allProjects();
    return [
      for (final p in await projectsCollection.list(await _storeOf(space))) p.copyWith(space: space),
    ];
  }

  /// This account's entries in every workspace: its own and, in each
  /// team, the ones it logged.
  Future<List<TimeEntry>> _myEntriesEverywhere() async {
    final out = await allEntries();
    List<Team> teams;
    try {
      teams = await _ref.read(teamsProvider.future);
    } on Object {
      teams = const [];
    }
    if (teams.isEmpty) return out;
    final me = _ref.read(myUserIdProvider);
    for (final t in teams) {
      if (!t.ready) continue;
      try {
        for (final e in await entriesCollection.list(await _storeOf(t.spaceId))) {
          final inTeam = e.copyWith(space: t.spaceId);
          if (isMine(inTeam, me)) out.add(inTeam);
        }
      } on Object {
        // This team can't be read right now.
      }
    }
    return out;
  }

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

  /// Starts a timer now, stopping any that is running (in any workspace):
  /// one thing at a time. It goes to the workspace on screen unless
  /// [space] is given (null: the account's own; use [inWorkspace]).
  Future<TimeEntry> start({
    String description = '',
    String? projectId,
    List<String> tags = const [],
    bool billable = false,
    EntryLink? link,
    DateTime? at,
    Object? space = inWorkspace,
  }) => _inTurn(() async {
    final now = at ?? DateTime.now();
    final where = identical(space, inWorkspace) ? _ref.read(workspaceProvider) : space as String?;
    await _stopAll(now);
    final entry = TimeEntry(
      id: newEntryId(where),
      space: where,
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

  /// [start]'s default: the workspace on screen.
  static const inWorkspace = Object();

  /// Starts a new timer with the same description, project and tags, in
  /// the same workspace.
  Future<TimeEntry> continueEntry(TimeEntry e) => start(
    description: e.description,
    projectId: e.projectId,
    tags: e.tags,
    billable: e.billable,
    link: e.link,
    space: e.space,
  );

  Future<void> stop(TimeEntry entry, {DateTime? at}) =>
      _inTurn(() => _stop(entry, at ?? DateTime.now()));

  Future<void> stopAll({DateTime? at}) => _inTurn(() => _stopAll(at ?? DateTime.now()));

  Future<void> _stop(TimeEntry entry, DateTime now) async {
    if (!entry.running) return;
    await saveEntry(entry.copyWith(end: now.isBefore(entry.start) ? entry.start : now));
  }

  Future<void> _stopAll(DateTime now) async {
    for (final e in await _myEntriesEverywhere()) {
      if (e.running) await _stop(e, now);
    }
  }

  /// In a team only its owners may (the space refuses anyone else).
  Future<void> saveProject(Project project) => _save(projectsCollection, project.space, project);

  /// Deletes a project. Its entries stay, shown as "No project".
  Future<void> deleteProject(String id, {String? space}) => _delete(space, id);

  /// The newest entry linked to the same task or event, so time started
  /// from it again lands in the same project with the same tags.
  Future<TimeEntry?> lastLinkedTo(EntryLink link) async {
    TimeEntry? best;
    for (final e in await _myEntriesEverywhere()) {
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
}
