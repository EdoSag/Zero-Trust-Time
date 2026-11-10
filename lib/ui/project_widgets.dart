import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/time_store.dart';
import '../model/project.dart';
import 'project_editor_page.dart';

class ProjectDot extends StatelessWidget {
  const ProjectDot(this.color, {super.key, this.size = 10});
  final int color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: Color(color), shape: BoxShape.circle),
  );
}

/// "Project · Client", or just the project.
String projectLabel(Project p) =>
    p.client.trim().isEmpty ? p.name : '${p.name} · ${p.client.trim()}';

/// A chip that shows the chosen project and opens the picker.
class ProjectChip extends ConsumerWidget {
  const ProjectChip({super.key, required this.projectId, required this.onChanged});

  final String? projectId;

  /// Called with the picked project, or null for "No project".
  final ValueChanged<Project?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    Project? current;
    for (final p in projects) {
      if (p.id == projectId) current = p;
    }
    return ActionChip(
      avatar: ProjectDot(current?.color ?? noProjectColor),
      label: Text(
        current == null ? 'No project' : projectLabel(current),
        overflow: TextOverflow.ellipsis,
      ),
      onPressed: () async {
        final picked = await pickProject(context, selected: projectId);
        if (picked != null) onChanged(picked.project);
      },
    );
  }
}

/// The result of the project picker: a project, or "No project".
class PickedProject {
  const PickedProject(this.project);
  final Project? project;
}

/// Bottom sheet listing the projects that aren't archived. Null: dismissed.
Future<PickedProject?> pickProject(BuildContext context, {String? selected}) {
  return showModalBottomSheet<PickedProject>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => Consumer(
      builder: (context, ref, _) {
        final projects = [
          for (final p in ref.watch(projectsProvider).value ?? const <Project>[])
            if (!p.archived || p.id == selected) p,
        ];
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  leading: const ProjectDot(noProjectColor, size: 14),
                  title: const Text('No project'),
                  selected: selected == null,
                  onTap: () => Navigator.of(sheet).pop(const PickedProject(null)),
                ),
                for (final p in projects)
                  ListTile(
                    leading: ProjectDot(p.color, size: 14),
                    title: Text(p.name),
                    subtitle: p.client.trim().isEmpty ? null : Text(p.client.trim()),
                    selected: p.id == selected,
                    onTap: () => Navigator.of(sheet).pop(PickedProject(p)),
                  ),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('New project'),
                  onTap: () async {
                    final created = await Navigator.of(context).push<Project>(
                      MaterialPageRoute(builder: (_) => const ProjectEditorPage()),
                    );
                    if (created != null && sheet.mounted) {
                      Navigator.of(sheet).pop(PickedProject(created));
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
