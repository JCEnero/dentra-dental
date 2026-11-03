/// What's known about someone besides their photos, gathered for one scan.
///
/// Three kinds of information meet here and never merge: what they told us, what
/// they keep in their records, and (in [ScreeningReport]) what the check saw.
/// None of this is sent to the image model and none of it changes a finding: it
/// only shapes how a result is explained and what to do next. A note or a photo
/// is the user's own, and is never taken as proof of a condition. No widgets, so
/// it can be tested on its own.
library;

import '../../../core/utils/dentra_dates.dart';
import '../../dental_profile/data/models/dental_answers.dart';
import '../../dental_records/data/models/dental_record.dart';
import '../../screening/data/models/scan_check_in.dart';
import '../../screening/data/models/screening_session.dart';
import 'scan_outcomes.dart';

/// A list in words: "a, b and c".
String wordList(List<String> items) => switch (items) {
      [] => '',
      [final one] => one,
      [...final rest, final last] => '${rest.join(', ')} and $last',
    };

/// "Tooth 26" or "Teeth 26 and 36".
String teethInWords(List<String> teeth, {bool capital = false}) {
  final word = teeth.length == 1 ? 'tooth' : 'teeth';
  return '${capital ? '${word[0].toUpperCase()}${word.substring(1)}' : word} '
      '${wordList(teeth)}';
}

String _concernInWords(CurrentConcern c) => switch (c) {
      CurrentConcern.toothPain => 'tooth pain',
      CurrentConcern.sensitivity => 'tooth sensitivity',
      CurrentConcern.bleedingGums => 'bleeding gums',
      CurrentConcern.swollenGums => 'swollen gums',
      CurrentConcern.discoloration => 'spots or discoloration',
      CurrentConcern.brokenTooth => 'a chipped or broken tooth',
      _ => 'a concern',
    };

/// What a clinic record's free-text procedure seems to be. Only used to phrase
/// advice, and always shown next to the user's own words.
enum ProcedureKind { filling, extraction, rootCanal, crown, cleaning }

ProcedureKind? procedureKindOf(String? procedure) {
  final p = procedure?.toLowerCase();
  if (p == null) return null;
  bool has(List<String> words) => words.any(p.contains);
  if (has(['root canal', 'endodon'])) return ProcedureKind.rootCanal;
  if (has(['extract', 'tooth removal', 'removed', 'pulled'])) {
    return ProcedureKind.extraction;
  }
  if (has(['fill', 'restoration', 'composite', 'amalgam'])) {
    return ProcedureKind.filling;
  }
  if (has(['crown', 'bridge'])) return ProcedureKind.crown;
  if (has(['clean', 'scaling', 'prophy', 'polish'])) {
    return ProcedureKind.cleaning;
  }
  return null;
}

/// A symptom someone says they have now.
class ReportedSymptoms {
  const ReportedSymptoms({
    required this.concerns,
    required this.fromCheckIn,
    required this.old,
    this.answeredOn,
    this.severity,
    this.started,
    this.pattern,
    this.area,
    this.teeth = const [],
    this.warnings = const {},
  });

  final Set<CurrentConcern> concerns;

  /// Answered just before this scan, rather than in their dental profile.
  final bool fromCheckIn;

  /// Answered too long before this scan to take for granted that it's current.
  final bool old;
  final DateTime? answeredOn;
  final DiscomfortLevel? severity;
  final ConcernDuration? started;
  final SymptomPattern? pattern;
  final MouthArea? area;
  final List<String> teeth;
  final Set<WarningSign> warnings;

  /// Where they said it is, if they did.
  Set<MouthArea> get areas =>
      {if (area case final a?) a, ...MouthArea.ofTeeth(teeth)};

  static const _gums = {
    CurrentConcern.bleedingGums,
    CurrentConcern.swollenGums
  };

  bool get aboutGums => concerns.any(_gums.contains);

  /// Something a tooth photo could say anything about.
  bool get aboutTeeth => concerns.any((c) => !_gums.contains(c));

  Set<CurrentConcern> get toothConcerns =>
      concerns.where((c) => !_gums.contains(c)).toSet();

  Set<CurrentConcern> get gumConcerns => concerns.where(_gums.contains).toSet();

