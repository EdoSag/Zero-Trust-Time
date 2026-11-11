import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import '../app/time_settings.dart';
import '../csv/timesheet_csv.dart';
import '../data/time_store.dart';
import '../notify/timer_notifier.dart';
import '../util/format.dart';
import 'timesheet_export.dart';
import '../l10n/l10n.dart';

/// The shared Zero-Trust settings screen, with Time's own rows.
class TimeSettingsPage extends ConsumerWidget {
  const TimeSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(timeSettingsProvider);
    final ctrl = ref.read(timeSettingsProvider.notifier);
    final weekStart = s.weekStart;

    return ZtSettingsPage(
      showSyncStatus: true,
      showStorageUsage: true,
      onSignedOut: () async {
        await ref.read(timerNotifierProvider).clear();
        if (context.mounted) {
          Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst);
        }
      },
      onOpenUrl: (Uri url) => launchUrl(url, mode: LaunchMode.externalApplication),
      appSection: <Widget>[
        ListTile(
          leading: const Icon(Icons.first_page),
          title: Text(context.l10n.startOfWeek),
          subtitle: Text(
            weekStart == null
                ? context.l10n.likeYourRegionDay(DateFormat.EEEE().format(DateTime(2024, 1, localeWeekStart(context))))
                : DateFormat.EEEE().format(DateTime(2024, 1, weekStart)),
          ),
          onTap: () async {
            final picked = await _pickFrom(
              context,
              context.l10n.startOfWeek,
              const [0, DateTime.saturday, DateTime.sunday, DateTime.monday],
              (v) => v == 0 ? context.l10n.likeYourRegion : DateFormat.EEEE().format(DateTime(2024, 1, v)),
            );
            if (picked != null) {
              await ctrl.update((x) => x.copyWith(weekStart: picked == 0 ? null : picked));
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.payments_outlined),
          title: Text(context.l10n.currency),
          subtitle: Text(context.l10n.currencySubtitle(s.currency)),
          onTap: () async {
            final picked = await _pickCurrency(context, s.currency);
            if (picked != null) await ctrl.update((x) => x.copyWith(currency: picked));
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.pin_outlined),
          title: Text(context.l10n.decimalHours),
          subtitle: Text(context.l10n.decimalHoursBody),
          value: s.decimalHours,
          onChanged: (v) => ctrl.update((x) => x.copyWith(decimalHours: v)),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.notifications_outlined),
          title: Text(context.l10n.runningNotification),
          subtitle: Text(context.l10n.runningNotificationBody),
          value: s.runningNotification,
          onChanged: (v) async {
            if (v) await ref.read(timerNotifierProvider).requestPermission();
            await ctrl.update((x) => x.copyWith(runningNotification: v));
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.title),
          title: Text(context.l10n.notificationDescription),
          subtitle: Text(context.l10n.notificationDescriptionBody),
          value: s.notificationText,
          onChanged: s.runningNotification
              ? (v) => ctrl.update((x) => x.copyWith(notificationText: v))
              : null,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.widgets_outlined),
          title: Text(context.l10n.widgetDetails),
          subtitle: Text(context.l10n.widgetDetailsBody),
          value: s.widgetDetails,
          onChanged: (v) => ctrl.update((x) => x.copyWith(widgetDetails: v)),
        ),
        ListTile(
          leading: const Icon(Icons.snooze_outlined),
          title: Text(context.l10n.remindLongTimer),
          subtitle: Text(
            s.nudgeAfterHours == null ? context.l10n.never : context.l10n.afterHours(s.nudgeAfterHours!),
          ),
          onTap: () async {
            final picked = await _pickFrom(
              context,
              context.l10n.remindLongTimer,
              const [0, 2, 4, 8, 12],
              (h) => h == 0 ? context.l10n.never : context.l10n.afterHours(h),
            );
            if (picked != null) {
              await ctrl.update((x) => x.copyWith(nudgeAfterHours: picked == 0 ? null : picked));
            }
          },
        ),
      ],
      backupSection: <Widget>[
        ListTile(
          leading: const Icon(Icons.file_download_outlined),
          title: Text(context.l10n.importTimesheet),
          subtitle: Text(context.l10n.importTimesheetBody),
          onTap: () => importTimesheetFile(context, ref),
        ),
        ListTile(
          leading: const Icon(Icons.file_upload_outlined),
          title: Text(context.l10n.exportAllEntries),
          subtitle: Text(context.l10n.exportAllEntriesBody),
          onTap: () => _exportAll(context, ref),
        ),
      ],
    );
  }

  Future<int?> _pickFrom(
    BuildContext context,
    String title,
    List<int> values,
    String Function(int) label,
  ) => showDialog<int>(
    context: context,
    builder: (d) => SimpleDialog(
      title: Text(title),
      children: [
        for (final v in values)
          SimpleDialogOption(
            onPressed: () => Navigator.of(d).pop(v),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(label(v)),
            ),
          ),
      ],
    ),
  );

  Future<String?> _pickCurrency(BuildContext context, String current) {
    final custom = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (d) => SimpleDialog(
        title: Text(context.l10n.currency),
        children: [
          for (final c in const [r'$', '€', '£', '₪', '¥', '₹', 'CHF '])
            SimpleDialogOption(
              onPressed: () => Navigator.of(d).pop(c),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(c.trim() + (c == current ? '  ✓' : '')),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: TextField(
              controller: custom,
              maxLength: 5,
              decoration: InputDecoration(
                labelText: d.l10n.other,
                suffixIcon: IconButton(
                  tooltip: d.l10n.useThis,
                  icon: const Icon(Icons.check),
                  onPressed: () {
                    final v = custom.text.trim();
                    if (v.isNotEmpty) Navigator.of(d).pop(v);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportAll(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(timeRepositoryProvider);
    final entries = [for (final e in await repo.allEntries()) if (!e.running) e];
    if (!context.mounted) return;
    if (entries.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(context.l10n.nothingToExportYet)));
      return;
    }
    final projects = await repo.allProjects();
    if (!context.mounted) return;
    await exportTimesheet(
      context,
      entries: entries,
      projects: projects,
      fileName: 'zt-time-${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
    );
  }
}

/// The reader's reasons (English, from `FormatException`) in the app's
/// language.
String importErrorText(AppL10n l, String message) => switch (message) {
  'The file is empty' => l.errFileEmpty,
  'No "Start date" column in this file' => l.errNoStartDate,
  'The file is damaged' => l.errFileDamaged,
  'Not a spreadsheet. Use .xlsx, .ods or .csv' => l.errNotSpreadsheet,
  "Old .xls files can't be read. Save it as .xlsx or .csv first" => l.errOldXls,
  _ => message,
};

/// Picks a CSV timesheet and imports it.
Future<void> importTimesheetFile(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final l = context.l10n;
  final help = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(d.l10n.importTimesheet),
      content: Text(d.l10n.importHelp),
      actions: [
        TextButton(onPressed: () => Navigator.of(d).pop(false), child: Text(d.l10n.cancel)),
        FilledButton(onPressed: () => Navigator.of(d).pop(true), child: Text(d.l10n.chooseFile)),
      ],
    ),
  );
  if (help != true) return;
  // The file picker is another app's screen: don't auto-lock behind it.
  final files = await ref
      .read(vaultControllerProvider.notifier)
      .whileShowingSystemUi(() => FilePicker.pickFiles(dialogTitle: l.chooseSpreadsheet));
  if (files.isEmpty) return;
  try {
    final repo = ref.read(timeRepositoryProvider);
    var added = 0, projects = 0, skipped = 0, unreadable = 0;
    for (final f in files) {
      final bytes = await f.readAsBytes();
      final plan = TimesheetImport.fromFile(
        bytes: bytes,
        existing: await repo.allEntries(),
        projects: await repo.allProjects(),
      );
      for (final p in plan.newProjects) {
        await repo.saveProject(p);
      }
      for (final e in plan.entries) {
        await repo.saveEntry(e);
      }
      added += plan.entries.length;
      projects += plan.newProjects.length;
      skipped += plan.skipped;
      unreadable += plan.unreadable;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          [
            [
              l.importedEntries(added),
              if (projects > 0) l.importedProjects(projects),
            ].join(' '),
            if (skipped > 0) l.importedSkipped(skipped),
            if (unreadable > 0) l.importedUnreadable(unreadable),
          ].join(', '),
        ),
      ),
    );
  } on FormatException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(l.couldNotImportReason(importErrorText(l, e.message)))));
  } on Object {
    messenger.showSnackBar(SnackBar(content: Text(l.couldNotImport)));
  }
}
