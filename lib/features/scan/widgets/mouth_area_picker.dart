import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsProperties;
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_glass.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../screening/data/models/scan_check_in.dart';

/// A flat map of the mouth to tap an area on: the upper and lower arch, each
/// in the same three general areas the results use. Upper right sits on the
/// left, as a dentist sees it, like the results map and the tooth chart.
///
/// "Not sure" isn't on the map; the caller offers it beside it.
class MouthAreaPicker extends StatefulWidget {
  const MouthAreaPicker({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  /// Null, or [AreaAnswer.notSure], leaves the map empty.
  final AreaAnswer? selected;
  final ValueChanged<AreaAnswer> onSelect;

  /// Widest the map is drawn.
  static const double maxWidth = 230;

  @override
  State<MouthAreaPicker> createState() => _MouthAreaPickerState();
}

class _MouthAreaPickerState extends State<MouthAreaPicker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fill = AnimationController(
    vsync: this,
    value: 1,
  );

  /// The area fading out while the new one fills in.
  AreaAnswer? _previous;

  @override
  void didUpdateWidget(MouthAreaPicker old) {
    super.didUpdateWidget(old);
    if (old.selected == widget.selected) return;
    _previous = old.selected;
    _fill
      ..duration = dentraMotion(context, 240)
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _fill.dispose();
    super.dispose();
  }

  void _tapAt(Offset at, _ArchGeometry geometry) {
    final area = geometry.areaAt(at);
    if (area != null) widget.onSelect(area);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = math.min(constraints.maxWidth, MouthAreaPicker.maxWidth);
      final geometry = _ArchGeometry(width);
      final label = GoogleFonts.outfit(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: AppColors.secondaryText,
        letterSpacing: 0.2,
      );
      return Center(
        child: SizedBox(
          width: width,
          height: geometry.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // The words sit in the open spaces, so the map stays clear.
              // Kept small: very large text would cover the arches, and screen
              // readers read each area's full name anyway.
              ExcludeSemantics(
                child: MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.3,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        top: geometry.upperCenter.dy - geometry.hollowLabelLift,
                        child: Text('Upper',
                            textAlign: TextAlign.center, style: label),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: geometry.lowerCenter.dy +
                            geometry.hollowLabelLift -
                            16,
                        child: Text('Lower',
                            textAlign: TextAlign.center, style: label),
                      ),
                      Positioned(
                        left: 0,
                        top: geometry.gapCenter - 8,
                        child: Text('Your right', style: label),
                      ),
                      Positioned(
                        right: 0,
                        top: geometry.gapCenter - 8,
                        child: Text('Your left', style: label),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  // Screen readers get one node per area from the painter.
                  excludeFromSemantics: true,
                  onTapUp: (d) => _tapAt(d.localPosition, geometry),
                  child: AnimatedBuilder(
                    animation: _fill,
                    builder: (context, _) => CustomPaint(
                      painter: _ArchPainter(
                        geometry: geometry,
                        selected: widget.selected,
                        previous: _previous,
                        progress: Curves.easeOutCubic.transform(_fill.value),
                        onSelect: widget.onSelect,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

/// Where each area is drawn, shared by painting, tapping and screen readers.
class _ArchGeometry {
  _ArchGeometry(this.width)
      : band = width * 0.13,
        pad = 2 {
    rx = width / 2 - band / 2 - pad;
    // Deeper than a half-ring, so each reads as a row of teeth.
    ry = rx * 0.8;
    gap = math.max(28.0, width * 0.13);
    final top = pad + ry + band / 2;
    upperCenter = Offset(width / 2, top);
    lowerCenter = Offset(width / 2, top + gap);
    height = top * 2 + gap;
  }

  final double width;

  /// How thick each arch is.
  final double band;
  final double pad;
  late final double rx;
  late final double ry;

  /// Space between the arches, where the side labels go.
  late final double gap;
  late final Offset upperCenter;
  late final Offset lowerCenter;
  late final double height;

  double get gapCenter => upperCenter.dy + gap / 2;

  /// How far into its arch's hollow the "Upper" and "Lower" labels sit.
  double get hollowLabelLift => ry * 0.52;

  static const double _deg = math.pi / 180;

  /// Degrees left between neighbouring areas.
  static const double _split = 1.6;

  /// Each area's span around its ellipse, in degrees (y points down, so the
  /// upper arch runs 180→360 over the top and the lower one 180→0 under).
  static const Map<AreaAnswer, (double, double)> _spans = {
    AreaAnswer.upperRight: (180, 240),
    AreaAnswer.upperFront: (240, 300),
    AreaAnswer.upperLeft: (300, 360),
    AreaAnswer.lowerRight: (180, 120),
    AreaAnswer.lowerFront: (120, 60),
    AreaAnswer.lowerLeft: (60, 0),
  };

  static Iterable<AreaAnswer> get areas => _spans.keys;

  Offset _centerOf(AreaAnswer area) =>
      area.area!.isUpper ? upperCenter : lowerCenter;

  /// The band for [area], with a hairline gap from its neighbours.
  Path pathOf(AreaAnswer area) {
    final (from, to) = _spans[area]!;
    final dir = to > from ? 1 : -1;
    final start = (from + dir * _split / 2) * _deg;
    final end = (to - dir * _split / 2) * _deg;
    final c = _centerOf(area);
    const steps = 24;
    Offset at(double t, double grow) {
      final a = start + (end - start) * t;
      return Offset(
        c.dx + (rx + grow) * math.cos(a),
        c.dy + (ry + grow) * math.sin(a),
      );
    }

    final path = Path()..moveTo(at(0, band / 2).dx, at(0, band / 2).dy);
    for (var i = 1; i <= steps; i++) {
      final p = at(i / steps, band / 2);
      path.lineTo(p.dx, p.dy);
    }
    for (var i = steps; i >= 0; i--) {
      final p = at(i / steps, -band / 2);
      path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  /// The area under [p], with some room around each band for a finger.
  AreaAnswer? areaAt(Offset p) {
    final upper = p.dy <= upperCenter.dy + gap / 2;
    final c = upper ? upperCenter : lowerCenter;
    final nx = (p.dx - c.dx) / rx;
    final ny = (p.dy - c.dy) / ry;
    final r = math.sqrt(nx * nx + ny * ny);
    final reach = (band / 2 + 12) / ry;
    if ((r - 1).abs() > reach) return null;
    var deg = math.atan2(ny, nx) / _deg;
    if (upper) {
      // Just below the ends still counts as the nearest end.
      if (deg < 0) deg += 360;
      if (deg < 90) deg = 360;
      if (deg < 180) deg = 180;
      if (deg < 240) return AreaAnswer.upperRight;
      if (deg < 300) return AreaAnswer.upperFront;
      return AreaAnswer.upperLeft;
    }
    if (deg < 0) deg = p.dx < c.dx ? 180 : 0;
    if (deg > 120) return AreaAnswer.lowerRight;
    if (deg > 60) return AreaAnswer.lowerFront;
    return AreaAnswer.lowerLeft;
  }
}

class _ArchPainter extends CustomPainter {
  _ArchPainter({
    required this.geometry,
    required this.selected,
    required this.previous,
    required this.progress,
    required this.onSelect,
  });

  final _ArchGeometry geometry;
  final AreaAnswer? selected;
  final AreaAnswer? previous;
  final double progress;
  final ValueChanged<AreaAnswer> onSelect;

  double _amount(AreaAnswer area) {
    if (area == selected) return progress;
    if (area == previous) return 1 - progress;
    return 0;
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final area in _ArchGeometry.areas) {
      final path = geometry.pathOf(area);
      final bounds = path.getBounds();
      final amount = _amount(area);
      canvas.drawPath(path, Paint()..color = AppGlass.fillHigh);
      if (amount > 0) {
        canvas.drawPath(
          path,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.g1.withValues(alpha: amount),
                AppColors.g2.withValues(alpha: amount),
              ],
            ).createShader(bounds),
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeJoin = StrokeJoin.round
          ..color = Color.lerp(
            AppColors.g2.withValues(alpha: 0.22),
            AppColors.g2,
            amount,
          )!,
      );
    }
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder => (size) => [
        for (final area in _ArchGeometry.areas)
          CustomPainterSemantics(
            key: ValueKey(area),
            rect: geometry.pathOf(area).getBounds(),
            properties: SemanticsProperties(
              label: area.label,
              checked: area == selected,
              inMutuallyExclusiveGroup: true,
              onTap: () => onSelect(area),
              textDirection: TextDirection.ltr,
            ),
          ),
      ];

  @override
  bool shouldRepaint(_ArchPainter old) =>
      old.progress != progress ||
      old.selected != selected ||
      old.previous != previous ||
      old.geometry.width != geometry.width;

  @override
  bool shouldRebuildSemantics(_ArchPainter old) =>
      old.selected != selected || old.geometry.width != geometry.width;
}
