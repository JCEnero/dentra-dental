/// What to say about one tooth the check marked: what was found, what it could
/// mean, what to do and how soon, and which treatments a dentist may consider.
/// No widgets, so it can be tested on its own.
///
/// The model reads one thing, possible tooth decay, as a box on a photo. It
/// can't say how deep decay goes, whether the nerve is involved, or which tooth
/// number it is, so nothing here claims to. A box does sit on one tooth, and the
/// photo with its ring shows exactly which; the words only say what the photo's
/// view allows. Urgency comes from the check's own rules and from what the user
/// told us, never from the confidence score, and their answer changes the
/// advice, never the finding.
library;

import '../../dental_profile/data/models/dental_answers.dart';
import '../../screening/data/models/finding_answer.dart';
import 'care_plan.dart';
import 'patient_context.dart';
import 'scan_regions.dart';
import 'scan_report.dart';

/// How soon to have one marked tooth looked at, in the words the results use.
enum ToothUrgency {
  /// A faint sign: nothing to book for it alone.
  watch('Keep an eye on it', 'Watch'),
  routine('Routine dental assessment', 'Routine'),
  soon('Schedule a dental visit soon', 'Soon'),
  prompt('Prompt dental evaluation', 'Prompt');

  const ToothUrgency(this.title, this.short);
  final String title;

  /// One word, for tight spaces.
  final String short;

  /// The same step on the page's own scale.
  CareLevel get careLevel => switch (this) {
        watch => CareLevel.routine,
        routine => CareLevel.nextVisit,
        soon => CareLevel.soon,
        prompt => CareLevel.prompt,
      };

  static ToothUrgency max(ToothUrgency a, ToothUrgency b) =>
      a.index >= b.index ? a : b;
}

/// A treatment a dentist may consider for a marked tooth, and when they might.
/// Never a plan: only an exam can say which, if any, is needed.
class TreatmentOption {
  const TreatmentOption({
    required this.treatmentId,
    required this.name,
    required this.when,
  });

  /// The procedure's page in the Treatment tab (`TreatmentData.byId`).
  final String treatmentId;
  final String name;

  /// When a dentist might choose it, in everyday words.
  final String when;
}

/// The procedures the results can point to. Each one has a page in the
/// Treatment tab with what it is, how it's done, recovery and risks.
abstract final class Procedures {
  static const fluoride = 'fluoride_treatment';
  static const filling = 'tooth_filling';
  static const rootCanal = 'root_canal';
  static const extraction = 'tooth_extraction';
  static const crown = 'dental_crown';

  static const all = [fluoride, filling, rootCanal, extraction, crown];

  /// How a link to each page reads.
  static String learnMore(String id) => switch (id) {
        fluoride => 'Learn more about fluoride treatment',
        filling => 'Learn more about dental fillings',
        rootCanal => 'Learn more about root canal treatment',
        extraction => 'Learn more about tooth extraction',
        crown => 'Learn more about dental crowns',
        _ => 'Learn more about this procedure',
      };
}

/// Signs of a cavity someone can notice themselves.
const List<String> cavitySymptoms = [
  'Sensitivity to cold or hot drinks',
  'Pain when eating sweets',
  'Discomfort when chewing',
  'An occasional toothache',
];

/// When a tooth problem can't wait for a dental appointment.
const String urgentCareWarning = 'Get urgent care for swelling in your face, a '
    'fever with tooth pain, or trouble swallowing or breathing.';

/// The recommendations from the check's rules that are about decay.
const Set<String> _decayAdvice = {
  'possible_filling',
  'enamel_lesion_check',
  'early_demineralization',
};

/// The views that show only the last two or three teeth.
const Set<String> _molarViews = {'back-left', 'back-right'};

