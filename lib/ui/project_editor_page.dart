import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/time_settings.dart';
import '../data/time_store.dart';
import '../model/project.dart';

/// Creates or edits a project. Pops with the saved project.
class ProjectEditorPage extends ConsumerStatefulWidget {
  const ProjectEditorPage({super.key, this.project});

  final Project? project;

  @override
  ConsumerState<ProjectEditorPage> createState() => _ProjectEditorPageState();
}

class _ProjectEditorPageState extends ConsumerState<ProjectEditorPage> {
  late final _name = TextEditingController(text: widget.project?.name ?? '');
  late final _client = TextEditingController(text: widget.project?.client ?? '');
  late final _rate = TextEditingController(
    text: widget.project?.hourlyRate == null ? '' : _trim(widget.project!.hourlyRate!),
  );
  late int _color = widget.project?.color ?? projectColors.first;
  late bool _billable = widget.project?.billable ?? false;
  late bool _archived = widget.project?.archived ?? false;
  String? _nameError;
  String? _rateError;

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void dispose() {
    _name.dispose();
    _client.dispose();
    _rate.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final rateText = _rate.text.trim().replaceAll(',', '.');
    final rate = rateText.isEmpty ? null : double.tryParse(rateText);
    setState(() {
      _nameError = name.isEmpty ? 'Give the project a name' : null;
      _rateError = rateText.isNotEmpty && (rate == null || rate < 0)
          ? 'Enter a number, like 60 or 42.50'
          : null;
    });
    if (_nameError != null || _rateError != null) return;
    final project = Project(
      id: widget.project?.id ?? TimeRepository.newId(),
      name: name,
      client: _client.text.trim(),
      color: _color,
      hourlyRate: rate,
      billable: _billable,
      archived: _archived,
    );
    await ref.read(timeRepositoryProvider).saveProject(project);
    if (mounted) Navigator.of(context).pop(project);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Delete this project?'),
        content: const Text(
          'Its time entries are kept and show as "No project". To hide a '
          'project but keep its reports, archive it instead.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(d).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(timeRepositoryProvider).deleteProject(widget.project!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(timeSettingsProvider).currency;
    final editing = widget.project != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Edit project' : 'New project'),
        actions: [
          if (editing)
            IconButton(
              tooltip: 'Delete project',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            autofocus: !editing,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Project name',
              errorText: _nameError,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _client,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Client (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Text('Colour', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final c in projectColors)
                Semantics(
                  button: true,
                  selected: c == _color,
                  label: 'Colour ${projectColors.indexOf(c) + 1}',
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() => _color = c),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: Color(c), shape: BoxShape.circle),
                      child: c == _color
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : null,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _rate,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Hourly rate (optional)',
              prefixText: '$currency ',
              helperText: 'Reports turn billable hours into an amount',
              errorText: _rateError,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Billable by default'),
            subtitle: const Text('New entries on this project start as billable'),
            value: _billable,
            onChanged: (v) => setState(() => _billable = v),
          ),
          if (editing)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Archived'),
              subtitle: const Text('Hidden when picking a project; reports keep it'),
              value: _archived,
              onChanged: (v) => setState(() => _archived = v),
            ),
        ],
      ),
    );
  }
}
