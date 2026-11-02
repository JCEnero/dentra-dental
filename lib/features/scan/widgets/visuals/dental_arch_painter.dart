import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show mapEquals;
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/scan_outcomes.dart';
import '../../data/scan_regions.dart';

/// Design-space size every region visual is painted at, then scaled
/// uniformly by its parent (10:7).
const Size kArchCanvas = Size(300, 210);

/// Design-space size of the mouth map on the results page.
const Size kMouthMapCanvas = Size(300, 326);

/// Occlusal (biting-surface) view of the dental arches with the region's
/// teeth lit and the rest receding.
///
/// Each tooth is drawn by type (incisor, canine, premolar, molar) with
/// cusps, fissures and studio lighting from the upper left. This is a 2D
/// illustration with 3D-style shading, not a 3D model; see
/// `ScanRegion.renderAsset` to use a real render instead.
class DentalArchPainter extends CustomPainter {
  const DentalArchPainter({required this.region, this.showSideLabels = true});

  final ScanRegion region;
  final bool showSideLabels;

  // Light comes from the upper left of the screen.
  static const Offset _toLight = Offset(-0.55, -0.83);
  static const Offset _shadowOffset = Offset(1.8, 3.2);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / kArchCanvas.width;
    canvas.save();
    canvas.scale(scale);

    final layouts = switch (region.view) {
      ArchView.upper => [
          _fitArch(DentalArch.upper, const Rect.fromLTWH(22, 8, 256, 194)),
        ],
      ArchView.lower => [
          _fitArch(DentalArch.lower, const Rect.fromLTWH(22, 8, 256, 194)),
        ],
      ArchView.both => [
          _fitArch(DentalArch.upper, const Rect.fromLTWH(22, 4, 256, 98)),
          _fitArch(DentalArch.lower, const Rect.fromLTWH(22, 108, 256, 98)),
        ],
    };

