import 'dart:convert';

import 'package:dentra_mobile/features/ai_assistant/ai_chat_controller.dart';
import 'package:dentra_mobile/features/history/screens/screening_detail_screen.dart';
import 'package:dentra_mobile/features/history/widgets/screening_history_card.dart';
import 'package:dentra_mobile/features/home/widgets/latest_scan_card.dart';
import 'package:dentra_mobile/features/scan/data/scan_outcomes.dart';
import 'package:dentra_mobile/features/scan/data/scan_regions.dart';
import 'package:dentra_mobile/features/scan/data/scan_report.dart';
import 'package:dentra_mobile/features/scan/widgets/report/mouth_3d.dart';
import 'package:dentra_mobile/features/scan/widgets/report/report_charts.dart';
import 'package:dentra_mobile/features/scan/widgets/report/next_steps.dart';
import 'package:dentra_mobile/features/scan/widgets/report/report_photos.dart';
import 'package:dentra_mobile/features/scan/widgets/report/scan_report_view.dart';
import 'package:dentra_mobile/features/scan/widgets/report/signs_section.dart';
import 'package:dentra_mobile/features/scan/widgets/report/spot_photo.dart';
import 'package:dentra_mobile/features/scan/widgets/report/trend_section.dart';
import 'package:dentra_mobile/features/screening/data/models/screening_session.dart';
import 'package:dentra_mobile/features/screening/data/screening_repository.dart';
import 'package:dentra_mobile/features/screening/providers/screening_sessions_provider.dart';
import 'package:flutter/material.dart' hide Rect, Size;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// A 1x1 PNG: enough for a real image stream to resolve.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M/AAwAD'
  'hgGAWjR9awAAAABJRU5ErkJggg==',
);

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
  String region, {
  double confidence = 0.9,
  List<double>? bbox,
}) =>
    ScreeningFinding(
      label: 'Possible tooth decay',
      category: 'enamel_caries',
      regionId: region,
      confidence: confidence,
      modality: 'rgb',
      bbox: bbox,
    );

ScreeningAnalysis _analysis({
  List<ScreeningFinding> findings = const [],
  List<ScreeningFinding> faint = const [],
  List<ScreeningRecommendation> recs = const [],
  List<ScreeningQualityIssue> issues = const [],
  String? model,
  AnalysisStatus status = AnalysisStatus.complete,
}) =>
    ScreeningAnalysis(
      summary: 'A summary.',
      analyzedAt: DateTime(2026, 11, 2),
      findings: findings,
      faintFindings: faint,
      recommendations: recs,
      qualityIssues: issues,
      model: model,
      status: status,
    );

ScreeningRecommendation _rec(String urgency, {String code = 'x'}) =>
    ScreeningRecommendation(
      code: code,
      title: 'A step',
      detail: 'Do this.',
      urgency: urgency,
      regionIds: const ['left'],
    );

ScreeningQualityIssue _rejected(String region, {String reason = 'no_teeth'}) =>
    ScreeningQualityIssue(
      regionId: region,
      modality: 'rgb',
      reason: reason,
      message: 'No teeth detected, or the photo might be blurry.',
    );

ScreeningSession _session(
  String id,
  DateTime at,
  ScreeningAnalysis? analysis, {
  List<String> views = _allViews,
}) =>
    ScreeningSession(
      id: id,
      completedAt: at,
      capturedRegions: views,
      totalRegions: 9,
      analysis: analysis,
    );

class _Repo implements ScreeningRepository {
  _Repo(this.sessions);
  final List<ScreeningSession> sessions;

