/// Minimal RFC 4180 CSV: quoted fields, doubled quotes, line breaks inside
/// quotes. Enough for timesheet exports from this and other trackers.
abstract final class Csv {
  static String write(List<List<String>> rows) {
    final out = StringBuffer();
    for (final row in rows) {
      out.writeln(row.map(_field).join(','));
    }
    return out.toString();
  }

  static String _field(String v) {
    // A leading = + - @ would run as a formula when the file is opened in a
    // spreadsheet; a leading apostrophe makes it plain text there.
    final safe = v.isNotEmpty && '=+-@\t\r'.contains(v[0]) ? "'$v" : v;
    return safe.contains(RegExp('[",\n\r]')) ? '"${safe.replaceAll('"', '""')}"' : safe;
  }

  /// Rows of fields. [separator] defaults to whichever of `,` `;` or tab the
  /// first line uses most.
  static List<List<String>> parse(String text, {String? separator}) {
    if (text.startsWith('﻿')) text = text.substring(1);
    final sep = separator ?? _guessSeparator(text);
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var quoted = false;
    var i = 0;

    void endField() {
      row.add(field.toString());
      field.clear();
    }

    void endRow() {
      endField();
      if (row.length > 1 || row.first.isNotEmpty) rows.add(row);
      row = <String>[];
    }

    while (i < text.length) {
      final c = text[i];
      if (quoted) {
        if (c == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            quoted = false;
          }
        } else {
          field.write(c);
        }
      } else if (c == '"' && field.isEmpty) {
        quoted = true;
      } else if (c == sep) {
        endField();
      } else if (c == '\n') {
        endRow();
      } else if (c != '\r') {
        field.write(c);
      }
      i++;
    }
    if (field.isNotEmpty || row.isNotEmpty) endRow();
    return rows;
  }

  static String _guessSeparator(String text) {
    final end = text.indexOf('\n');
    final line = end < 0 ? text : text.substring(0, end);
    var best = ',';
    var bestCount = -1;
    for (final s in const [',', ';', '\t']) {
      final n = s.allMatches(line).length;
      if (n > bestCount) {
        best = s;
        bestCount = n;
      }
    }
    return best;
  }
}
