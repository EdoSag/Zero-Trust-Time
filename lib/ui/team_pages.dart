import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zt_sharing_ui/zt_sharing_ui.dart';

import '../app/time_settings.dart';
import '../l10n/l10n.dart';
import '../team/team.dart';

/// Shows [spaceId]'s time (a team) or the account's own (null).
Future<void> switchWorkspace(WidgetRef ref, String? spaceId) =>
    ref.read(timeSettingsProvider.notifier).update((s) => s.copyWith(teamId: spaceId));

/// Business mode's switcher: the account's own time, each team, people
/// waiting to join a team this account owns, and new or join a team.
Future<void> showWorkspaceSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (sheet) => Consumer(
    builder: (context, ref, _) {
      final l = context.l10n;
      final current = ref.watch(workspaceProvider);
      final teams = ref.watch(teamsProvider).value ?? const <Team>[];
      final pending = ref.watch(ztPendingJoinsProvider).value ?? const <PendingJoin>[];
      final ready = ref.watch(ztSpacesProvider).ready;
      String teamName(String spaceId) {
        for (final t in teams) {
          if (t.spaceId == spaceId) return t.name.isEmpty ? l.teamUnnamed : t.name;
        }
        return l.teamUnnamed;
      }

      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(l.workspaceMine),
                subtitle: Text(l.workspaceMineBody),
                selected: current == null,
                trailing: current == null ? const Icon(Icons.check) : null,
                onTap: () async {
                  await switchWorkspace(ref, null);
                  if (sheet.mounted) Navigator.of(sheet).pop();
                },
              ),
              for (final t in teams)
                ListTile(
                  leading: const Icon(Icons.groups_outlined),
                  title: Text(t.name.isEmpty ? l.teamUnnamed : t.name),
                  subtitle: Text(
                    t.ready
                        ? (t.isOwner ? l.teamOwnerCount(t.members.length) : l.teamMemberCount(t.members.length))
                        : l.teamWaiting,
                  ),
                  selected: t.spaceId == current,
                  enabled: t.ready,
                  onTap: () async {
                    await switchWorkspace(ref, t.spaceId);
                    if (sheet.mounted) Navigator.of(sheet).pop();
                  },
                  trailing: IconButton(
                    tooltip: l.teamManage,
                    icon: const Icon(Icons.manage_accounts_outlined),
                    onPressed: () => openTeam(context, t),
                  ),
                ),
              for (final j in pending)
                ListTile(
                  leading: const Icon(Icons.person_add_alt_1_outlined),
                  title: Text(l.teamJoinRequest(j.name, teamName(j.spaceId))),
                  subtitle: Text(l.teamJoinRequestBody),
                  onTap: () => ztConfirmJoin(context, ref, j, title: teamName(j.spaceId)),
                ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.group_add_outlined),
                title: Text(l.teamCreate),
                subtitle: Text(l.teamCreateBody),
                enabled: ready,
                onTap: () async {
                  Navigator.of(sheet).pop();
                  await createTeam(context, ref);
                },
              ),
              ListTile(
                leading: const Icon(Icons.login),
                title: Text(l.teamJoin),
                enabled: ready,
                onTap: () async {
                  Navigator.of(sheet).pop();
                  await joinTeam(context);
                },
              ),
            ],
          ),
        ),
      );
    },
  ),
);

/// The shared members page: invite, confirm who joins, owners, leave.
Future<void> openTeam(BuildContext context, Team team, {bool inviteNow = false}) =>
    ZtSpacePage.open(
      context,
      spaceId: team.spaceId,
      title: team.name.isEmpty ? context.l10n.teamUnnamed : team.name,
      description: context.l10n.teamPageBody,
      inviteNow: inviteNow,
    );

/// Names a new team, makes this account its owner, switches to it and
/// opens the invite.
Future<void> createTeam(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final name = await showDialog<String>(context: context, builder: (_) => const _TeamNameDialog());
  if (name == null || name.trim().isEmpty || !context.mounted) return;
  final myName = await ztAskSharingName(context, ref, title: l.teamYourName);
  if (myName == null || !context.mounted) return;
  final spaces = ref.read(ztSpacesProvider.notifier);
  try {
    final space = await spaces.create(myName: myName);
    await spaces.save(space.id, teamItemId, {
      ZtCollection.kindKey: teamKind,
      ZtCollection.versionKey: 1,
      'name': name.trim(),
    });
    await switchWorkspace(ref, space.id);
    ref.invalidate(teamsProvider);
    if (!context.mounted) return;
    await openTeam(
      context,
      Team(spaceId: space.id, name: name.trim(), isOwner: true),
      inviteNow: true,
    );
  } on Object {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.teamNeedsInternet), duration: const Duration(seconds: 4)),
      );
    }
  }
}

/// Answers a team invite (pasted, scanned, or opened from a link). The team
/// shows up once an owner compares the code and lets this account in.
Future<void> joinTeam(BuildContext context, {String? link}) => Navigator.of(context).push(
  MaterialPageRoute<void>(builder: (_) => ZtJoinSpacePage(initialLink: link)),
);

class _TeamNameDialog extends StatefulWidget {
  const _TeamNameDialog();

  @override
  State<_TeamNameDialog> createState() => _TeamNameDialogState();
}

class _TeamNameDialogState extends State<_TeamNameDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _done() => Navigator.of(context).pop(_name.text.trim());

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.teamCreate),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.teamCreateExplain),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: l.teamName,
              hintText: l.teamNameHint,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _done(),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.cancel)),
        TextButton(onPressed: _done, child: Text(l.teamCreateAction)),
      ],
    );
  }
}
