import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_time/model/project.dart';
import 'package:zerotrust_time/model/time_entry.dart';
import 'package:zerotrust_time/ui/home_page.dart';
import 'package:zerotrust_time/util/format.dart';

import 'app_test.dart' show app;

void main() {
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
  }

  test('every English string has a Hebrew translation with the same placeholders', () {
    Map<String, dynamic> read(String name) =>
        jsonDecode(File('lib/l10n/$name').readAsStringSync()) as Map<String, dynamic>;
    final en = read('app_en.arb');
    final he = read('app_he.arb');
    final placeholder = RegExp(r'\{(\w+)[,}]');
    for (final key in en.keys.where((k) => !k.startsWith('@'))) {
      expect(he[key], isA<String>(), reason: 'app_he.arb is missing "$key"');
      Set<String?> names(String s) => placeholder.allMatches(s).map((m) => m[1]).toSet();
      expect(names(he[key] as String), names(en[key] as String), reason: key);
    }
  });

  testWidgets('Hebrew: the timer screen is translated and right-to-left', (tester) async {
    phone(tester);
    const web = Project(id: 'web', name: 'Website', client: 'Acme', hourlyRate: 100, billable: true);
    final now = DateTime.now();
    final y9 = DateTime(now.year, now.month, now.day - 1, 9);
    final done = TimeEntry(
      id: 'done',
      description: 'Landing page',
      projectId: 'web',
      start: y9,
      end: y9.add(const Duration(minutes: 90)),
    );
    await tester.pumpWidget(
      app(const HomePage(), entries: [done], projects: const [web], locale: ZtLanguages.hebrew),
    );
    await tester.pumpAndSettle();

    expect(find.text('טיימר'), findsWidgets); // Title and tab.
    expect(find.text('אתמול'), findsOneWidget); // "Yesterday".
    expect(find.text('על מה עובדים עכשיו?'), findsOneWidget);
    expect(Directionality.of(tester.element(find.byType(HomePage))), TextDirection.rtl);

    // Right-to-left for real: the day's name is on the right and its total
    // on the left; the Start button sits on the left end of its row.
    final day = tester.getRect(find.text('אתמול'));
    final total = tester.getRect(find.text('1 ש׳ 30 ד׳'));
    expect(day.left, greaterThan(total.right));
    final start = tester.getRect(find.text('התחלה'));
    final billable = tester.getRect(find.text('לחיוב'));
    expect(start.right, lessThan(billable.left));
    expect(tester.takeException(), isNull);

    // The tabs: Timer is the right-most.
    final timerTab = tester.getRect(find.descendant(of: find.byType(NavigationBar), matching: find.text('טיימר')));
    final projectsTab = tester.getRect(find.text('פרויקטים'));
    expect(timerTab.left, greaterThan(projectsTab.right));
  });

  testWidgets('Hebrew: every tab lays out at 200% text size', (tester) async {
    phone(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(app(const HomePage(), locale: ZtLanguages.hebrew));
    await tester.pumpAndSettle();
    for (final tab in ['דוחות', 'פרויקטים', 'טיימר']) {
      await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(tab)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: tab);
    }
  });

  testWidgets('durations and days follow the language', (tester) async {
    await tester.pumpWidget(app(const SizedBox(), locale: ZtLanguages.hebrew));
    await tester.pumpAndSettle();
    expect(formatDuration(const Duration(minutes: 450)), '7 ש׳ 30 ד׳');
    expect(formatDuration(const Duration(minutes: 450), decimal: true), '7.50 ש׳');
    expect(relativeDay(DateTime.now()), 'היום');

    await tester.pumpWidget(app(const SizedBox(key: Key('en'))));
    await tester.pumpAndSettle();
    expect(formatDuration(const Duration(minutes: 450)), '7h 30m');
    expect(relativeDay(DateTime.now()), 'Today');
  });
}