/// Where a marked tooth is, as exactly as its photo's view can say, e.g. "a back
/// tooth on your upper right", or "an upper back tooth" from an arch photo,
/// which can't tell left from right.
String toothPlace(ReportSpot spot, {bool capital = false}) {
  final areas = spot.areas;
  final upper = areas.every((a) => a.isUpper)
      ? true
      : areas.every((a) => !a.isUpper)
          ? false
          : null;
  final front = areas.every((a) => a.isFront)
      ? true
      : areas.every((a) => !a.isFront)
          ? false
          : null;
  // Only back teeth have a side: the front area spans the middle.
  final left = front == false && areas.every((a) => a.isLeft)
      ? true
      : front == false && areas.every((a) => !a.isLeft)
          ? false
          : null;
  final molar = _molarViews.contains(baseRegionId(spot.photoId));
  final kind = switch (front) {
    true => 'front tooth',
    false => molar ? 'molar' : 'back tooth',
    null => 'tooth',
  };
  final jaw = switch (upper) {
    true => 'upper',
    false => 'lower',
    null => null,
  };
  final side = switch (left) {
    true => 'left',
    false => 'right',
    null => null,
  };
  final String words;
  if (side != null && jaw != null) {
    words = 'a $kind on your $jaw $side';
  } else if (side != null) {
    words = 'a $kind on your $side side';
  } else if (jaw != null) {
    words = '${jaw == 'upper' ? 'an' : 'a'} $jaw $kind';
  } else {
    words = 'a $kind';
  }
  return capital ? '${words[0].toUpperCase()}${words.substring(1)}' : words;
}

/// Everything the results say about one marked tooth.
class ToothGuidance {
  const ToothGuidance._({
    required this.spot,
    required this.pain,
    required this.asks,
    required this.title,
    required this.where,
    required this.found,
    required this.meaning,
    required this.why,
    required this.nextStep,
    required this.urgency,
    required this.urgencyWhy,
    required this.treatments,
    required this.sources,
    this.answerNote,
    this.symptomsToWatch = const [],
    this.treatmentNote,
  });

  final ReportSpot spot;

  /// What the user told us about this tooth, if they answered.
  final ToothPain? pain;

  /// Whether to ask about pain: only for signs the advice is based on, never
  /// for faint ones, which are too unsure to act on.
  final bool asks;

  /// The condition, e.g. "Possible tooth decay".
  final String title;

  /// Where it is, e.g. "A back tooth on your upper right".
  final String where;

  /// What we found.
  final String found;

  /// What this could mean.
  final String meaning;

  /// Why acting early matters.
  final String why;

  /// What their answer means for this tooth. Null until they answer.
  final String? answerNote;

  /// Shown to someone who isn't sure whether the tooth has hurt.
  final List<String> symptomsToWatch;

  /// What you should do next.
  final String nextStep;
  final ToothUrgency urgency;

  /// Why it's that urgent. [sources] says where that comes from.
  final String urgencyWhy;

  /// What a dentist may consider, mildest first. Empty for a faint sign.
  final List<TreatmentOption> treatments;

  /// What decides between them.
  final String? treatmentNote;

  /// Where the advice comes from: the check, and the user once they answer.
  final Set<CareSource> sources;

  bool get faint => spot.strength == SignStrength.faint;

  /// Urgent-care signs are worth repeating next to a tooth that hurts.
  bool get warnsAboutUrgentCare => pain?.hurts ?? false;