  /// "tooth pain and bleeding gums".
  String get what => wordList([for (final c in concerns) _concernInWords(c)]);

  String get toothWords =>
      wordList([for (final c in toothConcerns) _concernInWords(c)]);

  String get gumWords =>
      wordList([for (final c in gumConcerns) _concernInWords(c)]);

  /// "tooth 46, lower right back", or null when they didn't say.
  String? get where {
    if (teeth.isNotEmpty) {
      final named = areas;
      return named.length == 1
          ? '${teethInWords(teeth)}, ${named.single.label.toLowerCase()}'
          : teethInWords(teeth);
    }
    return area?.label.toLowerCase();
  }

  /// Has gone on for more than a couple of days.
  bool get lasted =>
      started == ConcernDuration.fewDays ||
      started == ConcernDuration.fewWeeks ||
      started == ConcernDuration.monthOrLonger;

  bool get keepsGoing => lasted || pattern == SymptomPattern.persistent;

  bool get worsening => pattern == SymptomPattern.worsening;
}

/// Dental treatment someone mentioned before a scan.
class ReportedTreatment {
  const ReportedTreatment({
    required this.treatments,
    this.teeth = const [],
    this.when,
    this.sinceLastScan = false,
  });

  final Set<RecentTreatment> treatments;
  final List<String> teeth;
  final TreatmentWhen? when;

  /// Asked as "since your last scan", so it's recent even with no [when].
  final bool sinceLastScan;

  Set<MouthArea> get areas => MouthArea.ofTeeth(teeth);

  bool get recent => (when?.recent ?? false) || sinceLastScan;

  bool get changesTheLook => treatments.any((t) => t.changesTheLook);

  /// "a filling".
  String get what => wordList([for (final t in treatments) t.inWords]);

  /// "in the past month", or empty.
  String get whenWords => when?.inWords ?? '';
}

/// One label and answer, as the results and the PDF list them.
class ContextFact {
  const ContextFact(this.label, this.value);

  final String label;
  final String value;
}

/// One record from someone's dental history, seen from this scan.
class ContextRecord {
  ContextRecord(this.record)
      : areas = MouthArea.ofTeeth(record.toothNumbers),
        kind = procedureKindOf(record.procedure);

  final DentalRecord record;
  final Set<MouthArea> areas;
  final ProcedureKind? kind;

  RecordSource get source => record.source;
  DateTime get date => record.recordDate;
  List<String> get teeth => record.toothNumbers;

  /// "Mar 12, 2026", or "Date unknown" for a photo with no known date.
  String get dateLabel =>
      record.dateUnknown ? 'Date unknown' : DentraDates.medium(date);

  /// What it's about, in the user's own words.
  String get title => record.displayTitle;
}

class PatientContext {
  PatientContext({
    required this.at,
    this.profile,
    this.checkIn,
    List<DentalRecord> records = const [],
    this.recordsUnavailable = false,
    this.followUpScan = false,
  }) : records = List.unmodifiable([
          // Only what was known by then, so an old report keeps reading the same.
          for (final r in records)
            if (!r.recordDate.isAfter(DentraDates.dateOnly(at)))
              ContextRecord(r),
        ]..sort((a, b) => b.date.compareTo(a.date)));

  /// When the scan was taken.
  final DateTime at;

  /// The dental profile as it stood at this scan.
  final ScreeningReportedContext? profile;

  /// What they said just before this scan.
  final ScanCheckIn? checkIn;

  /// Records dated on or before this scan, newest first.
  final List<ContextRecord> records;

  /// The records couldn't be loaded, so nothing can be said about them.
  final bool recordsUnavailable;

  /// This wasn't their first scan.
  final bool followUpScan;

  /// Past this, a profile answer about how someone feels may no longer hold.
  static const Duration answerLifetime = Duration(days: 14);

  bool get isEmpty =>
      profile == null &&
      (checkIn == null || checkIn!.isEmpty) &&
      records.isEmpty;

