import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_time/app/time_config.dart';
import 'package:zerotrust_time/csv/timesheet_csv.dart';
import 'package:zerotrust_time/model/project.dart';
import 'package:zerotrust_time/model/time_entry.dart';
import 'package:zerotrust_time/sheets/spreadsheet.dart';
import 'package:zerotrust_time/ui/timesheet_export.dart';

Uint8List _zip(Map<String, String> files) {
  final a = Archive();
  for (final f in files.entries) {
    a.addFile(ArchiveFile.bytes(f.key, utf8.encode(f.value)));
  }
  return ZipEncoder().encodeBytes(a);
}

void main() {
  var n = 0;
  String id() => 'id${n++}';
  setUp(() => n = 0);

  const web = Project(id: 'web', name: 'אתר החברה', client: 'Acme', hourlyRate: 100);
  final start = DateTime(2026, 11, 10, 9);
  final entries = [
    TimeEntry(
      id: 'a',
      description: 'תיקון כותרת, again',
      projectId: 'web',
      tags: const ['באג', 'css'],
      billable: true,
      start: start,
      end: start.add(const Duration(minutes: 90)),
    ),
    // Longer than a day, so durations must keep counting past 24 hours.
    TimeEntry(
      id: 'b',
      description: '=not a formula\nsecond line',
      start: start.add(const Duration(hours: 3)),
      end: start.add(const Duration(hours: 29, minutes: 20, seconds: 5)),
    ),
    TimeEntry(id: 'running', start: start.add(const Duration(hours: 40))),
  ];

  for (final format in SheetFormat.values) {
    test('${format.name} export imports back the same entries, Hebrew included', () {
      final bytes = writeSheet(format, timesheetTable(entries, const [web]), name: 'Time entries');
      final plan = TimesheetImport.fromFile(
        bytes: bytes,
        existing: const [],
        projects: const [],
        newId: id,
      );
      expect(plan.unreadable, 0);
      expect(plan.entries, hasLength(2));
      expect(plan.newProjects.single.name, 'אתר החברה');
      expect(plan.newProjects.single.client, 'Acme');
      final a = plan.entries[0];
      expect(a.description, 'תיקון כותרת, again');
      expect(a.tags, ['באג', 'css']);
      expect(a.billable, isTrue);
      expect(a.start, entries[0].start);
      expect(a.end, entries[0].end);
      final b = plan.entries[1];
      expect(b.description, '=not a formula\nsecond line');
      expect(b.end, entries[1].end);

      // Importing the same file again adds nothing.
      final again = TimesheetImport.fromFile(
        bytes: bytes,
        existing: [...plan.entries],
        projects: plan.newProjects,
        newId: id,
      );
      expect(again.entries, isEmpty);
      expect(again.skipped, 2);
    });
  }

  test('CSV export starts with a byte-order mark so Excel reads Hebrew', () {
    final bytes = writeSheet(SheetFormat.csv, timesheetTable(entries, const [web]));
    expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
    expect(utf8.decode(bytes), contains('אתר החברה'));
  });

  test('spreadsheet cells are typed: dates, times, durations and numbers', () {
    final sheets = readSheets(writeSheet(SheetFormat.xlsx, timesheetTable(entries, const [web])));
    final rows = sheets.single;
    expect(rows.first, timesheetHeader);
    expect(rows[1].sublist(5, 12), ['2026-11-10', '09:00:00', '2026-11-10', '10:30:00', '01:30:00', '1.5', '150']);
    expect(rows[2][9], '26:20:05');

    final ods = readSheets(writeSheet(SheetFormat.ods, timesheetTable(entries, const [web]))).single;
    expect(ods[1].sublist(5, 12), rows[1].sublist(5, 12));
    expect(ods[2][9], '26:20:05');
  });

  test('reads an Excel file with shared strings, date styles and a title row', () {
    final bytes = _zip({
      'xl/workbook.xml':
          '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
          'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
          '<sheets><sheet name="Report" sheetId="1" r:id="rId7"/></sheets></workbook>',
      'xl/_rels/workbook.xml.rels':
          '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
          '<Relationship Id="rId7" Type="worksheet" Target="/xl/worksheets/data.xml"/></Relationships>',
      'xl/sharedStrings.xml':
          '<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
          '<si><t>Detailed report</t></si><si><t>Description</t></si><si><t>Start</t></si>'
          '<si><t>End</t></si><si><r><t>פגישה </t></r><r><rPr><b/></rPr><t>עם לקוח</t></r>'
          '<rPh><t>x</t></rPh></si><si><t>Billable</t></si></sst>',
      'xl/styles.xml':
          '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
          '<numFmts><numFmt numFmtId="170" formatCode="d/m/yyyy\\ h:mm;@"/></numFmts>'
          '<cellXfs><xf numFmtId="0"/><xf numFmtId="170"/><xf numFmtId="14"/></cellXfs></styleSheet>',
      'xl/worksheets/data.xml':
          '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>'
          '<row r="1"><c r="A1" t="s"><v>0</v></c></row>'
          '<row r="3"><c r="A3" t="s"><v>1</v></c><c r="B3" t="s"><v>2</v></c>'
          '<c r="C3" t="s"><v>3</v></c><c r="E3" t="s"><v>5</v></c></row>'
          // 46336.375 is 2026-11-10 09:00; .4375 is 10:30.
          '<row r="4"><c r="A4" t="s"><v>4</v></c><c r="B4" s="1"><v>46336.375</v></c>'
          '<c r="C4" s="1"><v>46336.4375</v></c><c r="E4" t="b"><v>1</v></c></row>'
          '</sheetData></worksheet>',
    });
    final plan = TimesheetImport.fromFile(bytes: bytes, existing: const [], projects: const [], newId: id);
    final e = plan.entries.single;
    expect(e.description, 'פגישה עם לקוח');
    expect(e.start, DateTime(2026, 11, 10, 9));
    expect(e.end, DateTime(2026, 11, 10, 10, 30));
    expect(e.billable, isTrue);
  });

  test('reads a LibreOffice file with repeated cells and spaces', () {
    const ns =
        'xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" '
        'xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" '
        'xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0"';
    final bytes = _zip({
      'mimetype': 'application/vnd.oasis.opendocument.spreadsheet',
      'content.xml':
          '<office:document-content $ns><office:body><office:spreadsheet><table:table table:name="A">'
          '<table:table-header-rows><table:table-row>'
          '<table:table-cell office:value-type="string"><text:p>Description</text:p></table:table-cell>'
          '<table:table-cell office:value-type="string"><text:p>Start date</text:p></table:table-cell>'
          '<table:table-cell table:number-columns-repeated="2"/>'
          '<table:table-cell office:value-type="string"><text:p>Duration</text:p></table:table-cell>'
          '</table:table-row></table:table-header-rows>'
          '<table:table-row>'
          '<table:table-cell office:value-type="string"><text:p>a<text:s text:c="2"/>b</text:p></table:table-cell>'
          '<table:table-cell office:value-type="date" office:date-value="2026-11-10T09:00:00"/>'
          '<table:table-cell table:number-columns-repeated="2"/>'
          '<table:table-cell office:value-type="time" office:time-value="PT1H30M00S"/>'
          '</table:table-row>'
          '<table:table-row table:number-rows-repeated="1048570"><table:table-cell table:number-columns-repeated="1024"/></table:table-row>'
          '</table:table></office:spreadsheet></office:body></office:document-content>',
    });
    final plan = TimesheetImport.fromFile(bytes: bytes, existing: const [], projects: const [], newId: id);
    final e = plan.entries.single;
    expect(e.description, 'a  b');
    expect(e.start, DateTime(2026, 11, 10, 9));
    expect(e.end, DateTime(2026, 11, 10, 10, 30));
  });

  test('reads UTF-16 text and says old .xls files need saving as .xlsx', () {
    const text = 'Description\tStart date\tDuration\nשלום\t2026-11-10 09:00\t1.5\n';
    final utf16 = Uint8List.fromList([
      0xFF,
      0xFE,
      for (final u in text.codeUnits) ...[u & 0xFF, u >> 8],
    ]);
    final plan = TimesheetImport.fromFile(bytes: utf16, existing: const [], projects: const [], newId: id);
    expect(plan.entries.single.description, 'שלום');
    expect(plan.entries.single.end, DateTime(2026, 11, 10, 10, 30));

    expect(
      () => readSheets(Uint8List.fromList([0xD0, 0xCF, 0x11, 0xE0, 0, 0])),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('.xls'))),
    );
    expect(
      () => readSheets(_zip({'word/document.xml': '<w/>'})),
      throwsA(isA<FormatException>()),
    );
  });

  test('date cells keep their time zone, and negative durations are not imported', () {
    const ns =
        'xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" '
        'xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" '
        'xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0"';
    String cell(String attrs) => '<table:table-cell $attrs/>';
    final ods = _zip({
      'content.xml':
          '<office:document-content $ns><office:body><office:spreadsheet><table:table>'
          '<table:table-row>${cell('office:value-type="string"')}</table:table-row>'
          '<table:table-row><table:table-cell office:value-type="string"><text:p>Start</text:p></table:table-cell>'
          '<table:table-cell office:value-type="string"><text:p>Duration</text:p></table:table-cell></table:table-row>'
          '<table:table-row>${cell('office:value-type="date" office:date-value="2026-11-10T09:00:00Z"')}'
          '${cell('office:value-type="time" office:time-value="PT1H"')}</table:table-row>'
          '<table:table-row>${cell('office:value-type="date" office:date-value="2026-11-11T09:00:00"')}'
          '${cell('office:value-type="time" office:time-value="-PT1H"')}</table:table-row>'
          '</table:table></office:spreadsheet></office:body></office:document-content>',
    });
    final plan = TimesheetImport.fromFile(bytes: ods, existing: const [], projects: const [], newId: id);
    expect(plan.entries.single.start, DateTime.utc(2026, 11, 10, 9).toLocal());
    expect(plan.unreadable, 1);

    final xlsx = _zip({
      'xl/workbook.xml': '<workbook><sheets><sheet/></sheets></workbook>',
      'xl/worksheets/sheet1.xml':
          '<worksheet><sheetData><row><c r="A1" t="inlineStr"><is><t>Start</t></is></c>'
          '<c r="B1" t="inlineStr"><is><t>End</t></is></c></row>'
          '<row><c r="A2" t="d"><v>2026-11-10T09:00:00Z</v></c><c r="B2" t="d"><v>2026-11-10T10:00:00.000Z</v></c></row>'
          '</sheetData></worksheet>',
    });
    final x = TimesheetImport.fromFile(bytes: xlsx, existing: const [], projects: const [], newId: id);
    expect(x.entries.single.start, DateTime.utc(2026, 11, 10, 9).toLocal());
    expect(x.entries.single.end, DateTime.utc(2026, 11, 10, 10).toLocal());
  });

  testWidgets('export asks for a file type, all three visible and tappable', (tester) async {
    SheetFormat? picked;
    await tester.pumpWidget(
      MaterialApp(
        theme: ZtTheme.light(accent: timeAppConfig.accent),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async => picked = await pickExportFormat(context),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.textContaining('not encrypted'), findsOneWidget);
    final screen = tester.getRect(find.byType(AlertDialog));
    double? lastTop;
    for (final label in ['Excel (.xlsx)', 'LibreOffice (.ods)', 'CSV (.csv)']) {
      final r = tester.getRect(find.text(label));
      expect(r.width, greaterThan(0));
      expect(screen.contains(r.center), isTrue, reason: label);
      if (lastTop != null) expect(r.top, greaterThan(lastTop), reason: '$label below the one before');
      lastTop = r.top;
    }
    await tester.tap(find.text('LibreOffice (.ods)'));
    await tester.pumpAndSettle();
    expect(picked, SheetFormat.ods);
  });
}