  /// [report] is the scan the spot is from, [pain] the user's answer about it,
  /// and [symptoms] what they said is wrong just before or around this scan.
  factory ToothGuidance.of(
    ReportSpot spot,
    ScreeningReport report, {
    ToothPain? pain,
    ReportedSymptoms? symptoms,
  }) {
    final child = isChildDentition(report.analysis.dentitionType);
    final place = toothPlace(spot);
    final photo = spot.photo.label;
    final where = toothPlace(spot, capital: true);

    if (spot.strength == SignStrength.faint) {
      return ToothGuidance._(
        spot: spot,
        pain: null,
        asks: false,
        title: spot.finding.label,
        where: where,
        found: 'In your $photo photo, the check made a faint mark on $place. '
            'Faint marks are often a false alarm.',
        meaning: 'Most faint marks turn out to be a stain or a shadow. If one '
            'keeps showing up in the same place, that\'s worth a dentist\'s '
            'look.',
        why: 'Comparing your scans over time shows whether a mark keeps coming '
            'back.',
        nextStep: 'Nothing to do for this one now. We\'ll compare it on your '
            'next scan. Mention it at your next check-up if it keeps showing '
            'up.',
        urgency: ToothUrgency.watch,
        urgencyWhy: 'Too unsure to act on by itself.',
        treatments: const [],
        sources: const {CareSource.check},
      );
    }

    final fromRules = _fromRules(report, spot);
    final current = symptoms != null && !symptoms.old ? symptoms : null;
    final severe = current != null &&
        (current.severity == DiscomfortLevel.severe ||
            current.worsening ||
            current.warnings.isNotEmpty);
    final urgency = switch (pain) {
      ToothPain.yes => ToothUrgency.max(
          fromRules,
          severe ? ToothUrgency.prompt : ToothUrgency.soon,
        ),
      ToothPain.sometimes => ToothUrgency.max(fromRules, ToothUrgency.soon),
      _ => fromRules,
    };

    return ToothGuidance._(
      spot: spot,
      pain: pain,
      asks: true,
      title: spot.finding.label,
      where: where,
      found: 'In your $photo photo, the check marked $place that may have '
          'tooth decay. ${signMeaning[spot.strength]}',
      meaning: [
        'Tooth decay slowly damages a tooth when it isn\'t treated. Early decay '
            'often doesn\'t hurt, so a mark can show up before you feel '
            'anything.',
        if (child)
          'Decay in baby and growing teeth can spread faster, because their '
              'enamel is thinner.',
        'It could also be a stain, an old filling or a shadow in the photo. '
            'Only a dentist can tell, and the check can\'t say how deep it '
            'goes.',
      ].join(' '),
      why: 'Decay found early is usually simpler to treat, sometimes with '
          'fluoride or a small filling. Left alone, it can grow into the softer '
          'layer under the enamel and reach the nerve, which can mean pain, '
          'infection and bigger treatment.',
      answerNote: switch (pain) {
        ToothPain.yes => 'Pain in a tooth the check marked is a reason to have '
            'it examined. A dentist can find what\'s causing it, so book soon, '
            'especially if the pain lasts or gets worse.',
        ToothPain.sometimes => 'Sensitivity that comes and goes has several '
            'possible causes, tooth decay among them, as well as worn enamel '
            'or gums pulling back. An exam can tell whether this tooth needs '
            'treatment.',
        ToothPain.no => 'No pain doesn\'t mean the tooth is healthy, or that '
            'the mark is harmless. Early decay often doesn\'t hurt, so it\'s '
            'worth checking before it can grow.',
        ToothPain.notSure => 'That\'s fine. These are common signs of a '
            'cavity. If you notice any of them in this tooth, tell your '
            'dentist.',
        null => null,
      },
      symptomsToWatch:
          pain == ToothPain.notSure ? cavitySymptoms : const <String>[],
      nextStep: _nextStep(urgency, pain, child: child),
      urgency: urgency,
      urgencyWhy: switch (pain) {
        ToothPain.yes when urgency == ToothUrgency.prompt =>
          'You told us this tooth hurts, and that your discomfort is severe, '
              'getting worse or comes with warning signs.',
        ToothPain.yes => 'You told us this tooth has hurt.',
        ToothPain.sometimes => 'You told us this tooth is sometimes sensitive.',
        _ when urgency == ToothUrgency.routine =>
          'It isn\'t urgent, but only a dentist can say what this mark is.',
        _ => child
            ? 'Decay in children\'s teeth can grow quickly.'
            : 'The check\'s own advice for decay in this photo.',
      },
      treatments: _treatments(pain),
      treatmentNote: [
        switch (pain) {
          ToothPain.yes => 'Which one, if any, depends on how deep the decay '
              'goes, whether the nerve is involved, how much healthy tooth is '
              'left, and what the dentist finds. Pain alone doesn\'t mean a '
              'tooth needs a root canal or removal.',
          ToothPain.sometimes => 'The exam decides which, if any, is needed. '
              'None of these is assumed from this check.',
          _ => 'The dentist decides after examining the tooth, sometimes with '
              'an X-ray.',
        },
        if (child)
          'Baby teeth are sometimes treated differently, and the dentist will '
              'explain the options for a child.',
      ].join(' '),
      sources: pain == null
          ? const {CareSource.check}
          : const {CareSource.check, CareSource.you},
    );
  }

  /// What the check's own rules advised for decay in this photo's view. The
  /// confidence score plays no part.
  static ToothUrgency _fromRules(ScreeningReport report, ReportSpot spot) {
    final view = baseRegionId(spot.photoId);
    var level = ToothUrgency.routine;
    for (final r in report.analysis.recommendations) {
      if (!_decayAdvice.contains(r.code)) continue;
      if (r.regionIds.isNotEmpty && !r.regionIds.contains(view)) continue;
      level = ToothUrgency.max(
        level,
        switch (r.urgency) {
          'prompt' => ToothUrgency.prompt,
          'soon' => ToothUrgency.soon,
          _ => ToothUrgency.routine,
        },
      );
    }
    return level;
  }