  /// What they say is wrong now, or null. A check-in overrides their profile,
  /// and saying nothing's wrong overrides an old complaint.
  ReportedSymptoms? get symptoms {
    final c = checkIn?.normalized();
    if (c != null && c.symptoms.isNotEmpty) {
      if (!c.hasSymptom) return null;
      return ReportedSymptoms(
        concerns: c.symptoms.where((s) => s.isActive).toSet(),
        fromCheckIn: true,
        old: false,
        answeredOn: c.recordedAt ?? at,
        severity: c.severity,
        started: c.started,
        pattern: c.pattern,
        area: c.symptomArea?.area,
        teeth: c.symptomTeeth,
        warnings: c.warningSigns.where((w) => !w.exclusive).toSet(),
      );
    }
    final p = profile;
    if (p == null) return null;
    final active = p.currentConcerns.where((s) => s.isActive).toSet();
    if (active.isEmpty) return null;
    final answered = p.answeredAt;
    return ReportedSymptoms(
      concerns: active,
      fromCheckIn: false,
      old: answered != null && at.difference(answered) > answerLifetime,
      answeredOn: answered ?? p.recordedAt,
      severity: p.discomfortLevel,
      started: p.concernDuration,
      pattern: p.concernDuration == ConcernDuration.comesAndGoes
          ? SymptomPattern.occasional
          : null,
    );
  }

  /// Treatment they mentioned before this scan, or null.
  ReportedTreatment? get treatment {
    final c = checkIn?.normalized();
    if (c == null || !c.hasTreatment) return null;
    return ReportedTreatment(
      treatments: c.treatments.where((t) => !t.exclusive).toSet(),
      teeth: c.treatmentTeeth,
      when: c.treatmentWhen,
      sinceLastScan: followUpScan,
    );
  }

  /// The tooth or area they asked to have noted, as (areas, in words).
  (Set<MouthArea>, String)? get focus {
    final c = checkIn;
    if (c == null) return null;
    final areas = {
      if (c.focusArea?.area case final a?) a,
      ...MouthArea.ofTeeth(c.focusTeeth),
    };
    if (areas.isEmpty) return null;
    final words = c.focusTeeth.isNotEmpty
        ? (areas.length == 1
            ? '${teethInWords(c.focusTeeth)}, '
                '${areas.single.label.toLowerCase()}'
            : teethInWords(c.focusTeeth))
        : areas.single.label.toLowerCase();
    return (areas, words);
  }

  LastCheckup? get lastCheckup => checkIn?.lastCheckup ?? profile?.lastCheckup;

  LastCleaning? get lastCleaning =>
      checkIn?.lastCleaning ?? profile?.lastCleaning;

  /// The newest visit on record, for telling whether a follow-up happened.
  ContextRecord? get lastVisit =>
      records.where((r) => r.source == RecordSource.clinicRecord).firstOrNull;

  /// Records that mention [areas], newest first.
  List<ContextRecord> recordsIn(Set<MouthArea> areas) =>
      records.where((r) => r.areas.any(areas.contains)).toList();

  /// The records most worth showing with a result: those in [areas] first, clinic
  /// records ahead of their own notes, then the newest.
  List<ContextRecord> relevantRecords(Set<MouthArea> areas) {
    int place(ContextRecord r) => r.areas.any(areas.contains) ? 0 : 1;
    int kind(ContextRecord r) => r.source == RecordSource.clinicRecord ? 0 : 1;
    final sorted = [...records];
    sorted.sort((a, b) {
      final byPlace = place(a).compareTo(place(b));
      if (byPlace != 0) return byPlace;
      final byKind = kind(a).compareTo(kind(b));
      if (byKind != 0) return byKind;
      return b.date.compareTo(a.date);
    });
    return sorted;
  }

  /// Teeth their records mention on more than one date, as (tooth, dates),
  /// most mentioned first. Only says what the entries say.
  List<(String, List<DateTime>)> get repeatedTeeth {
    final dates = <String, Set<DateTime>>{};
    for (final r in records) {
      if (r.record.dateUnknown) continue;
      for (final t in r.teeth) {
        (dates[t] ??= {}).add(r.date);
      }
    }
    return [
      for (final e in dates.entries)
        if (e.value.length >= 2) (e.key, e.value.toList()..sort()),
    ]..sort((a, b) => b.$2.length.compareTo(a.$2.length));
  }

