import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

import '../csv/csv.dart';
import 'ods.dart';
import 'xlsx.dart';

/// The file types a timesheet can be exported to.
enum SheetFormat {
  /// Excel. Also opens in Google Sheets, Numbers and LibreOffice.
  xlsx('xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),

  /// OpenDocument, LibreOffice's own format. Also opens in Excel and Sheets.
  ods('ods', 'application/vnd.oasis.opendocument.spreadsheet'),

  /// Plain text, for any app. UTF-8 with a byte-order mark, so Excel shows
  /// Hebrew and other non-Latin text correctly.
  csv('csv', 'text/csv');

  const SheetFormat(this.extension, this.mimeType);
  final String extension;
  final String mimeType;
}

/// A cell holding a calendar day (no time of day).
@immutable
class SheetDate {
  const SheetDate(this.value);
  final DateTime value;
}

/// A cell holding a time of day (no date).
@immutable
class SheetTime {
  const SheetTime(this.value);
  final DateTime value;
}

/// Writes [rows] as a file of [format]. A cell is a [String], a [num], a
/// [Duration], a [SheetDate], a [SheetTime] or null (empty). The first row is
/// the header. Spreadsheet formats get real dates, times and numbers, so
/// sorting, filtering and sums work there.
Uint8List writeSheet(SheetFormat format, List<List<Object?>> rows, {String name = 'Sheet1'}) =>
    switch (format) {
      SheetFormat.xlsx => Xlsx.write(rows, sheetName: name),
      SheetFormat.ods => Ods.write(rows, sheetName: name),
      SheetFormat.csv => Uint8List.fromList(
        utf8.encode('﻿${Csv.write([for (final r in rows) [for (final c in r) cellText(c)]])}'),
      ),
    };

String _two(int n) => n.toString().padLeft(2, '0');

/// How a cell reads as text: the same text the CSV export writes.
String cellText(Object? c) => switch (c) {
  null => '',
  String s => s,
  SheetDate(:final value) => '${value.year}-${_two(value.month)}-${_two(value.day)}',
  SheetTime(:final value) => '${_two(value.hour)}:${_two(value.minute)}:${_two(value.second)}',
  Duration d => '${_two(d.inHours)}:${_two(d.inMinutes % 60)}:${_two(d.inSeconds % 60)}',
  double v => v.toStringAsFixed(2),
  num v => '$v',
  _ => '$c',
};

/// The sheets in a spreadsheet or CSV file, each as rows of text cells.
/// Dates read as "2026-11-10", times as "14:05:09", dates with a time as
/// "2026-11-10 14:05:09", and numbers without a trailing ".0". Throws
/// [FormatException] for files that are not CSV, .xlsx or .ods.
List<List<List<String>>> readSheets(Uint8List bytes) {
  if (bytes.length >= 4 && bytes[0] == 0x50 && bytes[1] == 0x4B) {
    final Archive zip;
    try {
      zip = ZipDecoder().decodeBytes(bytes);
    } on Object {
      throw const FormatException('The file is damaged');
    }
    if (zip.findFile('xl/workbook.xml') != null) return Xlsx.read(zip);
    if (zip.findFile('content.xml') != null) return Ods.read(zip);
    throw const FormatException('Not a spreadsheet. Use .xlsx, .ods or .csv');
  }
  // The old binary Excel format (.xls) starts with the OLE2 signature.
  if (bytes.length >= 4 && bytes[0] == 0xD0 && bytes[1] == 0xCF && bytes[2] == 0x11 && bytes[3] == 0xE0) {
    throw const FormatException('Old .xls files can\'t be read. Save it as .xlsx or .csv first');
  }
  return [Csv.parse(_decodeText(bytes))];
}

/// UTF-8, or UTF-16 when the file starts with its byte-order mark (Excel's
/// "Unicode text" export).
String _decodeText(Uint8List bytes) {
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
    final units = <int>[for (var i = 2; i + 1 < bytes.length; i += 2) bytes[i] | (bytes[i + 1] << 8)];
    return String.fromCharCodes(units);
  }
  if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
    final units = <int>[for (var i = 2; i + 1 < bytes.length; i += 2) (bytes[i] << 8) | bytes[i + 1]];
    return String.fromCharCodes(units);
  }
  return utf8.decode(bytes, allowMalformed: true);
}

/// Shared by the readers: "1.5" stays "1.5", 2.0 becomes "2".
String numberText(double v) =>
    v == v.truncateToDouble() && v.abs() < 1e15 ? v.toInt().toString() : v.toString();

/// "2026-11-10", "14:05:09", "2026-11-10 14:05:09" or "25:00:00" for a date,
/// time or duration a spreadsheet stores as a count of days since 1899-12-30
/// (or 1904-01-01).
String serialText(double serial, {required bool date, required bool time, required bool duration, bool date1904 = false}) {
  final seconds = (serial * 86400).round();
  if (duration) {
    final d = Duration(seconds: seconds.abs());
    return '${seconds < 0 ? '-' : ''}${_two(d.inHours)}:${_two(d.inMinutes % 60)}:${_two(d.inSeconds % 60)}';
  }
  final base = date1904 ? DateTime.utc(1904) : DateTime.utc(1899, 12, 30);
  final t = base.add(Duration(seconds: seconds));
  final day = '${t.year}-${_two(t.month)}-${_two(t.day)}';
  final clock = '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';
  if (date && time) return '$day $clock';
  if (time) return clock;
  return day;
}
