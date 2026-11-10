import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../csv/timesheet_csv.dart';
import '../model/project.dart';
import '../model/time_entry.dart';
import '../sheets/spreadsheet.dart';

/// Asks which file type to export, warning that the file is not encrypted.
/// Null when cancelled.
Future<SheetFormat?> pickExportFormat(BuildContext context) => showDialog<SheetFormat>(
  context: context,
  builder: (d) => AlertDialog(
    title: const Text('Export a timesheet'),
    contentPadding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'The file is not encrypted. Anyone who gets it can read your '
              'entries. Share it only with people and apps you trust.',
            ),
          ),
          const SizedBox(height: 8),
          for (final (format, icon, title, subtitle) in const [
            (
              SheetFormat.xlsx,
              Icons.table_chart_outlined,
              'Excel (.xlsx)',
              'Excel, Google Sheets, Numbers',
            ),
            (
              SheetFormat.ods,
              Icons.grid_on_outlined,
              'LibreOffice (.ods)',
              'LibreOffice, OpenOffice, Collabora',
            ),
            (
              SheetFormat.csv,
              Icons.description_outlined,
              'CSV (.csv)',
              'Plain text for any app, and Toggl or Clockify',
            ),
          ])
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: Icon(icon),
              title: Text(title),
              subtitle: Text(subtitle),
              onTap: () => Navigator.of(d).pop(format),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.of(d).pop(), child: const Text('Cancel')),
    ],
  ),
);

/// Asks for a file type, then shares [entries] as a timesheet named
/// "[fileName].xlsx" (or .ods / .csv). The file is written on this phone;
/// nothing leaves it unencrypted except through the share sheet.
Future<void> exportTimesheet(
  BuildContext context, {
  required List<TimeEntry> entries,
  required List<Project> projects,
  required String fileName,
}) async {
  final format = await pickExportFormat(context);
  if (format == null) return;
  final bytes = writeSheet(format, timesheetTable(entries, projects), name: 'Time entries');
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName.${format.extension}');
  await file.writeAsBytes(bytes, flush: true);
  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path, mimeType: format.mimeType)]),
  );
}
