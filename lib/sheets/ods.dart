import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'spreadsheet.dart';
import 'xlsx.dart' show xmlEscape;

/// Minimal OpenDocument spreadsheet (.ods), LibreOffice's own format: one
/// sheet with real dates, times, durations and numbers.
abstract final class Ods {
  static const mimeType = 'application/vnd.oasis.opendocument.spreadsheet';

  static String _two(int n) => n.toString().padLeft(2, '0');

  static Uint8List write(List<List<Object?>> rows, {String sheetName = 'Sheet1'}) {
    final body = StringBuffer();
    final columns = rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
    for (var c = 0; c < columns; c++) {
      body.write('<table:table-column table:style-name="co1"/>');
    }
    for (var r = 0; r < rows.length; r++) {
      body.write('<table:table-row>');
      for (final v in rows[r]) {
        if (r == 0) {
          body.write(_string(cellText(v), style: 'ceH'));
          continue;
        }
        body.write(switch (v) {
          null => '<table:table-cell/>',
          String s => s.isEmpty ? '<table:table-cell/>' : _string(s),
          SheetDate() =>
            '<table:table-cell table:style-name="ceD" office:value-type="date" '
                'office:date-value="${cellText(v)}"><text:p>${cellText(v)}</text:p></table:table-cell>',
          SheetTime(:final value) =>
            '<table:table-cell table:style-name="ceT" office:value-type="time" '
                'office:time-value="PT${_two(value.hour)}H${_two(value.minute)}M${_two(value.second)}S">'
                '<text:p>${cellText(v)}</text:p></table:table-cell>',
          Duration d =>
            '<table:table-cell table:style-name="ceE" office:value-type="time" '
                'office:time-value="PT${d.inHours}H${_two(d.inMinutes % 60)}M${_two(d.inSeconds % 60)}S">'
                '<text:p>${cellText(v)}</text:p></table:table-cell>',
          double n =>
            '<table:table-cell table:style-name="ceN" office:value-type="float" office:value="$n">'
                '<text:p>${cellText(n)}</text:p></table:table-cell>',
          num n =>
            '<table:table-cell office:value-type="float" office:value="$n"><text:p>$n</text:p></table:table-cell>',
          _ => _string('$v'),
        });
      }
      body.write('</table:table-row>');
    }

    const ns =
        'xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" '
        'xmlns:style="urn:oasis:names:tc:opendocument:xmlns:style:1.0" '
        'xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" '
        'xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" '
        'xmlns:number="urn:oasis:names:tc:opendocument:xmlns:datastyle:1.0" '
        'xmlns:fo="urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0" '
        'xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0"';
    final content =
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<office:document-content $ns office:version="1.2">'
        '<office:automatic-styles>'
        '<number:date-style style:name="N1"><number:year number:style="long"/><number:text>-</number:text>'
        '<number:month number:style="long"/><number:text>-</number:text><number:day number:style="long"/></number:date-style>'
        '<number:time-style style:name="N2"><number:hours number:style="long"/><number:text>:</number:text>'
        '<number:minutes number:style="long"/><number:text>:</number:text><number:seconds number:style="long"/></number:time-style>'
        // truncate-on-overflow="false" keeps counting past 24 hours, like [h].
        '<number:time-style style:name="N3" number:truncate-on-overflow="false"><number:hours number:style="long"/><number:text>:</number:text>'
        '<number:minutes number:style="long"/><number:text>:</number:text><number:seconds number:style="long"/></number:time-style>'
        '<number:number-style style:name="N4"><number:number number:decimal-places="2" number:min-integer-digits="1"/></number:number-style>'
        '<style:style style:name="co1" style:family="table-column"><style:table-column-properties style:column-width="1.2in"/></style:style>'
        '<style:style style:name="ceD" style:family="table-cell" style:data-style-name="N1"/>'
        '<style:style style:name="ceT" style:family="table-cell" style:data-style-name="N2"/>'
        '<style:style style:name="ceE" style:family="table-cell" style:data-style-name="N3"/>'
        '<style:style style:name="ceN" style:family="table-cell" style:data-style-name="N4"/>'
        '<style:style style:name="ceH" style:family="table-cell"><style:text-properties fo:font-weight="bold"/></style:style>'
        '</office:automatic-styles>'
        '<office:body><office:spreadsheet>'
        '<table:table table:name="${xmlEscape(sheetName)}">$body</table:table>'
        '</office:spreadsheet></office:body></office:document-content>';
    const manifest =
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<manifest:manifest xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0" manifest:version="1.2">'
        '<manifest:file-entry manifest:full-path="/" manifest:version="1.2" manifest:media-type="$mimeType"/>'
        '<manifest:file-entry manifest:full-path="content.xml" manifest:media-type="text/xml"/>'
        '</manifest:manifest>';

    final archive = Archive();
    // The mimetype entry must come first and be stored uncompressed.
    archive.addFile(
      ArchiveFile.bytes('mimetype', utf8.encode(mimeType))..compression = CompressionType.none,
    );
    archive.addFile(ArchiveFile.bytes('META-INF/manifest.xml', utf8.encode(manifest)));
    archive.addFile(ArchiveFile.bytes('content.xml', utf8.encode(content)));
    return ZipEncoder().encodeBytes(archive);
  }

