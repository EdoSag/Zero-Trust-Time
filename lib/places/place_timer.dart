import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zt_places/zt_places.dart';

import '../model/place_rule.dart';

/// Hands the place rules to Android, which watches the places and starts
/// or stops the timer (see `PlaceTimer.kt`).
abstract interface class PlaceTimer {
  bool get supported;

  /// Watches exactly the active [rules]. Returns how many are watched.
  Future<int> sync(List<PlaceRule> rules);

  /// Forgets every place (sign-out).
  Future<void> clear();
}

class NoPlaceTimer implements PlaceTimer {
  NoPlaceTimer({this.supported = false});
  @override
  final bool supported;
  List<PlaceRule> watched = const [];
  @override
  Future<int> sync(List<PlaceRule> rules) async {
    watched = [for (final r in rules) if (r.active) r];
    return watched.length;
  }

  @override
  Future<void> clear() async => watched = const [];
}

class AndroidPlaceTimer implements PlaceTimer {
  const AndroidPlaceTimer();
  static const _channel = MethodChannel('dev.sagron.zerotrusttime/places');

  @override
  bool get supported => true;

  @override
  Future<int> sync(List<PlaceRule> rules) async =>
      await _channel.invokeMethod<int>('sync', {
        'rules': [for (final r in rules) if (r.active) r.toWatch()],
      }) ??
      0;

  @override
  Future<void> clear() => _channel.invokeMethod<void>('clear');
}

bool get _android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

final placeTimerProvider = Provider<PlaceTimer>(
  (ref) => _android ? const AndroidPlaceTimer() : NoPlaceTimer(),
);

/// The shared place picker's permissions and current location.
final placeRemindersProvider = Provider<ZtPlaceReminders>(
  (ref) => _android ? ZtPlaceRemindersAndroid() : ZtPlaceRemindersFake(supported: false),
);
