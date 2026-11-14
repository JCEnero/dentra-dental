import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/dentra_glass_ui.dart';
import '../../../ai_assistant/ai_chat_controller.dart';
import '../../../../core/utils/dentra_dates.dart';
import '../../../dental_profile/data/models/dental_answers.dart';
import '../../../dental_profile/providers/dental_profile_providers.dart';
import '../../../dental_records/data/models/dental_record.dart';
import '../../../dental_records/providers/dental_records_provider.dart';
import '../../../profile/providers/profile_provider.dart';
import '../../../screening/data/models/scan_check_in.dart';
import '../../../screening/data/models/screening_session.dart';
import '../../../screening/providers/screening_sessions_provider.dart';
import '../../../treatment/treatment_links.dart';
import '../../data/care_plan.dart';
import '../../data/patient_context.dart';
import '../../data/scan_regions.dart';
import '../../data/scan_report.dart';
import '../../data/tooth_guidance.dart';
import '../../services/report_download.dart';
import '../scan_motion.dart';
import '../scan_theme.dart';
import 'context_section.dart';
import 'next_steps.dart';
import 'report_charts.dart';
import 'report_hero.dart';
import 'report_photos.dart';
import 'report_style.dart';
import 'signs_section.dart';
import 'trend_section.dart';
import 'understand_section.dart';

/// The whole result of one analysis, as one story: where things stand on a 3D
/// mouth, what was seen in the real photos, how that sits with what the user told
/// us and their records, what to do, what the scan covered, how it's changing,
/// and what any of it means. Each part is a picture first and a sentence second.
/// Used right after a scan and when opening one from history.
class ScanReportView extends ConsumerStatefulWidget {
  const ScanReportView({
    super.key,
    required this.report,
    required this.imageOf,
    required this.status,
    required this.date,
    required this.at,
    required this.leading,
    this.saved,
    this.checkIn,
    this.sessionId,
    this.onClinics,
    this.showActions = true,
  });

  final ScreeningReport report;
  final ImageProvider? Function(String photoId) imageOf;

  /// How the scan went, e.g. "Scan complete".
  final String status;
  final String date;

  /// When the scan was taken.
  final DateTime at;
  final Widget leading;

  /// The stored scan, if it reached the server. It holds what the user had
  /// told us at the time, so an old report keeps reading the same.
  final ScreeningSession? saved;

  /// What the user said before this scan, if it hasn't been stored yet.
  final ScanCheckIn? checkIn;

  /// The scan on the timeline. Null means the newest in the history.
  final String? sessionId;
  final VoidCallback? onClinics;

  /// Whether to offer Rabi and clinics. They wait while photos need retaking.
  final bool showActions;

  @override
  ConsumerState<ScanReportView> createState() => _ScanReportViewState();
}

