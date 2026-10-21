import 'package:dentra_mobile/core/utils/dentra_dates.dart';
import 'package:dentra_mobile/features/comparison/screens/comparison_screen.dart';
import 'package:dentra_mobile/features/comparison/state/comparison_state.dart';
import 'package:dentra_mobile/features/dental_records/data/models/dental_record.dart';
import 'package:dentra_mobile/features/dental_records/providers/dental_records_provider.dart';
import 'package:dentra_mobile/features/dental_records/screens/record_detail_screen.dart';
import 'package:dentra_mobile/features/dental_records/screens/record_editor_screen.dart';
import 'package:dentra_mobile/features/history/screens/history_screen.dart';
import 'package:dentra_mobile/features/history/state/history_entry.dart';
import 'package:dentra_mobile/features/history/state/history_query.dart';
import 'package:dentra_mobile/features/home/widgets/screening_activity_card.dart';
import 'package:dentra_mobile/features/screening/data/models/screening_session.dart';
import 'package:dentra_mobile/features/screening/providers/screening_sessions_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_history_repositories.dart';

Widget _app(
  Widget home, {
  FakeScreeningRepository? screenings,
  FakeDentalRecordRepository? records,
}) {
  return ProviderScope(
    overrides: [
      screeningRepositoryProvider
          .overrideWithValue(screenings ?? FakeScreeningRepository()),
      dentalRecordRepositoryProvider
          .overrideWithValue(records ?? FakeDentalRecordRepository()),
    ],
    child: MaterialApp(home: Scaffold(body: home)),
  );
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final today = DentraDates.dateOnly(DateTime.now());

  group('timeline', () {
    final visit = recordFrom(
      DentalRecordInput(
        source: RecordSource.clinicRecord,
        recordDate: today,
        clinicName: 'Smile Dental Clinic',
        procedure: 'Filling',
        toothNumbers: const ['26'],
      ),
      id: 'visit',
    );
    final session = screening('s1', today.add(const Duration(hours: 8)),
        findings: const [ScreeningFinding(label: 'Possible plaque', tooth: '36')]);
    final entries = <HistoryEntry>[ScreeningEntry(session), RecordEntry(visit)];
    final view = HistoryViewState(
      month: DentraDates.monthOf(today),
      weekStart: DentraDates.weekStart(today),
    );

    test('keeps each item\'s own source', () {
      expect(entries.map((e) => e.source),
          [RecordSource.aiScreening, RecordSource.clinicRecord]);
    });

    test('teeth come only from what the record states', () {
      expect(ScreeningEntry(session).teeth, {36});
      expect(RecordEntry(visit).teeth, {26});
      expect(ScreeningEntry(screening('s2', today)).teeth, isEmpty);
    });

    test('filters by source, and screening-only filters exclude records', () {
      final clinicOnly = applyHistoryQuery(
        entries,
        view.copyWith(filters: const HistoryFilters(sources: {RecordSource.clinicRecord})),
      );
      expect(clinicOnly.single, isA<RecordEntry>());

      final partial = applyHistoryQuery(
        entries,
        view.copyWith(filters: const HistoryFilters(statuses: {ScreeningStatus.partial})),
      );
      expect(partial.single, isA<ScreeningEntry>());
    });

    test('search finds clinics and teeth', () {
      expect(applyHistoryQuery(entries, view.copyWith(query: 'smile')).single,
          isA<RecordEntry>());
      expect(applyHistoryQuery(entries, view.copyWith(query: 'tooth 36')).single,
          isA<ScreeningEntry>());
    });
  });

  group('comparison selection', () {
    final a = ComparableItem(
        entry: RecordEntry(photoRecord('a', DateTime(2026, 9, 1))), images: const []);
    final b = ComparableItem(
        entry: RecordEntry(photoRecord('b', DateTime(2026, 10, 1))), images: const []);
    final c = ComparableItem(
        entry: ScreeningEntry(screening('c', DateTime(2026, 10, 1, 15))),
        images: const []);
    final all = [a, b, c];

    test('only offers dates in order, and a shared day needs two records', () {
      final sel = const ComparisonSelection().copyWithSlot(
        ComparisonSlot.later,
        day: DateTime(2026, 9, 1),
        key: a.key,
      );
      // Sep 1 has one record and it's already the later one.
      expect(selectableDays(all, sel, ComparisonSlot.earlier), isEmpty);

      final fromOct = const ComparisonSelection().copyWithSlot(
        ComparisonSlot.later,
        day: DateTime(2026, 10, 1),
        key: b.key,
      );
      expect(selectableDays(all, fromOct, ComparisonSlot.earlier),
          [DateTime(2026, 10, 1), DateTime(2026, 9, 1)]);
    });

    test('a record is never compared with itself', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final sub = container.listen(comparisonControllerProvider, (_, __) {});
      final ctrl = container.read(comparisonControllerProvider.notifier);

      ctrl.setDay(ComparisonSlot.earlier, DateTime(2026, 9, 1), all);
      expect(sub.read().earlierKey, a.key, reason: 'single record is chosen');

      ctrl.setDay(ComparisonSlot.later, DateTime(2026, 10, 1), all);
      expect(sub.read().laterKey, isNull, reason: 'two records: user chooses');
      ctrl.setItem(ComparisonSlot.later, a.key);
      expect(sub.read().laterKey, isNull);
      ctrl.setItem(ComparisonSlot.later, c.key);
      expect(sub.read().canCompare, isTrue);
    });
  });

  testWidgets('comparison: choose two dates and compare photos', (tester) async {
    tester.view.physicalSize = const Size(390, 900) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final records = FakeDentalRecordRepository([
      photoRecord('early', today.subtract(const Duration(days: 30))),
      photoRecord('late', today),
    ]);
    await tester.pumpWidget(_app(const ComparisonScreen(), records: records));
    await tester.pumpAndSettle();

    expect(find.text('Comparison'), findsOneWidget);
    final compare = find.widgetWithText(InkWell, 'Compare');

    await tester.tap(find.text('Choose date').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(DentraDates.full(today.subtract(const Duration(days: 30)))));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choose date'));
    await tester.pumpAndSettle();
    // Only the later date is offered for "Later".
    expect(find.text(DentraDates.full(today.subtract(const Duration(days: 30)))),
        findsOneWidget, reason: 'shown once: on the earlier card, not in the sheet');
    await tester.tap(find.text(DentraDates.full(today)).last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(compare);
    await tester.tap(compare);
    await tester.pumpAndSettle();

    expect(find.text('30 days apart'), findsOneWidget);
    expect(find.text('Personal Photo'), findsNWidgets(2));
    expect(find.textContaining("doesn't show that anything changed"), findsOneWidget);

    // Back goes to the selection, not out of the page.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('EARLIER'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('comparison explains when there is too little history', (tester) async {
    await tester.pumpWidget(_app(const ComparisonScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Nothing to compare yet'), findsOneWidget);
  });

  testWidgets('clinic visit saves with only a procedure', (tester) async {
    final records = FakeDentalRecordRepository();
    await tester.pumpWidget(_app(
      const RecordEditorScreen(source: RecordSource.clinicRecord),
      records: records,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Clinic Record'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Add the clinic name or the procedure'), findsOneWidget);
    expect(records.created, isEmpty);

    await tester.enterText(
        find.widgetWithText(TextField, 'e.g. Cleaning, filling, extraction'), 'Cleaning');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(records.created.single.procedure, 'Cleaning');
    expect(records.created.single.dentistName, '');
    // Lands on the new record's details, labelled by source.
    expect(find.text('Clinic Visit'), findsOneWidget);
    expect(find.text('Information you recorded from a dental visit'), findsOneWidget);
  });

  testWidgets('history lists screenings and records with their sources', (tester) async {
    tester.view.physicalSize = const Size(390, 1400) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(
      const HistoryScreen(),
      screenings: FakeScreeningRepository([screening('s1', today.add(const Duration(hours: 7)))]),
      records: FakeDentalRecordRepository([
        recordFrom(
          DentalRecordInput(
            source: RecordSource.personalNote,
            recordDate: today,
            notes: 'Ask about sensitivity',
          ),
          id: 'n1',
        ),
      ]),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Dental History'), findsOneWidget);
    expect(find.text('AI Screening'), findsOneWidget);
    expect(find.text('Personal Note'), findsOneWidget);
    expect(find.text('Ask about sensitivity'), findsOneWidget);
    expect(find.text('2 items'), findsOneWidget);
  });

  testWidgets('history still shows screenings when records fail', (tester) async {
    await tester.pumpWidget(_app(
      const HistoryScreen(),
      screenings: FakeScreeningRepository([screening('s1', today.add(const Duration(hours: 7)))]),
      records: FakeDentalRecordRepository()..fetchError = Exception('offline'),
    ));
    await tester.pumpAndSettle();
    expect(find.text('AI Screening'), findsOneWidget);
    expect(find.textContaining("couldn't load"), findsOneWidget);
  });

  group('home graph', () {
    testWidgets('new users get a short empty state', (tester) async {
      await tester.pumpWidget(_app(const ScreeningActivityCard()));
      await tester.pumpAndSettle();
      expect(find.textContaining('No screenings yet'), findsOneWidget);
    });

    testWidgets('plots real screenings and explains what height means', (tester) async {
      await tester.pumpWidget(_app(
        const ScreeningActivityCard(),
        screenings: FakeScreeningRepository([
          screening('s1', today.subtract(const Duration(days: 3)), regions: ['ul', 'ur', 'll']),
          screening('s2', today.subtract(const Duration(days: 120))),
        ]),
      ));
      await tester.pumpAndSettle();
      expect(find.text('1 screening · last 3 months'), findsOneWidget);
      expect(find.textContaining('not your dental health'), findsOneWidget);

      await tester.tap(find.text('6M'));
      await tester.pumpAndSettle();
      expect(find.text('2 screenings · last 6 months'), findsOneWidget);

      await tester.tap(find.text('30D'));
      await tester.pumpAndSettle();
      expect(find.text('1 screening · last 30 days'), findsOneWidget);
    });
  });

  testWidgets('comparison result fits a small phone with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 640) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(overrides: [
      screeningRepositoryProvider.overrideWithValue(FakeScreeningRepository([
        screening('s1', today.subtract(const Duration(days: 9)),
            findings: const [ScreeningFinding(label: 'Possible plaque', confidence: 0.62)]),
      ])),
      dentalRecordRepositoryProvider
          .overrideWithValue(FakeDentalRecordRepository([photoRecord('p', today)])),
    ]);
    addTearDown(container.dispose);
    final all = await container.read(dentalRecordsProvider.future).then((_) async {
      await container.read(screeningSessionsProvider.future);
      return container.read(comparableItemsProvider).requireValue;
    });
    final ctrl = container.read(comparisonControllerProvider.notifier);
    container.listen(comparisonControllerProvider, (_, __) {});
    ctrl.setDay(ComparisonSlot.earlier, all.last.day, all);
    ctrl.setDay(ComparisonSlot.later, all.first.day, all);
    ctrl.showResult();

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: MaterialApp(home: ComparisonScreen()),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('different kinds of records'), findsOneWidget);
    expect(find.text('62% reported confidence'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('history screens fit a small phone with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 640) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final visit = recordFrom(
      DentalRecordInput(
        source: RecordSource.clinicRecord,
        recordDate: today,
        clinicName: 'Smile Dental Clinic and Orthodontic Center',
        procedure: 'Composite filling',
        dentistName: 'Dr. Reyes',
        clinicNotes: 'Follow up in six months.',
        followUpDate: today.add(const Duration(days: 180)),
        toothNumbers: const ['26', '36'],
      ),
      id: 'v1',
    ).copyWith(attachments: [imageAttachment('x1')]);

    for (final screen in <Widget>[
      const HistoryScreen(),
      const RecordEditorScreen(source: RecordSource.clinicRecord),
      const RecordEditorScreen(source: RecordSource.personalPhoto),
      const RecordDetailScreen(recordId: 'v1'),
      const SingleChildScrollView(child: ScreeningActivityCard()),
    ]) {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          screeningRepositoryProvider.overrideWithValue(FakeScreeningRepository([
            screening('s1', today.subtract(const Duration(days: 2)),
                findings: const [ScreeningFinding(label: 'Possible plaque', tooth: '26')]),
          ])),
          dentalRecordRepositoryProvider
              .overrideWithValue(FakeDentalRecordRepository([visit])),
        ],
        child: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(1.3),
          ),
          child: MaterialApp(home: Scaffold(body: screen)),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '${screen.runtimeType}');
    }
  });
}
