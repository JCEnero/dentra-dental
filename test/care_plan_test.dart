import 'package:dentra_mobile/features/dental_profile/data/models/dental_answers.dart';
import 'package:dentra_mobile/features/dental_records/data/models/dental_record.dart';
import 'package:dentra_mobile/features/scan/data/care_plan.dart';
import 'package:dentra_mobile/features/scan/data/check_in_plan.dart';
import 'package:dentra_mobile/features/scan/data/patient_context.dart';
import 'package:dentra_mobile/features/scan/data/scan_outcomes.dart';
import 'package:dentra_mobile/features/scan/data/scan_report.dart';
import 'package:dentra_mobile/features/screening/data/models/scan_check_in.dart';
import 'package:dentra_mobile/features/screening/data/models/screening_session.dart';
import 'package:flutter_test/flutter_test.dart';

final at = DateTime(2026, 11, 3, 9);

const views = ['front', 'upper-occlusal', 'lower-occlusal', 'left', 'right'];

/// A sign on a lower back tooth, in the lower arch photo.
ScreeningFinding lowerBack({double confidence = 0.7}) => ScreeningFinding(
      label: 'Possible tooth decay',
      regionId: 'lower-occlusal',
      confidence: confidence,
      bbox: const [0.05, 0.4, 0.12, 0.12],
    );

ScreeningReport report({
  List<ScreeningFinding> findings = const [],
  List<ScreeningFinding> faint = const [],
  List<ScreeningRecommendation> recs = const [],
  List<String> photos = views,
}) =>
    ScreeningReport(
      ScreeningAnalysis(
        summary: 'Summary',
        analyzedAt: at,
        findings: findings,
        faintFindings: faint,
        recommendations: recs,
        model: 'det-test+rules',
      ),
      photos,
    );

const routineRec = ScreeningRecommendation(
  code: 'enamel_lesion_check',
  title: 'Possible tooth decay: ask your dentist at your next visit',
  detail: 'It is not urgent.',
  urgency: 'routine',
);

ScanTrend noHistory() => ScanTrend.of(const []);

CarePlan plan(
  ScreeningReport r, {
  ScanCheckIn? checkIn,
  ScreeningReportedContext? profile,
  List<DentalRecord> records = const [],
  ScanTrend? trend,
  bool followUp = false,
}) =>
    CarePlan.of(
      r,
      PatientContext(
        at: at,
        checkIn: checkIn,
        profile: profile,
        records: records,
        followUpScan: followUp,
      ),
      trend ?? noHistory(),
    );

ScreeningReportedContext profile({
  Set<CurrentConcern> concerns = const {CurrentConcern.none},
  DiscomfortLevel? discomfort,
  ConcernDuration? duration,
  DateTime? answeredAt,
  LastCheckup? lastCheckup,
  LastCleaning? lastCleaning,
  BrushingHabit? brushing,
  BetweenTeethHabit? betweenTeeth,
  Set<HealthFactor> factors = const {},
}) =>
    ScreeningReportedContext(
      profileVersion: 1,
      recordedAt: at,
      currentConcerns: concerns,
      discomfortLevel: discomfort,
      concernDuration: duration,
      answeredAt: answeredAt,
      lastCheckup: lastCheckup,
      lastCleaning: lastCleaning,
      brushing: brushing,
      betweenTeeth: betweenTeeth,
      healthFactors: factors,
    );

DentalRecord record({
  RecordSource source = RecordSource.clinicRecord,
  DateTime? date,
  String? procedure,
  String? title,
  List<String> teeth = const [],
  DateTime? followUp,
  String? notes,
}) {
  final d = date ?? DateTime(2026, 3, 12);
  return DentalRecord(
    id: 'r${d.millisecondsSinceEpoch}${teeth.join()}',
    source: source,
    recordDate: d,
    createdAt: d,
    updatedAt: d,
    procedure: procedure,
    title: title,
    toothNumbers: teeth,
    followUpDate: followUp,
    notes: notes,
  );
}

