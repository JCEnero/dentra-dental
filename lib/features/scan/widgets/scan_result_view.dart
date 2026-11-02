import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../dental_profile/providers/dental_profile_providers.dart';
import '../../dental_profile/widgets/prompt_care_note.dart';
import '../data/scan_regions.dart';
import '../data/scan_report.dart';
import '../providers/scan_session_provider.dart';
import '../services/screening_analysis_service.dart';
import 'report/report_photos.dart';
import 'report/scan_report_view.dart';
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

  ImageProvider? _imageOf(String photoId) {
    final bytes = session.captures[photoId]?.bytes;
    return bytes == null ? null : MemoryImage(bytes);
  }

  @override
  Widget build(BuildContext context) {
    final details = session.analysis?.analysis;
    final report =
        details == null ? null : ScreeningReport(details, session.photoIds);
    final retakes = details?.qualityIssues.isNotEmpty ?? false;
    final n = session.capturedViewCount;
    final total = scanRegions.length;
    final status = retakes
        ? 'Some photos need a retake'
        : n == total
            ? 'Scan complete'
            : 'Partial scan saved';
    // No success check while some photos couldn't be used.
    final Widget mark = ScanIconDisc(
      retakes ? Icons.refresh_rounded : Icons.check_rounded,
      size: 42,
      iconSize: 22,
    );
    final date = _formatDate(session.finishedAt ?? DateTime.now());

    // With no model behind it, a clean result would say nothing.
    final Widget body = report != null && !report.detectorOff
        ? ScanReportView(
            report: report,
            imageOf: _imageOf,
            status: status,
            date: date,
            viewsTaken: n,
            leading: mark,
            sessionId: session.analysis?.savedSession?.id,
            showActions: !retakes,
            onClinics:
                onNavigate == null ? null : () => onNavigate!(_clinicsTab),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Reveal(
                child: _SummaryCard(
                  status: status,
                  date: '$date · $n of $total views',
                  mark: mark,
                  summary: session.analysis?.summary,
                  notConnected: !analysisAvailable ||
                      session.analysisFailure == AnalysisFailure.unavailable,
                ),
              ),
              if (retakes) ...[
                const SizedBox(height: 12),
                Reveal(
                  delay: const Duration(milliseconds: 180),
                  child: RetakeList(
                    issues: details!.qualityIssues,
                    imageOf: _imageOf,
                  ),
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
                // Nothing was looked for, so no photo gets a result.
                child: ReportPhotoRow(
                  photoIds: session.photoIds,
                  imageOf: _imageOf,
                ),
              ),
            ],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        body,
        const _ReportedCareNote(),
        const SizedBox(height: 14),
        const ScanDisclaimer(),
      ],
    );
  }

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
}

/// How the scan went, for runs with no analysis to report on.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.status,
    required this.date,
    required this.mark,
    required this.summary,
    required this.notConnected,
  });

  final String status;
  final String date;
  final Widget mark;
  final String? summary;
  final bool notConnected;

  @override
  Widget build(BuildContext context) {
    return _Card(
      children: [
        Row(
          children: [
            mark,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    liveRegion: true,
                    child: Text(status, style: _title),
                  ),
                  const SizedBox(height: 2),
                  Text(date, style: _body),
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
      ],
    );
  }
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

final TextStyle _title = GoogleFonts.outfit(
  fontSize: 18,
  fontWeight: FontWeight.w800,
  color: AppColors.navy,
  letterSpacing: -0.2,
);
final TextStyle _body = GoogleFonts.outfit(
  fontSize: 13,
  color: AppColors.secondaryText,
  height: 1.45,
);
