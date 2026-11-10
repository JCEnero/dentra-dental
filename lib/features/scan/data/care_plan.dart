/// What to do next, from what the check saw, what someone told us and what's in
/// their records together. Every step says where it came from, so a symptom never
/// reads as something the check detected, and nothing here can change a finding.
///
/// Urgency follows NHS guidance on toothache, dental abscesses and gum disease:
/// a toothache lasting more than 2 days, or one with a swollen cheek or jaw, a
/// high temperature or pain that won't settle, needs a dentist; swelling by the
/// eye or in the neck, or trouble breathing, swallowing, speaking or opening the
/// mouth, needs emergency care. The check can't rule anything out, so no result
/// lowers what a symptom calls for. No widgets, so it can be tested on its own.
library;

import '../../../core/utils/dentra_dates.dart';
import '../../dental_profile/data/models/dental_answers.dart';
import '../../dental_records/data/models/dental_record.dart';
import '../../screening/data/models/finding_answer.dart';
import '../../screening/data/models/scan_check_in.dart';
import 'patient_context.dart';
import 'scan_outcomes.dart';
import 'scan_report.dart';
import 'tooth_guidance.dart';

/// Where a piece of advice comes from.
enum CareSource {
  check('the check'),
  you('what you told us'),
  records('your records'),
  earlierScans('your earlier scans');

  const CareSource(this.words);
  final String words;
}

/// "From the check and what you told us".
String careSourcesInWords(Set<CareSource> sources) => 'From ${wordList([
          for (final s in CareSource.values)
            if (sources.contains(s)) s.words
        ])}';

/// How soon to see someone, least to most pressing.
enum CareLevel {
  routine('Keep your regular check-ups', 'Regular'),
  nextVisit('Mention this at your next visit', 'Next visit'),
  soon('Book a dental visit soon', 'Soon'),
  prompt('See a dentist promptly', 'Promptly'),
  emergency('Get emergency care now', 'Now');

  const CareLevel(this.title, this.short);
  final String title;

  /// Its stop on the scale.
  final String short;

  static CareLevel of(ReportLevel level) => switch (level) {
        ReportLevel.none => routine,
        ReportLevel.nextVisit => nextVisit,
        ReportLevel.soon => soon,
        ReportLevel.prompt => prompt,
      };

  static CareLevel max(CareLevel a, CareLevel b) => a.index >= b.index ? a : b;
}

/// One thing to do.
class CareStep {
  const CareStep({
    required this.level,
    required this.title,
    required this.detail,
    required this.why,
    required this.sources,
  });

  final CareLevel level;
  final String title;
  final String detail;

  /// Why this sets the result's urgency, if it's the most pressing.
  final String why;
  final Set<CareSource> sources;
}

/// Something that connects two kinds of information, only ever said when the
/// entries behind it support it.
class ContextLink {
  const ContextLink({
    required this.title,
    required this.text,
    required this.sources,
  });

  final String title;
  final String text;
  final Set<CareSource> sources;
}

class CarePlan {
  CarePlan._({
    required this.steps,
    required this.links,
    required this.questions,
    required this.dailyCare,
    required this.report,
    required this.teeth,
  });

  final ScreeningReport report;

  /// What to say about each marked tooth, in the report's order.
  final List<ToothGuidance> teeth;

  /// What the user said about the marked teeth, as lines for a dentist or Rabi.
  /// Their words, so they go under their own heading, never with the findings.
  List<String> get toothAnswerLines => [
        for (final g in teeth)
          if (g.pain case final pain?)
            'The tooth marked in the ${g.spot.photo.label} photo: '
                '${pain.short.toLowerCase()}',
      ];

  /// Most pressing first. Empty when nothing calls for anything in particular.
  final List<CareStep> steps;

  /// How the check, their answers and their records relate.
  final List<ContextLink> links;
  final List<String> questions;
  final List<String> dailyCare;

  CareLevel get level => steps.firstOrNull?.level ?? CareLevel.routine;

  bool get isEmergency => level == CareLevel.emergency;