const pain = ScanCheckIn(
  symptoms: {CurrentConcern.toothPain},
  symptomArea: AreaAnswer.lowerRight,
);

ScreeningSession session(
  String id,
  DateTime when, {
  List<ScreeningFinding> findings = const [],
  ScanCheckIn? checkIn,
  String model = 'det-test+rules',
}) =>
    ScreeningSession(
      id: id,
      completedAt: when,
      capturedRegions: views,
      totalRegions: 9,
      checkIn: checkIn,
      analysis: ScreeningAnalysis(
        summary: 'Summary',
        analyzedAt: when,
        findings: findings,
        model: model,
      ),
    );

void main() {
  group('symptoms stay apart from findings', () {
    test('a reported symptom never becomes a sign', () {
      final r = report();
      final p = plan(r, checkIn: pain);
      expect(r.signCount, 0);
      expect(r.spots, isEmpty);
      expect(p.report.spots, isEmpty);
    });

    test('advice from a symptom says it came from the user', () {
      final p = plan(
        report(),
        checkIn: pain.copyWith(started: ConcernDuration.fewDays),
      );
      expect(p.steps.first.sources, {CareSource.you});
      expect(p.drivenByContext, isTrue);
      expect(p.because, contains('you told us'));
      for (final s in p.steps) {
        expect(s.detail, isNot(contains('detected')));
        expect(s.detail, isNot(contains('the check found')));
      }
    });

    test('a finding with no symptoms comes from the check alone', () {
      final p = plan(report(findings: [lowerBack()], recs: const [routineRec]));
      expect(p.steps.single.sources, {CareSource.check});
      expect(p.drivenByContext, isFalse);
      expect(p.links, isEmpty);
    });
  });

  group('pain with nothing marked', () {
    test('is not dismissed', () {
      final p = plan(report(), checkIn: pain);
      expect(p.level.index, greaterThan(CareLevel.routine.index));
      final link =
          p.links.singleWhere((l) => l.title == 'Nothing marked there');
      expect(link.text, contains("can't rule out"));
      expect(link.text, contains('still counts'));
    });

    test('with no area named is not dismissed either', () {
      final p = plan(
        report(),
        checkIn: const ScanCheckIn(symptoms: {CurrentConcern.toothPain}),
      );
      expect(p.links.single.text, contains("can't rule out"));
    });

    test('lasting more than two days means seeing a dentist', () {
      final p = plan(
        report(),
        checkIn: pain.copyWith(started: ConcernDuration.fewDays),
      );
      expect(p.level, CareLevel.soon);
      expect(p.steps.first.detail, contains('more than 2 days'));
    });

    test('that started today says when to go', () {
      final p = plan(
        report(),
        checkIn: pain.copyWith(started: ConcernDuration.today),
      );
      expect(p.level, CareLevel.nextVisit);
      expect(p.steps.first.detail, contains('more than 2 days'));
    });

    test('in an area the scan could not read says so', () {
      final p = plan(
        report(photos: const ['front']),
        checkIn: const ScanCheckIn(
          symptoms: {CurrentConcern.toothPain},
          symptomArea: AreaAnswer.lowerRight,
        ),
      );
      expect(
        p.links.single.title,
        'Not in this scan',
      );
    });
  });

  group('how soon', () {
    test('worsening means promptly, whatever the scan shows', () {
      final p = plan(
        report(),
        checkIn: pain.copyWith(pattern: SymptomPattern.worsening),
      );
      expect(p.level, CareLevel.prompt);
    });

    test('severe discomfort means promptly', () {
      final p = plan(
        report(),
        checkIn: pain.copyWith(severity: DiscomfortLevel.severe),
      );
      expect(p.level, CareLevel.prompt);
    });

    test('trouble breathing or swelling by the eye means emergency care', () {
      for (final sign in [
        WarningSign.hardToBreathe,
        WarningSign.eyeOrNeckSwelling,
        WarningSign.hardToOpenMouth,
      ]) {
        final p = plan(
          report(),
          checkIn: const ScanCheckIn(
            symptoms: {CurrentConcern.swollenGums},
          ).copyWith(warningSigns: {sign}),
        );
        expect(p.level, CareLevel.emergency, reason: sign.id);
        expect(p.isEmergency, isTrue);
        expect(p.title, 'Get emergency care now');
        expect(p.steps.first.detail, contains('emergency'));
        expect(p.because, contains('not because of your photos'));
      }
    });

    test('a swollen cheek or a fever means an urgent appointment', () {
      final p = plan(
        report(),
        checkIn: const ScanCheckIn(
          symptoms: {CurrentConcern.swollenGums},
          warningSigns: {WarningSign.cheekOrJawSwelling},
        ),
      );
      expect(p.level, CareLevel.prompt);
      expect(p.steps.first.title, contains('urgent'));
    });

    test('bleeding gums are never answered by the check', () {
      final p = plan(
        report(),
        checkIn: const ScanCheckIn(symptoms: {CurrentConcern.bleedingGums}),
      );
      expect(p.level, CareLevel.nextVisit);
      expect(p.links.single.title, "Gums aren't read");
    });

    test('bleeding that keeps going means soon', () {
      final p = plan(
        report(),
        checkIn: const ScanCheckIn(
          symptoms: {CurrentConcern.bleedingGums},
          pattern: SymptomPattern.persistent,
        ),
      );
      expect(p.level, CareLevel.soon);
    });

    test('a clear result with nothing reported gives no false comfort', () {
      final p = plan(report());
      expect(p.level, CareLevel.routine);
      expect(p.title, 'Keep your regular check-ups');
      expect(p.because, contains('photos can miss things'));
    });

    test('the most pressing step sets the level', () {
      final p = plan(
        report(findings: [lowerBack()], recs: const [routineRec]),
        checkIn: const ScanCheckIn(
          symptoms: {CurrentConcern.sensitivity},
          severity: DiscomfortLevel.severe,
        ),
      );
      expect(p.level, CareLevel.prompt);
      expect(p.steps.first.level.index,
          greaterThanOrEqualTo(p.steps.last.level.index));
    });
  });

  group('a symptom and a mark in the same area', () {
    test('is a reason to get it looked at, never a confirmed problem', () {
      final p = plan(report(findings: [lowerBack()]), checkIn: pain);
      expect(p.level, CareLevel.soon);
      final link = p.links.singleWhere((l) => l.title == 'Same general area');
      expect(link.sources, {CareSource.check, CareSource.you});
      expect(link.text, contains("can't tell if it's the same tooth"));
      expect(link.text, isNot(contains('cavity')));
    });

    test('with a strong sign and lasting pain means promptly', () {
      final p = plan(
        report(findings: [lowerBack(confidence: 0.93)]),
        checkIn: pain.copyWith(started: ConcernDuration.fewWeeks),
      );
      expect(p.level, CareLevel.prompt);
    });

    test('a tooth number finds its area', () {
      final p = plan(
        report(findings: [lowerBack()]),
        checkIn: const ScanCheckIn(
          symptoms: {CurrentConcern.toothPain},
          symptomTeeth: ['46'],
        ),
      );
      final link = p.links.singleWhere((l) => l.title == 'Same general area');
      expect(link.text, contains('tooth 46, lower right back'));
    });

    test('in a different area is not called a match', () {
      final p = plan(
        report(findings: [lowerBack()]),
        checkIn: const ScanCheckIn(
          symptoms: {CurrentConcern.toothPain},
          symptomArea: AreaAnswer.upperFront,
        ),
      );
      expect(p.links.map((l) => l.title), isNot(contains('Same general area')));
    });
  });

  group('recent treatment', () {
    test('explains a mark, without saying that is what it is', () {
      final p = plan(
        report(findings: [lowerBack()]),
        checkIn: const ScanCheckIn(
          treatments: {RecentTreatment.filling},
          treatmentTeeth: ['46'],
          treatmentWhen: TreatmentWhen.pastMonth,
        ),
      );
      final link = p.links.singleWhere((l) => l.title == 'Recent treatment');
      expect(link.text, contains('can look like a mark'));
      expect(link.text, contains('tooth 46'));
      expect(p.questions.first, contains('recent dental work'));
    });

    test('elsewhere in the mouth is left out', () {
      final p = plan(
        report(findings: [lowerBack()]),
        checkIn: const ScanCheckIn(
          treatments: {RecentTreatment.filling},
          treatmentTeeth: ['11'],
          treatmentWhen: TreatmentWhen.pastMonth,
        ),
      );
      expect(p.links, isEmpty);
    });

    test('with pain sends them back to the clinic', () {
      final p = plan(
        report(),
        checkIn: pain.copyWith(
          treatments: {RecentTreatment.extraction},
          treatmentWhen: TreatmentWhen.pastWeek,
        ),
      );
      expect(p.steps.map((s) => s.title),
          contains('Tell the clinic that treated you'));
    });

    test('a long time ago makes no claim', () {
      final p = plan(
        report(findings: [lowerBack()]),
        checkIn: const ScanCheckIn(
          treatments: {RecentTreatment.filling},
          treatmentWhen: TreatmentWhen.longer,
        ),
      );
      expect(p.links, isEmpty);
    });
  });

  group('old answers', () {
    test('count as current when recent', () {
      final p = plan(
        report(),
        profile: profile(
          concerns: {CurrentConcern.toothPain},
          discomfort: DiscomfortLevel.severe,
          answeredAt: at.subtract(const Duration(days: 3)),
        ),
      );
      expect(p.level, CareLevel.prompt);
    });

    test('are asked about, not assumed, when months old', () {
      final p = plan(
        report(),
        profile: profile(
          concerns: {CurrentConcern.toothPain},
          discomfort: DiscomfortLevel.severe,
          answeredAt: at.subtract(const Duration(days: 120)),
        ),
      );
      expect(p.level, CareLevel.soon);
      expect(p.steps.first.detail, contains("If it's still there"));
    });

    test('are replaced by saying nothing is wrong today', () {
      final p = plan(
        report(),
        checkIn: const ScanCheckIn(symptoms: {CurrentConcern.none}),
        profile: profile(
          concerns: {CurrentConcern.toothPain},
          discomfort: DiscomfortLevel.severe,
          answeredAt: at.subtract(const Duration(days: 2)),
        ),
      );
      expect(p.level, CareLevel.routine);
    });

    test('are kept when the check-in was skipped', () {
      final p = plan(
        report(),
        checkIn: const ScanCheckIn(focusArea: AreaAnswer.upperFront),
        profile: profile(
          concerns: {CurrentConcern.toothPain},
          discomfort: DiscomfortLevel.severe,
          answeredAt: at.subtract(const Duration(days: 2)),
        ),
      );
      expect(p.level, CareLevel.prompt);
    });
  });

  group('records', () {
    test('only those known by the scan count', () {
      final c = PatientContext(
        at: at,
        records: [
          record(date: DateTime(2026, 11, 3)),
          record(date: DateTime(2026, 11, 4)),
          record(date: DateTime(2026, 10, 1)),
        ],
      );
      expect(c.records.map((r) => r.date), [
        DateTime(2026, 11, 3),
        DateTime(2026, 10, 1),
      ]);
    });

    test('a clinic record in a marked area stays hedged', () {
      final p = plan(
        report(findings: [lowerBack()]),
        records: [
          record(procedure: 'Composite filling', teeth: const ['46']),
        ],
      );
      final link =
          p.links.singleWhere((l) => l.title == 'In your clinic record');
      expect(link.sources, {CareSource.check, CareSource.records});
      expect(link.text, contains('Mar 12, 2026'));
      expect(link.text, contains('Composite filling'));
      expect(link.text, contains('tooth 46'));
      expect(link.text, contains("can't tell if it's the same tooth"));
      expect(link.text, contains('can look like a mark'));
    });

    test('a note or photo proves nothing and raises nothing', () {
      final base =
          plan(report(findings: [lowerBack()], recs: const [routineRec]));
      final withNote = plan(
        report(findings: [lowerBack()], recs: const [routineRec]),
        records: [
          record(
            source: RecordSource.personalNote,
            notes: 'I think I have a cavity on 46',
            teeth: const ['46'],
          ),
        ],
      );
      expect(withNote.level, base.level);
      final link = withNote.links.single;
      expect(link.title, 'In your own note');
      expect(link.text, isNot(contains('cavity')));
    });

    test('a note with no tooth or elsewhere is not linked', () {
      final p = plan(
        report(findings: [lowerBack()]),
        records: [
          record(source: RecordSource.personalPhoto, teeth: const ['11']),
          record(source: RecordSource.personalNote, notes: 'Sore'),
        ],
      );
      expect(p.links, isEmpty);
    });

    test('nothing is called recurring from one entry', () {
      final one = plan(
        report(),
        records: [
          record(procedure: 'Filling', teeth: const ['26'])
        ],
      );
      expect(one.links, isEmpty);

      final two = plan(
        report(),
        records: [
          record(procedure: 'Filling', teeth: const ['26']),
          record(
            date: DateTime(2026, 6, 2),
            procedure: 'Review',
            teeth: const ['26'],
          ),
        ],
      );
      expect(two.links.single.title, 'Comes up more than once');
      expect(two.links.single.text, contains('tooth 26 on 2 dates'));
      expect(two.links.single.text, contains('Jun 2, 2026'));
    });

    test('two entries on the same day are not a pattern', () {
      final p = plan(
        report(),
        records: [
          record(procedure: 'Filling', teeth: const ['26']),
          record(procedure: 'X-ray', teeth: const ['26']),
        ],
      );
      expect(p.links, isEmpty);
    });

    test('a missed follow-up says only what the records show', () {
      final p = plan(
        report(),
        records: [
          record(procedure: 'Filling', followUp: DateTime(2026, 6, 1)),
        ],
      );
      final step = p.steps.single;
      expect(step.sources, {CareSource.records});
      expect(step.level, CareLevel.nextVisit);
      expect(step.detail, contains("don't show a visit since"));
    });

    test('a later visit answers the follow-up', () {
      final p = plan(
        report(),
        records: [
          record(procedure: 'Filling', followUp: DateTime(2026, 6, 1)),
          record(date: DateTime(2026, 6, 3), procedure: 'Review'),
        ],
      );
      expect(p.steps, isEmpty);
    });

    test('an upcoming follow-up is a place to raise it', () {
      final p = plan(
        report(),
        records: [
          record(
            date: DateTime(2026, 10, 1),
            procedure: 'Filling',
            followUp: DateTime(2026, 11, 20),
          ),
        ],
      );
      expect(p.steps.single.title, 'Raise this at your follow-up');
      expect(p.level, CareLevel.routine);
    });
  });

  group('visits', () {
    test('an overdue check-up is advised from what they said', () {
      final p = plan(
        report(),
        profile: profile(lastCheckup: LastCheckup.overAYear),
      );
      expect(p.level, CareLevel.nextVisit);
      expect(p.title, 'Book a check-up');
      expect(p.steps.single.sources, {CareSource.you});
    });

    test('a recent visit on record answers it', () {
      final p = plan(
        report(),
        profile: profile(lastCheckup: LastCheckup.overAYear),
        records: [record(date: DateTime(2026, 9, 1), procedure: 'Check-up')],
      );
      expect(p.steps, isEmpty);
    });

    test('a check-in overrides the profile', () {
      final p = plan(
        report(),
        profile: profile(lastCheckup: LastCheckup.overAYear),
        checkIn: const ScanCheckIn(lastCheckup: LastCheckup.within6Months),
      );
      expect(p.steps, isEmpty);
    });

    test('a cleaning long ago points at what the check cannot read', () {
      final p = plan(
        report(),
        profile: profile(lastCleaning: LastCleaning.overAYear),
      );
      expect(p.steps.single.title, 'Ask about a cleaning');
      expect(p.steps.single.detail, contains('plaque'));
      expect(p.level, CareLevel.routine);
    });
  });

  group('across scans', () {
    final sign = lowerBack();

    test('an area that keeps being marked is worth asking about', () {
      final trend = ScanTrend.of([
        session('3', at, findings: [sign]),
        session('2', at.subtract(const Duration(days: 30)), findings: [sign]),
        session('1', at.subtract(const Duration(days: 60)), findings: [sign]),
      ], currentId: '3');
      final p = plan(report(findings: [sign]), trend: trend);
      expect(p.level, CareLevel.soon);
      expect(p.steps.single.detail, contains('3 scans'));
      expect(p.steps.single.detail, contains("doesn't show whether"));
      expect(p.steps.single.detail, isNot(contains('worse')));
    });

    test('scans from different model versions are not compared', () {
      final trend = ScanTrend.of([
        session('3', at, findings: [sign], model: 'det-b+rules'),
        session('2', at.subtract(const Duration(days: 30)), findings: [sign]),
        session('1', at.subtract(const Duration(days: 60)), findings: [sign]),
      ], currentId: '3');
      final p = plan(report(findings: [sign]), trend: trend);
      expect(p.steps, isEmpty);
    });

    test('two scans in a row are not called a pattern yet', () {
      final trend = ScanTrend.of([
        session('2', at, findings: [sign]),
        session('1', at.subtract(const Duration(days: 30)), findings: [sign]),
      ], currentId: '2');
      final p = plan(report(findings: [sign]), trend: trend);
      expect(p.steps, isEmpty);
    });
  });

  group('what they asked to have noted', () {
    test('reports only what was read', () {
      String text(ScreeningReport r) => plan(
            r,
            checkIn: const ScanCheckIn(focusArea: AreaAnswer.lowerRight),
          ).links.single.text;
      expect(
        text(report(findings: [lowerBack()])),
        contains('marked something'),
      );
      expect(text(report()), contains('marked nothing'));
      expect(
        text(report(photos: const ['front'])),
        contains('no photo of that area'),
      );
    });
  });

  group('questions and daily care', () {
    test('fit what was reported', () {
      final p = plan(report(), checkIn: pain);
      expect(p.questions.first, contains('X-ray'));
      expect(p.questions.length, lessThanOrEqualTo(3));
    });

    test('habits change the advice only when answered', () {
      final none = plan(report());
      expect(none.dailyCare, contains('Clean between your teeth once a day.'));

      final p = plan(
        report(),
        profile: profile(
          brushing: BrushingHabit.once,
          betweenTeeth: BetweenTeethHabit.rarely,
          factors: {HealthFactor.dryMouth},
        ),
      );
      expect(p.dailyCare.join(), contains('You told us you brush once a day'));
      expect(p.dailyCare.join(), contains("can't read there"));
      expect(p.dailyCare.join(), contains('Dry mouth'));
    });
  });

  group('what they told us', () {
    test('lists real answers only', () {
      final c = PatientContext(
        at: at,
        checkIn: pain.copyWith(
          started: ConcernDuration.fewDays,
          pattern: SymptomPattern.worsening,
          severity: DiscomfortLevel.moderate,
          symptomTeeth: ['46'],
        ),
        profile: profile(lastCheckup: LastCheckup.within6Months),
      );
      final facts = {for (final f in c.symptomFacts) f.label: f.value};
      expect(facts['Today'], 'Tooth pain, moderate');
      expect(facts['Where'], 'Tooth 46, lower right back');
      expect(facts['Timing'], 'Started a few days ago, getting worse');
      expect(c.backgroundFacts.single.label, 'Last check-up');
    });

    test('an empty context stays empty', () {
      final c = PatientContext(at: at);
      expect(c.isEmpty, isTrue);
      expect(c.symptoms, isNull);
      expect(c.reportedLines, isEmpty);
    });

    test('procedures are read from the user\'s own words', () {
      expect(procedureKindOf('Composite filling'), ProcedureKind.filling);
      expect(procedureKindOf('Tooth extraction'), ProcedureKind.extraction);
      expect(procedureKindOf('Root canal treatment'), ProcedureKind.rootCanal);
      expect(procedureKindOf('Scaling and polish'), ProcedureKind.cleaning);
      expect(procedureKindOf('Consultation'), isNull);
      expect(procedureKindOf(null), isNull);
    });

    test('teeth map to the general areas', () {
      expect(MouthArea.ofTeeth(['46']), {MouthArea.lowerRight});
      expect(MouthArea.ofTeeth(['26', '11']),
          {MouthArea.upperLeft, MouthArea.upperFront});
      expect(MouthArea.ofTeeth(['99', 'x']), isEmpty);
    });
  });

  group('the check-in itself', () {
    test('drops follow-ups when their answer goes away', () {
      final c = pain.copyWith(
        symptoms: {CurrentConcern.none},
        severity: DiscomfortLevel.severe,
        started: ConcernDuration.today,
      ).normalized();
      expect(c.symptomArea, isNull);
      expect(c.severity, isNull);
      expect(c.started, isNull);
    });

    test('only asks warning signs when they could apply', () {
      expect(pain.asksWarningSigns, isFalse);
      expect(
        pain.copyWith(pattern: SymptomPattern.worsening).asksWarningSigns,
        isTrue,
      );
      expect(
        pain.copyWith(severity: DiscomfortLevel.severe).asksWarningSigns,
        isTrue,
      );
      expect(
        const ScanCheckIn(symptoms: {CurrentConcern.swollenGums})
            .asksWarningSigns,
        isTrue,
      );
    });

    test('nothing answered is nothing to store', () {
      expect(const ScanCheckIn().isEmpty, isTrue);
      expect(
        const ScanCheckIn(symptoms: {CurrentConcern.none}).isEmpty,
        isFalse,
      );
    });

    test('survives the trip to the API and back', () {
      const c = ScanCheckIn(
        symptoms: {CurrentConcern.toothPain, CurrentConcern.bleedingGums},
        symptomArea: AreaAnswer.notSure,
        symptomTeeth: ['46'],
        started: ConcernDuration.fewWeeks,
        pattern: SymptomPattern.persistent,
        severity: DiscomfortLevel.mild,
        lastCheckup: LastCheckup.overAYear,
        lastCleaning: LastCleaning.never,
        treatments: {RecentTreatment.filling},
        treatmentTeeth: ['36'],
        treatmentWhen: TreatmentWhen.past3Months,
        focusArea: AreaAnswer.upperFront,
        focusTeeth: ['11'],
      );
      final back = ScanCheckIn.fromJson(c.toJson());
      expect(back.toJson(), c.toJson());
      expect(c.toJson()['source'], 'user_reported');
      expect(c.toJson()['symptom_area'], 'not_sure');
      expect(back.symptomArea?.area, isNull);
    });

    test('is kept with the session, apart from its analysis', () {
      final s = session('1', at, checkIn: pain);
      final back = ScreeningSession.fromJson(s.toJson());
      expect(back.checkIn?.symptoms, {CurrentConcern.toothPain});
      expect(back.analysis?.findings, isEmpty);
    });
  });

  group('which questions are asked', () {
    DentalProfile answered(
      DateTime when, {
      Set<CurrentConcern> concerns = const {CurrentConcern.none},
      LastCheckup checkup = LastCheckup.within6Months,
      LastCleaning? cleaning,
      Set<ScreeningGoal> goals = const {ScreeningGoal.decay},
    }) =>
        DentalProfile(
          version: 1,
          completedAt: when,
          answers: DentalAnswers(
            lastCheckup: checkup,
            currentConcerns: concerns,
            lastCleaning: cleaning,
            screeningGoals: goals,
          ),
        );

    test('right after onboarding with nothing wrong, not symptoms again', () {
      final p = CheckInPlan.of(
        now: at,
        profile: answered(at.subtract(const Duration(hours: 1))),
      );
      expect(p.asksSymptoms, isFalse);
      expect(p.asksCheckup, isFalse);
      expect(p.asksFocus, isFalse);
    });

    test('right after onboarding with a concern, starts from the answer', () {
      final p = CheckInPlan.of(
        now: at,
        profile: answered(
          at.subtract(const Duration(hours: 1)),
          concerns: {CurrentConcern.toothPain},
        ),
      );
      expect(p.asksSymptoms, isTrue);
      expect(p.prefill.symptoms, {CurrentConcern.toothPain});
    });

    test('months later, asks again', () {
      final p = CheckInPlan.of(
        now: at,
        profile: answered(at.subtract(const Duration(days: 200))),
      );
      expect(p.asksSymptoms, isTrue);
      expect(p.asksCheckup, isTrue);
    });

    test('with no profile at all, asks the basics', () {
      final p = CheckInPlan.of(now: at);
      expect(p.asksSymptoms, isTrue);
      expect(p.asksTreatment, isTrue);
      expect(p.asksCheckup, isTrue);
      expect(p.asksCleaning, isTrue);
      expect(p.asksFocus, isFalse);
      expect(p.lastScanAt, isNull);
    });

    test('a first scan skips treatment after no recent visit', () {
      final p = CheckInPlan.of(
        now: at,
        profile: answered(
          at.subtract(const Duration(days: 2)),
          checkup: LastCheckup.never,
        ),
      );
      expect(p.asksTreatment, isFalse);
    });

    test('a follow-up asks what changed since then', () {
      final last = at.subtract(const Duration(days: 30));
      final p = CheckInPlan.of(
        now: at,
        profile: answered(at.subtract(const Duration(days: 40))),
        sessions: [session('1', last)],
      );
      expect(p.lastScanAt, last);
      expect(p.asksTreatment, isTrue);
      expect(p.asksFocus, isTrue);
    });

    test('a visit on record since the last scan is not asked about', () {
      final p = CheckInPlan.of(
        now: at,
        sessions: [session('1', DateTime(2026, 10, 1))],
        records: [record(date: DateTime(2026, 10, 20), procedure: 'Filling')],
      );
      expect(p.asksTreatment, isFalse);
      expect(p.asksCheckup, isFalse);
    });

    test('scanning again today does not ask again', () {
      final p = CheckInPlan.of(
        now: at,
        sessions: [
          session(
            '1',
            at.subtract(const Duration(hours: 2)),
            checkIn: const ScanCheckIn(symptoms: {CurrentConcern.none}),
          ),
        ],
      );
      expect(p.asksSymptoms, isFalse);
      expect(p.asksTreatment, isFalse);
    });

    test('scanning again today starts from what they said', () {
      final p = CheckInPlan.of(
        now: at,
        sessions: [
          session('1', at.subtract(const Duration(hours: 2)), checkIn: pain)
        ],
      );
      expect(p.asksSymptoms, isTrue);
      expect(p.prefill.symptomArea, AreaAnswer.lowerRight);
    });

    test('a cleaning on record answers the cleaning question', () {
      final p = CheckInPlan.of(
        now: at,
        records: [record(date: DateTime(2026, 9, 1), procedure: 'Scaling')],
      );
      expect(p.asksCleaning, isFalse);
    });

    test('a skipped question waits before it is asked again', () {
      final p = CheckInPlan.of(
        now: at,
        sessions: [
          session(
            '1',
            at.subtract(const Duration(days: 5)),
            checkIn: const ScanCheckIn(symptoms: {CurrentConcern.none}),
          ),
        ],
      );
      expect(p.asksCheckup, isFalse);
      expect(p.asksCleaning, isFalse);
    });

    test('someone with a specific concern can note it on a first scan', () {
      final p = CheckInPlan.of(
        now: at,
        profile: answered(
          at.subtract(const Duration(days: 1)),
          goals: {ScreeningGoal.specificConcern},
        ),
      );
      expect(p.asksFocus, isTrue);
    });

    test('with everything known and nothing wrong, the sheet stays away', () {
      final p = CheckInPlan.of(
        now: at,
        profile: answered(
          at.subtract(const Duration(hours: 1)),
          checkup: LastCheckup.never,
          cleaning: LastCleaning.never,
        ),
      );
      expect(p.isEmpty, isTrue);
    });
  });
}