    for (final layout in layouts) {
      _paintGingiva(canvas, layout);
    }
    // Dim teeth first so the glow of lit teeth sits on top.
    for (final lit in [false, true]) {
      for (final layout in layouts) {
        for (final tooth in layout.teeth) {
          final isLit = region.highlights(layout.arch, tooth.side, tooth.kind);
          if (isLit == lit) _paintTooth(canvas, layout, tooth, lit: isLit);
        }
      }
    }
    if (showSideLabels) _paintSideLabels(canvas, layouts);
    canvas.restore();
  }

  // ── Gingiva ───────────────────────────────────────────────────

  void _paintGingiva(Canvas canvas, _ArchLayout layout) {
    final path = Path()..addPolygon(layout.centerline, false);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = layout.gumWidth
        ..color = AppColors.peachBg.withValues(alpha: 0.55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, layout.scale * 1.2),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = layout.gumWidth * 0.55
        ..color = AppColors.white.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, layout.scale * 1.6),
    );
  }

  // ── Teeth ─────────────────────────────────────────────────────

  void _paintTooth(
    Canvas canvas,
    _ArchLayout layout,
    _PlacedTooth t, {
    required bool lit,
  }) {
    // Local unit frame: x runs distally, y outward (cheek/lip side), both
    // spanning -1…1 across the tooth.
    final a = t.distal * t.halfLength;
    final b = t.outward * t.halfDepth;
    final matrix = Float64List.fromList([
      a.dx, a.dy, 0, 0, //
      b.dx, b.dy, 0, 0, //
      0, 0, 1, 0, //
      t.center.dx, t.center.dy, 0, 1,
    ]);

    // Light and shadow directions expressed in the local frame.
    final light = Offset(
      _dot(_toLight, t.distal),
      _dot(_toLight, t.outward),
    );
    final shadow = Offset(
      _dot(_shadowOffset, t.distal) / t.halfLength,
      _dot(_shadowOffset, t.outward) / t.halfDepth,
    );

    final outline = _ToothShapes.outline(t.kind);
    const unit = Rect.fromLTRB(-1, -1, 1, 1);

    canvas.save();
    canvas.transform(matrix);

    if (lit) {
      canvas.drawPath(
        outline.transform(Matrix4.diagonal3Values(1.3, 1.3, 1).storage),
        Paint()
          ..color = AppColors.g1.withValues(alpha: 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.32),
      );
    }

    canvas.drawPath(
      outline.shift(shadow),
      Paint()
        ..color = AppColors.navy.withValues(alpha: lit ? 0.26 : 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.18),
    );

    canvas.save();
    canvas.clipPath(outline);

    // Enamel: ivory dome lit from the light side.
    canvas.drawRect(
      unit,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(light.dx * 0.42, light.dy * 0.42),
          radius: 1.05,
          colors: [
            AppColors.white,
            Color.lerp(AppColors.offWhite, AppColors.peachBg, 0.28)!,
            Color.lerp(AppColors.border, AppColors.peachBg, 0.55)!,
            Color.lerp(AppColors.border, AppColors.secondaryText, 0.35)!,
          ],
          stops: const [0.0, 0.38, 0.78, 1.0],
        ).createShader(unit),
    );

    // Rim falloff for a rounded crown.
    canvas.drawRect(
      unit,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(light.dx * 0.25, light.dy * 0.25),
          radius: 1.1,
          colors: [
            AppColors.navy.withValues(alpha: 0.0),
            AppColors.navy.withValues(alpha: 0.0),
            AppColors.navy.withValues(alpha: 0.26),
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(unit),
    );

    _ToothShapes.paintSurface(canvas, t.kind, light);

    // Specular glint on the light side.
    canvas.drawOval(
      Rect.fromCenter(
        center: light * 0.52,
        width: 0.42,
        height: 0.24,
      ),
      Paint()
        ..color = AppColors.white.withValues(alpha: 0.85)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.08),
    );

    if (!lit) {
      // Teeth outside the region fade toward the mint backdrop.
      canvas.drawRect(
        unit,
        Paint()..color = AppColors.lightLavender.withValues(alpha: 0.58),
      );
    }
    canvas.restore();

    canvas.drawPath(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = lit ? 0.07 : 0.05
        ..color = lit
            ? AppColors.g2.withValues(alpha: 0.65)
            : AppColors.navy.withValues(alpha: 0.10),
    );
    canvas.restore();
  }

  /// "L" / "R" just outside the back teeth, so the mirror-style
  /// orientation never has to be guessed.
  void _paintSideLabels(Canvas canvas, List<_ArchLayout> layouts) {
    var left = kArchCanvas.width;
    var right = 0.0;
    for (final layout in layouts) {
      for (final t in layout.teeth) {
        final r = math.max(t.halfLength, t.halfDepth);
        left = math.min(left, t.center.dx - r);
        right = math.max(right, t.center.dx + r);
      }
    }
    final y = switch (region.view) {
      ArchView.upper => 150.0,
      ArchView.lower => 60.0,
      ArchView.both => kArchCanvas.height / 2,
    };
    for (final (text, x, alignRight) in [
      ('L', math.max(2.0, left - 12), true),
      ('R', math.min(kArchCanvas.width - 2, right + 12), false),
    ]) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: AppColors.secondaryText.withValues(alpha: 0.8),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(
          (alignRight ? x - tp.width : x)
              .clamp(2.0, kArchCanvas.width - 2 - tp.width),
          y - tp.height / 2,
        ),
      );
    }
  }

  static double _dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;

  @override
  bool shouldRepaint(DentalArchPainter old) =>
      old.region.id != region.id || old.showSideLabels != showSideLabels;
}

/// How the teeth of one area of the mouth map are drawn.
@immutable
class MouthMapStyle {
  const MouthMapStyle({
    required this.fill,
    required this.outline,
    this.selected = false,
  });

  final Color fill;
  final Color outline;

  /// Set apart with a soft glow, keeping its true colour.
  final bool selected;

  @override
  bool operator ==(Object other) =>
      other is MouthMapStyle &&
      other.fill == fill &&
      other.outline == outline &&
      other.selected == selected;

  @override
  int get hashCode => Object.hash(fill, outline, selected);
}

/// The two arches as a plain chart, upper above lower, every tooth flat in its
/// area's style. A general picture of a mouth, not of this person's teeth.
class MouthMapPainter extends CustomPainter {
  const MouthMapPainter(this.styles);

  final Map<MouthArea, MouthMapStyle> styles;