  /// The most pressing step comes from something other than the photos.
  bool get drivenByContext {
    final first = steps.firstOrNull;
    return first != null && !first.sources.contains(CareSource.check);
  }

  /// What to do, in a few words.
  String get title {
    if (level == CareLevel.nextVisit && report.signCount == 0) {
      return steps.first.title;
    }
    return level.title;
  }

  /// Why, in one line. It never suggests the check saw what someone felt.
  String get because =>
      steps.firstOrNull?.why ??
      'Nothing here calls for an earlier visit, but photos can miss things.';

  /// [answers] is what the user said about the marked teeth, by finding id.
  factory CarePlan.of(
    ScreeningReport report,
    PatientContext context,
    ScanTrend trend, {
    Map<String, ToothPain> answers = const {},
  }) {
    final steps = <CareStep>[];
    final links = <ContextLink>[];
    final now = context.symptoms;

    // Signs the check marked, strongest first.
    final marked = report.spots;
    List<ReportSpot> markedIn(Set<MouthArea> areas) =>
        marked.where((s) => s.areas.any(areas.contains)).toList();

    // A symptom with a mark in the same area gets one step, not two.
    final sameArea = now == null || now.old || !now.aboutTeeth
        ? const <ReportSpot>[]
        : markedIn(now.areas);

    // ── What they say is wrong ──
    if (now != null && now.old) {
      final on = now.answeredOn == null
          ? 'Earlier'
          : 'On ${DentraDates.medium(now.answeredOn!)}';
      steps.add(CareStep(
        level: now.severity == DiscomfortLevel.severe
            ? CareLevel.soon
            : CareLevel.nextVisit,
        title: 'Check on what you told us',
        detail: '$on you told us about ${now.what}. If it\'s still there, '
            'see a dentist. A clear photo wouldn\'t rule it out.',
        why:
            'Because of what you told us on your profile, if it\'s still there.',
        sources: const {CareSource.you},
      ));
    } else if (now != null) {
      steps.addAll(_symptomSteps(now, toothCovered: sameArea.isNotEmpty));
    }
    final current = now != null && !now.old ? now : null;

    // ── What they told us about the teeth the check marked ──
    final teeth = toothGuidanceFor(report, answers: answers, symptoms: current);
    final hurting = [
      for (final g in teeth)
        if (g.pain?.hurts ?? false) g,
    ];
    if (hurting.isNotEmpty) {
      final one = hurting.length == 1;
      final first = hurting.first;
      final felt = first.pain == ToothPain.yes
          ? 'has hurt'
          : 'is sometimes sensitive';
      steps.add(CareStep(
        level: hurting
            .map((g) => g.urgency)
            .reduce(ToothUrgency.max)
            .careLevel,
        title: one
            ? 'Have the tooth that hurts examined'
            : 'Have the teeth that hurt examined',
        detail: one
            ? 'You told us the tooth the check marked in your '
                '${first.spot.photo.label} photo $felt. Pain or sensitivity '
                'in a marked tooth is a good reason to have it examined.'
            : 'You told us ${hurting.length} of the teeth the check marked '
                'have hurt or been sensitive. That\'s a good reason to have '
                'them examined.',
        why: one
            ? 'Because you told us a tooth the check marked $felt.'
            : 'Because you told us teeth the check marked have hurt.',
        sources: const {CareSource.check, CareSource.you},
      ));
    }

    // ── Where symptoms and marks meet, or don't ──
    if (current != null) {
      final areas = current.areas;
      if (current.aboutTeeth && areas.isNotEmpty) {
        final place = current.where!;
        if (sameArea.isNotEmpty) {
          final spot = sameArea.first;
          final strong = spot.strength == SignStrength.strong &&
              (current.keepsGoing ||
                  current.severity == DiscomfortLevel.moderate);
          steps.add(CareStep(
            level: strong ? CareLevel.prompt : CareLevel.soon,
            title: 'Have this area looked at',
            detail: 'What you feel and what the check marked are in the same '
                'general area. Together they\'re a good reason to have it '
                'looked at.',
            why: 'Because what you feel and what the check marked are in the '
                'same general area.',
            sources: const {CareSource.check, CareSource.you},
          ));
          links.add(ContextLink(
            title: 'Same general area',
            text: 'You told us about ${current.toothWords}: $place. The check '
                'marked a ${spot.strength.label.toLowerCase()} in '
                '${spot.where.toLowerCase()}. It can\'t tell if it\'s the same '
                'tooth.',
            sources: const {CareSource.check, CareSource.you},
          ));
        } else if (areas.any((a) => report.areas[a]!.state.read)) {
          links.add(ContextLink(
            title: 'Nothing marked there',
            text: 'You told us about ${current.toothWords}: $place. The check '
                'marked nothing there, but a photo can\'t rule out a problem '
                'under the surface or between teeth. What you feel still counts.',
            sources: const {CareSource.check, CareSource.you},
          ));
        } else {
          links.add(ContextLink(
            title: 'Not in this scan',
            text:
                'You told us about ${current.toothWords}: $place. This scan has '
                'no photo of that area the check could read.',
            sources: const {CareSource.check, CareSource.you},
          ));
        }
      } else if (current.aboutTeeth &&
          marked.isEmpty &&
          report.photosRead > 0) {
        links.add(ContextLink(
          title: 'Nothing marked',
          text: 'You told us about ${current.toothWords}. The check marked '
              'nothing, but a photo can\'t rule out a problem under the surface '
              'or between teeth. What you feel still counts.',
          sources: const {CareSource.check, CareSource.you},
        ));
      }
      if (current.aboutGums) {
        links.add(ContextLink(
          title: 'Gums aren\'t read',
          text: 'The check doesn\'t read gums, so this result says nothing '
              'about the ${current.gumWords} you told us about.',
          sources: const {CareSource.check, CareSource.you},
        ));
      }
    }

    // ── Treatment they mentioned ──
    final treatment = context.treatment;
    if (treatment != null && treatment.recent) {
      final named =
          treatment.teeth.isEmpty ? '' : ' on ${teethInWords(treatment.teeth)}';
      final when = treatment.whenWords.isEmpty ? '' : ' ${treatment.whenWords}';
      final near = treatment.areas.isEmpty ? marked : markedIn(treatment.areas);
      if (treatment.changesTheLook && near.isNotEmpty) {
        links.add(ContextLink(
          title: 'Recent treatment',
          text: treatment.treatments.contains(RecentTreatment.extraction)
              ? 'You told us you had ${treatment.what}$named$when. A healing '
                  'area can look unusual in a photo, and the check doesn\'t read '
                  'gums. Mention it to your dentist.'
              : 'You told us you had ${treatment.what}$named$when. Dental work '
                  'can look like a mark in a photo, so ask your dentist about '
                  'this one.',
          sources: const {CareSource.check, CareSource.you},
        ));
      }
      if (current != null && current.aboutTeeth) {
        steps.add(CareStep(
          level: CareLevel.soon,
          title: 'Tell the clinic that treated you',
          detail: 'You told us you had ${treatment.what}$when and also '
              'about ${current.toothWords}. Ask them whether that\'s expected.',
          why: 'Because you told us about ${current.toothWords} after recent '
              'treatment.',
          sources: const {CareSource.you},
        ));
      }
    }

    // ── What the check itself advised ──
    for (final r in report.analysis.recommendations) {
      if (r.code == 'braces_seen') continue;
      final level = switch (r.urgency) {
        'prompt' => CareLevel.prompt,
        'soon' => CareLevel.soon,
        _ => CareLevel.nextVisit,
      };
      steps.add(CareStep(
        level: level,
        title: r.title,
        detail: r.detail,
        why: level == CareLevel.nextVisit
            ? 'It isn\'t urgent, but only a dentist can say what these marks are.'
            : 'Because of what the check marked in your photos.',
        sources: const {CareSource.check},
      ));
    }

    // ── Across scans ──
    if (trend.repeating.isNotEmpty && !trend.mixedVersions) {
      final areas = trend.repeating.keys.toSet();
      final worstNow = markedIn(areas).firstOrNull?.strength;
      final runs = trend.repeating.values.reduce((a, b) => a > b ? a : b);
      steps.add(CareStep(
        level: worstNow == null || worstNow == SignStrength.faint
            ? CareLevel.nextVisit
            : CareLevel.soon,
        title: 'Ask about the area that keeps showing up',
        detail: 'The check has flagged the same general area in $runs scans in '
            'a row. That doesn\'t show whether it\'s changing, only that it '
            'keeps being marked.',
        why: 'Because the same area keeps being marked across your scans.',
        sources: const {CareSource.check, CareSource.earlierScans},
      ));
    }

    // ── Their records ──
    links.addAll(_recordLinks(context, marked, current));
    final followUp = _followUp(context);
    if (followUp != null) steps.add(followUp);

    // ── Visits ──
    // Someone already told to book a visit doesn't need telling to book one.
    final overdue = _overdueCheckup(context);
    final visitAdvised =
        steps.any((s) => s.level.index >= CareLevel.soon.index);
    if (overdue != null && !visitAdvised) steps.add(overdue);
    final cleaning = _cleaningDue(context);
    if (cleaning != null) steps.add(cleaning);

    // ── What they asked to have noted ──
    final focus = context.focus;
    if (focus != null && (current == null || !_same(focus.$1, current.areas))) {
      links.add(_focusLink(report, focus));
    }

    steps.sort((a, b) => b.level.index.compareTo(a.level.index));

    return CarePlan._(
      report: report,
      steps: List.unmodifiable(steps),
      links: List.unmodifiable(links),
      questions: List.unmodifiable([
        // A symptom from the check-in already asks the same about the mark.
        if (hurting.isNotEmpty && !(current?.aboutTeeth ?? false))
          'Could the marked tooth be causing my pain, and what does it need?',
        ..._questions(report, context, trend),
      ].take(3)),
      dailyCare: List.unmodifiable(_dailyCare(report, context)),
      teeth: List.unmodifiable(teeth),
    );
  }

