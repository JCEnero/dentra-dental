import 'dart:math' as math;
import 'dart:ui' show ImageFilter, PathMetric;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_glass.dart';
import '../../auth/widgets/dentra_logo.dart';

/// The D mark in a frosted glass tile, with a teal line that traces the
/// tile's outline as loading moves along.
///
/// A pure view: the caller drives every value, so the same mark serves
/// the launch loader (real progress) and quieter waits (an orbiting
/// segment, see [traceStart]).
class LoadingMark extends StatelessWidget {
  const LoadingMark({
    super.key,
    required this.traceExtent,
    this.traceStart = 0,
    this.traceOpacity = 1,
    this.tileIn = 1,
    this.markIn = 1,
    this.sheen = 0,
    this.complete = 0,
  });

  /// How much of the outline the line covers, 0 to 1 (1 closes it).
  final double traceExtent;

  /// Where the line starts, as a fraction of the outline from the top
  /// centre, clockwise. Animate it with a short [traceExtent] for an
  /// orbit when there is no progress to show.
  final double traceStart;
  final double traceOpacity;

  /// Entrance of the glass tile, 0 to 1.
  final double tileIn;

  /// Entrance of the D mark inside it, 0 to 1 (may overshoot).
  final double markIn;

  /// A band of light crossing the tile, 0 to 1. Hidden at 0 and 1.
  final double sheen;

  /// The finish, 0 to 1: the line glows and a ripple leaves the tile.
  final double complete;

  static const double tileSize = 120;
  static const double tileRadius = 36;

  /// Space between the tile and the traced outline.
  static const double gap = 11;

  /// The whole mark; the ripple may paint past it.
  static const double extent = tileSize + gap * 2 + 8;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(tileRadius);
    // A small nod as the line closes.
    final nod = 1 + math.sin(complete.clamp(0.0, 0.5) * 2 * math.pi) * 0.035;

    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: extent,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _TracePainter(
                  start: traceStart,
                  extent: traceExtent,
                  opacity: traceOpacity,
                  complete: complete,
                ),
              ),
            ),
            Opacity(
              opacity: tileIn.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: (0.86 + 0.14 * tileIn) * nod,
                // No drop shadow: under see-through glass it shows
                // through as a dark band.
                child: SizedBox(
                  width: tileSize,
                  height: tileSize,
                  child: ClipRRect(
                    borderRadius: radius,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                      child: DecoratedBox(
                        decoration: AppGlass.surface(
                          borderRadius: radius,
                          borderWidth: 1.4,
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [_mark(), _sheen()],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mark() {
    return Opacity(
      opacity: markIn.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, (1 - markIn) * 14),
        child: Transform.scale(
          scale: 0.88 + 0.12 * markIn,
          child: Padding(
            padding: const EdgeInsets.all(29),
            child: Image.asset(DentraLogo.markAsset, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  Widget _sheen() {
    if (sheen <= 0 || sheen >= 1) return const SizedBox.shrink();
    return IgnorePointer(
      child: FractionalTranslation(
        translation: Offset(-1.2 + sheen * 2.4, 0),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.white.withValues(alpha: 0),
                AppColors.white.withValues(alpha: 0.55),
                AppColors.white.withValues(alpha: 0),
              ],
              stops: const [0.35, 0.5, 0.65],
            ),
          ),
        ),
      ),
    );
  }
}

/// The faint outline around the tile, the teal line running along it
/// with a bright head, and the ripple when it closes.
class _TracePainter extends CustomPainter {
  const _TracePainter({
    required this.start,
    required this.extent,
    required this.opacity,
    required this.complete,
  });

  final double start;
  final double extent;
  final double opacity;
  final double complete;

  @override
  void paint(Canvas canvas, Size size) {
    const side = LoadingMark.tileSize + LoadingMark.gap * 2;
    final outline = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: size.center(Offset.zero), width: side, height: side),
      const Radius.circular(LoadingMark.tileRadius + LoadingMark.gap),
    );

    // The track the line runs on.
    canvas.drawRRect(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = AppColors.g2.withValues(alpha: 0.12 * opacity),
    );

    // One ripple leaving the tile as the line closes.
    if (complete > 0 && complete < 1) {
      final t = Curves.easeOutCubic.transform(complete);
      canvas.drawRRect(
        outline.inflate(t * 30),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = AppColors.g1.withValues(alpha: (1 - complete) * 0.55),
      );
    }

    final amount = extent.clamp(0.0, 1.0);
    if (amount <= 0.002 || opacity <= 0) return;

    final metric = _outlinePath(outline).computeMetrics().first;
    final full = amount >= 0.999;
    final line = full ? (Path()..addRRect(outline)) : _segment(metric, amount);

    // Soft light under the line; it brightens as the line closes.
    final pulse = math.sin(complete.clamp(0.0, 1.0) * math.pi);
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5)
        ..color = AppColors.g1.withValues(alpha: (0.22 + 0.3 * pulse) * opacity),
    );

    // Mint at the tail deepening to teal at the head.
    Color tone(Color color, [double alpha = 1]) =>
        color.withValues(alpha: alpha * opacity);
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          colors: full
              ? [tone(AppColors.g2), tone(AppColors.g1), tone(AppColors.g2)]
              : [
                  tone(AppColors.g1, 0.35),
                  tone(AppColors.g1),
                  tone(AppColors.g2),
                ],
          stops: full ? const [0, 0.5, 1] : [0, amount * 0.4, amount],
          transform: GradientRotation(-math.pi / 2 + start * 2 * math.pi),
        ).createShader(outline.outerRect),
    );

    // A bright head leading the line.
    if (!full) {
      final head = metric
          .getTangentForOffset(((start + amount) % 1) * metric.length)
          ?.position;
      if (head != null) {
        canvas.drawCircle(
          head,
          5,
          Paint()
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
            ..color = AppColors.g1.withValues(alpha: 0.6 * opacity),
        );
        canvas.drawCircle(
          head,
          1.8,
          Paint()..color = AppColors.white.withValues(alpha: opacity),
        );
      }
    }
  }

  /// The part of the outline from [start] covering [amount], wrapping
  /// past the top centre when it has to.
  Path _segment(PathMetric metric, double amount) {
    final length = metric.length;
    final from = (start % 1) * length;
    final to = from + amount * length;
    if (to <= length) return metric.extractPath(from, to);
    return metric.extractPath(from, length)
      ..addPath(metric.extractPath(0, to - length), Offset.zero);
  }

  /// The outline as one path starting at the top centre, clockwise, so
  /// progress reads like a clock hand.
  static Path _outlinePath(RRect r) {
    final radius = Radius.circular(r.tlRadiusX);
    final k = r.tlRadiusX;
    return Path()
      ..moveTo(r.center.dx, r.top)
      ..lineTo(r.right - k, r.top)
      ..arcToPoint(Offset(r.right, r.top + k), radius: radius)
      ..lineTo(r.right, r.bottom - k)
      ..arcToPoint(Offset(r.right - k, r.bottom), radius: radius)
      ..lineTo(r.left + k, r.bottom)
      ..arcToPoint(Offset(r.left, r.bottom - k), radius: radius)
      ..lineTo(r.left, r.top + k)
      ..arcToPoint(Offset(r.left + k, r.top), radius: radius)
      ..close();
  }

  @override
  bool shouldRepaint(_TracePainter old) =>
      old.start != start ||
      old.extent != extent ||
      old.opacity != opacity ||
      old.complete != complete;
}