  static final List<_ArchLayout> _layouts = [
    // Inset, so the gums drawn around the teeth stay inside the canvas.
    _fitArch(DentalArch.upper, const Rect.fromLTWH(20, 8, 260, 146)),
    _fitArch(DentalArch.lower, const Rect.fromLTWH(20, 172, 260, 146)),
  ];

  /// Each area's teeth in map coordinates, for tapping and for labels.
  static final Map<MouthArea, Rect> areaBounds = () {
    final bounds = <MouthArea, Rect>{};
    for (final layout in _layouts) {
      for (final t in layout.teeth) {
        final area = MouthArea.at(layout.arch, t.side, t.kind);
        final r = math.max(t.halfLength, t.halfDepth);
        final box = Rect.fromCircle(center: t.center, radius: r);
        bounds[area] = bounds[area]?.expandToInclude(box) ?? box;
      }
    }
    return bounds;
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / kMouthMapCanvas.width;
    canvas.save();
    canvas.scale(scale);
    for (final layout in _layouts) {
      canvas.drawPath(
        Path()..addPolygon(layout.centerline, false),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.butt
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = layout.gumWidth * 0.86
          ..color = AppColors.lavender.withValues(alpha: 0.2),
      );
      // Glows first, so none of them falls on a neighbouring tooth.
      for (final selected in [true, false]) {
        for (final t in layout.teeth) {
          final style = styles[MouthArea.at(layout.arch, t.side, t.kind)];
          if (style != null && style.selected == selected) {
            _paintTooth(canvas, t, style);
          }
        }
      }
    }
    canvas.restore();
  }

  void _paintTooth(Canvas canvas, _PlacedTooth t, MouthMapStyle style) {
    final a = t.distal * t.halfLength;
    final b = t.outward * t.halfDepth;
    final matrix = Float64List.fromList([
      a.dx, a.dy, 0, 0, //
      b.dx, b.dy, 0, 0, //
      0, 0, 1, 0, //
      t.center.dx, t.center.dy, 0, 1,
    ]);
    final path = _ToothShapes.outline(t.kind).transform(matrix);
    if (style.selected) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeJoin = StrokeJoin.round
          ..color = AppColors.g1.withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
    }
    canvas.drawPath(path, Paint()..color = style.fill);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = style.outline,
    );
  }

  @override
  bool shouldRepaint(MouthMapPainter old) => !mapEquals(old.styles, styles);
}

/// Fits an arch (in millimetres) into [box], front teeth toward the outside
/// edge: the top for the upper arch, the bottom for the lower.
_ArchLayout _fitArch(DentalArch arch, Rect box) {
  final geometry = _ArchGeometry.of(arch);
  final b = geometry.bounds;
  final s = math.min(box.width / b.width, box.height / b.height);
  final flip = arch == DentalArch.lower;
  final origin = Offset(
    box.center.dx,
    flip
        ? box.center.dy + b.height * s / 2 + b.top * s
        : box.center.dy - b.height * s / 2 - b.top * s,
  );
  Offset map(Offset mm) =>
      origin + Offset(mm.dx * s, flip ? -mm.dy * s : mm.dy * s);
  Offset dir(Offset v) => Offset(v.dx, flip ? -v.dy : v.dy);

  return _ArchLayout(
    arch: arch,
    scale: s,
    centerline: geometry.centerline.map(map).toList(),
    gumWidth: geometry.gumWidth * s,
    teeth: [
      for (final t in geometry.teeth)
        _PlacedTooth(
          side: t.side,
          kind: t.kind,
          center: map(t.center),
          distal: dir(t.distal),
          outward: dir(t.outward),
          halfLength: t.length * s / 2,
          halfDepth: t.depth * s / 2,
        ),
    ],
  );
}

// ── Tooth anatomy ───────────────────────────────────────────────

abstract class _ToothShapes {
  static final Map<ToothKind, Path> _outlines = {};

