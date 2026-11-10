import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../app/time_settings.dart';
import '../data/time_store.dart';
import '../model/project.dart';
import '../model/report.dart';
import '../util/format.dart';
import 'project_widgets.dart';
import 'timesheet_export.dart';

enum ReportPeriod { day, week, month, year, custom }

/// The `[from, to)` range of [period] around [anchor].
(DateTime, DateTime) rangeFor(ReportPeriod period, DateTime anchor, int weekStart) {
  final day = dayOf(anchor);
  switch (period) {
    case ReportPeriod.day:
    case ReportPeriod.custom:
      return (day, addDays(day, 1));
    case ReportPeriod.week:
      final from = startOfWeek(day, weekStart);
      return (from, addDays(from, 7));
    case ReportPeriod.month:
      return (DateTime(day.year, day.month), DateTime(day.year, day.month + 1));
    case ReportPeriod.year:
      return (DateTime(day.year), DateTime(day.year + 1));
  }
}

class ReportsTab extends ConsumerStatefulWidget {
  const ReportsTab({super.key});

  @override
  ConsumerState<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends ConsumerState<ReportsTab> {
  ReportPeriod _period = ReportPeriod.week;
  DateTime _anchor = DateTime.now();
  DateTimeRange? _custom;

  (DateTime, DateTime) _range(int weekStart) {
    final custom = _custom;
    if (_period == ReportPeriod.custom && custom != null) {
      return (dayOf(custom.start), addDays(dayOf(custom.end), 1));
    }
    return rangeFor(_period, _anchor, weekStart);
  }

  void _step(int direction) => setState(() {
    final a = _anchor;
    _anchor = switch (_period) {
      ReportPeriod.day || ReportPeriod.custom => addDays(a, direction),
      ReportPeriod.week => addDays(a, 7 * direction),
      ReportPeriod.month => DateTime(a.year, a.month + direction),
      ReportPeriod.year => DateTime(a.year + direction),
    };
  });

  String _label(DateTime from, DateTime to) {
    final last = addDays(to, -1);
    return switch (_period) {
      ReportPeriod.day => relativeDay(from),
      ReportPeriod.month => DateFormat.yMMMM().format(from),
      ReportPeriod.year => '${from.year}',
      _ => from.year == last.year
          ? '${DateFormat.MMMd().format(from)} – ${DateFormat.MMMd().format(last)}'
          : '${DateFormat.yMMMd().format(from)} – ${DateFormat.yMMMd().format(last)}',
    };
  }

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange:
          _custom ?? DateTimeRange(start: addDays(dayOf(now), -6), end: dayOf(now)),
    );
    if (picked != null) {
      setState(() {
        _custom = picked;
        _period = ReportPeriod.custom;
      });
    }
  }

  Future<void> _export(Report report, List<Project> projects) async {
    final messenger = ScaffoldMessenger.of(context);
    final finished = report.entries.where((e) => !e.running).toList();
    if (finished.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Nothing to export in this period')));
      return;
    }
    final f = DateFormat('yyyy-MM-dd');
    await exportTimesheet(
      context,
      entries: finished,
      projects: projects,
      fileName: 'zt-time-${f.format(report.from)}-to-${f.format(addDays(report.to, -1))}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(timeSettingsProvider);
    final entries = ref.watch(entriesProvider).value;
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    if (entries == null) return const Center(child: CircularProgressIndicator());

    final weekStart = settings.weekStart ?? localeWeekStart(context);
    final (from, to) = _range(weekStart);
    final running = entries.any((e) => e.running);

    Widget body(DateTime now) {
      final report = buildReport(
        entries: entries,
        projects: projects,
        from: from,
        to: to,
        now: now,
      );
      final decimal = settings.decimalHours;
      return ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<ReportPeriod>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: ReportPeriod.day, label: Text('Day')),
                ButtonSegment(value: ReportPeriod.week, label: Text('Week')),
                ButtonSegment(value: ReportPeriod.month, label: Text('Month')),
                ButtonSegment(value: ReportPeriod.year, label: Text('Year')),
                ButtonSegment(value: ReportPeriod.custom, label: Text('Custom')),
              ],
              selected: {_period},
              onSelectionChanged: (s) {
                if (s.first == ReportPeriod.custom) {
                  _pickCustom();
                } else {
                  setState(() => _period = s.first);
                }
              },
            ),
          ),
          Row(
            children: [
              if (_period != ReportPeriod.custom)
                IconButton(
                  tooltip: 'Earlier',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _step(-1),
                ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _period == ReportPeriod.custom
                      ? _pickCustom
                      : () => setState(() => _anchor = DateTime.now()),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      _label(from, to),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
              ),
              if (_period != ReportPeriod.custom)
                IconButton(
                  tooltip: 'Later',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _step(1),
                ),
              IconButton(
                tooltip: 'Export this period (Excel, LibreOffice or CSV)',
                icon: const Icon(Icons.ios_share),
                onPressed: () => _export(report, projects),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _Stat(label: 'Total', value: formatDuration(report.total, decimal: decimal)),
              ),
              Expanded(
                child: _Stat(
                  label: 'Billable',
                  value: formatDuration(report.billable, decimal: decimal),
                ),
              ),
              if (report.amount > 0)
                Expanded(
                  child: _Stat(
                    label: 'Amount',
                    value: formatAmount(report.amount, settings.currency),
                  ),
                ),
            ],
          ),
          if (report.byDay.length > 1) ...[
            const SizedBox(height: 16),
            _Bars(report: report, decimal: decimal),
          ],
          const SizedBox(height: 16),
          if (report.byProject.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'No time tracked in this period',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final p in report.byProject)
              _ProjectRow(
                total: p,
                share: report.total.inSeconds == 0
                    ? 0
                    : p.total.inSeconds / report.total.inSeconds,
                decimal: decimal,
                currency: settings.currency,
              ),
        ],
      );
    }

    // Only tick while something is running; a finished report is still.
    return running ? EveryHalfMinute(builder: body) : body(DateTime.now());
  }
}