  static bool _same(Set<MouthArea> a, Set<MouthArea> b) =>
      a.length == b.length && a.containsAll(b);

  /// [toothCovered] means a mark in the same area already has a step of its own.
  static List<CareStep> _symptomSteps(
    ReportedSymptoms s, {
    bool toothCovered = false,
  }) {
    final out = <CareStep>[];
    const you = {CareSource.you};

    final emergency = s.warnings.where((w) => w.emergency).toList();
    if (emergency.isNotEmpty) {
      out.add(CareStep(
        level: CareLevel.emergency,
        title: CareLevel.emergency.title,
        detail: 'You told us about '
            '${wordList([for (final w in emergency) w.inWords])}. Call your '
            'local emergency number or go to the nearest emergency department. '
            'Don\'t drive yourself, and don\'t wait for a dental appointment.',
        why: 'Because of the warning signs you told us about, not because of '
            'your photos.',
        sources: you,
      ));
    }
    final urgent = s.warnings.where((w) => !w.emergency).toList();
    if (urgent.isNotEmpty) {
      out.add(CareStep(
        level: CareLevel.prompt,
        title: 'Ask for an urgent dental appointment',
        detail: 'You told us about '
            '${wordList([for (final w in urgent) w.inWords])}. Contact a '
            'dentist today. If it becomes hard to breathe, swallow or speak, '
            'get emergency care right away.',
        why: 'Because of the warning signs you told us about, not because of '
            'your photos.',
        sources: you,
      ));
    }
    if (s.severity == DiscomfortLevel.severe) {
      out.add(const CareStep(
        level: CareLevel.prompt,
        title: 'See a dentist about your discomfort',
        detail: 'You told us it\'s severe. Please contact a dentist as soon as '
            'you can. If you have facial swelling, a fever, or trouble '
            'swallowing or breathing, get emergency care right away.',
        why: 'Because you told us your discomfort is severe. No scan can rule '
            'out what\'s causing it.',
        sources: you,
      ));
    }
    if (s.worsening) {
      out.add(CareStep(
        level: CareLevel.prompt,
        title: 'Get this seen before it gets worse',
        detail:
            'You told us your ${s.what} ${s.concerns.length > 1 ? 'are' : 'is'} '
            'getting worse. That\'s worth a prompt visit, whatever a scan shows.',
        why: 'Because you told us it\'s getting worse. No scan can rule out '
            'what\'s causing it.',
        sources: you,
      ));
    }

    if (s.aboutTeeth) {
      final words = s.toothWords;
      final pain = s.concerns.contains(CurrentConcern.toothPain);
      final broken = s.concerns.contains(CurrentConcern.brokenTooth);
      if (broken) {
        out.add(const CareStep(
          level: CareLevel.soon,
          title: 'Have your broken tooth looked at',
          detail: 'A chipped or broken tooth is worth a dentist\'s look, even '
              'when it doesn\'t hurt.',
          why: 'Because you told us about a chipped or broken tooth.',
          sources: you,
        ));
      }
      if (toothCovered) {
        // Said once, with the mark it shares an area with.
      } else if (pain && s.lasted) {
        out.add(CareStep(
          level: CareLevel.soon,
          title: 'Book a visit about your tooth pain',
          detail: 'You told us it started ${_startedInWords(s.started)}. '
              'Toothache that lasts more than 2 days is a reason to see a '
              'dentist, even with nothing marked in your photos.',
          why: 'Because of the tooth pain you told us about. No scan can rule '
              'out what\'s causing it.',
          sources: you,
        ));
      } else if (s.keepsGoing || s.severity == DiscomfortLevel.moderate) {
        out.add(CareStep(
          level: CareLevel.soon,
          title: 'Book a visit about your $words',
          detail: 'You told us it keeps going. That\'s worth a dentist\'s '
              'look, even with nothing marked in your photos.',
          why: 'Because of the $words you told us about. No scan can rule out '
              'what\'s causing it.',
          sources: you,
        ));
      } else if (pain) {
        out.add(const CareStep(
          level: CareLevel.nextVisit,
          title: 'Keep an eye on your tooth pain',
          detail:
              'See a dentist if it lasts more than 2 days, or if painkillers '
              'don\'t help. A photo can\'t rule out what\'s causing it.',
          why: 'Because of the tooth pain you told us about.',
          sources: you,
        ));
      } else if (!broken) {
        out.add(CareStep(
          level: CareLevel.nextVisit,
          title: 'Mention your $words at your next visit',
          detail: 'See a dentist sooner if it stays or gets worse.',
          why: 'Because of the $words you told us about.',
          sources: you,
        ));
      }
    }

    if (s.aboutGums) {
      final swollen = s.concerns.contains(CurrentConcern.swollenGums);
      out.add(CareStep(
        level: swollen || s.keepsGoing ? CareLevel.soon : CareLevel.nextVisit,
        title: 'Have your gums looked at',
        detail: swollen || s.keepsGoing
            ? 'You told us about ${s.gumWords}. That\'s worth a dentist\'s '
                'look, and this check can\'t read gums.'
            : 'Mention your ${s.gumWords} at your next visit, or sooner if they '
                'keep on. This check can\'t read gums.',
        why:
            'Because of the ${s.gumWords} you told us about. This check can\'t '
            'read gums.',
        sources: you,
      ));
    }
    return out;
  }