  /// Occlusal outline in the unit frame (x distal, y outward).
  static Path outline(ToothKind kind) => _outlines.putIfAbsent(kind, () {
        switch (kind) {
          case ToothKind.centralIncisor:
          case ToothKind.lateralIncisor:
            // Broad labial face narrowing to the cingulum.
            return Path()
              ..moveTo(-1.0, 0.42)
              ..cubicTo(-0.72, 0.86, 0.72, 0.86, 1.0, 0.42)
              ..cubicTo(1.06, -0.1, 0.62, -0.9, 0, -0.92)
              ..cubicTo(-0.62, -0.9, -1.06, -0.1, -1.0, 0.42)
              ..close();
          case ToothKind.canine:
            // Rounded diamond with a labial bulge.
            return Path()
              ..moveTo(-1.0, 0.1)
              ..cubicTo(-0.86, 0.72, -0.42, 1.0, 0, 1.0)
              ..cubicTo(0.42, 1.0, 0.86, 0.72, 1.0, 0.1)
              ..cubicTo(0.82, -0.56, 0.36, -1.0, 0, -1.0)
              ..cubicTo(-0.36, -1.0, -0.82, -0.56, -1.0, 0.1)
              ..close();
          case ToothKind.firstPremolar:
          case ToothKind.secondPremolar:
            return Path()
              ..moveTo(-0.94, 0.05)
              ..cubicTo(-0.97, 0.76, -0.5, 1.0, 0, 1.0)
              ..cubicTo(0.5, 1.0, 0.97, 0.76, 0.94, 0.05)
              ..cubicTo(0.9, -0.66, 0.46, -0.98, 0, -0.98)
              ..cubicTo(-0.46, -0.98, -0.9, -0.66, -0.94, 0.05)
              ..close();
          case ToothKind.firstMolar:
          case ToothKind.secondMolar:
            // Rounded rhomboid crown.
            return Path()
              ..moveTo(-0.96, 0)
              ..cubicTo(-1.0, 0.66, -0.66, 1.0, 0, 0.98)
              ..cubicTo(0.7, 0.98, 1.0, 0.62, 0.96, 0)
              ..cubicTo(0.93, -0.66, 0.6, -1.0, 0, -0.96)
              ..cubicTo(-0.64, -1.0, -0.93, -0.62, -0.96, 0)
              ..close();
        }
      });

  /// Cusps catch the light; grooves sit in shadow with a lit lip on the
  /// side facing the light, which reads as carved depth.
  static void paintSurface(Canvas canvas, ToothKind kind, Offset light) {
    switch (kind) {
      case ToothKind.centralIncisor:
      case ToothKind.lateralIncisor:
        _fossa(canvas, const Offset(0, -0.2), 0.6, alpha: 0.12);
        _groove(
          canvas,
          Path()
            ..moveTo(-0.78, 0.36)
            ..quadraticBezierTo(0, 0.44, 0.78, 0.36),
          light,
        );
        _ridge(
            canvas,
            Path()
              ..moveTo(-0.84, 0.5)
              ..quadraticBezierTo(0, 0.6, 0.84, 0.5),
            0.16);
        _ridge(
            canvas,
            Path()
              ..moveTo(-0.78, 0.28)
              ..quadraticBezierTo(-0.55, -0.4, -0.12, -0.78),
            0.08,
            alpha: 0.45);
        _ridge(
            canvas,
            Path()
              ..moveTo(0.78, 0.28)
              ..quadraticBezierTo(0.55, -0.4, 0.12, -0.78),
            0.08,
            alpha: 0.45);
      case ToothKind.canine:
        _fossa(canvas, const Offset(-0.42, -0.38), 0.36);
        _fossa(canvas, const Offset(0.42, -0.38), 0.36);
        _cusp(canvas, const Offset(0, 0.28), 0.5, light);
        for (final end in const [
          Offset(-0.86, 0.1),
          Offset(0.86, 0.1),
          Offset(0, -0.86),
        ]) {
          _ridge(
              canvas,
              Path()
                ..moveTo(0, 0.28)
                ..lineTo(end.dx, end.dy),
              0.1,
              alpha: end.dy < 0 ? 0.4 : 0.6);
        }
      case ToothKind.firstPremolar:
      case ToothKind.secondPremolar:
        _occlusalTable(canvas, kind);
        _cusp(canvas, const Offset(0, 0.46), 0.58, light);
        _cusp(canvas, const Offset(0, -0.5), 0.46, light, alpha: 0.8);
        _groove(
          canvas,
          Path()
            ..moveTo(-0.62, 0.0)
            ..quadraticBezierTo(0, -0.1, 0.62, 0.0),
          light,
        );
        _pit(canvas, const Offset(-0.62, 0.0));
        _pit(canvas, const Offset(0.62, 0.0));
      case ToothKind.firstMolar:
      case ToothKind.secondMolar:
        _occlusalTable(canvas, kind);
        for (final c in const [
          Offset(-0.46, 0.48),
          Offset(0.46, 0.5),
          Offset(-0.44, -0.46),
          Offset(0.48, -0.42),
        ]) {
          _cusp(canvas, c, 0.5, light);
        }
        _groove(
          canvas,
          Path()
            ..moveTo(-0.6, 0.08)
            ..cubicTo(-0.2, -0.1, 0.2, 0.1, 0.6, -0.06),
          light,
        );
        _groove(
          canvas,
          Path()
            ..moveTo(-0.02, 0.02)
            ..quadraticBezierTo(0.06, 0.32, 0.02, 0.6),
          light,
        );
        _groove(
          canvas,
          Path()
            ..moveTo(0.06, -0.0)
            ..quadraticBezierTo(0.16, -0.3, 0.12, -0.58),
          light,
        );
        _pit(canvas, const Offset(0.02, 0.0));
    }
  }