  /// How they said they are today, for showing apart from what the check saw.
  List<ContextFact> get symptomFacts {
    final s = symptoms;
    if (s == null) {
      final c = checkIn;
      return [
        if (c != null && c.symptoms.isNotEmpty)
          const ContextFact('Today', 'No symptoms'),
      ];
    }
    final label = s.fromCheckIn
        ? 'Today'
        : s.old && s.answeredOn != null
            ? DentraDates.medium(s.answeredOn!)
            : 'Your profile';
    final severity = s.severity;
    return [
      ContextFact(
        label,
        [
          _capital(s.what),
          if (severity != null && severity != DiscomfortLevel.none)
            severity.label.toLowerCase(),
        ].join(', '),
      ),
      if (s.where case final where?) ContextFact('Where', _capital(where)),
      if (_timing(s) case final timing?) ContextFact('Timing', timing),
      if (s.warnings.isNotEmpty)
        ContextFact(
          'Also',
          wordList([for (final w in s.warnings) w.label]),
        ),
    ];
  }

  /// Treatment and the tooth they asked to have noted.
  List<ContextFact> get treatmentFacts {
    final t = treatment;
    final f = focus;
    return [
      if (t != null)
        ContextFact(
          followUpScan ? 'Since last scan' : 'Recent treatment',
          [
            wordList([for (final x in t.treatments) x.label]),
            if (t.teeth.isNotEmpty) teethInWords(t.teeth),
            if (t.whenWords.isNotEmpty) t.whenWords,
          ].join(', '),
        ),
      if (checkIn?.treatments.contains(RecentTreatment.none) ?? false)
        ContextFact(
          followUpScan ? 'Since last scan' : 'Recent treatment',
          'None',
        ),
      if (f != null) ContextFact('Asked to note', _capital(f.$2)),
    ];
  }

  /// Their background: past problems, visits, daily care. Only real answers.
  List<ContextFact> get backgroundFacts {
    final p = profile;
    List<String> labels(Iterable<AnswerOption> options) => [
          for (final o in options)
            if (!o.exclusive) o.label
        ];
    final problems = labels(p?.previousProblems ?? const {});
    final past = labels(p?.pastTreatments ?? const {});
    final appliances = labels(p?.dentalAppliances ?? const {});
    final factors = labels(p?.healthFactors ?? const {});
    final goals = labels(p?.screeningGoals ?? const {});
    return [
      if (lastCheckup case final c?) ContextFact('Last check-up', c.label),
      if (lastCleaning case final c?) ContextFact('Last cleaning', c.label),
      if (problems.isNotEmpty)
        ContextFact('Past problems', problems.join(', ')),
      if (past.isNotEmpty) ContextFact('Past treatment', past.join(', ')),
      if (appliances.isNotEmpty)
        ContextFact('Appliances', appliances.join(', ')),
      if (p?.brushing case final b?) ContextFact('Brushing', b.label),
      if (p?.betweenTeeth case final b?) ContextFact('Between teeth', b.label),
      if (factors.isNotEmpty) ContextFact('Health factors', factors.join(', ')),
      if (goals.isNotEmpty) ContextFact('Wanted to check', goals.join(', ')),
    ];
  }

  /// Everything they told us, as lines for a dentist or for Rabi.
  List<String> get reportedLines => [
        for (final f in [
          ...symptomFacts,
          ...treatmentFacts,
          ...backgroundFacts
        ])
          '${f.label}: ${f.value}',
      ];

  /// "Started a few days ago, constant", or null when they didn't say.
  static String? _timing(ReportedSymptoms s) {
    final started = s.started;
    final parts = [
      if (started != null &&
          started != ConcernDuration.notSure &&
          started != ConcernDuration.comesAndGoes)
        'Started ${_startedWords(started)}',
      if (s.pattern case final pattern?) pattern.label.toLowerCase(),
    ];
    return parts.isEmpty ? null : _capital(parts.join(', '));
  }

  static String _capital(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  static String _startedWords(ConcernDuration d) => switch (d) {
        ConcernDuration.today => 'today',
        ConcernDuration.fewDays => 'a few days ago',
        ConcernDuration.fewWeeks => 'a few weeks ago',
        ConcernDuration.monthOrLonger => 'a month or more ago',
        _ => d.label.toLowerCase(),
      };
}
