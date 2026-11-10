import 'dart:convert';
import 'dart:io';

import 'package:dentra_mobile/core/network/api_client.dart';
import 'package:dentra_mobile/features/ai_assistant/ai_chat_controller.dart';
import 'package:dentra_mobile/features/dental_profile/data/models/dental_answers.dart';
import 'package:dentra_mobile/features/scan/data/care_plan.dart';
import 'package:dentra_mobile/features/scan/data/patient_context.dart';
import 'package:dentra_mobile/features/scan/data/scan_regions.dart';
import 'package:dentra_mobile/features/scan/data/scan_report.dart';
import 'package:dentra_mobile/features/scan/data/tooth_guidance.dart';
import 'package:dentra_mobile/features/scan/services/report_pdf.dart';
import 'package:dentra_mobile/features/scan/widgets/report/scan_report_view.dart';
import 'package:dentra_mobile/features/screening/data/api_screening_repository.dart';
import 'package:dentra_mobile/features/screening/data/models/scan_check_in.dart';
import 'package:dentra_mobile/features/screening/data/models/screening_session.dart';
import 'package:dentra_mobile/features/screening/providers/screening_sessions_provider.dart';
import 'package:dentra_mobile/features/treatment/data/treatment_data.dart';
import 'package:dentra_mobile/features/treatment/screens/treatment_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_history_repositories.dart';

final _at = DateTime(2026, 11, 10, 9, 30);

const _allViews = [
  'front',
  'upper-occlusal',
  'lower-occlusal',
  'left',
  'right',
  'upper-lingual',
  'lower-lingual',
  'back-left',
  'back-right',
];

ScreeningFinding _sign(
  String id,
  String region, {
  double confidence = 0.9,
  List<double> bbox = const [0.7, 0.2, 0.15, 0.2],
}) =>
    ScreeningFinding(
      id: id,
      label: 'Possible tooth decay',
      category: 'enamel_caries',
      regionId: region,
      confidence: confidence,
      modality: 'rgb',
      bbox: bbox,
    );

/// What the live rules say for adult decay: ask at the next visit.
const _adultRule = ScreeningRecommendation(
  code: 'enamel_lesion_check',
  title: 'Possible tooth decay: ask your dentist at your next visit',
  detail: 'We spotted signs that may be tooth decay.',
  urgency: 'routine',
  regionIds: _allViews,
);

/// And for children: book soon.
const _childRule = ScreeningRecommendation(
  code: 'possible_filling',
  title: 'Possible cavity: see a dentist',
  detail: 'Cavities in children\'s teeth can grow quickly.',
  urgency: 'soon',
  regionIds: _allViews,
);

ScreeningAnalysis _analysis({
  List<ScreeningFinding> findings = const [],
  List<ScreeningFinding> faint = const [],
  List<ScreeningRecommendation> recs = const [_adultRule],
  String dentition = 'permanent',
}) =>
    ScreeningAnalysis(
      summary: 'A summary.',
      analyzedAt: _at,
      model: 'det-caries-nano-v6+teeth-v4+braces-v1+rules-0.6',
      dentitionType: dentition,
      findings: findings,
      faintFindings: faint,
      recommendations: findings.isEmpty ? const [] : recs,
    );

ScreeningSession _session(
  ScreeningAnalysis analysis, {
  String id = 's1',
  List<FindingAnswer> answers = const [],
  ScanCheckIn? checkIn,
}) =>
    ScreeningSession(
      id: id,
      completedAt: _at,
      capturedRegions: _allViews,
      totalRegions: 9,
      analysis: analysis,
      checkIn: checkIn,
      findingAnswers: answers,
    );

ScreeningReport _report(ScreeningAnalysis a) => ScreeningReport(a, _allViews);

ReportSpot _spotOf(ScreeningReport r, String id) =>
    r.spots.firstWhere((s) => s.finding.id == id);

