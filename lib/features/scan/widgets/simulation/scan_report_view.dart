import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_glass.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/dentra_dates.dart';
import '../../../../shared/widgets/dentra_glass_ui.dart';
import '../../../../shared/widgets/dentra_note_card.dart';
import '../../../../shared/widgets/dentra_page_header.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../ai_assistant/ai_chat_controller.dart';
import '../../data/capture_regions.dart';
import '../../data/mock_scan_report.dart';
import '../../providers/scan_flow_provider.dart';
import '../scan_motion.dart';
import 'scan_sim_theme.dart';

/// Results of the simulated scan: score, what was found in each general
/// area of the mouth, region breakdown, metrics, recommendations and
/// next steps. Nothing points at a specific tooth.
class ScanReportView extends ConsumerStatefulWidget {
  const ScanReportView({
    super.key,
    required this.report,
    required this.onScanAgain,
    this.onNavigate,
  });

  final ScanReport report;
  final VoidCallback onScanAgain;

  /// Switches app tabs (used for "Find Clinics Nearby").
  final ValueChanged<int>? onNavigate;

  @override
  ConsumerState<ScanReportView> createState() => _ScanReportViewState();
}

class _ScanReportViewState extends ConsumerState<ScanReportView> {
  /// Index of the Clinics tab in `AppShell`.
  static const _clinicsTab = 3;

  bool _saved = false;

  void _askRabi() {
    final chat = AiChatScope.read(context);
    chat.open();
    chat.sendMessage(
      'Can you explain my scan results?',
      prompt: _rabiPrompt(widget.report),
    );
  }

  void _save() {
    setState(() => _saved = true);
    showDentraSnack(context, 'Report #${widget.report.id} saved');
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final score = [Reveal(child: _ScoreCard(report: report))];
    final findings = [
      Reveal(
        delay: const Duration(milliseconds: 200),
        child: SimSectionTitle(
          'What we found',
          trailing: _CountPill('${report.findings.length}'),
        ),
      ),
      const SizedBox(height: 10),
      for (var i = 0; i < report.findings.length; i++) ...[
        Reveal(
          delay: Duration(milliseconds: 240 + 60 * i),
          child: _FindingCard(finding: report.findings[i]),
        ),
        const SizedBox(height: 10),
      ],
      if (report.countOf(AreaHealth.healthy) > 0)
        Reveal(
          delay: Duration(milliseconds: 240 + 60 * report.findings.length),
          child: _OthersTile(report: report),
        ),
    ];
    final breakdown = [
      const Reveal(
        delay: Duration(milliseconds: 300),
        child: SimSectionTitle('Region Breakdown'),
      ),
      const SizedBox(height: 10),
      Reveal(
        delay: const Duration(milliseconds: 340),
        child: _RegionBreakdown(report: report),
      ),
    ];
    final metrics = [
      const Reveal(
        delay: Duration(milliseconds: 80),
        child: SimSectionTitle('Health Metrics'),
      ),
      const SizedBox(height: 10),
      Reveal(
        delay: const Duration(milliseconds: 120),
        child: _MetricGrid(metrics: report.metrics),
      ),
    ];
    final nextSteps = [
      const Reveal(
        delay: Duration(milliseconds: 460),
        child: SimSectionTitle('Recommendations'),
      ),
      const SizedBox(height: 10),
      Reveal(
        delay: const Duration(milliseconds: 500),
        child: _Recommendations(items: report.recommendations),
      ),
      const SizedBox(height: 26),
      Reveal(
        delay: const Duration(milliseconds: 540),
        child: _Actions(
          saved: _saved,
          onBook: widget.onNavigate == null
              ? null
              : () => widget.onNavigate!(_clinicsTab),
          onAskRabi: _askRabi,
          onSave: _saved ? null : _save,
          onScanAgain: widget.onScanAgain,
        ),
      ),
      const SizedBox(height: 16),
      const Reveal(
        delay: Duration(milliseconds: 580),
        child: DentraNoteCard(
          icon: Icons.health_and_safety_outlined,
          message: 'This is a smart screening, not a medical '
              'diagnosis. Please consult a licensed dentist. Results in '
              'this demo are simulated.',
        ),
      ),
    ];
    const gap = SizedBox(height: 26);

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DentraPageHeader(title: 'Scan Results'),
            Divider(height: 1, thickness: 1, color: AppGlass.divider),
            const SizedBox(height: 16),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
                  child: LayoutBuilder(builder: (context, constraints) {
                    // Two columns on wide screens: the overview on the
                    // left, what to do about it on the right.
                    if (constraints.maxWidth >= 920) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ...score,
                                gap,
                                ...metrics,
                                gap,
                                ...breakdown,
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 6,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [...findings, gap, ...nextSteps],
                            ),
                          ),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ...score,
                        gap,
                        ...metrics,
                        gap,
                        ...findings,
                        gap,
                        ...breakdown,
                        gap,
                        ...nextSteps,
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What Rabi is told, so its answer is about these results.
String _rabiPrompt(ScanReport report) {
  final findings = report.findings.isEmpty
      ? '- Nothing that needs attention.'
      : report.findings
          .map((f) => '- ${f.condition} (${f.health.label.toLowerCase()}, '
              '${(f.confidence * 100).round()}% confidence): ${f.summary}')
          .join('\n');
  final tips = report.recommendations.map((r) => '- ${r.title}').join('\n');
  return 'I just finished a Dentra demo scan. The results are simulated '
      'sample data, not a real analysis, and they describe general areas '
      'of the mouth rather than specific teeth.\n'
      'Oral health score: ${report.score}/100 (${report.scoreHeadline}). '
      '${report.captured.length} of ${captureRegions.length} views captured.\n'
      'What was found:\n$findings\n'
      'Suggested next steps:\n$tips\n'
      'Explain what these findings mean in plain language and what I '
      'should do next. Remind me this is a screening, not a diagnosis.';
}

class _CountPill extends StatelessWidget {
  const _CountPill(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.lightLavender,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lavender),
      ),
      child: Text(text, style: figureText(size: 12, color: AppColors.g2)),
    );
  }
}

