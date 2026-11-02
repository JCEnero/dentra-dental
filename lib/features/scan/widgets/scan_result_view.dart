import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../ai_assistant/ai_chat_controller.dart';
import '../../dental_profile/providers/dental_profile_providers.dart';
import '../../dental_profile/widgets/prompt_care_note.dart';
import '../../screening/data/models/screening_session.dart';
import '../data/scan_outcomes.dart';
import '../data/scan_regions.dart';
import '../providers/scan_session_provider.dart';
import '../services/screening_analysis_service.dart';
import 'scan_feedback_panel.dart';
import 'scan_motion.dart';
import 'scan_theme.dart';

/// Saving, analyzing and completion views for a finished session. Everything
/// shown as a result comes from the real analysis.
class ScanResultView extends StatelessWidget {
  const ScanResultView({
    super.key,
    required this.session,
    required this.analysisAvailable,
    this.onNavigate,
  });

  final ScanSessionState session;

  /// Whether an analysis backend is configured in this build.
  final bool analysisAvailable;

  /// Switches app tabs, e.g. to Clinics.
  final ValueChanged<int>? onNavigate;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: ScanMotion.of(context, ScanMotion.slow),
      transitionBuilder: ScanMotion.fadeRise,
      child: switch (session.finishPhase) {
        FinishPhase.saving => const _Saving(key: ValueKey('saving')),
        FinishPhase.analyzing =>
          _Analyzing(key: const ValueKey('analyzing'), session: session),
        FinishPhase.analysisFailed => _AnalysisFailed(
            key: ValueKey('failed-${session.analysisFailure}'),
            session: session,
          ),
        _ => _Done(
            key: const ValueKey('done'),
            session: session,
            analysisAvailable: analysisAvailable,
            onNavigate: onNavigate,
          ),
      },
    );
  }
}

