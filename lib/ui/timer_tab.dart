import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/time_settings.dart';
import '../data/time_store.dart';
import '../model/project.dart';
import '../model/report.dart';
import '../model/time_entry.dart';
import '../notify/timer_notifier.dart';
import '../util/format.dart';
import 'entry_editor_page.dart';
import 'project_widgets.dart';
import '../l10n/l10n.dart';

/// Rebuilds once a second, for clocks that count while a timer runs.
class EverySecond extends StatefulWidget {
  const EverySecond({super.key, required this.builder});
  final Widget Function(BuildContext context, DateTime now) builder;

  @override
  State<EverySecond> createState() => _EverySecondState();
}

class _EverySecondState extends State<EverySecond> {
  late final Timer _timer = Timer.periodic(
    const Duration(seconds: 1),
    (_) => setState(() {}),
  );

  @override
  void initState() {
    super.initState();
    _timer; // Starts it.
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, DateTime.now());
}

/// The suite's theme makes filled buttons as wide as the screen; these sit
/// beside other things in a row.
final _compact = FilledButton.styleFrom(minimumSize: const Size(0, 48));

class TimerTab extends ConsumerStatefulWidget {
  const TimerTab({super.key});

  @override
  ConsumerState<TimerTab> createState() => _TimerTabState();
}

class _TimerTabState extends ConsumerState<TimerTab> {
  final _description = TextEditingController();
  String? _projectId;
  bool _billable = false;
  int _daysShown = 30;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final repo = ref.read(timeRepositoryProvider);
    final description = _description.text;
    _description.clear();
    FocusManager.instance.primaryFocus?.unfocus();
    await repo.start(description: description, projectId: _projectId, billable: _billable);
    if (ref.read(timeSettingsProvider).runningNotification) {
      // Asked the first time a timer starts; a "no" only hides the
      // notification.
      ref.read(timerNotifierProvider).requestPermission().ignore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(entriesProvider);
    final projects = {
      for (final p in ref.watch(projectsProvider).value ?? const <Project>[]) p.id: p,
    };
    final decimal = ref.watch(timeSettingsProvider).decimalHours;
    final list = entries.value;
    if (list == null) {
      return entries.hasError
          ? Center(child: Text(context.l10n.couldNotLoadEntries))
          : const Center(child: CircularProgressIndicator());
    }
    final running = [for (final e in list) if (e.running) e];
    final days = groupByDay(list.where((e) => !e.running));
    final shown = days.take(_daysShown).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        if (running.isEmpty)
          _StartCard(
            description: _description,
            projectId: _projectId,
            billable: _billable,
            onProject: (p) => setState(() {
              _projectId = p?.id;
              _billable = p?.billable ?? false;
            }),
            onBillable: (v) => setState(() => _billable = v),
            onStart: _start,
          )
        else
          for (final e in running) _RunningCard(entry: e, project: projects[e.projectId]),
        if (days.isEmpty && running.isEmpty) const _Empty(),
        for (final (day, dayEntries) in shown) ...[
          _DayHeader(
            day: day,
            entries: dayEntries,
            running: running.where((e) => e.day == day).toList(),
            decimal: decimal,
          ),
          for (final e in dayEntries)
            _EntryTile(key: ValueKey(e.id), entry: e, project: projects[e.projectId]),
        ],
        if (days.length > shown.length)
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton(
              onPressed: () => setState(() => _daysShown += 60),
              child: Text(context.l10n.showOlderEntries),
            ),
          ),
      ],
    );
  }
}

class _StartCard extends StatelessWidget {
  const _StartCard({
    required this.description,
    required this.projectId,
    required this.billable,
    required this.onProject,
    required this.onBillable,
    required this.onStart,
  });

