import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/time_settings.dart';
import '../data/time_store.dart';
import '../model/project.dart';
import '../model/time_entry.dart';
import '../util/format.dart';
import 'project_editor_page.dart';
import 'project_widgets.dart';

class ProjectsTab extends ConsumerWidget {
  const ProjectsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider);
    final entries = ref.watch(entriesProvider).value ?? const <TimeEntry>[];
    final decimal = ref.watch(timeSettingsProvider).decimalHours;
    final list = projects.value;
    if (list == null) {
      return projects.hasError
          ? const Center(child: Text('Could not load your projects'))
          : const Center(child: CircularProgressIndicator());
    }
    if (list.isEmpty) {
      return const _Empty();
    }
    final now = DateTime.now();
    final totals = <String, Duration>{};
    for (final e in entries) {
      final id = e.projectId;
      if (id != null) totals[id] = (totals[id] ?? Duration.zero) + e.durationAt(now);
    }
    final active = [for (final p in list) if (!p.archived) p];
    final archived = [for (final p in list) if (p.archived) p];

    Widget tile(Project p) => ListTile(
      leading: ProjectDot(p.color, size: 16),
      title: Text(p.name),
      subtitle: Text(
        [
          if (p.client.trim().isNotEmpty) p.client.trim(),
          formatDuration(totals[p.id] ?? Duration.zero, decimal: decimal),
        ].join(' · '),
      ),
      trailing: p.hourlyRate == null
          ? null
          : Text('${formatAmount(p.hourlyRate!, ref.watch(timeSettingsProvider).currency)}/h'),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ProjectEditorPage(project: p)),
      ),
    );

    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        for (final p in active) tile(p),
        if (archived.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
            child: Text('Archived', style: Theme.of(context).textTheme.labelLarge),
          ),
          for (final p in archived) Opacity(opacity: 0.6, child: tile(p)),
        ],
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_outlined, size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text('No projects yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Group your time by project or client, and set an hourly rate '
              'to see what it is worth.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