  static String _string(String s, {String? style}) {
    final lines = s.split('\n').map((l) => '<text:p>${xmlEscape(l)}</text:p>').join();
    return '<table:table-cell${style == null ? '' : ' table:style-name="$style"'} '
        'office:value-type="string">$lines</table:table-cell>';
  }

  // ---------------------------------------------------------------- reading

  /// Repeated rows past this many are left out: LibreOffice writes the empty
  /// rest of a sheet as one row repeated about a million times.
  static const _maxRepeat = 10000;

  static List<List<List<String>>> read(Archive zip) {
    final f = zip.findFile('content.xml')!;
    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(utf8.decode(f.content, allowMalformed: true));
    } on Object {
      throw const FormatException('The file is damaged');
    }
    final sheets = <List<List<String>>>[];
    for (final table in doc.descendantElements) {
      if (table.name.local != 'table' || table.name.prefix != 'table') continue;
      final rows = <List<String>>[];
      for (final row in table.descendantElements) {
        if (row.name.local != 'table-row') continue;
        final cells = <String>[];
        var pendingEmpty = 0;
        for (final c in row.childElements) {
          if (c.name.local != 'table-cell' && c.name.local != 'covered-table-cell') continue;
          final repeat = int.tryParse(_attr(c, 'number-columns-repeated') ?? '1') ?? 1;
          final text = _cellValue(c);
          if (text.isEmpty) {
            pendingEmpty += repeat;
            continue;
          }
          for (var i = 0; i < pendingEmpty; i++) {
            cells.add('');
          }
          pendingEmpty = 0;
          for (var i = 0; i < repeat.clamp(1, 1024); i++) {
            cells.add(text);
          }
        }
        if (cells.isEmpty) continue;
        final repeat = (int.tryParse(_attr(row, 'number-rows-repeated') ?? '1') ?? 1).clamp(1, _maxRepeat);
        for (var i = 0; i < repeat; i++) {
          rows.add(List.of(cells));
        }
      }
      sheets.add(rows);
    }
    return sheets;
  }

  static String _cellValue(XmlElement c) {
    switch (_attr(c, 'value-type')) {
      case 'float' || 'percentage' || 'currency':
        final v = double.tryParse(_attr(c, 'value') ?? '');
        if (v != null) return numberText(v);
      case 'date':
        final v = _attr(c, 'date-value');
        if (v != null) {
          // With a "Z" or offset, keep it so parsing converts to local time.
          if (RegExp(r'T.*(Z|[+-]\d\d:?\d\d)$').hasMatch(v)) return v;
          return v.replaceFirst('T', ' ').replaceFirst(RegExp(r'\.\d+$'), '').replaceFirst(RegExp(r' 00:00:00$'), '');
        }
      case 'time':
        final v = _attr(c, 'time-value');
        final m = v == null ? null : RegExp(r'^-?P(?:(\d+)D)?T(?:(\d+)H)?(?:(\d+)M)?(?:([\d.]+)S)?$').firstMatch(v);
        if (m != null) {
          final sign = v!.startsWith('-') ? -1 : 1;
          final seconds = sign * ((int.parse(m.group(1) ?? '0') * 86400) +
              (int.parse(m.group(2) ?? '0') * 3600) +
              (int.parse(m.group(3) ?? '0') * 60) +
              (double.parse(m.group(4) ?? '0')).round());
          return serialText(seconds / 86400, date: false, time: false, duration: true);
        }
      case 'boolean':
        final v = _attr(c, 'boolean-value');
        if (v != null) return v == 'true' ? 'TRUE' : 'FALSE';
    }
    return [
      for (final p in c.childElements)
        if (p.name.local == 'p') _paragraph(p),
    ].join('\n');
  }

  /// A `text:p` element's text, with `text:s` spaces, tabs and line breaks.
  static String _paragraph(XmlNode node) {
    final out = StringBuffer();
    for (final n in node.children) {
      if (n is XmlText || n is XmlCDATA) {
        out.write(n.value);
      } else if (n is XmlElement) {
        switch (n.name.local) {
          case 's':
            out.write(' ' * (int.tryParse(_attr(n, 'c') ?? '1') ?? 1).clamp(1, 1000));
          case 'tab':
            out.write('\t');
          case 'line-break':
            out.write('\n');
          case 'annotation':
            break;
          default:
            out.write(_paragraph(n));
        }
      }
    }
    return out.toString();
  }

  static String? _attr(XmlElement e, String local) {
    for (final a in e.attributes) {
      if (a.name.local == local) return a.value;
    }
    return null;
  }
}
