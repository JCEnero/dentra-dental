import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dentra_mobile/features/ai_assistant/ai_chat_controller.dart';
import 'package:dentra_mobile/features/dental_profile/data/models/dental_answers.dart';
import 'package:dentra_mobile/features/dental_records/data/models/dental_record.dart';
import 'package:dentra_mobile/features/dental_records/providers/dental_records_provider.dart';
import 'package:dentra_mobile/features/profile/data/models/user_profile.dart';
import 'package:dentra_mobile/features/scan/data/care_plan.dart';
import 'package:dentra_mobile/features/scan/data/check_in_plan.dart';
import 'package:dentra_mobile/features/scan/data/patient_context.dart';
import 'package:dentra_mobile/features/scan/data/scan_report.dart';
import 'package:dentra_mobile/features/scan/services/report_download.dart';
import 'package:dentra_mobile/features/scan/services/report_pdf.dart';
import 'package:dentra_mobile/features/scan/widgets/check_in_sheet.dart';
import 'package:dentra_mobile/features/scan/widgets/report/context_section.dart';
import 'package:dentra_mobile/features/scan/widgets/report/scan_report_view.dart';
import 'package:dentra_mobile/features/screening/data/models/scan_check_in.dart';
import 'package:dentra_mobile/features/screening/data/models/screening_session.dart';
import 'package:dentra_mobile/features/screening/data/screening_repository.dart';
import 'package:dentra_mobile/features/screening/providers/screening_sessions_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

final _at = DateTime(2026, 11, 3, 9, 41);

/// A 1x1 PNG, for pages that only need an image to exist.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M/AAwAD'
  'hgGAWjR9awAAAABJRU5ErkJggg==',
);

const _views = ['front', 'upper-occlusal', 'lower-occlusal', 'left', 'right'];

const _sign = ScreeningFinding(
  label: 'Possible tooth decay',
  regionId: 'lower-occlusal',
  confidence: 0.71,
  bbox: [0.05, 0.4, 0.12, 0.12],
);

const _rec = ScreeningRecommendation(
  code: 'enamel_lesion_check',
  title: 'Possible tooth decay: ask your dentist at your next visit',
  detail: 'It is not urgent.',
  urgency: 'routine',
);

ScreeningSession _session({
  List<ScreeningFinding> findings = const [],
  ScanCheckIn? checkIn,
  ScreeningReportedContext? context,
  List<ScreeningQualityIssue> issues = const [],
}) =>
    ScreeningSession(
      id: 's1',
      completedAt: _at,
      capturedRegions: _views,
      totalRegions: 9,
      checkIn: checkIn,
      reportedContext: context,
      analysis: ScreeningAnalysis(
        summary: 'Summary',
        analyzedAt: _at,
        findings: findings,
        recommendations: findings.isEmpty ? const [] : const [_rec],
        qualityIssues: issues,
        model: 'det-test+rules',
      ),
    );

DentalRecord _record({
  RecordSource source = RecordSource.clinicRecord,
  String? procedure,
  List<String> teeth = const [],
  String? notes,
}) {
  final d = DateTime(2026, 3, 12);
  return DentalRecord(
    id: 'r$source$procedure',
    source: source,
    recordDate: d,
    createdAt: d,
    updatedAt: d,
    procedure: procedure,
    toothNumbers: teeth,
    notes: notes,
  );
}

class _Repo implements ScreeningRepository {
  _Repo(this.sessions);
  final List<ScreeningSession> sessions;
  @override
  Future<List<ScreeningSession>> fetchSessions(String userId) async => sessions;
  @override
  Future<ScreeningSession> upsertSession(
    String userId,
    ScreeningSession session,
  ) async =>
      session;
  @override
  Future<void> deleteSession(String userId, String sessionId) async {}
  @override
  Future<void> deleteAll(String userId) async {}
  @override
  Future<ScreeningSession?> uploadCaptureImage(
    String userId,
    String sessionId,
    String regionId,
    Uint8List bytes, {
    String modality = 'rgb',
  }) async =>
      null;
}