  static String _startedInWords(ConcernDuration? d) => switch (d) {
        ConcernDuration.today => 'today',
        ConcernDuration.fewDays => 'a few days ago',
        ConcernDuration.fewWeeks => 'a few weeks ago',
        ConcernDuration.monthOrLonger => 'a month or more ago',
        _ => 'a while ago',
      };

  /// Where their records meet this scan. A clinic record is what they wrote down
  /// from a visit; a note or photo is only ever theirs, never proof of anything.
  static List<ContextLink> _recordLinks(
    PatientContext context,
    List<ReportSpot> marked,
    ReportedSymptoms? current,
  ) {
    final links = <ContextLink>[];
    final flagged = {for (final s in marked) ...s.areas};

    final clinic = context
        .recordsIn(flagged)
        .where((r) => r.source == RecordSource.clinicRecord)
        .firstOrNull;
    if (clinic != null) {
      final spot = marked.firstWhere((s) => s.areas.any(clinic.areas.contains));
      final works = clinic.kind == ProcedureKind.filling ||
          clinic.kind == ProcedureKind.crown;
      links.add(ContextLink(
        title: 'In your clinic record',
        text: 'Your clinic record from ${clinic.dateLabel} lists '
            '"${clinic.title}" for ${teethInWords(clinic.teeth)}. The check '
            'marked a ${spot.strength.label.toLowerCase()} in '
            '${spot.where.toLowerCase()}. It can\'t tell if it\'s the same '
            'tooth.${works ? ' Dental work can look like a mark in a photo.' : ''}',
        sources: const {CareSource.check, CareSource.records},
      ));
    }

    final own = context
        .recordsIn({...flagged, ...?current?.areas})
        .where((r) => r.source != RecordSource.clinicRecord)
        .firstOrNull;
    if (own != null) {
      final kind = own.source == RecordSource.personalPhoto ? 'photo' : 'note';
      links.add(ContextLink(
        title: 'In your own $kind',
        text: 'You added a $kind from ${own.dateLabel} about '
            '${teethInWords(own.teeth)}, in the same general area. It may be '
            'worth showing your dentist.',
        sources: const {CareSource.records},
      ));
    }

    final repeated = context.repeatedTeeth.firstOrNull;
    if (repeated != null) {
      links.add(ContextLink(
        title: 'Comes up more than once',
        text: 'Your records mention ${teethInWords([repeated.$1])} on '
            '${repeated.$2.length} dates, most recently '
            '${DentraDates.medium(repeated.$2.last)}.',
        sources: const {CareSource.records},
      ));
    }
    return links;
  }

