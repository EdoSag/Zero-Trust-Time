import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_time/model/place_rule.dart';
import 'package:zerotrust_time/model/project.dart';
import 'package:zerotrust_time/places/place_timer.dart';
import 'package:zerotrust_time/ui/place_rules_page.dart';
import 'package:zt_places/zt_places.dart';

import 'app_test.dart' show app, repo;

void main() {
  const office = ZtPlace(id: 'p1', name: 'Office', latitude: 32.0853, longitude: 34.7818, radiusMeters: 300);
  const rule = PlaceRule(id: 'r1', place: office, projectId: 'web');

  test('a rule keeps everything through storage', () {
    final back = PlaceRule.fromJson('r1', rule.toJson());
    expect(back, rule);
    final off = rule.copyWith(enabled: false, stopOnLeave: false, projectId: null);
    expect(PlaceRule.fromJson('r1', off.toJson()), off);
    expect(PlaceRule.fromJson('r1', {'place': 'nowhere'}), isNull);
  });

  test('Android gets the place and what to do, never its name', () {
    final watch = rule.toWatch();
    expect(watch['latitude'], 32.0853);
    expect(watch['radius'], 300);
    expect(watch['projectId'], 'web');
    expect(watch.values, isNot(contains('Office')));
  });

  test('only active rules are watched', () async {
    final timer = NoPlaceTimer(supported: true);
    final n = await timer.sync([
      rule,
      rule.copyWith(enabled: false),
      const PlaceRule(id: 'r3', place: office, startOnArrive: false, stopOnLeave: false),
    ]);
    expect(n, 1);
    expect(timer.watched.single.id, 'r1');
  });

  testWidgets('the editor saves the project and switches', (tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    const web = Project(id: 'web', name: 'Website');
    await tester.pumpWidget(app(
      const PlaceRuleEditorPage(
        rule: PlaceRule(id: 'r1', place: office),
        isNew: true,
      ),
      projects: const [web],
    ));
    await tester.pumpAndSettle();
    expect(find.text('Office'), findsWidgets);
    expect(find.text('Start a timer when I arrive'), findsOneWidget);
    await tester.tap(find.text('Stop it when I leave'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final saved = repo.placeRules['r1']!;
    expect(saved.startOnArrive, isTrue);
    expect(saved.stopOnLeave, isFalse);
  });
}
