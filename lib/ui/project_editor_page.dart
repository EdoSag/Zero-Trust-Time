import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/time_settings.dart';
import '../data/time_store.dart';
import '../model/project.dart';
import '../l10n/l10n.dart';

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
      _nameError = name.isEmpty ? context.l10n.projectNameRequired : null;
      _rateError = rateText.isNotEmpty && (rate == null || rate < 0)
          ? context.l10n.rateInvalid
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
        title: Text(d.l10n.deleteProjectQuestion),
        content: Text(d.l10n.deleteProjectBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(false), child: Text(d.l10n.cancel)),
          TextButton(onPressed: () => Navigator.of(d).pop(true), child: Text(d.l10n.delete)),
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
        title: Text(editing ? context.l10n.editProject : context.l10n.newProject),
        actions: [
          if (editing)
            IconButton(
              tooltip: context.l10n.deleteProject,
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          TextButton(onPressed: _save, child: Text(context.l10n.save)),
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
              labelText: context.l10n.projectName,
              errorText: _nameError,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _client,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: context.l10n.clientOptional,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Text(context.l10n.colour, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final c in projectColors)
                Semantics(
                  button: true,
                  selected: c == _color,
                  label: context.l10n.colourNumber(projectColors.indexOf(c) + 1),
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
              labelText: context.l10n.hourlyRateOptional,
              prefixText: '$currency ',
              helperText: context.l10n.hourlyRateHelper,
              errorText: _rateError,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.billableByDefault),
            subtitle: Text(context.l10n.billableByDefaultBody),
            value: _billable,
            onChanged: (v) => setState(() => _billable = v),
          ),
          if (editing)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.archived),
              subtitle: Text(context.l10n.archivedBody),
              value: _archived,
              onChanged: (v) => setState(() => _archived = v),
            ),
        ],
      ),
    );
  }
}
