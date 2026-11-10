import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/time_store.dart';
import '../model/time_entry.dart';
import '../util/format.dart';
import 'project_widgets.dart';

/// Adds time by hand, or edits an entry (a running one too).
class EntryEditorPage extends ConsumerStatefulWidget {
  const EntryEditorPage({super.key, this.entry});

  final TimeEntry? entry;

  @override
  ConsumerState<EntryEditorPage> createState() => _EntryEditorPageState();
}

class _EntryEditorPageState extends ConsumerState<EntryEditorPage> {
  late final _description = TextEditingController(text: widget.entry?.description ?? '');
  late final _tags = TextEditingController(text: widget.entry?.tags.join(', ') ?? '');
  late String? _projectId = widget.entry?.projectId;
  late bool _billable = widget.entry?.billable ?? false;
  late DateTime _start;
  DateTime? _end;
  String? _error;

  bool get _running => widget.entry?.running ?? false;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
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
      setState(() => _error = 'The end is before the start');
      return;
    }
    if (_running && _start.isAfter(DateTime.now())) {
      setState(() => _error = 'A running timer can\'t start in the future');
      return;
    }
    final entry = TimeEntry(
      id: widget.entry?.id ?? TimeRepository.newId(),
      description: _description.text.trim(),
      projectId: _projectId,
      tags: {
        for (final t in _tags.text.split(','))
          if (t.trim().isNotEmpty) t.trim().replaceFirst(RegExp('^#'), ''),
      }.toList(),
      billable: _billable,
      start: _start,
      end: _running ? null : end,
      createdAt: widget.entry?.createdAt,
    );
    await ref.read(timeRepositoryProvider).saveEntry(entry);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(_running ? 'Discard this timer?' : 'Delete this entry?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(d).pop(true),
            child: Text(_running ? 'Discard' : 'Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(timeRepositoryProvider).deleteEntry(widget.entry!.id);
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
        title: Text(_running ? 'Running timer' : editing ? 'Edit entry' : 'Add time'),
        actions: [
          if (editing)
            IconButton(
              tooltip: _running ? 'Discard timer' : 'Delete entry',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          TextButton(onPressed: _save, child: const Text('Save')),
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
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
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
          ListTile(
            leading: const Icon(Icons.play_circle_outline),
            title: const Text('Start'),
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
              title: const Text('End'),
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
            title: const Text('Billable'),
            value: _billable,
            onChanged: (v) => setState(() => _billable = v),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _tags,
              decoration: const InputDecoration(
                labelText: 'Tags',
                helperText: 'Separate with commas: meeting, design',
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