class _Records extends DentalRecordsNotifier {
  _Records(this.records);
  final List<DentalRecord> records;
  @override
  Future<List<DentalRecord>> build() async => records;
}

Future<void> _pumpPage(
  WidgetTester tester,
  ScreeningSession session, {
  List<DentalRecord> records = const [],
  Size size = const Size(390, 844),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final report = ScreeningReport(session.analysis!, session.capturedRegions);
  final view = ScanReportView(
    report: report,
    imageOf: (_) => MemoryImage(_png),
    status: 'Scan complete',
    date: 'November 3, 2026',
    at: session.completedAt,
    saved: session,
    leading: const SizedBox.square(dimension: 44),
    sessionId: session.id,
    onClinics: () {},
  );
  await tester.pumpWidget(ProviderScope(
    overrides: [
      screeningRepositoryProvider.overrideWithValue(_Repo([session])),
      dentalRecordsProvider.overrideWith(() => _Records(records)),
    ],
    child: MaterialApp(
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: AiChatScope(controller: AiChatController(), child: view),
          ),
        ),
      ),
    ),
  ));
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Opens the check-in and returns what it closes with.
Future<List<CheckInResult?>> _openSheet(
  WidgetTester tester,
  CheckInPlan plan, {
  Size size = const Size(390, 1400),
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final results = <CheckInResult?>[];
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                results.add(await showCheckInSheet(context, plan)),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return results;
}

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).first);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(find.text(text).first);
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the results page', () {
    testWidgets('with nothing reported has no section about it', (tester) async {
      await _pumpPage(tester, _session(findings: const [_sign]));
      expect(find.text('You and this scan'), findsNothing);
      expect(find.text('You told us'), findsNothing);
      expect(find.text('1 possible sign of decay'), findsOneWidget);
    });

    testWidgets('keeps a symptom apart from what the check saw', (tester) async {
      await _pumpPage(
        tester,
        _session(
          checkIn: const ScanCheckIn(
            symptoms: {CurrentConcern.toothPain},
            symptomArea: AreaAnswer.lowerRight,
            started: ConcernDuration.fewDays,
          ),
        ),
      );
      // The finding is still about the photos.
      expect(find.text('Nothing flagged in your photos'), findsOneWidget);
      // The symptom is labelled as theirs, and raises the advice anyway.
      expect(find.text('You told us'), findsWidgets);
      expect(find.text('Book a dental visit soon'), findsOneWidget);
      expect(find.textContaining('No scan can rule out'), findsOneWidget);
      expect(find.textContaining("can't rule out a problem"), findsOneWidget);
      expect(find.text('You and this scan'), findsOneWidget);
    });

    testWidgets('leads with emergency care for warning signs', (tester) async {
      await _pumpPage(
        tester,
        _session(
          checkIn: const ScanCheckIn(
            symptoms: {CurrentConcern.swollenGums},
            warningSigns: {WarningSign.hardToBreathe},
          ),
        ),
      );
      expect(find.byType(EmergencyBanner), findsOneWidget);
      expect(
        find.text('From what you told us. Not something the check saw.'),
        findsOneWidget,
      );
    });

    testWidgets('names the source of every record', (tester) async {
      await _pumpPage(
        tester,
        _session(findings: const [_sign]),
        records: [
          _record(procedure: 'Composite filling', teeth: const ['46']),
          _record(
            source: RecordSource.personalNote,
            notes: 'Sore when I chew',
            teeth: const ['46'],
          ),
        ],
      );
      expect(find.text('Your records'), findsWidgets);
      expect(find.text('Clinic Record'), findsOneWidget);
      expect(find.text('Personal Note'), findsOneWidget);
      expect(find.textContaining("DENTRA hasn't checked them"), findsOneWidget);
      expect(find.textContaining("can't tell if it's the same"), findsWidgets);
    });

    testWidgets('offers the download only with something to report',
        (tester) async {
      await _pumpPage(tester, _session(findings: const [_sign]));
      expect(find.text('Download My Results'), findsOneWidget);

      await _pumpPage(
        tester,
        _session(
          issues: [
            for (final v in _views)
              ScreeningQualityIssue(
                regionId: v,
                modality: 'rgb',
                reason: 'blurry',
                message: 'Too blurry. Try again.',
              ),
          ],
        ),
      );
      expect(find.text('Download My Results'), findsNothing);
    });

    testWidgets('tells the user when the PDF fails', (tester) async {
      await _pumpPage(tester, _session(findings: const [_sign]));
      await tester.ensureVisible(find.text('Download My Results'));
      await tester.pump(const Duration(milliseconds: 200));
      // Real decoding runs outside the fake clock. The share plugin isn't there
      // in a test, so this always fails at the very end.
      await tester.runAsync(() async {
        await tester.tap(find.text('Download My Results'));
        await Future<void>.delayed(const Duration(seconds: 4));
      });
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining("Couldn't make your PDF"), findsOneWidget);
      expect(find.text('Download My Results'), findsOneWidget);
    });

    for (final (name, size, scale) in [
      ('small phone, large text', const Size(320, 568), 1.3),
      ('standard phone', const Size(390, 844), 1.0),
      ('large phone, accessibility text', const Size(430, 932), 2.0),
    ]) {
      testWidgets('lays out without overflow: $name', (tester) async {
        await _pumpPage(
          tester,
          _session(
            findings: const [_sign],
            checkIn: const ScanCheckIn(
              symptoms: {CurrentConcern.toothPain, CurrentConcern.bleedingGums},
              symptomTeeth: ['46', '36'],
              pattern: SymptomPattern.worsening,
              severity: DiscomfortLevel.severe,
            ),
          ),
          records: [_record(procedure: 'Composite filling', teeth: const ['46'])],
          size: size,
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('the check-in sheet', () {
    const plan = CheckInPlan(asksSymptoms: true, asksTreatment: true);

    testWidgets('shows follow-ups only when they apply', (tester) async {
      await _openSheet(tester, plan);
      expect(find.text('Where is it?'), findsNothing);
      expect(find.text('How bad is it?'), findsNothing);
      expect(find.text('When, and on which tooth?'), findsNothing);

      await _tap(tester, 'Tooth pain');
      expect(find.text('Where is it?'), findsOneWidget);
      expect(find.text('When did it start?'), findsOneWidget);
      expect(find.text('How bad is it?'), findsOneWidget);
      expect(find.text('Do you have any of these?'), findsNothing);

      await _tap(tester, 'Nothing right now');
      expect(find.text('Where is it?'), findsNothing);

      await _tap(tester, 'Filling');
      expect(find.text('When, and on which tooth?'), findsOneWidget);
    });

    testWidgets('marks what can be skipped', (tester) async {
      await _openSheet(
        tester,
        const CheckInPlan(asksSymptoms: true, asksTreatment: true, asksFocus: true),
      );
      // Treatment and the tooth to note, but not whether anything's wrong.
      expect(find.text('Optional'), findsNWidgets(2));
      expect(find.text('Skip for now'), findsOneWidget);
    });

    testWidgets('asks only the questions in the plan', (tester) async {
      await _openSheet(tester, const CheckInPlan(asksCleaning: true));
      expect(find.text('Is anything bothering you today?'), findsNothing);
      expect(find.text('And your last professional cleaning?'), findsOneWidget);
    });

    testWidgets('says when it follows an earlier scan', (tester) async {
      await _openSheet(
        tester,
        CheckInPlan(asksTreatment: true, lastScanAt: DateTime(2026, 10, 5)),
      );
      expect(find.textContaining('Since your last scan on Oct 5'), findsOneWidget);
      expect(find.text('Any dental treatment since then?'), findsOneWidget);
    });

    testWidgets('warns at once about signs that can\'t wait', (tester) async {
      await _openSheet(tester, plan);
      await _tap(tester, 'Swollen gums');
      expect(find.text('Do you have any of these?'), findsOneWidget);
      expect(find.text('Get emergency care now'), findsNothing);

      await _tap(tester, 'Hard to breathe, swallow or speak');
      expect(find.text('Get emergency care now'), findsOneWidget);
    });

    testWidgets('warns about severe discomfort', (tester) async {
      await _openSheet(tester, plan);
      await _tap(tester, 'Tooth pain');
      await _tap(tester, 'Severe');
      expect(find.text('Severe discomfort needs prompt attention'), findsOneWidget);
      // Bad pain could be spreading, so the warning signs are asked too.
      expect(find.text('Do you have any of these?'), findsOneWidget);
    });

    testWidgets('skipping stores nothing', (tester) async {
      final results = await _openSheet(tester, plan);
      await _tap(tester, 'Tooth pain');
      await _tap(tester, 'Skip for now');
      expect(results.single, isNotNull);
      expect(results.single!.answers, isNull);
    });

    testWidgets('continuing with nothing answered stores nothing',
        (tester) async {
      final results = await _openSheet(tester, plan);
      await _tap(tester, 'Continue');
      expect(results.single!.answers, isNull);
    });

    testWidgets('keeps only answers that are still showing', (tester) async {
      final results = await _openSheet(tester, plan);
      await _tap(tester, 'Tooth pain');
      await _tap(tester, 'Upper front');
      await _tap(tester, 'Severe');
      await _tap(tester, 'Tooth pain');
      await _tap(tester, 'Filling');
      await _tap(tester, 'Past week');
      await _tap(tester, 'Continue');
      final a = results.single!.answers!;
      expect(a.symptoms, isEmpty);
      expect(a.symptomArea, isNull);
      expect(a.severity, isNull);
      expect(a.treatments, {RecentTreatment.filling});
      expect(a.treatmentWhen, TreatmentWhen.pastWeek);
    });

    testWidgets('starts from recent answers', (tester) async {
      await _openSheet(
        tester,
        const CheckInPlan(
          asksSymptoms: true,
          prefill: ScanCheckIn(symptoms: {CurrentConcern.sensitivity}),
        ),
      );
      expect(find.text('Where is it?'), findsOneWidget);
    });

    for (final (name, size) in [
      ('small phone', const Size(320, 568)),
      ('standard phone', const Size(390, 844)),
    ]) {
      testWidgets('lays out without overflow: $name', (tester) async {
        await _openSheet(
          tester,
          CheckInPlan(
            asksSymptoms: true,
            asksTreatment: true,
            asksCheckup: true,
            asksCleaning: true,
            asksFocus: true,
            lastScanAt: DateTime(2026, 10, 5),
          ),
          size: size,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('the PDF', () {
    ByteData font(String weight) => ByteData.sublistView(
          File('assets/fonts/Outfit-$weight.ttf').readAsBytesSync(),
        );
    final fonts = ReportFonts(
      regular: font('Regular'),
      medium: font('Medium'),
      semiBold: font('SemiBold'),
      bold: font('Bold'),
    );

    Future<Uint8List> build(
      ScreeningSession s, {
      List<DentalRecord> records = const [],
      UserProfile? person,
      Map<String, ReportPhoto> photos = const {},
      bool recordsUnavailable = false,
    }) {
      final report = ScreeningReport(s.analysis!, s.capturedRegions);
      final patient = PatientContext(
        at: s.completedAt,
        profile: s.reportedContext,
        checkIn: s.checkIn,
        records: records,
        recordsUnavailable: recordsUnavailable,
      );
      final trend = ScanTrend.of([s], currentId: s.id);
      return buildReportPdf(ReportPdfData(
        report: report,
        patient: patient,
        plan: CarePlan.of(report, patient, trend),
        trend: trend,
        fonts: fonts,
        generatedAt: _at,
        person: person,
        sessionId: s.id,
        photos: photos,
      ));
    }

    void expectPdf(Uint8List bytes) {
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(bytes.length, greaterThan(1000));
    }

    test('is made with no extra information at all', () async {
      expectPdf(await build(_session()));
    });

    test('is made with everything filled in', () async {
      expectPdf(await build(
        _session(
          findings: const [_sign],
          checkIn: const ScanCheckIn(
            symptoms: {CurrentConcern.toothPain},
            symptomArea: AreaAnswer.lowerRight,
            symptomTeeth: ['46'],
            started: ConcernDuration.fewDays,
            pattern: SymptomPattern.worsening,
            severity: DiscomfortLevel.moderate,
            treatments: {RecentTreatment.filling},
            treatmentTeeth: ['46'],
            treatmentWhen: TreatmentWhen.pastMonth,
          ),
          context: ScreeningReportedContext(
            profileVersion: 1,
            recordedAt: _at,
            lastCheckup: LastCheckup.overAYear,
            lastCleaning: LastCleaning.never,
            previousProblems: const {PreviousProblem.toothDecay},
            pastTreatments: const {PastTreatment.filling},
            dentalAppliances: const {DentalAppliance.retainers},
            brushing: BrushingHabit.once,
            betweenTeeth: BetweenTeethHabit.rarely,
            healthFactors: const {HealthFactor.diabetes},
            screeningGoals: const {ScreeningGoal.decay},
          ),
        ),
        records: [
          _record(procedure: 'Composite filling', teeth: const ['46']),
          _record(source: RecordSource.personalNote, notes: 'Sore on 46'),
        ],
        person: UserProfile(
          fullName: 'Test Person',
          email: 'person@example.com',
          dateOfBirth: DateTime(1990, 5, 2),
        ),
      ));
    });

    test('is made when a photo with a sign could not be loaded', () async {
      expectPdf(await build(_session(findings: const [_sign])));
    });

    test('is made when the records could not be loaded', () async {
      expectPdf(await build(_session(), recordsUnavailable: true));
    });

    test('is made for an emergency', () async {
      expectPdf(await build(
        _session(
          checkIn: const ScanCheckIn(
            symptoms: {CurrentConcern.swollenGums},
            warningSigns: {WarningSign.eyeOrNeckSwelling},
          ),
        ),
      ));
    });

    test('survives words the font has no letters for', () async {
      expect(fonts.safe('Pain 😣 here'), 'Pain ? here');
      expect(fonts.safe('Dr. Peña, line\nnext'), 'Dr. Peña, line\nnext');
      expectPdf(await build(
        _session(),
        records: [_record(procedure: '根管治療 😣', teeth: const ['46'])],
      ));
    });

    testWidgets('scales a large photo down, keeping its shape', (tester) async {
      await tester.runAsync(() async {
        final png = img.encodePng(img.Image(width: 2000, height: 1000));
        final photo = await loadReportPhoto(MemoryImage(png));
        expect(photo.width, 1000);
        expect(photo.height, 500);
      });
    });

    testWidgets('marks a real photo, at its own shape', (tester) async {
      await tester.runAsync(() async {
        final png = img.encodePng(img.Image(width: 64, height: 48));
        final photo = await loadReportPhoto(MemoryImage(png));
        expect(photo.width, 64);
        expect(photo.height, 48);
        expect(photo.jpeg.sublist(0, 2), [0xFF, 0xD8]);
        expectPdf(await build(
          _session(findings: const [_sign]),
          photos: {'lower-occlusal': photo},
        ));
      });
    });

    test('says what the limits are, word for word', () {
      expect(
        screeningNotice,
        contains(
          'preliminary AI-assisted screening findings, not a professional '
          'dental diagnosis',
        ),
      );
    });
  });
}