  /// Raised marginal ridge around a hollow central fossa.
  static void _occlusalTable(Canvas canvas, ToothKind kind) {
    canvas.drawPath(
      outline(kind).transform(Matrix4.diagonal3Values(0.8, 0.8, 1).storage),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.14
        ..color = AppColors.white.withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.06),
    );
    _fossa(canvas, Offset.zero, 0.62, alpha: 0.13);
  }

  static void _cusp(
    Canvas canvas,
    Offset c,
    double r,
    Offset light, {
    double alpha = 0.95,
  }) {
    final center = c + light * 0.08;
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.white.withValues(alpha: alpha),
            AppColors.white.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
  }

  static void _fossa(
    Canvas canvas,
    Offset c,
    double r, {
    double alpha = 0.09,
  }) {
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.navy.withValues(alpha: alpha),
            AppColors.navy.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  static void _ridge(
    Canvas canvas,
    Path path,
    double width, {
    double alpha = 0.85,
  }) {
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = width
        ..color = AppColors.white.withValues(alpha: alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.04),
    );
  }

  static void _groove(Canvas canvas, Path path, Offset light) {
    canvas.drawPath(
      path.shift(light * 0.05),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 0.06
        ..color = AppColors.white.withValues(alpha: 0.7),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 0.08
        ..color = AppColors.navy.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.025),
    );
  }

  static void _pit(Canvas canvas, Offset c) {
    canvas.drawCircle(
      c,
      0.07,
      Paint()
        ..color = AppColors.navy.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.03),
    );
  }
}

// ── Arch geometry (millimetres) ─────────────────────────────────

class _ToothSpec {
  const _ToothSpec(this.kind, this.width, this.depth);
  final ToothKind kind;

  /// Mesiodistal width and buccolingual depth, approximate adult values.
  final double width;
  final double depth;
}

class _GeometryTooth {
  const _GeometryTooth({
    required this.side,
    required this.kind,
    required this.center,
    required this.distal,
    required this.outward,
    required this.length,
    required this.depth,
  });

  final DentalSide side;
  final ToothKind kind;
  final Offset center;
  final Offset distal;
  final Offset outward;
  final double length;
  final double depth;
}

/// One arch laid out along a curved centreline: front teeth at y = 0,
/// back teeth toward +y, the user's left toward −x.
class _ArchGeometry {
  _ArchGeometry._(this.teeth, this.centerline, this.bounds, this.gumWidth);

  final List<_GeometryTooth> teeth;
  final List<Offset> centerline;
  final Rect bounds;
  final double gumWidth;

  static final Map<DentalArch, _ArchGeometry> _cache = {};

  static _ArchGeometry of(DentalArch arch) =>
      _cache.putIfAbsent(arch, () => _build(arch));

  static const _upper = [
    _ToothSpec(ToothKind.centralIncisor, 8.5, 7.0),
    _ToothSpec(ToothKind.lateralIncisor, 6.5, 6.0),
    _ToothSpec(ToothKind.canine, 7.5, 8.0),
    _ToothSpec(ToothKind.firstPremolar, 7.0, 9.0),
    _ToothSpec(ToothKind.secondPremolar, 6.5, 9.0),
    _ToothSpec(ToothKind.firstMolar, 10.0, 11.0),
    _ToothSpec(ToothKind.secondMolar, 9.0, 11.0),
  ];

