import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'spreadsheet.dart';

/// Minimal Office Open XML spreadsheet (.xlsx): one sheet, with real dates,
/// times, durations and numbers. Opens in Excel, Google Sheets, Numbers and
/// LibreOffice.
abstract final class Xlsx {
  // Indexes into cellXfs in [_styles].
  static const _sDate = 1, _sTime = 2, _sDuration = 3, _sNumber = 4, _sHeader = 5;

  static Uint8List write(List<List<Object?>> rows, {String sheetName = 'Sheet1'}) {
    final sheet = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">')
      // Keep the header row in view while scrolling.
      ..write(
        '<sheetViews><sheetView workbookViewId="0">'
        '<pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/>'
        '</sheetView></sheetViews>',
      );
    final widths = _widths(rows);
    if (widths.isNotEmpty) {
      sheet.write('<cols>');
      for (var i = 0; i < widths.length; i++) {
        sheet.write('<col min="${i + 1}" max="${i + 1}" width="${widths[i]}" customWidth="1"/>');
      }
      sheet.write('</cols>');
    }
    sheet.write('<sheetData>');
    for (var r = 0; r < rows.length; r++) {
      sheet.write('<row r="${r + 1}">');
      for (var c = 0; c < rows[r].length; c++) {
        final ref = '${columnName(c)}${r + 1}';
        final v = rows[r][c];
        if (r == 0) {
          sheet.write(_text(ref, cellText(v), style: _sHeader));
          continue;
        }
        sheet.write(switch (v) {
          null => '',
          String s => s.isEmpty ? '' : _text(ref, s),
          SheetDate(:final value) => _num(ref, _days(DateTime.utc(value.year, value.month, value.day)), _sDate),
          SheetTime(:final value) => _num(ref, (value.hour * 3600 + value.minute * 60 + value.second) / 86400, _sTime),
          Duration d => _num(ref, d.inSeconds / 86400, _sDuration),
          double n => _num(ref, n, _sNumber),
          num n => _num(ref, n, 0),
          _ => _text(ref, '$v'),
        });
      }
      sheet.write('</row>');
    }
    sheet.write('</sheetData></worksheet>');

    final name = _xml(_sheetName(sheetName));
    final files = <String, String>{
      '[Content_Types].xml':
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
          '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
          '<Default Extension="xml" ContentType="application/xml"/>'
          '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
          '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
          '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
          '</Types>',
      '_rels/.rels':
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
          '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
          '</Relationships>',
      'xl/workbook.xml':
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
          'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
          '<sheets><sheet name="$name" sheetId="1" r:id="rId1"/></sheets></workbook>',
      'xl/_rels/workbook.xml.rels':
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
          '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
          '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
          '</Relationships>',
      'xl/styles.xml': _styles,
      'xl/worksheets/sheet1.xml': sheet.toString(),
    };
    final archive = Archive();
    for (final e in files.entries) {
      archive.addFile(ArchiveFile.bytes(e.key, utf8.encode(e.value)));
    }
    return ZipEncoder().encodeBytes(archive);
  }

  static const _styles =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<numFmts count="2">'
      '<numFmt numFmtId="164" formatCode="yyyy-mm-dd"/>'
      '<numFmt numFmtId="165" formatCode="hh:mm:ss"/>'
      '</numFmts>'
      '<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font>'
      '<font><b/><sz val="11"/><name val="Calibri"/></font></fonts>'
      '<fills count="2"><fill><patternFill patternType="none"/></fill>'
      '<fill><patternFill patternType="gray125"/></fill></fills>'
      '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
      '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
      '<cellXfs count="6">'
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
      '<xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
      '<xf numFmtId="165" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
      // 46 is the built-in [h]:mm:ss, which keeps counting past 24 hours.
      '<xf numFmtId="46" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
      '<xf numFmtId="2" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
      '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
      '</cellXfs>'
      '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
      '</styleSheet>';

  static String _text(String ref, String s, {int style = 0}) =>
      '<c r="$ref" t="inlineStr"${style == 0 ? '' : ' s="$style"'}>'
      '<is><t xml:space="preserve">${_xml(s.length > 32767 ? s.substring(0, 32767) : s)}</t></is></c>';

  static String _num(String ref, num v, int style) =>
      '<c r="$ref"${style == 0 ? '' : ' s="$style"'}><v>$v</v></c>';

  static double _days(DateTime utcDay) =>
      utcDay.difference(DateTime.utc(1899, 12, 30)).inSeconds / 86400;

