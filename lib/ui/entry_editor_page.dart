import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import '../data/time_store.dart';
import '../team/team.dart';
import '../model/time_entry.dart';
import '../util/format.dart';
import 'project_widgets.dart';
import '../l10n/l10n.dart';
import '../links/zt_links.dart';

/// Adds time by hand, or edits an entry (a running one too). Pops `true`
/// once saved.
class EntryEditorPage extends ConsumerStatefulWidget {
  const EntryEditorPage({super.key, this.entry, this.draft});

  /// The saved entry to edit.
  final TimeEntry? entry;

  /// A new entry filled in ahead, e.g. from a ZT Calendar event.
  final TimeEntry? draft;

  @override
  ConsumerState<EntryEditorPage> createState() => _EntryEditorPageState();
}

class _EntryEditorPageState extends ConsumerState<EntryEditorPage> {
  late final TimeEntry? _initial = widget.entry ?? widget.draft;
  late final _description = TextEditingController(text: _initial?.description ?? '');
  late final _tags = TextEditingController(text: _initial?.tags.join(', ') ?? '');
  late String? _projectId = _initial?.projectId;
  late bool _billable = _initial?.billable ?? false;
  late EntryLink? _link = _initial?.link;
  late DateTime _start;
  DateTime? _end;
  String? _error;

  /// ZT Tasks and ZT Calendar, when installed, to pick from.
  List<String> _pickable = const [];

  bool get _running => widget.entry?.running ?? false;

  @override
  void initState() {
    super.initState();
    _findPickable();
    final e = _initial;
    if (e != null) {
      _start = e.start;
      _end = e.end;
    } else {
      // A new entry: the last hour, to the minute.
      final now = DateTime.now();
      _end = DateTime(now.year, now.month, now.day, now.hour, now.minute);
      _start = _end!.subtract(const Duration(hours: 1));
    }
  }

  Future<void> _findPickable() async {
    final links = ref.read(ztLinksProvider);
    final found = <String>[
      for (final app in linkedApps.keys)
        if (await links.canPick(app)) app,
    ];
    if (mounted && found.isNotEmpty) setState(() => _pickable = found);
  }

  /// Picks a task or an event in its app; its title becomes the description
  /// (if there is none yet) and, for an event, its times the entry's.
  Future<void> _pickFrom(String app) async {
    // The other app's screen is not a reason to auto-lock behind it.
    final links = ref.read(ztLinksProvider);
    final item = await ref
        .read(vaultControllerProvider.notifier)
        .whileShowingSystemUi(() => links.pick(app));
    if (item == null || !mounted) return;
    setState(() {
      if (_description.text.trim().isEmpty) _description.text = item.description;
      _link = item.link ?? _link;
      if (item.hasTimes && !_running) {
        _start = item.start!;
        _end = item.end;
        _error = null;
      }
    });
  }

  Future<void> _openLink(EntryLink link) async {
    final opened = await ref.read(ztLinksProvider).open(link);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.linkedAppMissing(linkedAppName(link.app)))),
      );
    }
  }

  @override
  void dispose() {
    _description.dispose();
    _tags.dispose();
    super.dispose();
  }

  Future<DateTime?> _pick(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2200),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _save() async {
    final end = _end;
    if (!_running && end != null && end.isBefore(_start)) {
      setState(() => _error = context.l10n.endBeforeStart);
      return;
    }
    if (_running && _start.isAfter(DateTime.now())) {
      setState(() => _error = context.l10n.runningInFuture);
      return;
    }
    final space = _initial?.space ?? ref.read(workspaceProvider);
    final entry = TimeEntry(
      id: widget.entry?.id ?? ref.read(timeRepositoryProvider).newEntryId(space),
      space: space,
      description: _description.text.trim(),
      projectId: _projectId,
      tags: {
        for (final t in _tags.text.split(','))
          if (t.trim().isNotEmpty) t.trim().replaceFirst(RegExp('^#'), ''),
      }.toList(),
      billable: _billable,
      link: _link,
      start: _start,
      end: _running ? null : end,
      createdAt: widget.entry?.createdAt,
    );
    await ref.read(timeRepositoryProvider).saveEntry(entry);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(_running ? d.l10n.discardTimerQuestion : d.l10n.deleteEntryQuestion),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(false), child: Text(d.l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.of(d).pop(true),
            child: Text(_running ? d.l10n.discard : d.l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(timeRepositoryProvider).deleteEntry(widget.entry!.id, space: widget.entry!.space);
    if (mounted) Navigator.of(context).pop();
  }

  String _when(DateTime t) =>
      '${DateFormat.yMMMEd().format(t)}, ${formatTime(context, t)}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editing = widget.entry != null;
    final end = _end;
    return Scaffold(
      appBar: AppBar(
        title: Text(_running ? context.l10n.runningTimer : editing ? context.l10n.editEntry : context.l10n.addTime),
        actions: [
          if (editing)
            IconButton(
              tooltip: _running ? context.l10n.discardTimer : context.l10n.deleteEntry,
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          TextButton(onPressed: _save, child: Text(context.l10n.save)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _description,
              autofocus: !editing,
              textCapitalization: TextCapitalization.sentences,
              maxLines: null,
              decoration: InputDecoration(
                labelText: context.l10n.description,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: ProjectChip(
                projectId: _projectId,
                onChanged: (p) => setState(() {
                  _projectId = p?.id;
                  if (p != null && !editing) _billable = p.billable;
                }),
              ),
            ),
          ),
          if (_link case final link?)
            ListTile(
              leading: const Icon(Icons.link),
              title: Text(context.l10n.linkedTo(linkedAppName(link.app))),
              subtitle: link.title.isEmpty ? null : Text(link.title, maxLines: 2, overflow: TextOverflow.ellipsis),
              onTap: () => _openLink(link),
              trailing: IconButton(
                tooltip: context.l10n.removeLink,
                icon: const Icon(Icons.link_off),
                onPressed: () => setState(() => _link = null),
              ),
            )
          else if (_pickable.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final app in _pickable)
                    ActionChip(
                      avatar: Icon(app == 'calendar' ? Icons.event_outlined : Icons.task_alt),
                      label: Text(context.l10n.pickFromApp(linkedAppName(app))),
                      onPressed: () => _pickFrom(app),
                    ),
                ],
              ),
            ),
          ListTile(
            leading: const Icon(Icons.play_circle_outline),
            title: Text(context.l10n.start),
            subtitle: Text(_when(_start)),
            onTap: () async {
              final picked = await _pick(_start);
              if (picked == null) return;
              setState(() {
                // For a new entry, moving the start keeps its length.
                if (end != null && !editing) _end = picked.add(end.difference(_start));
                _start = picked;
                _error = null;
              });
            },
          ),
          if (!_running && end != null)
            ListTile(
              leading: const Icon(Icons.stop_circle_outlined),
              title: Text(context.l10n.end),
              subtitle: Text(_when(end)),
              trailing: Text(
                end.isBefore(_start) ? '' : formatDuration(end.difference(_start)),
                style: theme.textTheme.titleMedium,
              ),
              onTap: () async {
                final picked = await _pick(end);
                if (picked == null) return;
                setState(() {
                  _end = picked;
                  _error = null;
                });
              },
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ),
          SwitchListTile(
            secondary: const Icon(Icons.paid_outlined),
            title: Text(context.l10n.billable),
            value: _billable,
            onChanged: (v) => setState(() => _billable = v),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _tags,
              decoration: InputDecoration(
                labelText: context.l10n.tags,
                helperText: context.l10n.tagsHelper,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
