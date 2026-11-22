import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/time_entry.dart';

// Time and the other Zero-Trust apps (roadmap TM-2 links, TM-5 events to
// time entries). Android only; every hand-over is between apps signed with
// the suite's own key, which the Android side checks (`ZtLinks.kt`).
// The protocol is written up in the project's reports, "zt-time-links".
//
// - Another app asks Time to track time on one of its items
//   (`bz.zerotrust.action.TRACK_TIME`): ZT Tasks for a task, ZT Calendar
//   for an event. With a start and end it becomes a time entry to check
//   and save; without, a timer starts.
// - Time asks ZT Tasks or ZT Calendar to pick an item
//   (`bz.zerotrust.action.PICK_TEXT`, the keyboard's "Insert from ZT apps"
//   pick, with `WANT_ITEM`): an app that knows `WANT_ITEM` answers the
//   item's id, title and times; one that doesn't answers only text.
// - A linked entry opens its item in the other app
//   (`bz.zerotrust.action.OPEN_ITEM`), or just the app if it can't.

/// The apps Time links to, by app id, with their Android package.
const Map<String, String> linkedApps = {
  'tasks': 'dev.sagron.zerotrusttasks',
  'calendar': 'dev.sagron.zerotrustcalendar',
};

/// The app id for an Android package of the suite, or null.
String? appForPackage(String? package) {
  if (package == null) return null;
  for (final e in linkedApps.entries) {
    if (e.value == package) return e.key;
  }
  // Another suite app: its id is the package name's last word.
  const prefix = 'dev.sagron.zerotrust';
  if (package.startsWith(prefix) && package.length > prefix.length) {
    return package.substring(prefix.length);
  }
  return null;
}

/// The app's name as the user sees it, e.g. "ZT Calendar".
String linkedAppName(String app) => switch (app) {
  'tasks' => 'ZT Tasks',
  'calendar' => 'ZT Calendar',
  _ => 'ZT ${app.isEmpty ? '' : app[0].toUpperCase() + app.substring(1)}',
};

DateTime? _ms(Object? v) => v is int ? DateTime.fromMillisecondsSinceEpoch(v) : null;

String _text(Object? v) => v is String ? v.trim() : '';

/// Another app asked Time to track time on one of its items.
@immutable
class TrackRequest {
  const TrackRequest({
    required this.app,
    this.itemId = '',
    this.title = '',
    this.start,
    this.end,
  });

  /// The asking app, from its Android package (not from what it claims).
  final String app;
  final String itemId;
  final String title;
  final DateTime? start;
  final DateTime? end;

  /// A finished stretch to save as an entry; otherwise start a timer.
  bool get isLog {
    final s = start, e = end;
    return s != null && e != null && e.isAfter(s);
  }

  EntryLink? get link =>
      itemId.isEmpty ? null : EntryLink(app: app, id: itemId, title: title);

  /// From the map `ZtLinks.kt` hands over, or null when it isn't one.
  static TrackRequest? fromMap(Map<Object?, Object?>? map) {
    if (map == null) return null;
    final app = appForPackage(map['package'] as String?);
    if (app == null) return null;
    return TrackRequest(
      app: app,
      itemId: _text(map['itemId']),
      title: _text(map['title']),
      start: _ms(map['start']),
      end: _ms(map['end']),
    );
  }
}

/// What the user picked in ZT Tasks or ZT Calendar.
@immutable
class PickedItem {
  const PickedItem({required this.app, this.text = '', this.itemId = '', this.title = '', this.start, this.end});

  final String app;

  /// The text the app typed for the keyboard; used when there is no title.
  final String text;
  final String itemId;
  final String title;
  final DateTime? start;
  final DateTime? end;

  /// The best words for the entry's description.
  String get description => title.isNotEmpty ? title : text;

  EntryLink? get link => itemId.isEmpty
      ? null
      : EntryLink(app: app, id: itemId, title: description);

  bool get hasTimes {
    final s = start, e = end;
    return s != null && e != null && e.isAfter(s);
  }

  static PickedItem? fromMap(String app, Map<Object?, Object?>? map) {
    if (map == null) return null;
    final item = PickedItem(
      app: app,
      text: _text(map['text']),
      itemId: _text(map['itemId']),
      title: _text(map['title']),
      start: _ms(map['start']),
      end: _ms(map['end']),
    );
    return item.description.isEmpty && item.itemId.isEmpty ? null : item;
  }
}

/// Talks to the other apps. [NoZtLinks] where there are none (tests, iOS).
abstract interface class ZtLinks {
  /// The request that opened Time, once; null when there is none.
  Future<TrackRequest?> takeTrackRequest();

  /// Tells the asking app whether the time was saved, and goes back to it.
  Future<void> finishTrack({required bool saved});

  /// Whether [app] is installed and can be asked to pick an item.
  Future<bool> canPick(String app);

  /// Lets the user pick an item in [app]; null when they backed out.
  Future<PickedItem?> pick(String app);

  /// Opens the linked item in its app (or the app). False when it isn't
  /// installed.
  Future<bool> open(EntryLink link);
}

class NoZtLinks implements ZtLinks {
  const NoZtLinks();
  @override
  Future<TrackRequest?> takeTrackRequest() async => null;
  @override
  Future<void> finishTrack({required bool saved}) async {}
  @override
  Future<bool> canPick(String app) async => false;
  @override
  Future<PickedItem?> pick(String app) async => null;
  @override
  Future<bool> open(EntryLink link) async => false;
}

class AndroidZtLinks implements ZtLinks {
  const AndroidZtLinks();
  static const _channel = MethodChannel('dev.sagron.zerotrusttime/links');

  Future<T?> _call<T>(String method, [Object? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<TrackRequest?> takeTrackRequest() async =>
      TrackRequest.fromMap(await _call<Map<Object?, Object?>>('takeTrack'));

  @override
  Future<void> finishTrack({required bool saved}) =>
      _call<void>('finishTrack', {'saved': saved});

  @override
  Future<bool> canPick(String app) async {
    final package = linkedApps[app];
    if (package == null) return false;
    return await _call<bool>('canPick', {'package': package}) ?? false;
  }

  @override
  Future<PickedItem?> pick(String app) async {
    final package = linkedApps[app];
    if (package == null) return null;
    return PickedItem.fromMap(
      app,
      await _call<Map<Object?, Object?>>('pick', {'package': package}),
    );
  }

  @override
  Future<bool> open(EntryLink link) async {
    final package = linkedApps[link.app] ?? 'dev.sagron.zerotrust${link.app}';
    return await _call<bool>('open', {'package': package, 'itemId': link.id}) ?? false;
  }
}

final ztLinksProvider = Provider<ZtLinks>((ref) {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return const AndroidZtLinks();
  }
  return const NoZtLinks();
});
