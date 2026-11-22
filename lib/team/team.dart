import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import '../app/time_settings.dart';
import '../model/time_entry.dart';

/// Business mode (roadmap TM-6): a team tracks time together in a shared
/// space (Z24). Everything in it is end-to-end encrypted with the team's
/// keys; the server sees neither names nor times.
///
/// In a team space:
/// - item `team` (kind `team`) holds the team's name;
/// - projects (kind `project`) are shared by everyone;
/// - entries (kind `entry`) have ids `entry/<user id>/<uuid>`.
///
/// Only team owners (space admins) may create or change projects and the
/// team's name; each member may write only their own entries, not even an
/// owner can log time in someone else's name. Every member sees the whole
/// team's time, so reports cover the team.
const timeSpacePolicy = SpacePolicy(
  adminOnlyKinds: {'project', teamKind},
  ownedPrefixes: {TimeEntry.teamPrefix},
);

const teamKind = 'team';
const teamItemId = 'team';

/// One team this account is in.
@immutable
class Team {
  const Team({
    required this.spaceId,
    required this.name,
    required this.isOwner,
    this.members = const [],
    this.ready = true,
  });

  final String spaceId;
  final String name;

  /// May change projects and the team's name, invite and remove people.
  final bool isOwner;
  final List<SpaceMember> members;

  /// False while this phone can't read the team yet (waiting to be let in
  /// by an owner, or before its first sync).
  final bool ready;

  String memberName(String? userId) {
    for (final m in members) {
      if (m.userId == userId) return m.name;
    }
    return '';
  }

  @override
  bool operator ==(Object other) =>
      other is Team &&
      other.spaceId == spaceId &&
      other.name == name &&
      other.isOwner == isOwner &&
      other.ready == ready &&
      listEquals(
        [for (final m in other.members) '${m.userId}|${m.name}'],
        [for (final m in members) '${m.userId}|${m.name}'],
      );

  @override
  int get hashCode => Object.hash(spaceId, name, isOwner, ready, members.length);
}

/// The teams this account is in, by name. Empty while locked or offline
/// before the first sync.
final teamsProvider = FutureProvider<List<Team>>((ref) async {
  final state = ref.watch(ztSpacesProvider);
  final teams = <Team>[];
  for (final e in state.entries) {
    final space = e.space;
    var name = '';
    if (space != null) {
      try {
        final json = (await space.store.get(teamItemId))?.json;
        if (json != null && json['name'] is String) name = json['name'] as String;
      } on Object {
        // Not readable yet.
      }
    }
    teams.add(Team(
      spaceId: e.info.id,
      name: name,
      isOwner: e.info.myRole == SpaceRole.admin,
      members: space?.members ?? const [],
      ready: space != null,
    ));
  }
  teams.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return teams;
});

/// Where new time goes and what the tabs show: the account's own time
/// (null) or a team's space id. Kept per phone in Time's settings; a team
/// this account left falls back to its own time.
final workspaceProvider = Provider<String?>((ref) {
  final chosen = ref.watch(timeSettingsProvider.select((s) => s.teamId));
  if (chosen == null) return null;
  final teams = ref.watch(teamsProvider).value;
  // Until the teams have loaded, trust the choice.
  if (teams == null) return chosen;
  return teams.any((t) => t.spaceId == chosen && t.ready) ? chosen : null;
});

/// The selected team, or null for the account's own time.
final currentTeamProvider = Provider<Team?>((ref) {
  final id = ref.watch(workspaceProvider);
  if (id == null) return null;
  for (final t in ref.watch(teamsProvider).value ?? const <Team>[]) {
    if (t.spaceId == id) return t;
  }
  return null;
});

/// Whether this account may add and change projects where it is: always
/// in its own time, only as an owner in a team.
final canEditProjectsProvider = Provider<bool>((ref) {
  if (ref.watch(workspaceProvider) == null) return true;
  return ref.watch(currentTeamProvider)?.isOwner ?? false;
});

/// This account's user id.
final myUserIdProvider = Provider<String?>(
  (ref) => ref.watch(accountServiceProvider).currentUserId,
);
