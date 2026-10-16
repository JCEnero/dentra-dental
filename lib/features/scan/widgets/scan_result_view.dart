import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../data/scan_regions.dart';
import '../providers/scan_session_provider.dart';
import '../services/screening_analysis_service.dart';
import 'scan_feedback_panel.dart';
import 'scan_motion.dart';

/// Saving, analyzing and completion views for a finished session.
class ScanResultView extends StatelessWidget {
  const ScanResultView({
    super.key,
    required this.session,
    required this.analysisAvailable,
  });

  final ScanSessionState session;

  /// Whether an analysis backend is configured in this build.
  final bool analysisAvailable;

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

class _Analyzing extends StatelessWidget {
  const _Analyzing({super.key, required this.session});
  final ScanSessionState session;

  @override
  Widget build(BuildContext context) {
    final n = session.capturedCount;
    return Semantics(
      liveRegion: true,
      label: 'Analyzing images',
      child: _Card(
        children: [
          Text('Analyzing images…', style: _title),
          const SizedBox(height: 4),
          Text(
            '$n image${n == 1 ? '' : 's'} · This can take up to a minute',
            style: _body,
          ),
          const SizedBox(height: 16),
          _ThumbGrid(session: session, sweeping: true),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: const LinearProgressIndicator(
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
  });

  final ScanSessionState session;
  final bool analysisAvailable;

  @override
  Widget build(BuildContext context) {
    final n = session.capturedCount;
    final total = scanRegions.length;
    final at = session.finishedAt ?? DateTime.now();
    final summary = session.analysis?.summary;

    return Column(
      children: [
        _Card(
          children: [
            Row(
              children: [
                const _SuccessMark(),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        liveRegion: true,
                        child: Text(
                          n == total ? 'Scan complete' : 'Partial scan saved',
                          style: _title,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_formatDate(at)} · $n of $total regions',
                        style: _body,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _ThumbGrid(session: session, showMissing: true),
            if (summary != null) ...[
              const SizedBox(height: 16),
              Text('AI-assisted summary', style: _subtitle),
              const SizedBox(height: 4),
              Text(summary, style: _body.copyWith(color: AppColors.navy)),
            ] else if (!analysisAvailable) ...[
              const SizedBox(height: 14),
              Text(
                "AI analysis isn't connected in this version yet, so no "
                'findings were generated.',
                style: _body,
              ),
            ],
          ],
        ),
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
              'DENTRA provides AI-assisted screening information and does not '
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.g2.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
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
    this.showMissing = false,
  });

  final ScanSessionState session;
  final bool sweeping;
  final bool showMissing;

  @override
  Widget build(BuildContext context) {
    final regions = [
      for (final r in scanRegions)
        if (showMissing || session.isCaptured(r.id)) r,
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