  static CareStep? _followUp(PatientContext context) {
    for (final r in context.records) {
      final date = r.record.followUpDate;
      if (date == null) continue;
      final at = DentraDates.dateOnly(context.at);
      if (!date.isBefore(at)) {
        if (date.difference(at).inDays > 60) continue;
        return CareStep(
          level: CareLevel.routine,
          title: 'Raise this at your follow-up',
          detail: 'Your clinic record from ${r.dateLabel} lists a follow-up on '
              '${DentraDates.medium(date)}.',
          why: 'Your clinic record lists a follow-up on '
              '${DentraDates.medium(date)}.',
          sources: const {CareSource.records},
        );
      }
      final seen = context.records.any((v) =>
          v.source == RecordSource.clinicRecord && !v.date.isBefore(date));
      if (seen) return null;
      return CareStep(
        level: CareLevel.nextVisit,
        title: 'Check on your follow-up',
        detail: 'Your clinic record from ${r.dateLabel} lists a follow-up on '
            '${DentraDates.medium(date)}. Your records don\'t show a visit since.',
        why: 'Because your records don\'t show the follow-up on '
            '${DentraDates.medium(date)}.',
        sources: const {CareSource.records},
      );
    }
    return null;
  }

  static CareStep? _overdueCheckup(PatientContext context) {
    final visit = context.lastVisit;
    if (visit != null && context.at.difference(visit.date).inDays <= 365) {
      return null;
    }
    final never = context.lastCheckup == LastCheckup.never;
    if (!never && context.lastCheckup != LastCheckup.overAYear) return null;
    return CareStep(
      level: CareLevel.nextVisit,
      title: 'Book a check-up',
      detail: never
          ? 'You told us you haven\'t had a dental check-up yet. A dentist can '
              'see what photos can\'t.'
          : 'You told us your last check-up was more than a year ago. A dentist '
              'can see what photos can\'t.',
      why: never
          ? 'Because you told us you haven\'t had a check-up yet.'
          : 'Because you told us your last check-up was over a year ago.',
      sources: const {CareSource.you},
    );
  }

