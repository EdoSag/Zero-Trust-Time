import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:zt_places/zt_places.dart';

/// "Start the timer when I arrive at the office, stop it when I leave"
/// (roadmap TM-3). Kept in the encrypted store like entries and projects;
/// each phone hands only the place, the project id and the two switches to
/// Android to watch (see `PlaceTimer.kt`).
///
/// Passing by is not arriving: the timer starts only after staying for
/// [startAfterMinutes] and stops only after being away for
/// [stopAfterMinutes] (see `PlaceDwell.kt`). The entry still begins at the
/// arrival and ends at the leaving.
@immutable
class PlaceRule {
  const PlaceRule({
    required this.id,
    required this.place,
    this.projectId,
    this.startOnArrive = true,
    this.stopOnLeave = true,
    this.enabled = true,
    this.radiusMeters,
    this.startAfterMinutes = defaultStartAfterMinutes,
    this.stopAfterMinutes = defaultStopAfterMinutes,
  });

  /// Kept in step with `PlaceDwell.kt`, which uses the same for places
  /// stored on the phone before these existed.
  static const defaultStartAfterMinutes = 5;
  static const defaultStopAfterMinutes = 5;

  /// 0 is "right away".
  static const waitChoices = [0, 1, 2, 3, 5, 10, 15];

  /// Smaller than the shared place picker offers ([ZtPlace.minRadius]):
  /// fine for a timer that waits before it starts, with a good GPS signal.
  static const radiusChoices = <double>[50, 100, 150, 300, 500, 1000];

  final String id;
  final ZtPlace place;

  /// How close counts as there, when it isn't the [place]'s own radius.
  final double? radiusMeters;

  double get radius => radiusMeters ?? place.radiusMeters;

  /// Minutes to stay before the timer starts; 0 starts it right away.
  final int startAfterMinutes;

  /// Minutes away before the timer stops; 0 stops it right away.
  final int stopAfterMinutes;

  /// The project the started timer is for, or none.
  final String? projectId;
  final bool startOnArrive;

  /// Stops the timer this place started (not one started by hand).
  final bool stopOnLeave;
  final bool enabled;

  bool get active => enabled && (startOnArrive || stopOnLeave);

  static const _unset = Object();

  PlaceRule copyWith({
    ZtPlace? place,
    Object? projectId = _unset,
    bool? startOnArrive,
    bool? stopOnLeave,
    bool? enabled,
    Object? radiusMeters = _unset,
    int? startAfterMinutes,
    int? stopAfterMinutes,
  }) => PlaceRule(
    id: id,
    place: place ?? this.place,
    projectId: identical(projectId, _unset) ? this.projectId : projectId as String?,
    startOnArrive: startOnArrive ?? this.startOnArrive,
    stopOnLeave: stopOnLeave ?? this.stopOnLeave,
    enabled: enabled ?? this.enabled,
    radiusMeters: identical(radiusMeters, _unset)
        ? this.radiusMeters
        : (radiusMeters as num?)?.toDouble(),
    startAfterMinutes: startAfterMinutes ?? this.startAfterMinutes,
    stopAfterMinutes: stopAfterMinutes ?? this.stopAfterMinutes,
  );

  Map<String, Object?> toJson() => {
    'place': place.toJson(),
    'projectId': projectId,
    'startOnArrive': startOnArrive,
    'stopOnLeave': stopOnLeave,
    'enabled': enabled,
    if (radiusMeters != null) 'radius': radiusMeters,
    'startAfter': startAfterMinutes,
    'stopAfter': stopAfterMinutes,
  };

  static int _minutes(Object? value, int fallback) =>
      value is num ? value.round().clamp(0, 60) : fallback;

  static PlaceRule? fromJson(String id, Map<String, Object?> json) {
    final place = ZtPlace.fromJson(json['place']);
    if (place == null) return null;
    return PlaceRule(
      id: id,
      place: place,
      projectId: json['projectId'] as String?,
      startOnArrive: json['startOnArrive'] != false,
      stopOnLeave: json['stopOnLeave'] != false,
      enabled: json['enabled'] != false,
      radiusMeters: switch (json['radius']) {
        final num r when r > 0 => math.max(radiusChoices.first, r.toDouble()),
        _ => null,
      },
      // Rules saved before the waits existed get them too.
      startAfterMinutes: _minutes(json['startAfter'], defaultStartAfterMinutes),
      stopAfterMinutes: _minutes(json['stopAfter'], defaultStopAfterMinutes),
    );
  }

  /// What Android watches: no names, only where and what to do.
  Map<String, Object?> toWatch() => {
    'id': id,
    'latitude': place.latitude,
    'longitude': place.longitude,
    'radius': radius,
    'projectId': projectId ?? '',
    'start': startOnArrive,
    'stop': stopOnLeave,
    'startAfter': startAfterMinutes,
    'stopAfter': stopAfterMinutes,
  };

  @override
  bool operator ==(Object other) =>
      other is PlaceRule &&
      other.id == id &&
      other.place == place &&
      other.projectId == projectId &&
      other.startOnArrive == startOnArrive &&
      other.stopOnLeave == stopOnLeave &&
      other.enabled == enabled &&
      other.radiusMeters == radiusMeters &&
      other.startAfterMinutes == startAfterMinutes &&
      other.stopAfterMinutes == stopAfterMinutes;

  @override
  int get hashCode => Object.hash(
    id,
    place,
    projectId,
    startOnArrive,
    stopOnLeave,
    enabled,
    radiusMeters,
    startAfterMinutes,
    stopAfterMinutes,
  );
}
