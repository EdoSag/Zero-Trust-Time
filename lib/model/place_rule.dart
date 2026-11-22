import 'package:flutter/foundation.dart';
import 'package:zt_places/zt_places.dart';

/// "Start the timer when I arrive at the office, stop it when I leave"
/// (roadmap TM-3). Kept in the encrypted store like entries and projects;
/// each phone hands only the place, the project id and the two switches to
/// Android to watch (see `PlaceTimer.kt`).
@immutable
class PlaceRule {
  const PlaceRule({
    required this.id,
    required this.place,
    this.projectId,
    this.startOnArrive = true,
    this.stopOnLeave = true,
    this.enabled = true,
  });

  final String id;
  final ZtPlace place;

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
  }) => PlaceRule(
    id: id,
    place: place ?? this.place,
    projectId: identical(projectId, _unset) ? this.projectId : projectId as String?,
    startOnArrive: startOnArrive ?? this.startOnArrive,
    stopOnLeave: stopOnLeave ?? this.stopOnLeave,
    enabled: enabled ?? this.enabled,
  );

  Map<String, Object?> toJson() => {
    'place': place.toJson(),
    'projectId': projectId,
    'startOnArrive': startOnArrive,
    'stopOnLeave': stopOnLeave,
    'enabled': enabled,
  };

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
    );
  }

  /// What Android watches: no names, only where and what to do.
  Map<String, Object?> toWatch() => {
    'id': id,
    'latitude': place.latitude,
    'longitude': place.longitude,
    'radius': place.radiusMeters,
    'projectId': projectId ?? '',
    'start': startOnArrive,
    'stop': stopOnLeave,
  };

  @override
  bool operator ==(Object other) =>
      other is PlaceRule &&
      other.id == id &&
      other.place == place &&
      other.projectId == projectId &&
      other.startOnArrive == startOnArrive &&
      other.stopOnLeave == stopOnLeave &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(id, place, projectId, startOnArrive, stopOnLeave, enabled);
}
