import 'package:flutter/foundation.dart';

/// Where an entry came from in another Zero-Trust app: a task in ZT Tasks
/// or an event in ZT Calendar (roadmap TM-2, TM-5). Only the other app's
/// item id and the title it gave are kept; tapping the link asks that app
/// to open the item.
@immutable
class EntryLink {
  const EntryLink({required this.app, required this.id, this.title = ''});

  /// The other app's id: 'tasks', 'calendar', or another suite app.
  final String app;

  /// The item's id in that app.
  final String id;
  final String title;

  Map<String, Object?> toJson() => {'app': app, 'id': id, 'title': title};

  static EntryLink? fromJson(Object? json) {
    if (json is! Map) return null;
    final app = json['app'];
    final id = json['id'];
    if (app is! String || app.isEmpty || id is! String || id.isEmpty) return null;
    final title = json['title'];
    return EntryLink(app: app, id: id, title: title is String ? title : '');
  }

  @override
  bool operator ==(Object other) =>
      other is EntryLink && other.app == app && other.id == id && other.title == title;

  @override
  int get hashCode => Object.hash(app, id, title);
}

/// One stretch of tracked time. An entry without an [end] is a running
/// timer; it is synced like any other, so every device sees it running.
@immutable
class TimeEntry {
  const TimeEntry({
    required this.id,
    required this.start,
    this.end,
    this.description = '',
    this.projectId,
    this.tags = const [],
    this.billable = false,
    this.link,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String description;
  final String? projectId;
  final List<String> tags;

  /// Local time in memory, UTC in storage.
  final DateTime start;

  /// Null while the timer runs.
  final DateTime? end;
  final bool billable;

  /// The task or event this time was spent on, when it came from one.
  final EntryLink? link;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get running => end == null;

  /// Time tracked so far. Never negative, even when a clock moved back.
  Duration durationAt(DateTime now) {
    final d = (end ?? now).difference(start);
    return d.isNegative ? Duration.zero : d;
  }

  /// The local day the entry counts towards: the day it started.
  DateTime get day => DateTime(start.year, start.month, start.day);

  static const _unset = Object();

  TimeEntry copyWith({
    String? id,
    String? description,
    Object? projectId = _unset,
    List<String>? tags,
    DateTime? start,
    Object? end = _unset,
    bool? billable,
    Object? link = _unset,
    DateTime? createdAt,
  }) => TimeEntry(
    id: id ?? this.id,
    description: description ?? this.description,
    projectId: identical(projectId, _unset) ? this.projectId : projectId as String?,
    tags: tags ?? this.tags,
    start: start ?? this.start,
    end: identical(end, _unset) ? this.end : end as DateTime?,
    billable: billable ?? this.billable,
    link: identical(link, _unset) ? this.link : link as EntryLink?,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt,
  );

  Map<String, Object?> toJson() => {
    'description': description,
    'projectId': projectId,
    'tags': tags,
    'start': start.toUtc().toIso8601String(),
    'end': end?.toUtc().toIso8601String(),
    'billable': billable,
    if (link != null) 'link': link!.toJson(),
    'createdAt': createdAt?.toUtc().toIso8601String(),
  };

  /// Null when the entry has no readable start time.
  static TimeEntry? fromJson(String id, Map<String, Object?> json, DateTime updatedAt) {
    final start = _time(json['start']);
    if (start == null) return null;
    final end = _time(json['end']);
    return TimeEntry(
      id: id,
      description: (json['description'] as String?) ?? '',
      projectId: json['projectId'] as String?,
      tags: [
        for (final t in (json['tags'] as List?) ?? const [])
          if (t is String && t.trim().isNotEmpty) t.trim(),
      ],
      start: start,
      end: end,
      billable: json['billable'] == true,
      link: EntryLink.fromJson(json['link']),
      createdAt: _time(json['createdAt']),
      updatedAt: updatedAt,
    );
  }

  static DateTime? _time(Object? v) =>
      v is String ? DateTime.tryParse(v)?.toLocal() : null;
}