/// A side photo (right) tells upper from lower; this box sits above the bite.
final _rightUpper = _sign('1', 'right', bbox: const [0.4, 0.2, 0.15, 0.2]);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('where a marked tooth is', () {
    String place(ScreeningFinding f) =>
        toothPlace(_spotOf(_report(_analysis(findings: [f])), f.id!));

    test('a side photo gives the jaw and the side', () {
      expect(place(_rightUpper), 'a back tooth on your upper right');
    });

    test('a molar photo says molar', () {
      expect(
        place(_sign('2', 'back-left', bbox: const [0.4, 0.7, 0.2, 0.2])),
        'a molar on your lower left',
      );
    });

    test('an arch photo never guesses left or right', () {
      expect(
        place(_sign('3', 'upper-occlusal', bbox: const [0.8, 0.5, 0.1, 0.1])),
        'an upper back tooth',
      );
      expect(
        place(_sign('4', 'lower-occlusal', bbox: const [0.45, 0.4, 0.1, 0.1])),
        'a lower front tooth',
      );
    });

    test('a mark on the bite line stays with both jaws', () {
      expect(
        place(_sign('5', 'front', bbox: const [0.45, 0.45, 0.1, 0.1])),
        'a front tooth',
      );
    });

    test('never gives a tooth number', () {
      for (final view in _allViews) {
        final words = place(_sign('9', view));
        expect(words, isNot(matches(RegExp(r'\d'))));
      }
    });
  });

  group('advice for one marked tooth', () {
    ToothGuidance guide(
      ToothPain? pain, {
      ScreeningFinding? finding,
      String dentition = 'permanent',
      ReportedSymptoms? symptoms,
    }) {
      final f = finding ?? _rightUpper;
      final report = _report(_analysis(
        findings: [f],
        dentition: dentition,
        recs: [dentition == 'permanent' ? _adultRule : _childRule],
      ));
      return ToothGuidance.of(
        _spotOf(report, f.id!),
        report,
        pain: pain,
        symptoms: symptoms,
      );
    }

    test('says what was found, what it could mean and why it matters', () {
      final g = guide(null);
      expect(g.title, 'Possible tooth decay');
      expect(g.where, 'A back tooth on your upper right');
      expect(g.found, contains('Right Side photo'));
      expect(g.found, contains('may have tooth decay'));
      expect(g.meaning, contains('Only a dentist can tell'));
      expect(g.why, contains('early'));
      expect(g.asks, isTrue);
    });

    test('urgency never comes from the confidence score', () {
      for (final confidence in [0.61, 0.79, 0.81, 0.99]) {
        final g =
            guide(null, finding: _sign('1', 'right', confidence: confidence));
        expect(g.urgency, ToothUrgency.routine, reason: '$confidence');
      }
    });

    test('with no pain or no answer, an adult gets a routine assessment', () {
      for (final pain in [null, ToothPain.no, ToothPain.notSure]) {
        expect(guide(pain).urgency, ToothUrgency.routine, reason: '$pain');
      }
    });

    test('a child\'s tooth follows the rules and is booked soon', () {
      final g = guide(ToothPain.no, dentition: 'mixed');
      expect(g.urgency, ToothUrgency.soon);
      expect(g.meaning, contains('baby and growing teeth'));
      expect(g.treatmentNote, contains('Baby teeth'));
    });

    test('pain or sensitivity books a visit soon, and says why', () {
      final yes = guide(ToothPain.yes);
      expect(yes.urgency, ToothUrgency.soon);
      expect(yes.urgencyWhy, 'You told us this tooth has hurt.');
      expect(yes.answerNote, contains('reason to have it examined'));
      expect(yes.warnsAboutUrgentCare, isTrue);
      expect(yes.sources, {CareSource.check, CareSource.you});

      final sometimes = guide(ToothPain.sometimes);
      expect(sometimes.urgency, ToothUrgency.soon);
      expect(sometimes.answerNote, contains('several'));
    });

    test('pain that is severe or getting worse calls for prompt care', () {
      const symptoms = ReportedSymptoms(
        concerns: {CurrentConcern.toothPain},
        fromCheckIn: true,
        old: false,
        pattern: SymptomPattern.worsening,
      );
      expect(guide(ToothPain.yes, symptoms: symptoms).urgency,
          ToothUrgency.prompt);
      // An old answer from a profile doesn't count as today's.
      const old = ReportedSymptoms(
        concerns: {CurrentConcern.toothPain},
        fromCheckIn: false,
        old: true,
        severity: DiscomfortLevel.severe,
      );
      expect(guide(ToothPain.yes, symptoms: old).urgency, ToothUrgency.soon);
    });

    test('pain alone never puts a root canal or extraction first', () {
      List<String> ids(ToothPain? pain) =>
          [for (final t in guide(pain).treatments) t.treatmentId];
      expect(ids(ToothPain.yes).first, Procedures.filling);
      expect(guide(ToothPain.yes).treatmentNote,
          contains('Pain alone doesn\'t mean'));
      for (final pain in [null, ToothPain.no, ToothPain.notSure]) {
        expect(ids(pain), isNot(contains(Procedures.rootCanal)));
        expect(ids(pain), isNot(contains(Procedures.extraction)));
        expect(ids(pain), contains(Procedures.fluoride));
        expect(ids(pain), contains(Procedures.filling));
      }
      expect(ids(ToothPain.sometimes), isNot(contains(Procedures.extraction)));
    });

    test('someone not sure is shown what a cavity can feel like', () {
      final g = guide(ToothPain.notSure);
      expect(g.symptomsToWatch, cavitySymptoms);
      expect(cavitySymptoms, hasLength(4));
      expect(guide(ToothPain.no).symptomsToWatch, isEmpty);
    });

    test('no pain is never read as a healthy tooth', () {
      final g = guide(ToothPain.no);
      expect(g.answerNote, contains('doesn\'t mean the tooth is healthy'));
      expect(g.nextStep, contains('before it has a chance to grow'));
    });

    test('a faint sign asks nothing and suggests no treatment', () {
      final f = _sign('8', 'right', confidence: 0.4);
      final report = _report(_analysis(faint: [f]));
      final g =
          ToothGuidance.of(_spotOf(report, '8'), report, pain: ToothPain.yes);
      expect(g.asks, isFalse);
      expect(g.pain, isNull);
      expect(g.treatments, isEmpty);
      expect(g.urgency, ToothUrgency.watch);
    });

    test('every treatment it names has a full page in the Treatment tab', () {
      for (final id in Procedures.all) {
        final t = TreatmentData.byId(id);
        expect(t, isNotNull, reason: id);
        expect(t!.whyRecommended, isNotNull, reason: id);
        expect(t.whenNeeded, isNotEmpty, reason: id);
        expect(t.steps, isNotEmpty, reason: id);
        expect(t.aftercare, isNotEmpty, reason: id);
        expect(t.risks, isNotEmpty, reason: id);
        expect(Procedures.learnMore(id), startsWith('Learn more about'));
      }
      for (final pain in [...ToothPain.values, null]) {
        for (final t in guide(pain).treatments) {
          expect(Procedures.all, contains(t.treatmentId));
        }
      }
    });

    test('answers only count for signs still in this result', () {
      final report = _report(_analysis(
        findings: [_rightUpper],
        faint: [_sign('8', 'left', confidence: 0.4)],
      ));
      final answers = answersIn(report, const [
        FindingAnswer(findingId: '1', pain: ToothPain.yes),
        FindingAnswer(findingId: '8', pain: ToothPain.yes),
        FindingAnswer(findingId: 'gone', pain: ToothPain.no),
      ]);
      expect(answers, {'1': ToothPain.yes});
    });
  });

  group('the care plan', () {
    CarePlan plan(Map<String, ToothPain> answers, {ScanCheckIn? checkIn}) {
      final report = _report(_analysis(findings: [_rightUpper]));
      return CarePlan.of(
        report,
        PatientContext(at: _at, checkIn: checkIn),
        ScanTrend.of(const []),
        answers: answers,
      );
    }

    test('a tooth that hurts moves the visit up, from the check and the user',
        () {
      expect(plan(const {}).level, CareLevel.nextVisit);
      final p = plan(const {'1': ToothPain.yes});
      expect(p.level, CareLevel.soon);
      expect(p.steps.first.title, 'Have the tooth that hurts examined');
      expect(p.steps.first.sources, {CareSource.check, CareSource.you});
      expect(p.questions.first, contains('marked tooth be causing my pain'));
      expect(p.toothAnswerLines,
          ['The tooth marked in the Right Side photo: has had pain']);
    });

    test('no pain leaves the advice as the check gave it', () {
      final p = plan(const {'1': ToothPain.no});
      expect(p.level, CareLevel.nextVisit);
      expect(
        p.steps.map((s) => s.title),
        isNot(contains('Have the tooth that hurts examined')),
      );
    });

    test('severe pain from the check-in makes it prompt', () {
      final p = plan(
        const {'1': ToothPain.yes},
        checkIn: const ScanCheckIn(
          symptoms: {CurrentConcern.toothPain},
          severity: DiscomfortLevel.severe,
        ),
      );
      expect(p.level, CareLevel.prompt);
    });
  });

  group('answers are stored', () {
    test('with the session, apart from its findings, and survive a reload', () {
      final s = _session(
        _analysis(findings: [_rightUpper]),
        answers: [
          FindingAnswer(
            findingId: '1',
            pain: ToothPain.sometimes,
            answeredAt: _at,
          ),
        ],
      );
      final json = jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>;
      expect(json['finding_answers'][0]['source'], 'user_reported');
      expect((json['analysis']['findings'][0] as Map).containsKey('pain'),
          isFalse);
      final back = ScreeningSession.fromJson(json);
      expect(back.analysis!.findings.single.id, '1');
      expect(back.painByFinding, {'1': ToothPain.sometimes});
    });

    test('older results without ids or answers still load', () {
      final back = ScreeningSession.fromJson({
        'id': 'old',
        'completed_at': '2026-10-01T08:00:00.000Z',
        'captured_regions': ['front'],
        'total_regions': 9,
        'analysis': {
          'summary': 'x',
          'analyzed_at': '2026-10-01T08:00:05.000Z',
          'findings': [
            {'label': 'Possible tooth decay', 'region_id': 'front'},
          ],
        },
        'finding_answers': [
          {'finding_id': '1', 'pain': 'maybe'},
        ],
      });
      expect(back.analysis!.findings.single.id, isNull);
      expect(back.findingAnswers, isEmpty);
    });

    test('the API is sent the answer, and nothing for taking it back',
        () async {
      final calls = <http.Request>[];
      final session = _session(_analysis(findings: [_rightUpper]));
      final api = ApiClient(
        baseUrl: 'https://api.test',
        accessToken: () async => 'token',
        client: MockClient((req) async {
          calls.add(req);
          return http.Response(jsonEncode({'session': session.toJson()}), 200);
        }),
      );
      final repo = ApiScreeningRepository(api);
      await repo.answerFinding('u', 's1', '1', ToothPain.notSure);
      await repo.answerFinding('u', 's1', '1', null);
      expect(calls[0].method, 'PUT');
      expect(calls[0].url.path, '/api/screenings/s1/findings/1/answer');
      expect(jsonDecode(calls[0].body), {'pain': 'not_sure'});
      expect(calls[1].method, 'DELETE');
      expect(calls[1].body, isEmpty);
    });

    test('shows at once, and goes back if it can\'t be saved', () async {
      final repo = FakeScreeningRepository([
        _session(_analysis(findings: [_rightUpper]))
      ]);
      final container = ProviderContainer(overrides: [
        screeningRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);
      final notifier = container.read(screeningSessionsProvider.notifier);
      await container.read(screeningSessionsProvider.future);
      ToothPain? stored() => container
          .read(screeningSessionsProvider)
          .value!
          .single
          .painByFinding['1'];

      await notifier.answerFinding('s1', '1', ToothPain.yes);
      expect(stored(), ToothPain.yes);
      expect(repo.answers.single, ('s1', '1', ToothPain.yes));

      repo.answerError = const ApiException(500, 'x', 'Down.');
      await expectLater(
        notifier.answerFinding('s1', '1', ToothPain.no),
        throwsA(isA<ApiException>()),
      );
      expect(stored(), ToothPain.yes);
    });
  });

  group('the results page', () {
    final findings = [
      _rightUpper,
      _sign('2', 'back-left',
          confidence: 0.7, bbox: const [0.4, 0.7, 0.2, 0.2]),
    ];

    Future<FakeScreeningRepository> pump(
      WidgetTester tester, {
      bool stored = true,
      Size size = const Size(390, 844),
      double textScale = 1.0,
    }) async {
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final session = _session(_analysis(findings: findings));
      final repo = FakeScreeningRepository(stored ? [session] : const []);
      final view = ScanReportView(
        report: _report(session.analysis!),
        imageOf: (_) => MemoryImage(tinyPng),
        status: 'Scan complete',
        date: 'November 10, 2026',
        at: _at,
        leading: const SizedBox.square(dimension: 44),
        sessionId: stored ? 's1' : null,
        onClinics: () {},
      );
      await tester.pumpWidget(ProviderScope(
        overrides: [screeningRepositoryProvider.overrideWithValue(repo)],
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
      await frames(tester);
      return repo;
    }

    Future<void> tapText(WidgetTester tester, String text) async {
      final target = find.text(text).first;
      await tester.ensureVisible(target);
      await tester.pump();
      await tester.tap(target);
      await frames(tester);
    }

    testWidgets('asks about pain in the marked tooth, and saves the answer',
        (tester) async {
      final repo = await pump(tester);
      expect(
        find.text(
            'Have you experienced pain or sensitivity in this tooth before?'),
        findsOneWidget,
      );
      for (final pain in ToothPain.values) {
        expect(find.text(pain.label), findsOneWidget);
      }
      expect(find.text('Routine dental assessment'), findsOneWidget);

      await tapText(tester, ToothPain.yes.label);
      expect(repo.answers.single, ('s1', '1', ToothPain.yes));
      expect(find.text('You told us'), findsOneWidget);
      expect(find.text('Schedule a dental visit soon'), findsOneWidget);
      expect(find.text(urgentCareWarning), findsOneWidget);
      // The page's own advice follows the answer too.
      expect(find.text('Book a dental visit soon'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an answer can be changed or taken back', (tester) async {
      final repo = await pump(tester);
      await tapText(tester, ToothPain.sometimes.label);
      await tapText(tester, 'Change');
      await tapText(tester, ToothPain.no.label);
      await tapText(tester, 'Change');
      await tapText(tester, 'Remove my answer');
      expect(repo.answers.map((a) => a.$3),
          [ToothPain.sometimes, ToothPain.no, null]);
      expect(
        find.text(
            'Have you experienced pain or sensitivity in this tooth before?'),
        findsOneWidget,
      );
    });

    testWidgets('someone not sure sees what a cavity can feel like',
        (tester) async {
      await pump(tester);
      await tapText(tester, ToothPain.notSure.label);
      for (final sign in cavitySymptoms) {
        expect(find.text(sign), findsOneWidget);
      }
    });

    testWidgets('asks nothing when the answer has nowhere to be kept',
        (tester) async {
      await pump(tester, stored: false);
      expect(
        find.text(
            'Have you experienced pain or sensitivity in this tooth before?'),
        findsNothing,
      );
      expect(find.text('What we found'), findsOneWidget);
    });

    testWidgets('a treatment opens its own page in the Treatment tab',
        (tester) async {
      await pump(tester);
      await tapText(tester, 'Possible treatments');
      expect(find.text('Fluoride treatment and monitoring'), findsOneWidget);
      await tapText(tester, 'Learn more about dental fillings');
      await tester.pumpAndSettle();
      expect(find.byType(TreatmentDetailScreen), findsOneWidget);
      expect(find.text('Tooth Filling'), findsWidgets);
      for (final section in [
        'Why a dentist may recommend it',
        'When it may be needed',
        'Recovery and aftercare',
        'Risks and things to consider',
      ]) {
        await tester.scrollUntilVisible(
          find.text(section),
          200,
          scrollable: find
              .descendant(
                of: find.byType(TreatmentDetailScreen),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(find.text(section), findsOneWidget);
      }
      // Back goes straight to the result, not the list of every treatment.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(TreatmentDetailScreen), findsNothing);
      expect(find.text('Possible treatments'), findsOneWidget);
    });

    testWidgets('shows what the check looked for, and what it can\'t read',
        (tester) async {
      await pump(tester);
      expect(find.bySemanticsLabel(RegExp('^Possible tooth decay: 2 marked')),
          findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^Plaque and tartar: Not read')),
          findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Areas checked: 6 of 6')),
          findsOneWidget);
    });

    for (final (name, size, scale) in const [
      ('small phone, large text', Size(320, 568), 1.3),
      ('large phone, accessibility text', Size(430, 932), 2.0),
    ]) {
      testWidgets('answered, with treatments open, lays out: $name',
          (tester) async {
        await pump(tester, size: size, textScale: scale);
        await tapText(tester, ToothPain.yes.label);
        await tapText(tester, 'Possible treatments');
        await tapText(tester, 'What this could mean');
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('the PDF', () {
    ByteData font(String weight) => ByteData.sublistView(
          File('assets/fonts/Outfit-$weight.ttf').readAsBytesSync(),
        );

    test('is made with answers, crops and faint signs', () async {
      final fonts = ReportFonts(
        regular: font('Regular'),
        medium: font('Medium'),
        semiBold: font('SemiBold'),
        bold: font('Bold'),
      );
      final analysis = _analysis(
        findings: [_rightUpper, _sign('2', 'back-left')],
        faint: [_sign('3', 'front', confidence: 0.4)],
      );
      final report = _report(analysis);
      final patient = PatientContext(at: _at);
      final trend = ScanTrend.of(const []);
      final plan = CarePlan.of(report, patient, trend, answers: const {
        '1': ToothPain.yes,
        '2': ToothPain.notSure,
      });
      expect(plan.teeth.where((g) => g.pain != null), hasLength(2));
      final photo = ReportPhoto(
        jpeg: img.encodeJpg(img.Image(width: 64, height: 48)),
        width: 64,
        height: 48,
      );
      final bytes = await buildReportPdf(ReportPdfData(
        report: report,
        patient: patient,
        plan: plan,
        trend: trend,
        fonts: fonts,
        generatedAt: _at,
        sessionId: 's1',
        photos: {'right': photo, 'back-left': photo},
      ));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(bytes.length, greaterThan(1000));
    });
  });

  test('every view the scan uses has a place in words', () {
    for (final r in scanRegions) {
      final f = _sign('1', r.id);
      final words = toothPlace(_spotOf(_report(_analysis(findings: [f])), '1'));
      expect(words, startsWith('a'));
    }
  });
}

Future<void> frames(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