  static List<double> _widths(List<List<Object?>> rows) {
    final widths = <double>[];
    for (final row in rows.take(200)) {
      for (var c = 0; c < row.length; c++) {
        final len = cellText(row[c]).length.clamp(6, 50) + 2.0;
        if (c >= widths.length) {
          widths.add(len);
        } else if (len > widths[c]) {
          widths[c] = len;
        }
      }
    }
    return widths;
  }

  /// Sheet names can't hold []:*?/\ and stop at 31 characters.
  static String _sheetName(String s) {
    final clean = s.replaceAll(RegExp(r'[\[\]:*?/\\]'), ' ').trim();
    if (clean.isEmpty) return 'Sheet1';
    return clean.length > 31 ? clean.substring(0, 31) : clean;
  }

  /// "A", "B", ... "Z", "AA", ...
  static String columnName(int index) {
    var n = index + 1;
    final chars = <int>[];
    while (n > 0) {
      chars.insert(0, 65 + (n - 1) % 26);
      n = (n - 1) ~/ 26;
    }
    return String.fromCharCodes(chars);
  }

  /// 0 for "A1", 27 for "AB7".
  static int columnIndex(String ref) {
    var n = 0;
    for (final u in ref.toUpperCase().codeUnits) {
      if (u < 65 || u > 90) break;
      n = n * 26 + (u - 64);
    }
    return n - 1;
  }

  // ---------------------------------------------------------------- reading

  static List<List<List<String>>> read(Archive zip) {
    final workbook = _parse(zip, 'xl/workbook.xml');
    if (workbook == null) throw const FormatException('The file is damaged');
    final date1904 = workbook.descendantElements.any(
      (e) => e.name.local == 'workbookPr' && const {'1', 'true'}.contains(_attr(e, 'date1904')),
    );
    final targets = <String, String>{};
    final rels = _parse(zip, 'xl/_rels/workbook.xml.rels');
    for (final r in rels?.descendantElements ?? const <XmlElement>[]) {
      if (r.name.local != 'Relationship') continue;
      final id = _attr(r, 'Id');
      var target = _attr(r, 'Target');
      if (id == null || target == null) continue;
      target = target.startsWith('/') ? target.substring(1) : 'xl/$target';
      targets[id] = target;
    }
    final sheetPaths = [
      for (final s in workbook.descendantElements)
        if (s.name.local == 'sheet')
          ?targets[_attr(s, 'id') ?? ''],
    ];
    if (sheetPaths.isEmpty) sheetPaths.add('xl/worksheets/sheet1.xml');

    final shared = <String>[];
    final sst = _parse(zip, 'xl/sharedStrings.xml');
    for (final si in sst?.rootElement.childElements ?? const <XmlElement>[]) {
      if (si.name.local == 'si') shared.add(_inlineText(si));
    }
    final dateStyles = _dateStyles(_parse(zip, 'xl/styles.xml'));

    final sheets = <List<List<String>>>[];
    for (final path in sheetPaths) {
      final doc = _parse(zip, path);
      if (doc == null) continue;
      final rows = <List<String>>[];
      for (final row in doc.descendantElements) {
        if (row.name.local != 'row') continue;
        final cells = <String>[];
        for (final c in row.childElements) {
          if (c.name.local != 'c') continue;
          final ref = _attr(c, 'r');
          final col = ref == null ? cells.length : columnIndex(ref);
          if (col < 0 || col > 16383) continue;
          final text = _cellValue(c, shared, dateStyles, date1904);
          if (text.isEmpty) continue;
          while (cells.length < col) {
            cells.add('');
          }
          if (col < cells.length) {
            cells[col] = text;
          } else {
            cells.add(text);
          }
        }
        if (cells.isNotEmpty) rows.add(cells);
      }
      sheets.add(rows);
    }
    return sheets;
  }

  static String _cellValue(XmlElement c, List<String> shared, Map<int, _Kind> dateStyles, bool date1904) {
    final type = _attr(c, 't') ?? 'n';
    XmlElement? child(String name) {
      for (final e in c.childElements) {
        if (e.name.local == name) return e;
      }
      return null;
    }

    final v = child('v')?.innerText ?? '';
    switch (type) {
      case 's':
        final i = int.tryParse(v.trim());
        return i == null || i < 0 || i >= shared.length ? '' : shared[i];
      case 'inlineStr':
        final s = child('is');
        return s == null ? v : _inlineText(s);
      case 'b':
        return v.trim() == '1' ? 'TRUE' : 'FALSE';
      case 'e':
        return '';
      case 'str':
        return v;
      case 'd':
        // An ISO 8601 date stored as text. Kept whole, so a "Z" or offset
        // still converts to local time when parsed.
        return v.trim();
      default:
        final n = double.tryParse(v.trim());
        if (n == null) return v;
        final kind = dateStyles[int.tryParse(_attr(c, 's') ?? '0') ?? 0];
        if (kind == null) return numberText(n);
        return serialText(
          n,
          date: kind.date,
          time: kind.time,
          duration: kind.duration,
          date1904: date1904,
        );
    }
  }