class _ScanReportViewState extends ConsumerState<ScanReportView> {
  final _focus = ValueNotifier<ReportSpot?>(null);
  final _signsKey = GlobalKey();
  bool _downloading = false;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _seeSpot(ReportSpot spot) {
    _focus.value = spot;
    final target = _signsKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      alignment: 0.04,
      duration: ScanMotion.of(context, ScanMotion.slow),
      curve: ScanMotion.curve,
    );
  }

  void _askRabi(AiChatController chat, PatientContext patient, CarePlan plan) {
    chat.open();
    chat.sendMessage(
      'Can you explain my scan results?',
      prompt: rabiPromptFor(
        widget.report,
        reported: [...patient.reportedLines, ...plan.toothAnswerLines],
      ),
    );
  }

  /// The scan as stored now: answers saved since the page opened are in the
  /// history, which the server's copy from the end of the scan doesn't have.
  ScreeningSession? _stored(List<ScreeningSession> sessions) {
    final id = widget.sessionId ?? widget.saved?.id;
    if (id == null) return null;
    return sessions.where((s) => s.id == id).firstOrNull;
  }

  /// Saves what the user said about one marked tooth. The page shows it at
  /// once, and puts it back with a note if it couldn't be saved.
  Future<void> _answer(String sessionId, String findingId, ToothPain? pain) async {
    final toast = DentraToast.of(context);
    try {
      await ref
          .read(screeningSessionsProvider.notifier)
          .answerFinding(sessionId, findingId, pain);
    } catch (_) {
      toast.show(
        'Couldn\'t save your answer. Please try again.',
        tone: DentraFeedbackTone.error,
      );
    }
  }

  /// Opens a procedure's page in the Treatment tab. From the scan tab, its
  /// clinic button closes the page and goes on to Clinics.
  void _learnMore(String treatmentId) {
    final clinics = widget.onClinics;
    final navigator = Navigator.of(context);
    openTreatment(
      context,
      treatmentId,
      onFindClinic: clinics == null
          ? null
          : () {
              navigator.pop();
              clinics();
            },
    );
  }

  /// What's known about the user at this scan. A stored scan has what was
  /// reported at the time, or knows there was nothing; only a scan the server
  /// hasn't seen falls back on the profile.
  PatientContext _patientFrom(
    DentalProfile? profile,
    AsyncValue<List<DentalRecord>> records,
    List<ScreeningSession> sessions,
  ) {
    final saved = widget.saved;
    return PatientContext(
      at: widget.at,
      profile: saved != null
          ? saved.reportedContext
          : profile == null
              ? null
              : ScreeningReportedContext.fromProfile(profile, widget.at),
      checkIn: saved?.checkIn ?? widget.checkIn,
      records: records.valueOrNull ?? const [],
      recordsUnavailable: records.hasError,
      followUpScan: sessions.any((s) =>
          s.id != (widget.sessionId ?? saved?.id) &&
          s.completedAt.isBefore(widget.at)),
    );
  }

  /// The PDF is made on this device, from what this signed-in user can already
  /// read, and goes nowhere but to them. It waits for anything still loading, so
  /// a quick tap doesn't leave out their name or records.
  Future<void> _download() async {
    setState(() => _downloading = true);
    final toast = DentraToast.of(context);
    Future<T?> loaded<T>(Future<T> future) async {
      try {
        return await future.timeout(const Duration(seconds: 10));
      } catch (_) {
        return null;
      }
    }

    try {
      final person = await loaded(ref.read(profileProvider.future));
      final profile = await loaded(ref.read(dentalProfileProvider.future));
      await loaded(ref.read(dentalRecordsProvider.future));
      final sessions =
          await loaded(ref.read(screeningSessionsProvider.future)) ??
              const <ScreeningSession>[];
      if (!mounted) return;
      final stored = _stored(sessions) ?? widget.saved;
      await downloadScreeningReport(
        report: widget.report,
        patient:
            _patientFrom(profile, ref.read(dentalRecordsProvider), sessions),
        trend: ScanTrend.of(sessions, currentId: widget.sessionId),
        answers: answersIn(widget.report, stored?.findingAnswers ?? const []),
        person: person,
        sessionId: widget.sessionId ?? widget.saved?.id,
        imageOf: widget.imageOf,
      );
    } catch (_) {
      toast.show(
        'Couldn\'t make your PDF. Please try again.',
        tone: DentraFeedbackTone.error,
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final issues = report.analysis.qualityIssues;
    final read = report.photosRead > 0;
    final surfaces = report.surfaces;
    final spots = report.spots;
    final sessions = ref.watch(screeningSessionsProvider).valueOrNull ??
        const <ScreeningSession>[];
    // Opened from the history, this page sits above the shell Rabi lives in.
    final chat = AiChatScope.maybeRead(context);
    final trend = ScanTrend.of(sessions, currentId: widget.sessionId);
    final patient = _patientFrom(
      ref.watch(dentalProfileProvider).valueOrNull,
      ref.watch(dentalRecordsProvider),
      sessions,
    );
    final stored = _stored(sessions);
    final answers = answersIn(
      report,
      (stored ?? widget.saved)?.findingAnswers ?? const [],
    );
    final plan = CarePlan.of(report, patient, trend, answers: answers);
    // Answers are saved against the stored scan, so only one can take them.
    final answerTo = stored?.id;
    final hasContext = plan.links.isNotEmpty ||
        patient.records.isNotEmpty ||
        patient.recordsUnavailable ||
        patient.symptomFacts.isNotEmpty ||
        patient.treatmentFacts.isNotEmpty ||
        patient.backgroundFacts.isNotEmpty;

    final sections = <Widget>[
      if (plan.isEmergency) EmergencyBanner(plan: plan, at: widget.at),
      ReportHero(
        report: report,
        plan: plan,
        context: patient,
        trend: trend,
        status: widget.status,
        date: widget.date,
        time: DentraDates.time(widget.at),
        leading: widget.leading,
        focus: _focus,
        onSeeSpot: _seeSpot,
      ),
      if (issues.isNotEmpty)
        RetakeList(issues: issues, imageOf: widget.imageOf),
      if (spots.isNotEmpty)
        _Section(
          key: _signsKey,
          heading: ReportHeading(
            report.signCount == 0 ? 'Faint signs to watch' : 'What we spotted',
            subtitle: report.signCount == 0
                ? 'On your own photos, one at a time.'
                : 'Each marked tooth on your own photo, what it could mean and '
                    'what to do.',
          ),
          child: SignsSection(
            report: report,
            guidance: plan.teeth,
            imageOf: widget.imageOf,
            focus: _focus,
            onAnswer: answerTo == null
                ? null
                : (findingId, pain) => _answer(answerTo, findingId, pain),
            onLearnMore: _learnMore,
          ),
        ),
      if (hasContext)
        _Section(
          heading: const ReportHeading(
            'You and this scan',
            subtitle: 'How your answers and records sit with your photos. None '
                'of this changes what the check saw.',
          ),
          child: ContextSection(plan: plan, patient: patient),
        ),
      if (read || plan.steps.isNotEmpty)
        _Section(
          heading: const ReportHeading('What to do next'),
          child: NextSteps(plan: plan, context_: patient, date: widget.date),
        ),
      if (read)
        ReportActions(
          onDownload: _download,
          downloading: _downloading,
          onAskRabi: !widget.showActions || chat == null
              ? null
              : () => _askRabi(chat, patient, plan),
          onClinics: widget.showActions ? widget.onClinics : null,
        ),
      if (read && surfaces != null)
        _Section(
          heading: const ReportHeading('What this scan covered'),
          child: GlassCard(
            width: double.infinity,
            borderRadius: BorderRadius.circular(24),
            padding: const EdgeInsets.all(16),
            child: CoverageRings(
              rows: [
                for (final (surface, done, unread) in surfaces)
                  (
                    surface.label,
                    done,
                    6,
                    unread > 0 && done == 0
                        ? 'Saved, can\'t be read yet'
                        : done == 0
                            ? 'No photo yet'
                            : null,
                  ),
              ],
            ),
          ),
        ),
      if (read)
        _Section(
          heading: const ReportHeading(
            'What the check looked for',
            subtitle: 'What it marked of each, and what it can\'t read yet.',
          ),
          child: FindingsByType(report: report),
        ),
      if (read)
        _Section(
          heading: const ReportHeading('Over time'),
          child: TrendSection(trend: trend),
        ),
      if (read)
        const _Section(
          heading: ReportHeading('How decay grows'),
          child: DecayStages(),
        ),
      _Section(
        heading: ReportHeading(
          'Your photos',
          subtitle: report.photoIds
                  .any((id) => hardToSeeViews.contains(baseRegionId(id)))
              ? 'Back molars and inner sides first: the teeth you can\'t '
                  'easily see yourself.'
              : null,
        ),
        child: ReportPhotoRow(
          photoIds: report.photoIds,
          imageOf: widget.imageOf,
          report: report,
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, section) in sections.indexed) ...[
          if (i > 0) const SizedBox(height: 24),
          Reveal(
            delay: Duration(milliseconds: 80 * i.clamp(0, 4)),
            child: section,
          ),
        ],
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({super.key, required this.heading, required this.child});

  final Widget heading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading,
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

/// What Rabi is told, so its answer is about these real results. What the user
/// [reported] is marked as theirs, so it isn't taken for something the check saw.
String rabiPromptFor(
  ScreeningReport report, {
  List<String> reported = const [],
}) {
  final seen = [
    for (final s in report.spots)
      '- ${s.finding.label}: ${s.where}, ${s.strength.label.toLowerCase()}'
          '${s.percent == null ? '' : ' (${s.percent}% model confidence)'}, '
          'in the ${s.photo.label} photo',
  ];
  final steps = [
    for (final r in report.analysis.recommendations)
      '- ${r.title}: ${r.detail}',
  ];
  return 'I just finished a DENTRA screening from my own photos. It describes '
      'general areas of the mouth rather than specific teeth, and it can\'t '
      'tell how far decay has gone.\n'
      '${report.photoIds.map(baseRegionId).toSet().length} of '
      '${scanRegions.length} views captured, ${report.photosRead} photos read.\n'
      'Summary: ${report.analysis.summary}\n'
      'What was seen:\n${seen.isEmpty ? '- Nothing that needs attention.' : seen.join('\n')}\n'
      'Suggested next steps:\n${steps.isEmpty ? '- None.' : steps.join('\n')}\n'
      '${reported.isEmpty ? '' : 'What I told DENTRA myself (not detected by the '
          'check):\n${reported.map((l) => '- $l').join('\n')}\n'}'
      'Explain what this means in plain language and what I should do next. '
      'Remind me this is a screening, not a diagnosis.';
}