// ── Score ─────────────────────────────────────────────────────────

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.report});
  final ScanReport report;

  @override
  Widget build(BuildContext context) {
    final at = report.completedAt;
    final partial = report.captured.length < captureRegions.length;
    final unchecked = report.countOf(AreaHealth.notChecked);
    return GlassCard(
      borderRadius: const BorderRadius.all(Radius.circular(24)),
      borderWidth: 1.5,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _ScoreRing(score: report.score, size: 120),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ORAL HEALTH SCORE', style: capsLabel()),
                    const SizedBox(height: 4),
                    Text(
                      report.scoreHeadline,
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: AppColors.navy,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      report.scoreSummary,
                      style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        height: 1.35,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${DentraDates.medium(at)} · ${DentraDates.time(at)}\n'
                      'Scan #${report.id}',
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              for (final (i, h) in const [
                AreaHealth.attention,
                AreaHealth.monitor,
                AreaHealth.healthy,
              ].indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _CountTile(health: h, count: report.countOf(h))),
              ],
            ],
          ),
          if (partial) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 15, color: HealthColors.monitorInk),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Based on ${report.captured.length} of '
                    '${captureRegions.length} regions.'
                    '${switch (unchecked) {
                      0 => '',
                      1 => ' 1 area was not checked.',
                      final n => ' $n areas were not checked.',
                    }}',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: HealthColors.monitorInk,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// How many areas of the mouth landed in each group.
class _CountTile extends StatelessWidget {
  const _CountTile({required this.health, required this.count});
  final AreaHealth health;
  final int count;

