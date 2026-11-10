import 'package:flutter/foundation.dart';

/// Colours offered for projects (the suite's accents plus a few more).
const projectColors = <int>[
  0xFF3B82F6, // blue
  0xFF06B6D4, // cyan
  0xFF10B981, // green
  0xFF84CC16, // lime
  0xFFF59E0B, // amber
  0xFFF97316, // orange
  0xFFEF4444, // red
  0xFFEC4899, // pink
  0xFF8B5CF6, // violet
  0xFF64748B, // slate
];

/// Entries without a project are drawn in this colour.
const noProjectColor = 0xFF94A3B8;

/// What tracked time is for. A project may belong to a client and carry an
/// hourly rate, which turns billable hours into an amount in reports.
@immutable
class Project {
  const Project({
    required this.id,
    required this.name,
    this.client = '',
    this.color = 0xFF3B82F6,
    this.hourlyRate,
    this.billable = false,
    this.archived = false,
  });

  final String id;
  final String name;
  final String client;
  final int color;

  /// In the currency chosen in settings. Null: no amount is worked out.
  final double? hourlyRate;

  /// Whether new entries on this project start as billable.
  final bool billable;

  /// Hidden from pickers; its entries and reports stay.
  final bool archived;

  static const _unset = Object();

  Project copyWith({
    String? name,
    String? client,
    int? color,
    Object? hourlyRate = _unset,
    bool? billable,
    bool? archived,
  }) => Project(
    id: id,
    name: name ?? this.name,
    client: client ?? this.client,
    color: color ?? this.color,
    hourlyRate: identical(hourlyRate, _unset) ? this.hourlyRate : hourlyRate as double?,
    billable: billable ?? this.billable,
    archived: archived ?? this.archived,
  );

  Map<String, Object?> toJson() => {
    'name': name,
    'client': client,
    'color': color,
    'hourlyRate': hourlyRate,
    'billable': billable,
    'archived': archived,
  };

  static Project fromJson(String id, Map<String, Object?> json) => Project(
    id: id,
    name: (json['name'] as String?) ?? '',
    client: (json['client'] as String?) ?? '',
    color: (json['color'] as num?)?.toInt() ?? 0xFF3B82F6,
    hourlyRate: (json['hourlyRate'] as num?)?.toDouble(),
    billable: json['billable'] == true,
    archived: json['archived'] == true,
  );
}