/// Rebuilds every 30 seconds: often enough for totals shown in minutes.
class EveryHalfMinute extends StatelessWidget {
  const EveryHalfMinute({super.key, required this.builder});
  final Widget Function(DateTime now) builder;

  @override
  Widget build(BuildContext context) => StreamBuilder<int>(
    stream: Stream.periodic(const Duration(seconds: 30), (i) => i),
    builder: (_, _) => builder(DateTime.now()),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(value, style: theme.textTheme.titleLarge),
            ),
          ],
        ),
      ),
    );
  }
}

/// Time per day; per month when the range is longer than two months.
class _Bars extends StatelessWidget {
  const _Bars({required this.report, required this.decimal});
  final Report report;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byMonth = report.byDay.length > 62;
    final bars = <(String, String, Duration)>[]; // short label, full label, time
    if (byMonth) {
      final months = <DateTime, Duration>{};
      for (final (day, d) in report.byDay) {
        final m = DateTime(day.year, day.month);
        months[m] = (months[m] ?? Duration.zero) + d;
      }
      for (final m in months.keys) {
        bars.add((DateFormat.MMM().format(m)[0], DateFormat.yMMMM().format(m), months[m]!));
      }
    } else {
      final few = report.byDay.length <= 7;
      for (final (day, d) in report.byDay) {
        bars.add((
          few
              ? DateFormat.E().format(day)
              : (day.day == 1 || day.day % 5 == 0 ? '${day.day}' : ''),
          DateFormat.MMMEd().format(day),
          d,
        ));
      }
    }
    final max = bars.fold<int>(1, (m, b) => b.$3.inSeconds > m ? b.$3.inSeconds : m);
    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (short, full, d) in bars)
            Expanded(
              child: Tooltip(
                message: '$full: ${formatDuration(d, decimal: decimal)}',
                triggerMode: TooltipTriggerMode.tap,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: FractionallySizedBox(
                        heightFactor: (d.inSeconds / max).clamp(0.0, 1.0),
                        child: Container(
                          margin: EdgeInsets.symmetric(horizontal: bars.length > 14 ? 1 : 4),
                          decoration: BoxDecoration(
                            color: d == Duration.zero
                                ? Colors.transparent
                                : theme.colorScheme.primary,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ),
                      ),
                    ),
                    Container(height: 1, color: theme.colorScheme.outlineVariant),
                    SizedBox(
                      height: 18,
                      child: Text(
                        short,
                        maxLines: 1,
                        overflow: TextOverflow.visible,
                        softWrap: false,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({
    required this.total,
    required this.share,
    required this.decimal,
    required this.currency,
  });

  final ProjectTotal total;
  final double share;
  final bool decimal;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = total.project;
    final color = Color(p?.color ?? noProjectColor);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProjectDot(p?.color ?? noProjectColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  p == null ? 'No project' : projectLabel(p),
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
              Text(
                [
                  formatDuration(total.total, decimal: decimal),
                  '${(share * 100).round()}%',
                  if (total.amount > 0) formatAmount(total.amount, currency),
                ].join(' · '),
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: share.clamp(0.0, 1.0),
              minHeight: 6,
              color: color,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}