  @override
  Widget build(BuildContext context) {
    final color = HealthColors.of(health);
    final label =
        health == AreaHealth.attention ? 'Attention' : health.label;
    return Semantics(
      label: '$count ${count == 1 ? 'area' : 'areas'} '
          '${label.toLowerCase()}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: AppColors.white.withValues(alpha: 0.5),
          border: Border.all(color: AppGlass.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '$count',
                  style: figureText(size: 20, weight: FontWeight.w800),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The score on a frosted glass disc, with a thin ring that fills to it
/// while the number counts up.
class _ScoreRing extends StatefulWidget {
  const _ScoreRing({required this.score, required this.size});
  final int score;
  final double size;

  @override
  State<_ScoreRing> createState() => _ScoreRingState();
}

class _ScoreRingState extends State<_ScoreRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fill = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final Animation<double> _curve =
      CurvedAnimation(parent: _fill, curve: Curves.easeOutCubic);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (ScanMotion.reduced(context)) {
      _fill.value = 1;
    } else {
      _fill.forward();
    }
  }

  @override
  void dispose() {
    _fill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Oral health score ${widget.score} out of 100',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: widget.size,
        child: DecoratedBox(
          // Frosted disc with a bright rim, like the app's glass cards.
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.white.withValues(alpha: 0.85),
                AppColors.lightLavender.withValues(alpha: 0.5),
              ],
            ),
            border: Border.all(color: AppGlass.border, width: 1.4),
          ),
          child: AnimatedBuilder(
            animation: _curve,
            builder: (context, _) {
              final value = widget.score * _curve.value;
              return CustomPaint(
                painter: _RingPainter(value / 100),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${value.round()}',
                        style: figureText(
                          size: widget.size * 0.3,
                          weight: FontWeight.w800,
                          letterSpacing: -1,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'out of 100',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A full, thin ring: a faint track and a teal arc from the top.
class _RingPainter extends CustomPainter {
  const _RingPainter(this.fraction);
  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: c, radius: size.shortestSide / 2 - 11);
    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = AppColors.g2.withValues(alpha: 0.12),
    );
    if (fraction <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * fraction.clamp(0.0, 1.0),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..shader = const SweepGradient(
          colors: [AppColors.g1, AppColors.g2],
          transform: GradientRotation(-math.pi / 2),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction;
}

// ── Findings ──────────────────────────────────────────────────────

/// One finding, described for an area of the mouth, with what to do.
class _FindingCard extends StatelessWidget {
  const _FindingCard({required this.finding});

  final ScanFinding finding;

  @override
  Widget build(BuildContext context) {
    final color = HealthColors.of(finding.health);
    final region =
        finding.foundIn == null ? null : captureRegionById(finding.foundIn!);
    return GlassCard(
      borderRadius: const BorderRadius.all(Radius.circular(20)),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.13),
                ),
                child: Icon(
                  finding.health == AreaHealth.attention
                      ? Icons.error_outline_rounded
                      : Icons.visibility_outlined,
                  size: 19,
                  color: HealthColors.ink(finding.health),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      finding.condition,
                      style: GoogleFonts.outfit(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    Text(
                      finding.area.label,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    HealthChip(health: finding.health),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            finding.summary,
            style: GoogleFonts.outfit(
              fontSize: 13.5,
              height: 1.45,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 12),
          ConfidenceBar(value: finding.confidence, color: color),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(10, 9, 12, 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AppColors.lightLavender.withValues(alpha: 0.7),
              border: Border.all(color: AppColors.lavender),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(Icons.tips_and_updates_outlined,
                      size: 16, color: AppColors.g2),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    finding.recommendation,
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      height: 1.45,
                      color: AppColors.navy,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (region != null) ...[
            const SizedBox(height: 10),
            Text(
              'Seen in your ${region.label} photo',
              style: GoogleFonts.outfit(
                fontSize: 11.5,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OthersTile extends StatelessWidget {
  const _OthersTile({required this.report});
  final ScanReport report;

  @override
  Widget build(BuildContext context) {
    final healthy = report.countOf(AreaHealth.healthy);
    final missing = report.countOf(AreaHealth.notChecked);
    String areas(int n) => '$n area${n == 1 ? '' : 's'}';
    return GlassCard(
      borderRadius: const BorderRadius.all(Radius.circular(20)),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: HealthColors.healthy.withValues(alpha: 0.15),
            ),
            child: const DrawnCheck(
              visible: true,
              size: 20,
              strokeWidth: 2.4,
              color: HealthColors.healthyInk,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Everywhere else',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                Text(
                  missing == 0
                      ? 'No concerns in ${areas(healthy)} of your mouth'
                      : 'No concerns in ${areas(healthy)} · '
                          '$missing not checked',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Region breakdown ──────────────────────────────────────────────

class _RegionBreakdown extends ConsumerWidget {
  const _RegionBreakdown({required this.report});
  final ScanReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = ref.watch(scanFlowProvider.select((s) => s.photos));
    return GlassCard(
      borderRadius: const BorderRadius.all(Radius.circular(20)),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      child: Column(
        children: [
          for (final (i, region) in captureRegions.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RegionBar(
                region: region,
                score: report.regionScores[region.id],
                photo: photos[region.id],
                index: i,
              ),
            ),
        ],
      ),
    );
  }
}

class _RegionBar extends StatelessWidget {
  const _RegionBar({
    required this.region,
    required this.score,
    required this.photo,
    required this.index,
  });

  final CaptureRegion region;
  final int? score;
  final RegionPhoto? photo;
  final int index;

  @override
  Widget build(BuildContext context) {
    final score = this.score;
    final health = score == null ? null : HealthColors.forScore(score);
    final color = health == null ? HealthColors.muted : HealthColors.of(health);
    return Semantics(
      label: score == null
          ? '${region.label}: not captured'
          : '${region.label}: $score out of 100',
      excludeSemantics: true,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: SizedBox(
              width: 48,
              height: 36,
              child: photo == null
                  ? ColoredBox(
                      color: AppColors.navy.withValues(alpha: 0.06),
                      child: Icon(Icons.hide_image_outlined,
                          size: 16,
                          color: AppColors.secondaryText.withValues(alpha: 0.6)),
                    )
                  : Image.memory(
                      photo!.bytes,
                      fit: BoxFit.cover,
                      cacheWidth: 144,
                      gaplessPlayback: true,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        region.shortLabel,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: score == null
                              ? AppColors.secondaryText
                              : AppColors.navy,
                        ),
                      ),
                    ),
                    score == null
                        ? Text(
                            'Not captured',
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondaryText,
                            ),
                          )
                        : Text(
                            '$score',
                            style: figureText(
                              size: 13,
                              color: HealthColors.ink(health!),
                            ),
                          ),
                  ],
                ),
                const SizedBox(height: 6),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: (score ?? 0) / 100),
                  duration: ScanMotion.of(
                      context, Duration(milliseconds: 900 + 70 * index)),
                  curve: ScanMotion.curve,
                  builder: (context, v, _) => Container(
                    height: 7,
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: AppColors.navy.withValues(alpha: 0.06),
                    ),
                    child: FractionallySizedBox(
                      widthFactor: v,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          gradient: LinearGradient(colors: [
                            color.withValues(alpha: 0.55),
                            color,
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Metrics ───────────────────────────────────────────────────────

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});
  final List<ScanMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 520 ? 3 : 2;
      final rows = (metrics.length / columns).ceil();
      return Column(
        children: [
          for (var row = 0; row < rows; row++) ...[
            if (row > 0) const SizedBox(height: 10),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var col = 0; col < columns; col++) ...[
                    if (col > 0) const SizedBox(width: 10),
                    Expanded(
                      child: row * columns + col < metrics.length
                          ? _MetricTile(metric: metrics[row * columns + col])
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    });
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric});
  final ScanMetric metric;

  static const _icons = {
    'plaque': Icons.bubble_chart_outlined,
    'gums': Icons.spa_outlined,
    'enamel': Icons.diamond_outlined,
    'alignment': Icons.straighten_rounded,
    'cavity': Icons.warning_amber_rounded,
    'staining': Icons.coffee_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final health = switch (metric.level) {
      MetricLevel.good => AreaHealth.healthy,
      MetricLevel.fair => AreaHealth.monitor,
      MetricLevel.poor => AreaHealth.attention,
    };
    final color = HealthColors.of(health);
    final bars = 3 - metric.level.index;
    return Semantics(
      label: '${metric.label}: ${metric.value}',
      excludeSemantics: true,
      child: GlassCard(
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.13),
                  ),
                  child: Icon(_icons[metric.id] ?? Icons.insights_rounded,
                      size: 18, color: HealthColors.ink(health)),
                ),
                const Spacer(),
                for (var i = 0; i < 3; i++)
                  Container(
                    margin: const EdgeInsets.only(left: 3),
                    width: 5,
                    height: 8 + i * 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: i < bars
                          ? color
                          : AppColors.navy.withValues(alpha: 0.08),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(metric.label.toUpperCase(), style: capsLabel()),
            const SizedBox(height: 2),
            Text(
              metric.value,
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Recommendations and actions ───────────────────────────────────

class _Recommendations extends StatelessWidget {
  const _Recommendations({required this.items});
  final List<ScanRecommendation> items;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: const BorderRadius.all(Radius.circular(20)),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        children: [
          for (final (i, item) in items.indexed) ...[
            if (i > 0) Divider(height: 1, color: AppGlass.divider),
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 12, bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.cardGradient,
                    ),
                    child: Text(
                      '0${i + 1}',
                      style: figureText(size: 12, color: AppColors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                            color: AppColors.navy,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.body,
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            height: 1.45,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.saved,
    required this.onBook,
    required this.onAskRabi,
    required this.onSave,
    required this.onScanAgain,
  });

  final bool saved;
  final VoidCallback? onBook;
  final VoidCallback onAskRabi;
  final VoidCallback? onSave;
  final VoidCallback onScanAgain;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlowButton(
          label: 'Find Clinics Nearby',
          icon: Icons.location_on_outlined,
          intensity: 0.8,
          onTap: onBook,
        ),
        const SizedBox(height: 10),
        GlassCard(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          onTap: onAskRabi,
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
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Ask Rabi AI about my results',
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
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _OutlineAction(
                icon: saved
                    ? Icons.check_circle_rounded
                    : Icons.download_rounded,
                label: saved ? 'Saved' : 'Save Report',
                onTap: onSave,
                done: saved,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _OutlineAction(
                icon: Icons.restart_alt_rounded,
                label: 'Scan Again',
                onTap: onScanAgain,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OutlineAction extends StatelessWidget {
  const _OutlineAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.done = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final color = done ? HealthColors.healthyInk : AppColors.navy;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: GlassCard(
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 50),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: ScanMotion.of(context, ScanMotion.medium),
                  child: Icon(icon, key: ValueKey(icon), size: 18, color: color),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