  final TextEditingController description;
  final String? projectId;
  final bool billable;
  final ValueChanged<Project?> onProject;
  final ValueChanged<bool> onBillable;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: description,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => onStart(),
              decoration: InputDecoration(
                hintText: context.l10n.whatAreYouWorkingOn,
                border: InputBorder.none,
              ),
            ),
            Row(
              children: [
                Flexible(child: ProjectChip(projectId: projectId, onChanged: onProject)),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(context.l10n.billable),
                  selected: billable,
                  onSelected: onBillable,
                ),
                const Spacer(),
                FilledButton.icon(
                  style: _compact,
                  onPressed: onStart,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(context.l10n.start),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RunningCard extends ConsumerWidget {
  const _RunningCard({required this.entry, required this.project});

  final TimeEntry entry;
  final Project? project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      color: theme.colorScheme.primaryContainer,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => EntryEditorPage(entry: entry)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.description.isEmpty ? context.l10n.noDescription : entry.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        ProjectDot(project?.color ?? noProjectColor),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            context.l10n.runningSince(
                              project == null ? context.l10n.noProject : projectLabel(project!),
                              formatTime(context, entry.start),
                            ),
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    EverySecond(
                      builder: (context, now) => Text(
                        formatClock(entry.durationAt(now)),
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                style: _compact,
                onPressed: () => ref.read(timeRepositoryProvider).stop(entry),
                icon: const Icon(Icons.stop),
                label: Text(context.l10n.stop),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.day,
    required this.entries,
    required this.running,
    required this.decimal,
  });

  final DateTime day;
  final List<TimeEntry> entries;

  /// Running timers that started this day; their time counts in the total.
  final List<TimeEntry> running;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Duration total(DateTime now) => [...entries, ...running].fold(
      Duration.zero,
      (sum, e) => sum + e.durationAt(now),
    );
    final style = theme.textTheme.labelLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(relativeDay(day), style: style),
          if (running.isEmpty)
            Text(formatDuration(total(DateTime.now()), decimal: decimal), style: style)
          else
            EverySecond(
              builder: (_, now) => Text(formatDuration(total(now), decimal: decimal), style: style),
            ),
        ],
      ),
    );
  }
}

class _EntryTile extends ConsumerWidget {
  const _EntryTile({super.key, required this.entry, required this.project});

  final TimeEntry entry;
  final Project? project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final repo = ref.read(timeRepositoryProvider);
    final end = entry.end!;
    return Dismissible(
      key: ValueKey('dismiss-${entry.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: theme.colorScheme.errorContainer,
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Icon(Icons.delete_outline, color: theme.colorScheme.onErrorContainer),
      ),
      onDismissed: (_) async {
        final messenger = ScaffoldMessenger.of(context);
        final l = context.l10n;
        await repo.deleteEntry(entry.id);
        messenger
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(l.entryDeleted),
              // Flutter keeps a snackbar with an action open until it is tapped.
              persist: false,
              action: SnackBarAction(label: l.undo, onPressed: () => repo.saveEntry(entry)),
            ),
          );
      },
      child: ListTile(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => EntryEditorPage(entry: entry)),
        ),
        title: Text(
          entry.description.isEmpty ? context.l10n.noDescription : entry.description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            ProjectDot(project?.color ?? noProjectColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                [
                  project?.name ?? context.l10n.noProject,
                  '${formatTime(context, entry.start)} – ${formatTime(context, end)}',
                  for (final t in entry.tags) '#$t',
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (entry.billable)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 6),
                child: Icon(
                  Icons.paid_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                  semanticLabel: context.l10n.billable,
                ),
              ),
            Text(
              formatClock(entry.durationAt(end)),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            IconButton(
              tooltip: context.l10n.startAgain,
              icon: const Icon(Icons.play_arrow_outlined),
              onPressed: () => repo.continueEntry(entry),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 64, 32, 32),
      child: Column(
        children: [
          Icon(Icons.timer_outlined, size: 56, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text(context.l10n.nothingTrackedYet, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            context.l10n.nothingTrackedBody,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