  static CareStep? _cleaningDue(PatientContext context) {
    final clean = context.lastCleaning;
    if (clean != LastCleaning.overAYear && clean != LastCleaning.never) {
      return null;
    }
    final recently = context.records.any((r) =>
        r.kind == ProcedureKind.cleaning &&
        context.at.difference(r.date).inDays <= 365);
    if (recently) return null;
    return CareStep(
      level: CareLevel.routine,
      title: 'Ask about a cleaning',
      detail: clean == LastCleaning.never
          ? 'You told us you haven\'t had a professional cleaning. This check '
              'can\'t read plaque or tartar, and a cleaning deals with both.'
          : 'You told us your last cleaning was more than a year ago. This check '
              'can\'t read plaque or tartar, and a cleaning deals with both.',
      why: 'Because of when you told us your last cleaning was.',
      sources: const {CareSource.you},
    );
  }

  static ContextLink _focusLink(
    ScreeningReport report,
    (Set<MouthArea>, String) focus,
  ) {
    final states = [for (final a in focus.$1) report.areas[a]!.state];
    final seen = states.any((s) => s.flagged)
        ? 'The check marked something in that general area'
        : states.any((s) => s.read)
            ? 'The check marked nothing in that general area'
            : 'This scan has no photo of that area the check could read';
    return ContextLink(
      title: 'What you asked us to note',
      text: 'You asked us to note ${focus.$2}. $seen. It can\'t look at one '
          'tooth in particular.',
      sources: const {CareSource.check, CareSource.you},
    );
  }

