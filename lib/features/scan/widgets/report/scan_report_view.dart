import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ai_assistant/ai_chat_controller.dart';
import '../../../screening/data/models/screening_session.dart';
import '../../../screening/providers/screening_sessions_provider.dart';
import '../../data/scan_regions.dart';
import '../../data/scan_report.dart';
import '../scan_motion.dart';
import '../scan_theme.dart';
import 'coverage_grid.dart';
import 'hidden_views.dart';
import 'mouth_map.dart';
import 'next_steps.dart';
import 'report_fold.dart';
import 'report_hero.dart';
import 'report_photos.dart';
import 'report_style.dart';
import 'signs_section.dart';
import 'trend_section.dart';
import 'understand_section.dart';

/// The whole result of one analysis. Up front only what everyone needs: the
/// result, the map, the marked photos and what to do. The rest waits in closed
/// rows. Used right after a scan and when opening one from the history.
class ScanReportView extends ConsumerStatefulWidget {
  const ScanReportView({
    super.key,
    required this.report,
    required this.imageOf,
    required this.status,
    required this.date,
    required this.viewsTaken,
    required this.leading,
    this.sessionId,
    this.onClinics,
    this.showActions = true,
  });

  final ScreeningReport report;
  final ImageProvider? Function(String photoId) imageOf;

  /// How the scan went, e.g. "Scan complete".
  final String status;
  final String date;
  final int viewsTaken;
  final Widget leading;

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

  void _askRabi(AiChatController chat) {
    chat.open();
    chat.sendMessage(
      'Can you explain my scan results?',
      prompt: rabiPromptFor(widget.report),
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final issues = report.analysis.qualityIssues;
    final read = report.photosRead > 0;
    final notes = report.analysis.recommendations;
    final hidden = HiddenViews.photosIn(report);
    final coverage = report.coverage;
    final spots = report.spots;
    final sessions = ref.watch(screeningSessionsProvider).valueOrNull ??
        const <ScreeningSession>[];
    // Opened from the history, this page sits above the shell Rabi lives in.
    final chat = AiChatScope.maybeRead(context);
    final trend = ScanTrend.of(sessions, currentId: widget.sessionId);
    final photos = ReportPhotoRow(
      photoIds: report.photoIds,
      imageOf: widget.imageOf,
      report: report,
    );

    final sections = <Widget>[
      ReportHero(
        report: report,
        status: widget.status,
        date: widget.date,
        viewsTaken: widget.viewsTaken,
        leading: widget.leading,
      ),
      if (issues.isNotEmpty) RetakeList(issues: issues, imageOf: widget.imageOf),
      if (read)
        _Section(
          heading: const ReportHeading(
            'Your mouth map',
            subtitle: 'General areas, not exact teeth.',
          ),
          child: MouthMap(report: report, onSeeSpot: _seeSpot),
        ),
      if (spots.isNotEmpty)
        _Section(
          key: _signsKey,
          heading: ReportHeading(
            report.signCount == 0 ? 'Faint signs to watch' : 'What we spotted',
            subtitle: '${spots.first.finding.label}, marked on your photos.',
          ),
          child: SignsSection(
            report: report,
            imageOf: widget.imageOf,
            focus: _focus,
          ),
        ),
      if (notes.isNotEmpty)
        _Section(
          heading: const ReportHeading('What to do next'),
          child: NextSteps(recommendations: notes),
        ),
      if (widget.showActions && read)
        ReportActions(
          onAskRabi: chat == null ? null : () => _askRabi(chat),
          onClinics: widget.onClinics,
        ),
      if (!read)
        _Section(
          heading: const ReportHeading('Your photos'),
          child: photos,
        )
      else
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ReportHeading('More about this scan'),
            const SizedBox(height: 10),
            for (final (i, fold) in [
              if (hidden.isNotEmpty)
                ReportFold(
                  icon: Icons.visibility_outlined,
                  title: 'Teeth you can\'t easily see',
                  summary: '${hidden.length} '
                      '${hidden.length == 1 ? 'photo' : 'photos'} of back molars '
                      'and inner sides',
                  child: HiddenViews(report: report, imageOf: widget.imageOf),
                ),
              if (coverage != null)
                ReportFold(
                  icon: Icons.grid_view_rounded,
                  title: 'What this scan covered',
                  summary: '${coverage.values.where((c) => c.read).length} of '
                      '${coverage.length} tooth surfaces read',
                  child: CoverageGrid(coverage: coverage),
                ),
              ReportFold(
                icon: Icons.show_chart_rounded,
                title: 'Over time',
                summary: trend.oneLine,
                child: TrendSection(trend: trend),
              ),
              const ReportFold(
                icon: Icons.menu_book_outlined,
                title: 'Understand your result',
                summary: 'How decay grows, and what this check reads',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DecayStages(),
                    SizedBox(height: 16),
                    WhatItReads(),
                  ],
                ),
              ),
              ReportFold(
                icon: Icons.photo_library_outlined,
                title: 'Your photos',
                summary: '${report.photoIds.length} '
                    '${report.photoIds.length == 1 ? 'photo' : 'photos'} from '
                    'this scan',
                child: photos,
              ),
            ].indexed) ...[
              if (i > 0) const SizedBox(height: 10),
              fold,
            ],
          ],
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, section) in sections.indexed) ...[
          if (i > 0) const SizedBox(height: 22),
          Reveal(
            delay: Duration(milliseconds: 80 * i.clamp(0, 6)),
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

/// What Rabi is told, so its answer is about these real results.
String rabiPromptFor(ScreeningReport report) {
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
      'Explain what this means in plain language and what I should do next. '
      'Remind me this is a screening, not a diagnosis.';
}
