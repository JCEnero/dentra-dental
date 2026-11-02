import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/scan_report.dart';
import '../scan_theme.dart';
import 'report_motion.dart';
import 'report_style.dart';

Color get _track => AppColors.g2.withValues(alpha: 0.13);

/// One ratio against its limit, drawn as a ring with the figure inside it.
class RingMeter extends StatelessWidget {
  const RingMeter({
    super.key,
    required this.value,
    required this.total,
    required this.label,
    this.size = 66,
  });

  final int value;
  final int total;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final share = total == 0 ? 0.0 : (value / total).clamp(0.0, 1.0);
    return Semantics(
      label: '$label: $value of $total',
      excludeSemantics: true,
      child: Column(
        children: [
          SizedBox.square(
            dimension: size,
            child: InViewAnimation(
              builder: (context, t) => CustomPaint(
                painter: _RingsPainter([(share * t, AppColors.primary)], 6),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text.rich(
                        TextSpan(
                          text: '${(value * t).round()}',
                          style: GoogleFonts.outfit(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                          ),
                          children: [
                            TextSpan(
                              text: '/$total',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(label, textAlign: TextAlign.center, style: reportNote),
        ],
      ),
    );
  }
}

/// Rings inside one another, outermost first. Each is a share from 0 to 1.
class _RingsPainter extends CustomPainter {
  const _RingsPainter(this.rings, this.stroke, {this.gap = 4});

  final List<(double, Color)> rings;
  final double stroke;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    var r = size.shortestSide / 2 - stroke / 2;
    for (final (share, color) in rings) {
      final rect = Rect.fromCircle(center: c, radius: r);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = _track,
      );
      if (share > 0) {
        canvas.drawArc(
          rect,
          -math.pi / 2,
          2 * math.pi * share,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.round
            ..color = color,
        );
      }
      r -= stroke + gap;
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) {
    if (old.rings.length != rings.length) return true;
    for (var i = 0; i < rings.length; i++) {
      if (old.rings[i] != rings[i]) return true;
    }
    return false;
  }
}

/// How much of each side of the teeth was read: one ring per surface, beside
/// its name and count, so the empty ring for inner sides says it plainly.
class CoverageRings extends StatelessWidget {
  const CoverageRings({super.key, required this.rows});

  /// Outermost first: (name, read, total, what the gap means or null).
  final List<(String, int, int, String?)> rows;

  static const _colors = [
    ReportColors.strong,
    ReportColors.possible,
    ReportColors.faint,
  ];

  @override
  Widget build(BuildContext context) {
    final read = rows.fold<int>(0, (sum, r) => sum + r.$2);
    final total = rows.fold<int>(0, (sum, r) => sum + r.$3);
    return Row(
      children: [
        SizedBox.square(
          dimension: 112,
          child: ExcludeSemantics(
            child: InViewAnimation(
              builder: (context, t) => CustomPaint(
                painter: _RingsPainter([
                  for (final (i, r) in rows.indexed)
                    (
                      r.$3 == 0 ? 0.0 : r.$2 / r.$3 * t,
                      _colors[i % _colors.length],
                    ),
                ], 9),
                child: Center(
                  child: Text(
                    '${(read / math.max(total, 1) * 100 * t).round()}%',
                    textScaler: TextScaler.noScaling,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, r) in rows.indexed)
                Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
                  child: Semantics(
                    label: '${r.$1} surfaces: ${r.$2} of ${r.$3} read'
                        '${r.$4 == null ? '' : '. ${r.$4}'}',
                    excludeSemantics: true,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _colors[i % _colors.length],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${r.$1} · ${r.$2} of ${r.$3}',
                                style: figureText(
                                  size: 13,
                                  weight: FontWeight.w600,
                                ),
                              ),
                              if (r.$4 != null) Text(r.$4!, style: reportNote),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A half-ring for how sure the model was about one sign, with the figure
/// inside. The band's end marks where a sign turns strong.
class ConfidenceGauge extends StatelessWidget {
  const ConfidenceGauge({
    super.key,
    required this.value,
    required this.color,
    this.size = 58,
  });

  /// 0 to 1.
  final double value;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => SizedBox(
        width: size,
        height: size * 0.62,
        child: CustomPaint(
          painter: _GaugePainter(v, color),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Text(
              '${(v * 100).round()}%',
              textScaler: TextScaler.noScaling,
              style: figureText(size: 13, weight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter(this.value, this.color);

  final double value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 6.0;
    final r = size.width / 2 - stroke / 2;
    final rect = Rect.fromCircle(
        center: Offset(size.width / 2, r + stroke / 2), radius: r);
    Paint line(Color c) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = c;
    canvas.drawArc(rect, math.pi, math.pi, false, line(_track));
    if (value > 0) {
      canvas.drawArc(rect, math.pi, math.pi * value, false, line(color));
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.value != value || old.color != color;
}

/// All the signs split by strength, in one bar, with its legend under it.
class StrengthBar extends StatelessWidget {
  const StrengthBar({super.key, required this.report});

  final ScreeningReport report;

  @override
  Widget build(BuildContext context) {
    final parts = [
      for (final s in SignStrength.values.reversed)
        if (report.countOf(s) > 0) (s, report.countOf(s)),
    ];
    final total = parts.fold<int>(0, (sum, p) => sum + p.$2);
    if (total == 0) return const SizedBox.shrink();
    return Semantics(
      label: 'Signs by strength: '
          '${parts.map((p) => '${p.$2} ${p.$1.label.toLowerCase()}').join(', ')}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InViewAnimation(
            builder: (context, t) => ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: math.max(t, 0.001),
                child: Row(
                  children: [
                    for (final (i, (s, n)) in parts.indexed) ...[
                      if (i > 0) const SizedBox(width: 2),
                      Expanded(
                        flex: n,
                        child: Container(
                          height: 10,
                          color: ReportColors.ofSign(s),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              for (final (s, n) in parts)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ReportSwatch(AreaState.of(s)),
                    const SizedBox(width: 5),
                    Text(
                      '$n ${s.name}',
                      style: reportNote,
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Signs per scan as a line that draws itself. Tap a scan to read its figures.
class TrendChart extends StatelessWidget {
  const TrendChart({
    super.key,
    required this.values,
    required this.selected,
    required this.onSelect,
    required this.describe,
    this.height = 96,
  });

  final List<int> values;
  final int selected;
  final ValueChanged<int> onSelect;

  /// What a screen reader says for one scan.
  final String Function(int index) describe;
  final double height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final width = c.maxWidth;
      return SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned.fill(
              child: InViewAnimation(
                duration: const Duration(milliseconds: 1300),
                builder: (context, t) => CustomPaint(
                  painter: _TrendPainter(values, selected, t),
                ),
              ),
            ),
            for (var i = 0; i < values.length; i++)
              Positioned(
                left: i * width / values.length,
                width: width / values.length,
                top: 0,
                bottom: 0,
                child: Semantics(
                  button: true,
                  selected: i == selected,
                  label: describe(i),
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => onSelect(i),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter(this.values, this.selected, this.t);

  final List<int> values;
  final int selected;
  final double t;

  static const _pad = 8.0;

  Offset _point(int i, Size s, int top) {
    final step = s.width / values.length;
    final y = _pad + (s.height - 2 * _pad) * (1 - values[i] / top);
    return Offset(step * (i + 0.5), y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final top = math.max(1, values.reduce(math.max));
    final base = size.height - _pad;
    canvas.drawLine(
      Offset(0, base),
      Offset(size.width, base),
      Paint()
        ..strokeWidth = 1
        ..color = AppColors.navy.withValues(alpha: 0.09),
    );
    final points = [
      for (var i = 0; i < values.length; i++) _point(i, size, top)
    ];
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      final mid = (a.dx + b.dx) / 2;
      line.cubicTo(mid, a.dy, mid, b.dy, b.dx, b.dy);
    }

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * t, size.height));
    final fill = Path.from(line)
      ..lineTo(points.last.dx, base)
      ..lineTo(points.first.dx, base)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.g1.withValues(alpha: 0.28),
            AppColors.g1.withValues(alpha: 0),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.primary,
    );
    for (final (i, p) in points.indexed) {
      final chosen = i == selected;
      canvas.drawCircle(p, chosen ? 6 : 4, Paint()..color = AppColors.white);
      canvas.drawCircle(
        p,
        chosen ? 4 : 2.5,
        Paint()..color = chosen ? ReportColors.strong : AppColors.primary,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.t != t || old.selected != selected || old.values != values;
}