  static List<String> _questions(
    ScreeningReport report,
    PatientContext context,
    ScanTrend trend,
  ) {
    final now = context.symptoms;
    final current = now != null && !now.old ? now : null;
    final treatment = context.treatment;
    final hasSigns = report.spots.isNotEmpty;
    return [
      if (current != null && current.aboutTeeth && hasSigns)
        'Could the mark in my photo be causing what I feel?',
      if (current != null && current.aboutTeeth && !hasSigns)
        'What could be causing this if nothing shows in my photos? Would an '
            'X-ray help?',
      if (treatment != null && treatment.changesTheLook && hasSigns)
        'Is this mark my recent dental work?',
      if (trend.repeating.isNotEmpty && !trend.mixedVersions)
        'This keeps being marked in my scans. Should we treat it or watch it?',
      if (current != null && current.aboutGums)
        'How do my gums look? The check can\'t read them.',
      ...report.dentistQuestions,
    ].take(3).toList();
  }

  static List<String> _dailyCare(
    ScreeningReport report,
    PatientContext context,
  ) {
    final p = context.profile;
    final tips = [
      if (report.careTips.first != report.careTips.last) report.careTips.first,
      switch (p?.brushing) {
        BrushingHabit.once =>
          'You told us you brush once a day. Twice a day with fluoride '
              'toothpaste is the usual advice.',
        BrushingHabit.lessThanDaily =>
          'You told us you brush less than once a day. Twice a day with '
              'fluoride toothpaste is the usual advice.',
        BrushingHabit.twiceOrMore => 'Keep brushing with fluoride toothpaste.',
        null => 'Brush twice a day with fluoride toothpaste.',
      },
      switch (p?.betweenTeeth) {
        BetweenTeethHabit.daily => null,
        BetweenTeethHabit.sometimes ||
        BetweenTeethHabit.rarely =>
          'Clean between your teeth once a day. The check can\'t read there.',
        null => 'Clean between your teeth once a day.',
      },
      if (p?.healthFactors.contains(HealthFactor.dryMouth) ?? false)
        'Dry mouth can raise the risk of decay. Mention it at your visit.',
      if (p?.healthFactors.contains(HealthFactor.diabetes) ?? false)
        'Diabetes is linked with gum problems, so tell your dentist about it.',
      if (p?.healthFactors.contains(HealthFactor.tobacco) ?? false)
        'Tobacco raises the risk of gum disease. Your dentist can help you quit.',
      if (p?.healthFactors.contains(HealthFactor.teethGrinding) ?? false)
        'Grinding can wear teeth down, and the check doesn\'t read wear. Ask '
            'about a night guard.',
    ];
    return tips.whereType<String>().take(4).toList();
  }
}
