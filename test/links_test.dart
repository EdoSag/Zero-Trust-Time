import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_time/links/zt_links.dart';
import 'package:zerotrust_time/model/time_entry.dart';
import 'package:zerotrust_time/ui/entry_editor_page.dart';

import 'app_test.dart' show app, repo;

/// ZT Calendar installed, answering a pick with [answer].
class FakeLinks implements ZtLinks {
  FakeLinks({this.answer});
  final PickedItem? answer;
  final opened = <EntryLink>[];

  @override
  Future<bool> canPick(String app) async => app == 'calendar';
  @override
  Future<PickedItem?> pick(String app) async => answer;
  @override
  Future<bool> open(EntryLink link) async {
    opened.add(link);
    return true;
  }

  @override
  Future<TrackRequest?> takeTrackRequest() async => null;
  @override
  Future<void> finishTrack({required bool saved}) async {}
}

void main() {
  final nine = DateTime(2026, 11, 23, 9);
  final ten = DateTime(2026, 11, 23, 10, 30);

  group('link data', () {
    test('an entry keeps its link through storage', () {
      final e = TimeEntry(
        id: '1',
        start: nine,
        end: ten,
        link: const EntryLink(app: 'calendar', id: 'ev1', title: 'Standup'),
      );
      final back = TimeEntry.fromJson('1', e.toJson(), nine)!;
      expect(back.link, const EntryLink(app: 'calendar', id: 'ev1', title: 'Standup'));
    });

    test('entries without a link, or with a broken one, have none', () {
      final plain = TimeEntry(id: '1', start: nine, end: ten);
      expect(plain.toJson().containsKey('link'), isFalse);
      final json = plain.toJson()..['link'] = {'app': 'tasks'};
      expect(TimeEntry.fromJson('1', json, nine)!.link, isNull);
    });

    test('the asking app comes from its package, not from what it says', () {
      expect(appForPackage('dev.sagron.zerotrusttasks'), 'tasks');
      expect(appForPackage('dev.sagron.zerotrustcalendar'), 'calendar');
      expect(appForPackage('dev.sagron.zerotrustnotes'), 'notes');
      expect(appForPackage('com.example.evil'), isNull);
      expect(TrackRequest.fromMap({'package': 'com.example.evil', 'title': 'x'}), isNull);
    });

    test('a request with start and end is a time entry, otherwise a timer', () {
      final log = TrackRequest.fromMap({
        'package': 'dev.sagron.zerotrustcalendar',
        'itemId': 'ev1',
        'title': ' Standup ',
        'start': nine.millisecondsSinceEpoch,
        'end': ten.millisecondsSinceEpoch,
      })!;
      expect(log.isLog, isTrue);
      expect(log.title, 'Standup');
      expect(log.link, const EntryLink(app: 'calendar', id: 'ev1', title: 'Standup'));
      final timer = TrackRequest.fromMap({
        'package': 'dev.sagron.zerotrusttasks',
        'itemId': 't1',
        'title': 'Write report',
      })!;
      expect(timer.isLog, isFalse);
      expect(timer.app, 'tasks');
      // An end before the start is not a stretch of time.
      final backwards = TrackRequest.fromMap({
        'package': 'dev.sagron.zerotrustcalendar',
        'start': ten.millisecondsSinceEpoch,
        'end': nine.millisecondsSinceEpoch,
      })!;
      expect(backwards.isLog, isFalse);
    });

    test('an app that answers only text still gives a description', () {
      final item = PickedItem.fromMap('calendar', {'text': '10:00-11:00 Standup'})!;
      expect(item.description, '10:00-11:00 Standup');
      expect(item.link, isNull);
      expect(item.hasTimes, isFalse);
      expect(PickedItem.fromMap('calendar', {'text': ' '}), isNull);
    });
  });

  testWidgets('picking an event fills the entry and links it', (tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final links = FakeLinks(
      answer: PickedItem(app: 'calendar', itemId: 'ev1', title: 'Standup', start: nine, end: ten),
    );
    await tester.pumpWidget(app(const EntryEditorPage(), links: links));
    await tester.pumpAndSettle();
    // Only installed apps are offered.
    expect(find.text('From ZT Tasks'), findsNothing);
    await tester.tap(find.text('From ZT Calendar'));
    await tester.pumpAndSettle();
    expect(find.text('Linked to ZT Calendar'), findsOneWidget);
    expect(find.text('1h 30m'), findsOneWidget);
    await tester.tap(find.text('Linked to ZT Calendar'));
    await tester.pumpAndSettle();
    expect(links.opened.single.id, 'ev1');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final saved = repo.entries.single;
    expect(saved.description, 'Standup');
    expect(saved.start, nine);
    expect(saved.end, ten);
    expect(saved.link?.id, 'ev1');
  });

  testWidgets('a draft from another app opens filled in', (tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(EntryEditorPage(
      draft: TimeEntry(
        id: 'd1',
        description: 'Review',
        start: nine,
        end: ten,
        link: const EntryLink(app: 'tasks', id: 't1', title: 'Review'),
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Add time'), findsOneWidget);
    expect(find.text('Review'), findsWidgets);
    expect(find.text('Linked to ZT Tasks'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove link'));
    await tester.pumpAndSettle();
    expect(find.text('Linked to ZT Tasks'), findsNothing);
  });
}