  static String _nextStep(
    ToothUrgency urgency,
    ToothPain? pain, {
    required bool child,
  }) =>
      switch (urgency) {
        ToothUrgency.prompt => 'See a dentist promptly about this tooth. Pain '
            'that is severe or getting worse, with a mark like this, '
            'shouldn\'t wait.',
        ToothUrgency.soon when pain == ToothPain.yes =>
          'Book a dental visit soon to have this tooth examined. Go sooner if '
              'the pain is persistent or getting worse.',
        ToothUrgency.soon when pain == ToothPain.sometimes =>
          'Book a dental exam soon to find out whether this tooth needs '
              'treatment.',
        ToothUrgency.soon => child
            ? 'Book a dental visit soon to have this tooth checked. Decay in '
                'children\'s teeth can grow quickly.'
            : 'Book a dental visit soon to have this tooth checked.',
        _ when pain == ToothPain.no =>
          'Have it checked at your next dental visit, before it has a chance '
              'to grow. The dentist can confirm the finding and see whether '
              'fluoride, monitoring or a filling is right.',
        _ => 'Ask a dentist to check this tooth at your next visit. They can '
            'confirm the finding and see whether fluoride, monitoring or a '
            'filling is right.',
      };

  static List<TreatmentOption> _treatments(ToothPain? pain) => switch (pain) {
        ToothPain.yes => const [
            TreatmentOption(
              treatmentId: Procedures.filling,
              name: 'Dental filling',
              when: 'If the decay is limited and the tooth can be repaired.',
            ),
            TreatmentOption(
              treatmentId: Procedures.rootCanal,
              name: 'Root canal treatment',
              when: 'If decay has reached the nerve (the pulp) and it\'s '
                  'inflamed or infected. A crown often follows.',
            ),
            TreatmentOption(
              treatmentId: Procedures.extraction,
              name: 'Tooth extraction',
              when: 'If the tooth is too damaged to repair. Dentists try to '
                  'save a tooth first.',
            ),
          ],
        ToothPain.sometimes => const [
            TreatmentOption(
              treatmentId: Procedures.fluoride,
              name: 'Fluoride treatment',
              when: 'If the enamel is weak or worn but there\'s no hole yet. '
                  'It can also ease sensitivity.',
            ),
            TreatmentOption(
              treatmentId: Procedures.filling,
              name: 'Dental filling',
              when: 'If the exam finds a cavity.',
            ),
            TreatmentOption(
              treatmentId: Procedures.rootCanal,
              name: 'Root canal treatment',
              when: 'Only if the nerve turns out to be affected.',
            ),
          ],
        ToothPain.no => const [
            _fluorideWatch,
            _filling,
            TreatmentOption(
              treatmentId: Procedures.crown,
              name: 'Crown or other repair',
              when: 'For larger damage, when a filling isn\'t enough.',
            ),
          ],
        _ => const [_fluorideWatch, _filling],
      };

  static const _fluorideWatch = TreatmentOption(
    treatmentId: Procedures.fluoride,
    name: 'Fluoride treatment and monitoring',
    when: 'For some early decay that hasn\'t broken through the surface. It '
        'can sometimes be stopped or reversed.',
  );

  static const _filling = TreatmentOption(
    treatmentId: Procedures.filling,
    name: 'Dental filling',
    when: 'For an established cavity.',
  );
}

/// Primary or mixed teeth, from what the analysis said.
bool isChildDentition(String? dentitionType) =>
    dentitionType == 'primary' || dentitionType == 'mixed';

/// Guidance for every sign in [report], in the report's own order, using the
/// user's [answers] by finding id.
List<ToothGuidance> toothGuidanceFor(
  ScreeningReport report, {
  Map<String, ToothPain> answers = const {},
  ReportedSymptoms? symptoms,
}) =>
    [
      for (final spot in report.spots)
        ToothGuidance.of(
          spot,
          report,
          pain: switch (spot.finding.id) {
            final id? => answers[id],
            null => null,
          },
          symptoms: symptoms,
        ),
    ];

/// The user's answers that belong to signs in [report]: an answer whose finding
/// has gone (the photos were read again) says nothing about this result.
Map<String, ToothPain> answersIn(
  ScreeningReport report,
  List<FindingAnswer> answers,
) {
  final ids = {
    for (final s in report.spots)
      if (s.strength != SignStrength.faint)
        if (s.finding.id case final id?) id,
  };
  return {
    for (final a in answers)
      if (ids.contains(a.findingId)) a.findingId: a.pain,
  };
}
