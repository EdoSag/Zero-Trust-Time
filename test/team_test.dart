import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_time/data/time_store.dart';
import 'package:zerotrust_time/model/project.dart';
import 'package:zerotrust_time/model/report.dart';
import 'package:zerotrust_time/model/time_entry.dart';
import 'package:zerotrust_time/team/team.dart';
import 'package:zerotrust_time/ui/home_page.dart';
import 'package:zerotrust_time/ui/reports_tab.dart';

import 'app_test.dart' show app;

void main() {
  final now = DateTime.now();
  final today9 = DateTime(now.year, now.month, now.day, 9);
  TimeEntry teamEntry(String who, String id, String text, int minutes, {bool billable = false}) => TimeEntry(
    id: 'entry/$who/$id',
    space: 't1',
    description: text,
    projectId: 'site',
    billable: billable,
    start: today9,
    end: today9.add(Duration(minutes: minutes)),
  );
  final mine = teamEntry('me', 'a', 'Homepage copy', 60, billable: true);
  final dana = teamEntry('dana', 'b', 'Logo sketches', 90);

  group('team data', () {
    test('a team entry names who logged it', () {
      expect(mine.ownerId, 'me');
      expect(TimeEntry(id: 'plain-uuid', start: today9).ownerId, isNull);
      expect(TimeEntry(id: 'entry//x', start: today9).ownerId, isNull);
    });

    test("only the account's own time is its own", () {
      expect(isMine(mine, 'me'), isTrue);
      expect(isMine(dana, 'me'), isFalse);
      expect(isMine(TimeEntry(id: 'x', start: today9), 'me'), isTrue);
    });

    test('the policy keeps projects to owners and entries to their author', () {
      expect(timeSpacePolicy.isAdminOnly('p1', {'kind': 'project'}), isTrue);
      expect(timeSpacePolicy.isAdminOnly(teamItemId, {'kind': teamKind}), isTrue);
      expect(timeSpacePolicy.isAdminOnly(mine.id, {'kind': 'entry'}), isFalse);
      expect(timeSpacePolicy.ownerOf(mine.id), 'me');
      expect(timeSpacePolicy.ownerOf(dana.id), 'dana');
    });

    test('time per member, most first', () {
      final totals = totalsByMember([mine, dana], now);
      expect(totals.map((t) => t.userId), ['dana', 'me']);
      expect(totals.last.billable, const Duration(hours: 1));
    });
  });

  testWidgets('in a team: my timesheet, the whole team in reports, projects for owners only',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    // Members carry public keys in the real app; a name is enough here.
    const team = Team(spaceId: 't1', name: 'Acme Studio', isOwner: false);
    await tester.pumpWidget(app(
      const HomePage(),
      entries: [mine, dana],
      projects: const [Project(id: 'site', name: 'Website', space: 't1')],
      teams: const [team],
      workspace: 't1',
    ));
    await tester.pumpAndSettle();
    expect(find.text('Acme Studio'), findsOneWidget);
    expect(find.text('Homepage copy'), findsOneWidget);
    expect(find.text('Logo sketches'), findsNothing);

    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('By member'),
      200,
      scrollable: find.descendant(of: find.byType(ReportsTab), matching: find.byType(Scrollable)).first,
    );
    expect(find.text('You'), findsOneWidget);
    // Dana left the member list here: shown as a former member.
    expect(find.text('Former member'), findsOneWidget);

    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('New project'), findsNothing);
  });
}