  static const _lower = [
    _ToothSpec(ToothKind.centralIncisor, 5.0, 6.0),
    _ToothSpec(ToothKind.lateralIncisor, 5.5, 6.5),
    _ToothSpec(ToothKind.canine, 7.0, 7.5),
    _ToothSpec(ToothKind.firstPremolar, 7.0, 7.5),
    _ToothSpec(ToothKind.secondPremolar, 7.0, 8.0),
    _ToothSpec(ToothKind.firstMolar, 11.0, 10.5),
    _ToothSpec(ToothKind.secondMolar, 10.5, 10.0),
  ];

  static _ArchGeometry _build(DentalArch arch) {
    final upper = arch == DentalArch.upper;
    final specs = upper ? _upper : _lower;
    // Half-arch centreline as a cubic Bézier from the midline.
    final p = upper
        ? const [Offset(0, 0), Offset(12, 0), Offset(26, 12), Offset(28, 40)]
        : const [Offset(0, 0), Offset(10, 0), Offset(23, 10), Offset(25, 37)];

    Offset bezier(double t) {
      final u = 1 - t;
      return p[0] * (u * u * u) +
          p[1] * (3 * u * u * t) +
          p[2] * (3 * u * t * t) +
          p[3] * (t * t * t);
    }

    const samples = 240;
    final points = [for (var i = 0; i <= samples; i++) bezier(i / samples)];
    final lengths = <double>[0];
    for (var i = 1; i < points.length; i++) {
      lengths.add(lengths.last + (points[i] - points[i - 1]).distance);
    }
    final total = lengths.last;
    final widthSum = specs.fold<double>(0, (s, t) => s + t.width);
    final k = total / widthSum;

    (Offset, Offset) at(double s) {
      var i = 1;
      while (i < lengths.length - 1 && lengths[i] < s) {
        i++;
      }
      final f = ((s - lengths[i - 1]) / (lengths[i] - lengths[i - 1]))
          .clamp(0.0, 1.0);
      final pos = Offset.lerp(points[i - 1], points[i], f)!;
      final d = points[i] - points[i - 1];
      return (pos, d / d.distance);
    }

    final teeth = <_GeometryTooth>[];
    var cursor = 0.0;
    for (final spec in specs) {
      final w = spec.width * k;
      final (pos, tangent) = at(cursor + w / 2);
      cursor += w;
      // Outward normal of the right half (toward the lips/cheek).
      final outward = Offset(tangent.dy, -tangent.dx);
      for (final side in DentalSide.values) {
        final m = side == DentalSide.left ? -1.0 : 1.0;
        teeth.add(_GeometryTooth(
          side: side,
          kind: spec.kind,
          center: Offset(pos.dx * m, pos.dy),
          distal: Offset(tangent.dx * m, tangent.dy),
          outward: Offset(outward.dx * m, outward.dy),
          length: w * 0.96,
          depth: spec.depth * math.min(k, 1.0),
        ));
      }
    }

    final centerline = [
      for (final pt in points.reversed) Offset(-pt.dx, pt.dy),
      ...points.skip(1),
    ];

    var bounds = Rect.zero;
    for (final t in teeth) {
      final r = math.max(t.length, t.depth) / 2 + 1.5;
      bounds =
          bounds.expandToInclude(Rect.fromCircle(center: t.center, radius: r));
    }
    final maxDepth = specs.map((s) => s.depth).reduce(math.max);
    return _ArchGeometry._(teeth, centerline, bounds, maxDepth * 1.35);
  }
}

class _ArchLayout {
  const _ArchLayout({
    required this.arch,
    required this.scale,
    required this.centerline,
    required this.gumWidth,
    required this.teeth,
  });

  final DentalArch arch;
  final double scale;
  final List<Offset> centerline;
  final double gumWidth;
  final List<_PlacedTooth> teeth;
}

class _PlacedTooth {
  const _PlacedTooth({
    required this.side,
    required this.kind,
    required this.center,
    required this.distal,
    required this.outward,
    required this.halfLength,
    required this.halfDepth,
  });

  final DentalSide side;
  final ToothKind kind;
  final Offset center;
  final Offset distal;
  final Offset outward;
  final double halfLength;
  final double halfDepth;
}
