import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import '../app/time_settings.dart';
import '../csv/timesheet_csv.dart';
import '../data/time_store.dart';
import '../notify/timer_notifier.dart';
import '../util/format.dart';
import 'reports_tab.dart' show confirmPlainExport;

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
          title: const Text('Start of the week'),
          subtitle: Text(
            weekStart == null
                ? 'Like your region (${DateFormat.EEEE().format(DateTime(2024, 1, localeWeekStart(context)))})'
                : DateFormat.EEEE().format(DateTime(2024, 1, weekStart)),
          ),
          onTap: () async {
            final picked = await _pickFrom(
              context,
              'Start of the week',
              const [0, DateTime.saturday, DateTime.sunday, DateTime.monday],
              (v) => v == 0 ? 'Like your region' : DateFormat.EEEE().format(DateTime(2024, 1, v)),
            );
            if (picked != null) {
              await ctrl.update((x) => x.copyWith(weekStart: picked == 0 ? null : picked));
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.payments_outlined),
          title: const Text('Currency'),
          subtitle: Text('${s.currency}  (for hourly rates and amounts)'),
          onTap: () async {
            final picked = await _pickCurrency(context, s.currency);
            if (picked != null) await ctrl.update((x) => x.copyWith(currency: picked));
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.pin_outlined),
          title: const Text('Decimal hours'),
          subtitle: const Text('Show totals as 7.50 h instead of 7h 30m'),
          value: s.decimalHours,
          onChanged: (v) => ctrl.update((x) => x.copyWith(decimalHours: v)),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.notifications_outlined),
          title: const Text('Notification while a timer runs'),
          subtitle: const Text('A lasting notification with a live clock (Android)'),
          value: s.runningNotification,
          onChanged: (v) async {
            if (v) await ref.read(timerNotifierProvider).requestPermission();
            await ctrl.update((x) => x.copyWith(runningNotification: v));
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.title),
          title: const Text('Description in that notification'),
          subtitle: const Text(
            'Off: it only says "Timer running". On, the description is '
            'handed to the phone so it can show while Time is locked.',
          ),
          value: s.notificationText,
          onChanged: s.runningNotification
              ? (v) => ctrl.update((x) => x.copyWith(notificationText: v))
              : null,
        ),
        ListTile(
          leading: const Icon(Icons.snooze_outlined),
          title: const Text('Remind me about a long timer'),
          subtitle: Text(
            s.nudgeAfterHours == null ? 'Never' : 'After ${s.nudgeAfterHours} hours',
          ),
          onTap: () async {
            final picked = await _pickFrom(
              context,
              'Remind me about a long timer',
              const [0, 2, 4, 8, 12],
              (h) => h == 0 ? 'Never' : 'After $h hours',
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
          title: const Text('Import a timesheet (.csv)'),
          subtitle: const Text('From Toggl Track, Clockify or ZT Time'),
          onTap: () => importTimesheetFile(context, ref),
        ),
        ListTile(
          leading: const Icon(Icons.file_upload_outlined),
          title: const Text('Export all entries (.csv)'),
          subtitle: const Text('Unencrypted file, for spreadsheets and invoicing'),
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
        title: const Text('Currency'),
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
                labelText: 'Other',
                suffixIcon: IconButton(
                  tooltip: 'Use this',
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
      messenger.showSnackBar(const SnackBar(content: Text('There is nothing to export yet')));
      return;
    }
    if (!await confirmPlainExport(context)) return;
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/zt-time-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv',
    );
    await file.writeAsString(writeTimesheet(entries, await repo.allProjects()));
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'text/csv')]));
  }
}

/// Picks a CSV timesheet and imports it.
Future<void> importTimesheetFile(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final help = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: const Text('Import a timesheet'),
      content: const Text(
        'Toggl Track: Reports, Detailed, Export, Download CSV.\n'
        'Clockify: Reports, Detailed, Export, Save as CSV.\n\n'
        'Projects in the file are created if you don\'t have them. '
        'Importing the same file again skips entries you already have.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(d).pop(true), child: const Text('Choose file')),
      ],
    ),
  );
  if (help != true) return;
  // The file picker is another app's screen: don't auto-lock behind it.
  final files = await ref
      .read(vaultControllerProvider.notifier)
      .whileShowingSystemUi(() => FilePicker.pickFiles(dialogTitle: 'Choose a .csv file'));
  if (files.isEmpty) return;
  try {
    final repo = ref.read(timeRepositoryProvider);
    var added = 0, projects = 0, skipped = 0, unreadable = 0;
    for (final f in files) {
      final bytes = await f.readAsBytes();
      final plan = TimesheetImport.build(
        csv: utf8.decode(bytes, allowMalformed: true),
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
          'Imported $added ${added == 1 ? 'entry' : 'entries'}'
          '${projects == 0 ? '' : ' and $projects new ${projects == 1 ? 'project' : 'projects'}'}'
          '${skipped == 0 ? '' : ', skipped $skipped already here'}'
          '${unreadable == 0 ? '' : ', $unreadable rows had no readable times'}.',
        ),
      ),
    );
  } on FormatException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Could not import that file: ${e.message}')));
  } on Object {
    messenger.showSnackBar(const SnackBar(content: Text('Could not import that file')));
  }
}
