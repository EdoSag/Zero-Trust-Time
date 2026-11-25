import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart' show ZtLanguages;
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
    final tuned = rule.copyWith(radiusMeters: 50, startAfterMinutes: 10, stopAfterMinutes: 0);
    expect(PlaceRule.fromJson('r1', tuned.toJson()), tuned);
    expect(tuned.copyWith(radiusMeters: null).radius, 300);
  });

  test('a rule saved before the waits existed waits by default', () {
    final old = PlaceRule.fromJson('r1', {
      'place': office.toJson(),
      'projectId': 'web',
      'startOnArrive': true,
      'stopOnLeave': true,
      'enabled': true,
    })!;
    expect(old, rule);
    expect(old.startAfterMinutes, 5);
    expect(old.stopAfterMinutes, 5);
    expect(old.radius, 300);
    // Nonsense from another device is kept within bounds.
    final odd = PlaceRule.fromJson('r1', {
      'place': office.toJson(),
      'radius': 3,
      'startAfter': -4,
      'stopAfter': 9000,
    })!;
    expect(odd.radius, 50);
    expect(odd.startAfterMinutes, 0);
    expect(odd.stopAfterMinutes, 60);
  });

  test('Android gets the place and what to do, never its name', () {
    final watch = rule.toWatch();
    expect(watch['latitude'], 32.0853);
    expect(watch['radius'], 300);
    expect(watch['projectId'], 'web');
    expect(watch['startAfter'], 5);
    expect(watch['stopAfter'], 5);
    expect(watch.values, isNot(contains('Office')));
    // A distance chosen for the timer wins over the place's own.
    expect(rule.copyWith(radiusMeters: 50).toWatch()['radius'], 50);
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

  testWidgets('the editor sets how close and how long to wait', (tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(
      const PlaceRuleEditorPage(rule: PlaceRule(id: 'r1', place: office), isNew: true),
    ));
    await tester.pumpAndSettle();
    // The waits show, each beside its own switch and inside the screen.
    final width = tester.getSize(find.byType(Scaffold)).width;
    for (final key in const ['startAfter', 'stopAfter']) {
      final tile = find.byKey(ValueKey(key));
      expect(find.descendant(of: tile, matching: find.text('5 minutes')), findsOneWidget);
      final box = tester.getRect(find.descendant(of: tile, matching: find.text('5 minutes')));
      expect(box.left, greaterThanOrEqualTo(0));
      expect(box.right, lessThanOrEqualTo(width));
    }
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('startAfter'))).dy,
      greaterThan(tester.getTopLeft(find.text('Start a timer when I arrive')).dy),
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('stopAfter'))).dy,
      greaterThan(tester.getTopLeft(find.text('Stop it when I leave')).dy),
    );
    // Every distance fits on the screen; under 100 m comes with a warning.
    for (final label in const ['50 m', '100 m', '150 m', '300 m', '500 m', '1 km']) {
      final chip = tester.getRect(find.widgetWithText(ChoiceChip, label));
      expect(chip.left, greaterThanOrEqualTo(0), reason: label);
      expect(chip.right, lessThanOrEqualTo(width), reason: label);
    }
    expect(find.textContaining('good GPS signal'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, '50 m'));
    await tester.pumpAndSettle();
    expect(find.textContaining('good GPS signal'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('startAfter')));
    await tester.pumpAndSettle();
    expect(find.text('5 minutes  ✓'), findsOneWidget);
    await tester.tap(find.text('10 minutes'));
    await tester.pumpAndSettle();
    // The page scrolls on a phone this size.
    await tester.ensureVisible(find.byKey(const ValueKey('stopAfter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stopAfter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No wait'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byKey(const ValueKey('stopAfter')), matching: find.text('No wait')),
      findsOneWidget,
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final saved = repo.placeRules['r1']!;
    expect(saved.radius, 50);
    expect(saved.startAfterMinutes, 10);
    expect(saved.stopAfterMinutes, 0);
  });

  testWidgets('a switched off half hides its wait', (tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(
      const PlaceRuleEditorPage(
        rule: PlaceRule(id: 'r1', place: office, startOnArrive: false),
        isNew: true,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('startAfter')), findsNothing);
    expect(find.byKey(const ValueKey('stopAfter')), findsOneWidget);
  });

  testWidgets('Hebrew: the waits and distances are translated and right-to-left', (tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(
      const PlaceRuleEditorPage(rule: PlaceRule(id: 'r1', place: office), isNew: true),
      locale: ZtLanguages.hebrew,
    ));
    await tester.pumpAndSettle();
    final width = tester.getSize(find.byType(Scaffold)).width;
    final tile = find.byKey(const ValueKey('startAfter'));
    final title = tester.getRect(find.descendant(of: tile, matching: find.text('המתנה לפני הפעלה')));
    final value = tester.getRect(find.descendant(of: tile, matching: find.text('5 דקות')));
    // The value sits at the far (left) end, clear of the title.
    expect(value.right, lessThanOrEqualTo(title.left));
    expect(value.left, greaterThanOrEqualTo(0));
    expect(title.right, lessThanOrEqualTo(width));
    expect(find.text('המתנה לפני עצירה'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '50 מ׳'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '1 ק״מ'), findsOneWidget);
  });
}