  @override
  Future<List<ScreeningSession>> fetchSessions(String userId) async => sessions;
  @override
  Future<ScreeningSession> upsertSession(
          String userId, ScreeningSession session) async =>
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

Future<void> _pumpReport(
  WidgetTester tester,
  ScreeningReport report, {
  List<ScreeningSession> history = const [],
  String? sessionId,
  Size size = const Size(390, 844),
  double textScale = 1.0,
  bool showActions = true,
  bool withRabi = true,
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final view = ScanReportView(
    report: report,
    imageOf: (_) => MemoryImage(_png),
    status: 'Scan complete',
    date: 'November 2, 2026',
    viewsTaken: 9,
    leading: const SizedBox.square(dimension: 44),
    sessionId: sessionId,
    onClinics: () {},
    showActions: showActions,
  );
  await tester.pumpWidget(ProviderScope(
    overrides: [screeningRepositoryProvider.overrideWithValue(_Repo(history))],
    child: MaterialApp(
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: withRabi
                ? AiChatScope(controller: AiChatController(), child: view)
                : view,
          ),
        ),
      ),
    ),
  ));
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> settleFrames(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('where a spot is', () {
    Rect at(double x, double y) => Rect.fromCenter(
          center: Offset(x, y),
          width: 0.1,
          height: 0.1,
        );

    test('an arch photo tells front teeth from back teeth, not left from right',
        () {
      final upper = scanRegionById('upper-occlusal');
      expect(spotAreas(upper, at(0.5, 0.2)), {MouthArea.upperFront});
      expect(
        spotAreas(upper, at(0.15, 0.7)),
        {MouthArea.upperLeft, MouthArea.upperRight},
      );
      // The other side of the photo says exactly the same.
      expect(spotAreas(upper, at(0.85, 0.7)), spotAreas(upper, at(0.15, 0.7)));
      expect(
        spotAreas(scanRegionById('lower-occlusal'), at(0.5, 0.8)),
        {MouthArea.lowerFront},
      );
    });

    test('a side photo knows its side and splits upper from lower at the bite',
        () {
      final left = scanRegionById('left');
      expect(spotAreas(left, at(0.4, 0.2)), {MouthArea.upperLeft});
      expect(spotAreas(left, at(0.4, 0.8)), {MouthArea.lowerLeft});
      expect(
        spotAreas(scanRegionById('back-right'), at(0.4, 0.8)),
        {MouthArea.lowerRight},
      );
      expect(
        spotAreas(scanRegionById('front'), at(0.5, 0.2)),
        {MouthArea.upperFront},
      );
    });

    test('a spot on the bite line stays with both arches', () {
      expect(
        spotAreas(scanRegionById('left'), at(0.4, 0.52)),
        {MouthArea.upperLeft, MouthArea.lowerLeft},
      );
    });

    test('with no box it stays with everything the view shows', () {
      expect(
        spotAreas(scanRegionById('upper-occlusal'), null),
        {MouthArea.upperLeft, MouthArea.upperFront, MouthArea.upperRight},
      );
    });

    test('a second photo counts the same as its view', () {
      expect(
        spotAreas(scanRegionById('left-2'), at(0.4, 0.2)),
        {MouthArea.upperLeft},
      );
    });

    test('areas read in everyday words', () {
      expect(describeAreas({MouthArea.upperLeft}), 'Upper left back');
      expect(
        describeAreas({MouthArea.upperLeft, MouthArea.upperRight}),
        'Upper back teeth',
      );
      expect(
        describeAreas({MouthArea.lowerLeft, MouthArea.lowerRight}),
        'Lower back teeth',
      );
      expect(
        describeAreas({MouthArea.upperLeft, MouthArea.lowerLeft}),
        'Left back teeth',
      );
      expect(
        describeAreas({MouthArea.upperFront, MouthArea.lowerFront}),
        'Front teeth',
      );
      expect(
        describeAreas({
          MouthArea.upperRight,
          MouthArea.upperFront,
          MouthArea.upperLeft,
        }),
        'Upper teeth',
      );
    });
  });

  group('a clear result', () {
    test('never reads as a clean bill of health', () {
      final report = ScreeningReport(_analysis(), _allViews);
      expect(report.sentence, contains('can miss early decay'));
      expect(report.sentence, contains('regular check-ups'));
      expect(report.sentence, isNot(contains('No signs')));
    });

    test('the wording on signs gives no figures', () {
      for (final text in signMeaning.values) {
        expect(text, isNot(contains(RegExp(r'\d'))));
      }
    });
  });

  group('the report', () {
    test('the headline follows the most pressing advice, never the note on braces',
        () {
      String headline(List<ScreeningRecommendation> recs) =>
          ScreeningReport(_analysis(recs: recs), _allViews).headline;

      expect(headline(const []), 'Nothing flagged in your photos');
      expect(
        headline([_rec('routine', code: 'braces_seen')]),
        'Nothing flagged in your photos',
      );
      expect(headline([_rec('routine')]), 'Mention this at your next visit');
      expect(
        headline([_rec('routine'), _rec('soon')]),
        'Book a dental visit soon',
      );
      expect(headline([_rec('prompt')]), 'See a dentist promptly');
    });

    test('faint signs alone ask for nothing, but are not called nothing', () {
      final report = ScreeningReport(
        _analysis(faint: [_sign('left', confidence: 0.4)]),
        _allViews,
      );
      expect(report.level, ReportLevel.none);
      expect(report.headline, 'Nothing to act on right now');
      expect(report.signCount, 0);
      expect(report.faintCount, 1);
      expect(report.spots.single.strength, SignStrength.faint);
    });

    test('strength comes from the model and the rules, in that order', () {
      final report = ScreeningReport(
        _analysis(
          findings: [_sign('left', confidence: 0.7), _sign('right')],
          faint: [_sign('front', confidence: 0.4)],
        ),
        _allViews,
      );
      expect(report.spots.map((s) => s.strength), [
        SignStrength.strong,
        SignStrength.possible,
        SignStrength.faint,
      ]);
      expect(report.spots.first.percent, 90);
    });

    test('photos are counted by what happened to them', () {
      final report = ScreeningReport(
        _analysis(issues: [_rejected('front')]),
        _allViews,
      );
      // Two inner views aren't read, and one photo was rejected.
      expect(report.photosRead, 6);
      expect(report.photosToRetake, 1);
    });

    test('rejected photos never read as a result', () {
      final report = ScreeningReport(
        _analysis(
          status: AnalysisStatus.retake,
          issues: [_rejected('front'), _rejected('left', reason: 'blurry')],
        ),
        const ['front', 'left'],
      );
      expect(report.photosRead, 0);
      expect(report.headline, "We couldn't read these photos");
      expect(report.areas.values.any((a) => a.state.read), isFalse);
    });

    test('only inner photos means saved, not clear', () {
      final report = ScreeningReport(
        _analysis(),
        const ['upper-lingual'],
      );
      expect(report.headline, 'Your photos are saved');
      expect(report.areas[MouthArea.upperLeft]!.state, AreaState.notRead);
      expect(report.areas[MouthArea.lowerLeft]!.state, AreaState.notTaken);
    });

    test('a service with no model behind it is not a clean result', () {
      expect(
        ScreeningReport(_analysis(model: 'det-none+teeth-none'), _allViews)
            .detectorOff,
        isTrue,
      );
      expect(
        ScreeningReport(_analysis(model: 'det-caries-nano-v3+x'), _allViews)
            .detectorOff,
        isFalse,
      );
    });

    test('an area takes its strongest sign, and only signs placed in it', () {
      final report = ScreeningReport(
        _analysis(findings: [
          _sign('left', bbox: const [0.3, 0.1, 0.1, 0.1]),
        ], faint: [
          _sign('left', confidence: 0.4, bbox: const [0.3, 0.8, 0.1, 0.1]),
        ]),
        _allViews,
      );
      expect(report.areas[MouthArea.upperLeft]!.state, AreaState.strong);
      expect(report.areas[MouthArea.lowerLeft]!.state, AreaState.faint);
      expect(report.areas[MouthArea.upperRight]!.state, AreaState.clear);
    });

    test('a read photo outranks a rejected one of the same area', () {
      final report = ScreeningReport(
        _analysis(issues: [_rejected('left')]),
        const ['left', 'back-left'],
      );
      expect(report.areas[MouthArea.upperLeft]!.state, AreaState.clear);
    });

    test('an area only a rejected photo shows needs a retake', () {
      final report = ScreeningReport(
        _analysis(issues: [_rejected('left')]),
        const ['left', 'front'],
      );
      expect(report.areas[MouthArea.upperLeft]!.state, AreaState.retake);
      expect(report.areas[MouthArea.upperFront]!.state, AreaState.clear);
      expect(report.areas[MouthArea.upperRight]!.state, AreaState.notTaken);
    });
  });

  group('what helps the person next', () {
    test('questions and tips follow what was seen', () {
      final clear = ScreeningReport(_analysis(), _allViews);
      final back = ScreeningReport(
        _analysis(findings: [_sign('left', bbox: const [0.3, 0.1, 0.1, 0.1])]),
        _allViews,
      );
      expect(back.dentistQuestions.first, contains('decay, a stain'));
      expect(clear.dentistQuestions.first, isNot(contains('decay, a stain')));
      expect(back.careTips.first, contains('back teeth'));
      expect(clear.careTips, hasLength(1));
    });

    test('the summary for a dentist says what it is and what it can\'t read', () {
      final text = ScreeningReport(
        _analysis(findings: [_sign('left', bbox: const [0.3, 0.1, 0.1, 0.1])]),
        _allViews,
      ).summaryForDentist('November 2, 2026');
      expect(text, contains('November 2, 2026'));
      expect(text, contains('Not a diagnosis'));
      expect(text, contains('Upper left back, strong sign (90% model confidence)'));
      expect(text, contains('Not read by this check'));
    });

    test('surfaces count what was read and what is only saved', () {
      final rows = ScreeningReport(_analysis(), _allViews).surfaces!;
      expect(rows.map((r) => r.$1), ToothSurface.values);
      expect(rows.map((r) => r.$2), [6, 6, 0]);
      expect(rows.last.$3, 6);
      expect(ScreeningReport(_analysis(), const ['ul']).surfaces, isNull);
    });
  });

  group('coverage', () {
    test('inner sides are never read, and the rest follow their photos', () {
      final coverage = ScreeningReport(_analysis(), _allViews).coverage!;
      expect(coverage, hasLength(18));
      for (final a in MouthArea.values) {
        expect(coverage[(ToothSurface.inner, a)], AreaState.notRead);
        expect(coverage[(ToothSurface.outer, a)], AreaState.clear);
        expect(coverage[(ToothSurface.biting, a)], AreaState.clear);
      }
    });

    test('a sign marks only the surface its photo looks at', () {
      final coverage = ScreeningReport(
        _analysis(findings: [
          _sign('upper-occlusal', bbox: const [0.45, 0.1, 0.1, 0.1]),
        ]),
        _allViews,
      ).coverage!;
      expect(
        coverage[(ToothSurface.biting, MouthArea.upperFront)],
        AreaState.strong,
      );
      expect(
        coverage[(ToothSurface.outer, MouthArea.upperFront)],
        AreaState.clear,
      );
      expect(
        coverage[(ToothSurface.biting, MouthArea.upperLeft)],
        AreaState.clear,
      );
    });

    test('a view not taken leaves its surfaces without a photo', () {
      final coverage =
          ScreeningReport(_analysis(), const ['front']).coverage!;
      expect(
        coverage[(ToothSurface.outer, MouthArea.upperFront)],
        AreaState.clear,
      );
      expect(
        coverage[(ToothSurface.biting, MouthArea.upperFront)],
        AreaState.notTaken,
      );
    });

    test('old five-region scans never said which surface', () {
      expect(ScreeningReport(_analysis(), const ['ul', 'ur']).coverage, isNull);
    });
  });

  group('over time', () {
    final upperFront = _sign('upper-occlusal', bbox: const [0.45, 0.1, 0.1, 0.1]);

    test('compares with the scan before, newest last', () {
      final trend = ScanTrend.of([
        _session('b', DateTime(2026, 10), _analysis(findings: [upperFront])),
        _session('a', DateTime(2026, 9), _analysis()),
      ]);
      expect(trend.points.map((p) => p.sessionId), ['a', 'b']);
      expect(trend.newAreas, [MouthArea.upperFront]);
      expect(trend.clearedAreas, isEmpty);
    });

    test('an area not read last time is neither new nor gone', () {
      final trend = ScanTrend.of([
        _session('b', DateTime(2026, 10), _analysis(findings: [upperFront])),
        _session('a', DateTime(2026, 9), _analysis(), views: const ['lower-occlusal']),
      ]);
      expect(trend.newAreas, isEmpty);
    });

    test('names what stopped showing up', () {
      final trend = ScanTrend.of([
        _session('b', DateTime(2026, 10), _analysis()),
        _session('a', DateTime(2026, 9), _analysis(findings: [upperFront])),
      ]);
      expect(trend.clearedAreas, [MouthArea.upperFront]);
    });

    test('three scans in a row counts as repeating, even when faint', () {
      final faint = _sign(
        'upper-occlusal',
        confidence: 0.4,
        bbox: const [0.45, 0.1, 0.1, 0.1],
      );
      final trend = ScanTrend.of([
        _session('c', DateTime(2026, 11), _analysis(faint: [faint])),
        _session('b', DateTime(2026, 10), _analysis(faint: [faint])),
        _session('a', DateTime(2026, 9), _analysis(findings: [upperFront])),
      ]);
      expect(trend.repeating, {MouthArea.upperFront: 3});
    });

    test('a clear scan breaks the run; a scan that didn\'t read it doesn\'t', () {
      final trend = ScanTrend.of([
        _session('d', DateTime(2026, 12), _analysis(findings: [upperFront])),
        _session('c', DateTime(2026, 11), _analysis(findings: [upperFront])),
        _session('b', DateTime(2026, 10), _analysis()),
        _session('a', DateTime(2026, 9), _analysis(findings: [upperFront])),
      ]);
      expect(trend.repeating, isEmpty);

      final skipped = ScanTrend.of([
        _session('d', DateTime(2026, 12), _analysis(findings: [upperFront])),
        _session('c', DateTime(2026, 11), _analysis(findings: [upperFront])),
        _session('b', DateTime(2026, 10), _analysis(), views: const ['lower-occlusal']),
        _session('a', DateTime(2026, 9), _analysis(findings: [upperFront])),
      ]);
      expect(skipped.repeating, {MouthArea.upperFront: 3});
    });

    test('says when older scans came from another version of the check', () {
      final mixed = ScanTrend.of([
        _session('b', DateTime(2026, 11), _analysis(model: 'det-v5+rules')),
        _session('a', DateTime(2026, 10), _analysis(model: 'det-v4+rules')),
      ]);
      expect(mixed.mixedVersions, isTrue);
      final same = ScanTrend.of([
        _session('b', DateTime(2026, 11), _analysis(model: 'det-v5+rules')),
        _session('a', DateTime(2026, 10), _analysis(model: 'det-v5+x')),
      ]);
      expect(same.mixedVersions, isFalse);
    });

    test('only scans that really read something count', () {
      final trend = ScanTrend.of([
        _session('e', DateTime(2026, 12), _analysis()),
        _session('d', DateTime(2026, 11), null),
        _session('c', DateTime(2026, 10), _analysis(status: AnalysisStatus.failed)),
        _session('b', DateTime(2026, 9), _analysis(model: 'det-none+x')),
        _session('a', DateTime(2026, 8), _analysis(), views: const ['upper-lingual']),
      ]);
      expect(trend.points.map((p) => p.sessionId), ['e']);
      expect(trend.hasHistory, isFalse);
    });

    test('opening an older scan looks only at what came before it', () {
      final sessions = [
        _session('c', DateTime(2026, 11), _analysis(findings: [upperFront])),
        _session('b', DateTime(2026, 10), _analysis()),
        _session('a', DateTime(2026, 9), _analysis()),
      ];
      expect(
        ScanTrend.of(sessions, currentId: 'b').points.map((p) => p.sessionId),
        ['a', 'b'],
      );
    });

    test('keeps the most recent scans the chart has room for', () {
      final sessions = [
        for (var i = 0; i < 12; i++)
          _session('$i', DateTime(2026, 11, 28 - i), _analysis()),
      ];
      final trend = ScanTrend.of(sessions);
      expect(trend.points, hasLength(ScanTrend.maxPoints));
      expect(trend.points.last.sessionId, '0');
    });
  });

  group('the marked photo', () {
    test('shows all a box can hold of the photo until told to go closer', () {
      final view = spotViewport(const Size(400, 300), const Size(800, 600), null);
      expect(view, const Rect.fromLTWH(0, 0, 1, 1));
    });

    test('crops to the shape of the box', () {
      final view = spotViewport(const Size(300, 300), const Size(800, 400), null);
      expect(view.width, closeTo(0.5, 1e-9));
      expect(view.height, closeTo(1, 1e-9));
    });

    test('goes in close enough for the focus to take about half the box', () {
      const focus = Rect.fromLTWH(0.4, 0.4, 0.2, 0.2);
      final view =
          spotViewport(const Size(400, 300), const Size(800, 600), focus);
      expect(view.center, focus.center);
      expect(view.width, closeTo(0.42, 1e-9));
      expect(view.contains(focus.topLeft) && view.contains(focus.bottomRight),
          isTrue);
    });

    test('stays inside the photo for a mark at its edge', () {
      const focus = Rect.fromLTWH(0, 0.9, 0.1, 0.1);
      final view =
          spotViewport(const Size(400, 300), const Size(800, 600), focus);
      expect(view.left, closeTo(0, 1e-9));
      expect(view.bottom, closeTo(1, 1e-9));
    });

    test('marks only the signs in that photo', () {
      final report = ScreeningReport(
        _analysis(findings: [
          _sign('left', bbox: const [0.1, 0.1, 0.1, 0.1]),
          _sign('right', bbox: const [0.5, 0.5, 0.1, 0.1]),
        ]),
        _allViews,
      );
      final marks = markersIn(report.spots, 'left', selected: report.spots.first);
      expect(marks, hasLength(1));
      expect(marks.single.selected, isTrue);
    });

    test('a sign without a box gets no mark', () {
      final report = ScreeningReport(
        _analysis(findings: [_sign('left')]),
        _allViews,
      );
      expect(markersIn(report.spots, 'left'), isEmpty);
    });
  });

  group('saved results', () {
    test('marks and faint signs survive a save and a reload', () {
      final analysis = _analysis(
        findings: [_sign('left', bbox: const [0.1, 0.2, 0.3, 0.4])],
        faint: [_sign('right', confidence: 0.4)],
      );
      final back = ScreeningAnalysis.fromJson(
        jsonDecode(jsonEncode(analysis.toJson())) as Map<String, dynamic>,
      );
      expect(back.findings.single.bbox, [0.1, 0.2, 0.3, 0.4]);
      expect(back.faintFindings.single.regionId, 'right');
    });

    test('results saved before either existed still load', () {
      final back = ScreeningAnalysis.fromJson({
        'summary': 's',
        'analyzed_at': '2026-11-02T00:00:00Z',
        'findings': [
          {'label': 'Possible tooth decay', 'region_id': 'left'},
        ],
      });
      expect(back.findings.single.bbox, isNull);
      expect(back.faintFindings, isEmpty);
    });

    test('a malformed box is ignored', () {
      final back = ScreeningFinding.fromJson({
        'label': 'x',
        'bbox': [0.1, 0.2],
      });
      expect(back.bbox, isNull);
    });
  });

  group('the page', () {
    final busy = ScreeningReport(
      _analysis(
        findings: [
          _sign('upper-occlusal', bbox: const [0.7, 0.6, 0.15, 0.2]),
          _sign('upper-occlusal', confidence: 0.7, bbox: const [0.1, 0.6, 0.15, 0.2]),
          _sign('back-left', bbox: const [0.2, 0.7, 0.2, 0.2]),
        ],
        faint: [_sign('front', confidence: 0.4, bbox: const [0.4, 0.2, 0.1, 0.2])],
        recs: [_rec('soon'), _rec('routine', code: 'braces_seen')],
      ),
      _allViews,
    );
    final history = [
      _session('b', DateTime(2026, 11, 2), busy.analysis),
      _session('a', DateTime(2026, 10, 2), _analysis()),
    ];

    for (final (name, size, scale) in const [
      ('small phone, large text', Size(320, 568), 1.3),
      ('standard phone', Size(390, 844), 1.0),
      ('large phone, accessibility text', Size(430, 932), 2.0),
    ]) {
      testWidgets('lays out without overflow: $name', (tester) async {
        await _pumpReport(
          tester,
          busy,
          history: history,
          sessionId: 'b',
          size: size,
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('a clear first scan lays out without overflow: $name',
          (tester) async {
        final clear = ScreeningReport(_analysis(), _allViews);
        await _pumpReport(tester, clear, size: size, textScale: scale);
        expect(tester.takeException(), isNull);
      });

      testWidgets('a rejected scan lays out without overflow: $name',
          (tester) async {
        final rejected = ScreeningReport(
          _analysis(issues: [_rejected('front')]),
          const ['front'],
        );
        await _pumpReport(tester, rejected, size: size, textScale: scale);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('leads with the result, the scale and the figures', (tester) async {
      await _pumpReport(tester, busy, history: history, sessionId: 'b');
      expect(find.text('Book a dental visit soon'), findsOneWidget);
      expect(find.textContaining('3 signs of possible decay'), findsOneWidget);
      expect(
        find.bySemanticsLabel('When to see a dentist: Book soon, step 3 of 4'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('surfaces read: 12 of 18'), findsOneWidget);
      expect(find.bySemanticsLabel('photos read: 7 of 9'), findsOneWidget);
      expect(find.byType(Mouth3D), findsOneWidget);
    });

    testWidgets('goes through the signs one at a time, the mouth turning along',
        (tester) async {
      await _pumpReport(tester, busy);
      expect(find.text('1 of 4'), findsOneWidget);
      expect(find.text('Upper back teeth'), findsOneWidget);

      final next = find.byTooltip('Next sign');
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('2 of 4'), findsOneWidget);
      expect(find.text('Whole mouth'), findsOneWidget);

      await tester.ensureVisible(find.text('Whole mouth'));
      await tester.pump();
      await tester.tap(find.text('Whole mouth'));
      await settleFrames(tester);
      expect(find.text('Whole mouth'), findsNothing);
      expect(find.text('2 of 4'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('says what each strength means, with no figures', (tester) async {
      expect(signMeaning.keys, unorderedEquals(SignStrength.values));
      await _pumpReport(tester, busy);
      expect(find.text(signMeaning[SignStrength.strong]!), findsOneWidget);
    });

    testWidgets('shows how the signs split by strength', (tester) async {
      await _pumpReport(tester, busy);
      expect(
        find.bySemanticsLabel(
            'Signs by strength: 2 strong sign, 1 possible sign, 1 faint sign'),
        findsOneWidget,
      );
    });

    testWidgets('says what dental work it saw, apart from signs', (tester) async {
      await _pumpReport(
        tester,
        ScreeningReport(
          ScreeningAnalysis(
            summary: 's',
            analyzedAt: DateTime(2026, 11, 2),
            findings: [_sign('left')],
            dentalWork: const [
              ScreeningFinding(label: 'Possible filling', regionId: 'left'),
              ScreeningFinding(label: 'Possible filling', regionId: 'left'),
              ScreeningFinding(label: 'Possible crown', regionId: 'left'),
            ],
          ),
          _allViews,
        ),
      );
      expect(find.textContaining('2 fillings and 1 crown'), findsOneWidget);
      expect(find.text('Upper left back'), findsNothing);
    });

    testWidgets('can copy the result for a dentist', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      await _pumpReport(tester, busy);
      final copy = find.text('Copy my result for the dentist');
      await tester.ensureVisible(copy);
      await tester.tap(copy);
      await tester.pump(const Duration(milliseconds: 100));
      expect(copied, contains('Not a diagnosis'));
      expect(copied, contains('Upper back teeth'));
      expect(find.textContaining('Copied'), findsOneWidget);
    });

    testWidgets('the teeth you can\'t easily see come first in the photos',
        (tester) async {
      expect(
        ReportPhotoRow.hardFirst([
          scanRegionById('front'),
          scanRegionById('back-left'),
          scanRegionById('upper-lingual'),
        ]).map((r) => r.id),
        ['back-left', 'upper-lingual', 'front'],
      );
    });

    testWidgets('faint signs alone are headed as such', (tester) async {
      await _pumpReport(
        tester,
        ScreeningReport(
          _analysis(faint: [_sign('left', confidence: 0.4)]),
          _allViews,
        ),
      );
      expect(find.text('Faint signs to watch'), findsOneWidget);
      expect(find.text('Keep your regular check-ups'), findsOneWidget);
    });

    testWidgets('a clear result has nothing to spot and nothing to do',
        (tester) async {
      await _pumpReport(tester, ScreeningReport(_analysis(), _allViews));
      expect(find.text('Nothing flagged in your photos'), findsOneWidget);
      expect(find.byType(SignsSection), findsNothing);
      // Still has something to say: keep the check-ups going.
      expect(find.text('Keep your regular check-ups'), findsOneWidget);
      // The first scan: nothing to compare with yet.
      expect(find.text('This is your starting point'), findsOneWidget);
    });

    testWidgets('a rejected scan shows the feedback and no result',
        (tester) async {
      await _pumpReport(
        tester,
        ScreeningReport(
          _analysis(issues: [_rejected('front')]),
          const ['front'],
        ),
        showActions: false,
      );
      expect(find.text("We couldn't read these photos"), findsOneWidget);
      expect(find.text('Retake for a better check'), findsOneWidget);
      expect(find.textContaining('No teeth detected'), findsOneWidget);
      expect(find.byType(Mouth3D), findsNothing);
      expect(find.byType(CoverageRings), findsNothing);
      expect(find.byType(TrendSection), findsNothing);
      expect(find.byType(NextSteps), findsNothing);
      expect(find.text('Ask Rabi about my results'), findsNothing);
    });

    testWidgets('offers Rabi only where the page can reach it', (tester) async {
      final clear = ScreeningReport(_analysis(), _allViews);
      await _pumpReport(tester, clear);
      expect(find.text('Ask Rabi about my results'), findsOneWidget);
      expect(find.text('Find clinics nearby'), findsOneWidget);

      await _pumpReport(tester, clear, withRabi: false);
      expect(find.text('Ask Rabi about my results'), findsNothing);
      expect(find.text('Find clinics nearby'), findsOneWidget);
    });

    testWidgets('names what it can\'t read', (tester) async {
      await _pumpReport(tester, ScreeningReport(_analysis(), _allViews));
      expect(find.textContaining('Plaque, tartar, gums'), findsOneWidget);
      expect(find.textContaining("can't be read yet"), findsOneWidget);
    });

    testWidgets('never shows a tooth number', (tester) async {
      await _pumpReport(tester, busy, history: history, sessionId: 'b');
      expect(find.textContaining(RegExp(r'\b[Tt]ooth \d')), findsNothing);
    });

    testWidgets('shows the change since last scan, and the chart stays in bounds',
        (tester) async {
      final many = [
        for (var i = 0; i < 8; i++)
          _session(
            '$i',
            DateTime(2026, 11, 20 - i),
            _analysis(
              findings: [
                for (var n = 0; n < (i == 0 ? 40 : 1); n++)
                  _sign('upper-occlusal', bbox: const [0.45, 0.1, 0.1, 0.1]),
              ],
              faint: [_sign('front', confidence: 0.4)],
            ),
          ),
      ];
      await _pumpReport(
        tester,
        ScreeningReport(many.first.analysis!, _allViews),
        history: many,
        sessionId: '0',
        size: const Size(320, 568),
      );
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Signs keep showing up'), findsOneWidget);
    });

    testWidgets('tapping a past scan on the chart shows its numbers',
        (tester) async {
      await _pumpReport(tester, busy, history: history, sessionId: 'b');
      expect(find.text('Nov 2, 2026 · 3 signs · 1 faint'), findsOneWidget);
      final past = find.bySemanticsLabel('Oct 2, 2026 · 0 signs');
      await tester.ensureVisible(past);
      await tester.tap(past, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Oct 2, 2026 · 0 signs'), findsOneWidget);
    });

    test('Rabi is told where each sign is and how sure the model was', () {
      final prompt = rabiPromptFor(busy);
      expect(prompt, contains('Upper back teeth'));
      expect(prompt, contains('faint sign'));
      expect(prompt, contains('90% model confidence'));
      expect(prompt, contains('not a diagnosis'));
    });
  });

  group('the history list', () {
    testWidgets('shows the result beside a read scan, and nothing beside others',
        (tester) async {
      Future<void> card(ScreeningSession s) => tester.pumpWidget(MaterialApp(
            home: Scaffold(
              body: ScreeningHistoryCard(
                session: s,
                isLatest: true,
                alternate: false,
                onTap: () {},
              ),
            ),
          ));

      await card(_session(
        'a',
        DateTime(2026, 11, 2),
        _analysis(findings: [_sign('left')], recs: [_rec('soon')]),
      ));
      expect(find.text('Book a dental visit soon'), findsOneWidget);

      await card(_session('b', DateTime(2026, 11, 2), null));
      expect(find.text('Book a dental visit soon'), findsNothing);
      expect(find.text('Dental Screening'), findsOneWidget);

      await card(_session(
        'c',
        DateTime(2026, 11, 2),
        _analysis(model: 'det-none+x'),
      ));
      expect(find.textContaining('Nothing flagged'), findsNothing);
    });
  });

  group('home', () {
    Future<void> pump(WidgetTester tester, List<ScreeningSession> sessions) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          screeningRepositoryProvider.overrideWithValue(_Repo(sessions)),
        ],
        child: const MaterialApp(home: Scaffold(body: LatestScanCard())),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('stays away until a scan has really been read', (tester) async {
      await pump(tester, [
        _session('a', DateTime.now(), null),
        _session('b', DateTime.now(), _analysis(model: 'det-none+x')),
      ]);
      expect(find.text('LATEST SCAN'), findsNothing);
    });

    testWidgets('shows the newest result and doesn\'t nag right after a scan',
        (tester) async {
      await pump(tester, [
        _session(
          'b',
          DateTime.now(),
          _analysis(findings: [_sign('left')], recs: [_rec('soon')]),
        ),
        _session('a', DateTime.now().subtract(const Duration(days: 40)), _analysis()),
      ]);
      expect(find.text('LATEST SCAN'), findsOneWidget);
      expect(find.text('Book a dental visit soon'), findsOneWidget);
      expect(find.textContaining('1 sign'), findsOneWidget);
      expect(find.textContaining('scan again'), findsNothing);
    });

    testWidgets('suggests scanning again after a while', (tester) async {
      await pump(tester, [
        _session('a', DateTime.now().subtract(const Duration(days: 40)), _analysis()),
      ]);
      expect(find.textContaining('scan again'), findsOneWidget);
    });
  });

  group('opening a scan from the history', () {
    Future<void> pump(WidgetTester tester, ScreeningSession session) async {
      tester.view.physicalSize = const Size(390, 844) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          screeningRepositoryProvider.overrideWithValue(_Repo([session])),
        ],
        child: MaterialApp(home: ScreeningDetailScreen(sessionId: session.id)),
      ));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('shows the same report as right after the scan', (tester) async {
      await pump(
        tester,
        _session(
          'a',
          DateTime(2026, 11, 2),
          _analysis(findings: [_sign('left')], recs: [_rec('soon')]),
        ),
      );
      expect(find.text('Book a dental visit soon'), findsOneWidget);
      expect(find.byType(Mouth3D), findsOneWidget);
      expect(find.text('Delete this screening'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('with no analysis it keeps to what was recorded', (tester) async {
      await pump(tester, _session('a', DateTime(2026, 11, 2), null));
      expect(find.byType(Mouth3D), findsNothing);
      expect(find.textContaining('No analysis was run'), findsOneWidget);
    });

    testWidgets('a service with no model behind it shows no result', (tester) async {
      await pump(
        tester,
        _session('a', DateTime(2026, 11, 2), _analysis(model: 'det-none+x')),
      );
      expect(find.byType(Mouth3D), findsNothing);
      expect(find.text('Nothing flagged in your photos'), findsNothing);
    });
  });
}