  /// Text of an `si` or `is` element: its `t`, or the `t` of each
  /// rich-text run. Leaves out phonetic hints (`rPh`).
  static String _inlineText(XmlElement e) {
    final out = StringBuffer();
    for (final c in e.childElements) {
      switch (c.name.local) {
        case 't':
          out.write(c.innerText);
        case 'r':
          for (final t in c.childElements) {
            if (t.name.local == 't') out.write(t.innerText);
          }
      }
    }
    return out.toString();
  }

  /// Which cell styles show a number as a date, a time or a duration.
  static Map<int, _Kind> _dateStyles(XmlDocument? styles) {
    if (styles == null) return const {};
    final custom = <int, String>{};
    for (final f in styles.descendantElements) {
      if (f.name.local != 'numFmt') continue;
      final id = int.tryParse(_attr(f, 'numFmtId') ?? '');
      if (id != null) custom[id] = _attr(f, 'formatCode') ?? '';
    }
    final out = <int, _Kind>{};
    for (final xfs in styles.descendantElements) {
      if (xfs.name.local != 'cellXfs') continue;
      var i = 0;
      for (final xf in xfs.childElements) {
        if (xf.name.local != 'xf') continue;
        final id = int.tryParse(_attr(xf, 'numFmtId') ?? '0') ?? 0;
        final kind = custom.containsKey(id) ? _Kind.ofCode(custom[id]!) : _Kind.builtIn(id);
        if (kind != null) out[i] = kind;
        i++;
      }
    }
    return out;
  }

  static XmlDocument? _parse(Archive zip, String path) {
    final f = zip.findFile(path);
    if (f == null) return null;
    try {
      return XmlDocument.parse(utf8.decode(f.content, allowMalformed: true));
    } on Object {
      throw const FormatException('The file is damaged');
    }
  }

  /// An attribute by local name, so "r:id" and "id" both match "id".
  static String? _attr(XmlElement e, String local) {
    for (final a in e.attributes) {
      if (a.name.local == local) return a.value;
    }
    return null;
  }
}

/// What a number format shows.
class _Kind {
  const _Kind({this.date = false, this.time = false, this.duration = false});
  final bool date;
  final bool time;
  final bool duration;

  static _Kind? builtIn(int id) {
    if (id >= 14 && id <= 17) return const _Kind(date: true);
    if (id == 22) return const _Kind(date: true, time: true);
    if (id == 46) return const _Kind(duration: true);
    if ((id >= 18 && id <= 21) || id == 45 || id == 47) return const _Kind(time: true);
    // East Asian locale dates.
    if ((id >= 27 && id <= 36) || (id >= 50 && id <= 58)) return const _Kind(date: true);
    return null;
  }

  static _Kind? ofCode(String code) {
    // Drop quoted text, escaped characters and [Red]-style tags, but keep
    // elapsed-time tags such as [h].
    final plain = code
        .replaceAll(RegExp(r'"[^"]*"'), '')
        .replaceAll(RegExp(r'\\.'), '')
        .replaceAll(RegExp(r'\[(?![hms]+\])[^\]]*\]', caseSensitive: false), '')
        .toLowerCase()
        .split(';')
        .first;
    if (RegExp(r'\[[hms]+\]').hasMatch(plain)) return const _Kind(duration: true);
    final date = plain.contains(RegExp('[yd]')) || (plain.contains('m') && !plain.contains(RegExp('[hs]')));
    final time = plain.contains(RegExp('[hs]'));
    if (!date && !time) return null;
    return _Kind(date: date, time: time);
  }
}

String _xml(String s) {
  final out = StringBuffer();
  for (final r in s.runes) {
    switch (r) {
      case 0x26:
        out.write('&amp;');
      case 0x3C:
        out.write('&lt;');
      case 0x3E:
        out.write('&gt;');
      case 0x22:
        out.write('&quot;');
      default:
        // XML 1.0 can't hold most control characters.
        if (r < 0x20 && r != 0x09 && r != 0x0A && r != 0x0D) continue;
        if (r == 0xFFFE || r == 0xFFFF) continue;
        out.writeCharCode(r);
    }
  }
  return out.toString();
}

/// Escapes text for XML, dropping characters XML can't hold.
String xmlEscape(String s) => _xml(s);