class _Saving extends StatelessWidget {
  const _Saving({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Saving your scan',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Column(
            children: [
              const SizedBox.square(
                dimension: 28,
                child: CircularProgressIndicator(
                    strokeWidth: 2.6, color: AppColors.g2),
              ),
              const SizedBox(height: 14),
              Text('Saving your scan…', style: _body),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when the 3D scan was closed while the run keeps going.
class _Analyzing extends StatelessWidget {
  const _Analyzing({super.key, required this.session});
  final ScanSessionState session;

  @override
  Widget build(BuildContext context) {
    final n = session.capturedCount;
    final progress = session.analysisProgress;
    return Semantics(
      liveRegion: true,
      label: 'Analyzing images',
      child: _Card(
        children: [
          Text('Analyzing images…', style: _title),
          const SizedBox(height: 4),
          Text(
            progress == null
                ? '$n image${n == 1 ? '' : 's'} · This can take a couple of '
                    'minutes'
                : '${progress.done} of ${progress.total} images read',
            style: _body,
          ),
          const SizedBox(height: 16),
          _ThumbGrid(session: session, sweeping: true),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress == null || progress.total == 0
                  ? null
                  : progress.done / progress.total,
              minHeight: 5,
              color: AppColors.g2,
              backgroundColor: AppColors.lavender,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalysisFailed extends StatelessWidget {
  const _AnalysisFailed({super.key, required this.session});
  final ScanSessionState session;

  @override
  Widget build(BuildContext context) {
    final message = switch (session.analysisFailure) {
      AnalysisFailure.offline =>
        "You seem to be offline. Check your connection and try again.",
      AnalysisFailure.timeout =>
        'Analysis is taking longer than expected. Please try again.',
      _ => "The analysis service isn't responding right now.",
    };
    return _Card(
      children: [
        Text('Analysis didn’t finish', style: _title),
        const SizedBox(height: 4),
        Text('Your images are still here.', style: _body),
        const SizedBox(height: 14),
        _ThumbGrid(session: session),
        const SizedBox(height: 14),
        ScanFeedbackPanel(
            title: "Couldn't analyze your scan", message: message),
      ],
    );
  }
}

class _Done extends StatelessWidget {
  const _Done({
    super.key,
    required this.session,
    required this.analysisAvailable,
    this.onNavigate,
  });

  final ScanSessionState session;
  final bool analysisAvailable;
  final ValueChanged<int>? onNavigate;

  /// Index of the Clinics tab in `AppShell`.
  static const _clinicsTab = 3;

  @override
  Widget build(BuildContext context) {
    final details = session.analysis?.analysis;
    final outcomes =
        details == null ? null : outcomesOf(details, session.photoIds);
    final summary = session.analysis?.summary;
    final notConnected = !analysisAvailable ||
        session.analysisFailure == AnalysisFailure.unavailable;
    final issues = details?.qualityIssues ?? const <ScreeningQualityIssue>[];
    final notes = details?.recommendations ?? const <ScreeningRecommendation>[];
    final retakes = issues.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Reveal(
          child: _SummaryCard(
            session: session,
            summary: summary,
            outcomes: outcomes,
            needsRetake: retakes,
            notConnected: notConnected,
          ),
        ),
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 22),
          const Reveal(
            delay: Duration(milliseconds: 100),
            child: ScanSectionTitle('What to do next'),
          ),
          const SizedBox(height: 10),
          for (final (i, r) in notes.indexed) ...[
            Reveal(
              delay: Duration(milliseconds: 140 + 60 * i),
              child: _NextStepCard(recommendation: r),
            ),
            const SizedBox(height: 10),
          ],
        ],
        if (retakes) ...[
          const SizedBox(height: 12),
          Reveal(
            delay: const Duration(milliseconds: 180),
            child: _RetakeList(issues: issues),
          ),
        ],
        const SizedBox(height: 22),
        const Reveal(
          delay: Duration(milliseconds: 220),
          child: ScanSectionTitle('Your photos'),
        ),
        const SizedBox(height: 10),
        Reveal(
          delay: const Duration(milliseconds: 260),
          child: _PhotoResults(session: session, outcomes: outcomes),
        ),
        if (summary != null && !retakes) ...[
          const SizedBox(height: 16),
          Reveal(
            delay: const Duration(milliseconds: 300),
            child: _HelpActions(
              session: session,
              onClinics: onNavigate == null
                  ? null
                  : () => onNavigate!(_clinicsTab),
            ),
          ),
        ],
        const _ReportedCareNote(),
        const SizedBox(height: 14),
        const ScanDisclaimer(),
      ],
    );
  }
}

/// The headline: how the scan went, in the analysis's own words, and how many
/// photos landed where.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.session,
    required this.summary,
    required this.outcomes,
    required this.needsRetake,
    required this.notConnected,
  });

  final ScanSessionState session;
  final String? summary;
  final Map<String, ViewOutcome>? outcomes;
  final bool needsRetake;
  final bool notConnected;

  static String _formatDate(DateTime d) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final n = session.capturedViewCount;
    final total = scanRegions.length;
    final at = session.finishedAt ?? DateTime.now();
    final values = outcomes?.values ?? const <ViewOutcome>[];
    int count(bool Function(ViewOutcome) test) => values.where(test).length;
    final notChecked = count((o) => o == ViewOutcome.notChecked);

    return _Card(
      children: [
        Row(
          children: [
            // No success check while some photos couldn't be used.
            needsRetake ? const _RetakeMark() : const _SuccessMark(),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    liveRegion: true,
                    child: Text(
                      needsRetake
                          ? 'Some photos need a retake'
                          : n == total
                              ? 'Scan complete'
                              : 'Partial scan saved',
                      style: _title,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('${_formatDate(at)} · $n of $total views', style: _body),
                ],
              ),
            ),
          ],
        ),
        if (summary != null) ...[
          const SizedBox(height: 14),
          Semantics(
            label: 'Screening summary: $summary',
            excludeSemantics: true,
            child: Text(
              summary!,
              style: GoogleFonts.outfit(
                fontSize: 14.5,
                height: 1.45,
                color: AppColors.navy,
              ),
            ),
          ),
        ] else if (notConnected) ...[
          const SizedBox(height: 14),
          Text(
            "Smart analysis isn't connected in this version yet, so no "
            'findings were generated.',
            style: _body,
          ),
        ],
        if (values.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            [
              '${count((o) => o == ViewOutcome.clear)} no concerns',
              '${count((o) => o == ViewOutcome.finding || o == ViewOutcome.urgent)} to check',
              '${count((o) => o == ViewOutcome.retake)} to retake',
              if (notChecked > 0) '$notChecked not read yet',
            ].join(' · '),
            style: figureText(
              size: 12.5,
              weight: FontWeight.w600,
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ],
    );
  }
}

/// One next step from the analysis, and the photos behind it. Urgency is
/// spelled out in words, not only shown by color.
class _NextStepCard extends StatelessWidget {
  const _NextStepCard({required this.recommendation});
  final ScreeningRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final r = recommendation;
    final (label, color) = switch (r.urgency) {
      'prompt' => ('See a dentist promptly', AppColors.navy),
      'soon' => ('Book a visit soon', ScanColors.check),
      _ => ('At your next check-up', AppColors.primary),
    };
    final seenIn = [
      for (final id in r.regionIds)
        if (findScanRegion(id) case final region?) region.label,
    ];
    return GlassCard(
      borderRadius: const BorderRadius.all(Radius.circular(20)),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.13),
            ),
            child: Icon(
              r.code == 'braces_seen'
                  ? Icons.info_outline_rounded
                  : Icons.visibility_outlined,
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.title, style: _subtitle),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: _body.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(r.detail, style: _body),
                if (seenIn.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Seen in: ${seenIn.join(', ')}',
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Every view and what came of it, in one sliding row of the real photos.
class _PhotoResults extends StatelessWidget {
  const _PhotoResults({required this.session, required this.outcomes});

  final ScanSessionState session;
  final Map<String, ViewOutcome>? outcomes;

  @override
  Widget build(BuildContext context) {
    final rows = regionsForSession(session.photoIds);
    final details = session.analysis?.analysis;
    return SizedBox(
      height: 92 + 44 * MediaQuery.textScalerOf(context).scale(1),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        clipBehavior: Clip.none,
        itemCount: rows.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) => SizedBox(
          width: 112,
          child: _PhotoTile(
            region: rows[i],
            bytes: session.captures[rows[i].id]?.bytes,
            outcome: outcomes?[rows[i].id],
            finding: details?.findings
                .where((f) => f.regionId == rows[i].id)
                .firstOrNull
                ?.label,
          ),
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.region,
    required this.bytes,
    required this.outcome,
    required this.finding,
  });

  final ScanRegion region;
  final Uint8List? bytes;
  final ViewOutcome? outcome;

  /// What was found in this photo, in the analysis's words.
  final String? finding;

  @override
  Widget build(BuildContext context) {
    final taken = bytes != null;
    final (String status, Color color) = switch (outcome) {
      ViewOutcome.clear => ('No concerns seen', ScanColors.clearInk),
      ViewOutcome.finding => (finding ?? 'Worth checking', ScanColors.check),
      ViewOutcome.urgent => (finding ?? 'Worth checking', AppColors.navy),
      ViewOutcome.retake => ('Needs a retake', AppColors.secondaryText),
      ViewOutcome.notChecked => ('Not read yet', AppColors.secondaryText),
      null => (taken ? 'Saved' : 'Not taken', AppColors.secondaryText),
    };
    return Semantics(
      label: '${region.label}: $status',
      excludeSemantics: true,
      child: GlassCard(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        padding: const EdgeInsets.all(5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: taken
                    ? Image.memory(
                        bytes!,
                        fit: BoxFit.cover,
                        cacheWidth: 300,
                        gaplessPlayback: true,
                        errorBuilder: (_, __, ___) =>
                            const ColoredBox(color: AppColors.lightLavender),
                      )
                    : ColoredBox(
                        color: AppColors.navy.withValues(alpha: 0.05),
                        child: Icon(
                          Icons.hide_image_outlined,
                          size: 18,
                          color: AppColors.secondaryText.withValues(alpha: 0.6),
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(3, 5, 3, 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    region.short,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: taken ? AppColors.navy : AppColors.secondaryText,
                    ),
                  ),
                  Text(
                    status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Where to go from here: nearby clinics, or asking Rabi about the results.
class _HelpActions extends StatelessWidget {
  const _HelpActions({required this.session, required this.onClinics});

  final ScanSessionState session;
  final VoidCallback? onClinics;

  void _askRabi(BuildContext context) {
    final chat = AiChatScope.read(context);
    chat.open();
    chat.sendMessage(
      'Can you explain my scan results?',
      prompt: _rabiPrompt(session),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassCard(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          onTap: () => _askRabi(context),
          padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
          child: Row(
            children: [
              // Rabi's bunny mark, as in the chat.
              SizedBox.square(
                dimension: 36,
                child: Image.asset(
                  'assets/images/rabi_avatar.png',
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: AppColors.g2,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Ask Rabi about my results',
                  style: GoogleFonts.outfit(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.g2),
            ],
          ),
        ),
        if (onClinics != null) ...[
          const SizedBox(height: 10),
          GlassCard(
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            onTap: onClinics,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 22, color: AppColors.g2),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Find clinics nearby',
                    style: GoogleFonts.outfit(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.g2),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// What Rabi is told, so its answer is about these real results.
String _rabiPrompt(ScanSessionState session) {
  final details = session.analysis?.analysis;
  final seen = [
    for (final f in details?.findings ?? const <ScreeningFinding>[])
      '- ${f.label}${f.regionId == null ? '' : ' (${findScanRegion(f.regionId!)?.label ?? f.regionId})'}',
  ];
  final steps = [
    for (final r in details?.recommendations ?? const <ScreeningRecommendation>[])
      '- ${r.title}: ${r.detail}',
  ];
  return 'I just finished a DENTRA screening from my own photos. It describes '
      'general areas of the mouth rather than specific teeth.\n'
      '${session.capturedViewCount} of ${scanRegions.length} views captured.\n'
      'Summary: ${session.analysis?.summary ?? 'None'}\n'
      'What was seen:\n${seen.isEmpty ? '- Nothing that needs attention.' : seen.join('\n')}\n'
      'Suggested next steps:\n${steps.isEmpty ? '- None.' : steps.join('\n')}\n'
      'Explain what this means in plain language and what I should do next. '
      'Remind me this is a screening, not a diagnosis.';
}

/// Care advice from what the user reported (severe discomfort in their
/// dental profile). Shown next to the result, never folded into it, and
/// no screening result removes it.
class _ReportedCareNote extends ConsumerWidget {
  const _ReportedCareNote();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(dentalProfileProvider).valueOrNull;
    if (profile == null || !profile.answers.needsPromptCare) {
      return const SizedBox.shrink();
    }
    return const Padding(
      padding: EdgeInsets.only(top: 14),
      child: PromptCareNote(),
    );
  }
}

/// The screening disclaimer carried over from the original scan page.
class ScanDisclaimer extends StatelessWidget {
  const ScanDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.lightLavender,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 15, color: AppColors.primary.withValues(alpha: 0.8)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'DENTRA provides smart screening information and does not '
              'replace professional dental evaluation.',
              style: GoogleFonts.outfit(
                fontSize: 11.5,
                color: AppColors.primary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pieces ──────────────────────────────────────────────────────

/// Photos the quality check couldn't use, with how to take them again.
class _RetakeList extends StatelessWidget {
  const _RetakeList({required this.issues});
  final List<ScreeningQualityIssue> issues;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: const BorderRadius.all(Radius.circular(20)),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Retake for a better check', style: _subtitle),
          for (final issue in issues)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${scanRegionById(issue.regionId).label}'
                '${issue.modality == 'nir' ? ' (light scan)' : ''}: '
                '${issue.message}',
                style: _body,
              ),
            ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      borderRadius: BorderRadius.circular(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

/// Captured photos per region; missing regions shown as empty slots.
class _ThumbGrid extends StatelessWidget {
  const _ThumbGrid({
    required this.session,
    this.sweeping = false,
  });

  final ScanSessionState session;
  final bool sweeping;

  @override
  Widget build(BuildContext context) {
    final regions = [
      for (final r in scanRegions) ...[
        if (session.isCaptured(r.id)) r,
        if (session.isCaptured(secondPhotoId(r.id))) r.secondPhoto,
      ],
    ];
    return LayoutBuilder(builder: (context, constraints) {
      const gap = 8.0;
      final columns = constraints.maxWidth < 300 ? 2 : 3;
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap + 2,
        children: [
          for (final r in regions)
            SizedBox(
              width: width,
              child: _Thumb(
                region: r,
                bytes: session.captures[r.id]?.bytes,
                sweeping: sweeping,
              ),
            ),
        ],
      );
    });
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.region,
    required this.bytes,
    required this.sweeping,
  });

  final ScanRegion region;
  final Uint8List? bytes;
  final bool sweeping;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Semantics(
      label: bytes == null
          ? '${region.label}, not captured'
          : '${region.label}, captured',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: bytes == null
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.offWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Center(
                        child:
                            Icon(Icons.remove_rounded, color: AppColors.border),
                      ),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        LayoutBuilder(
                          builder: (context, c) => Image.memory(
                            bytes!,
                            fit: BoxFit.cover,
                            cacheWidth: (c.maxWidth * dpr).round(),
                            gaplessPlayback: true,
                          ),
                        ),
                        if (sweeping) const _Sweep(),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            region.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: bytes == null ? AppColors.secondaryText : AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft light band passing over a photo while analysis runs. Lives only as
/// long as the analyzing view; static under reduced motion.
class _Sweep extends StatefulWidget {
  const _Sweep();

  @override
  State<_Sweep> createState() => _SweepState();
}

class _SweepState extends State<_Sweep> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ScanMotion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value * 1.6 - 0.3;
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.g1.withValues(alpha: 0),
                  AppColors.g1.withValues(alpha: 0.35),
                  AppColors.g1.withValues(alpha: 0),
                ],
                stops: [
                  (t - 0.15).clamp(0.0, 1.0),
                  t.clamp(0.0, 1.0),
                  (t + 0.15).clamp(0.0, 1.0),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Shown instead of the success check when photos need taking again.
class _RetakeMark extends StatelessWidget {
  const _RetakeMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        color: AppColors.lightLavender,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.refresh_rounded, color: AppColors.primary),
    );
  }
}

/// A check that draws itself once.
class _SuccessMark extends StatelessWidget {
  const _SuccessMark();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: ScanMotion.of(context, const Duration(milliseconds: 650)),
      curve: ScanMotion.curve,
      builder: (context, t, _) => SizedBox.square(
        dimension: 48,
        child: CustomPaint(painter: _CheckPainter(t)),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(
      c,
      r * (0.85 + 0.15 * t),
      Paint()
        ..shader = AppColors.primaryGradient
            .createShader(Rect.fromCircle(center: c, radius: r)),
    );
    final path = Path()
      ..moveTo(size.width * 0.3, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.66)
      ..lineTo(size.width * 0.71, size.height * 0.37);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * t),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.white,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.t != t;
}

final TextStyle _title = GoogleFonts.outfit(
  fontSize: 18,
  fontWeight: FontWeight.w800,
  color: AppColors.navy,
  letterSpacing: -0.2,
);
final TextStyle _subtitle = GoogleFonts.outfit(
  fontSize: 14,
  fontWeight: FontWeight.w700,
  color: AppColors.navy,
);
final TextStyle _body = GoogleFonts.outfit(
  fontSize: 13,
  color: AppColors.secondaryText,
  height: 1.45,
);
