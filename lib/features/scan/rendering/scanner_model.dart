import 'dart:math' as math;

import '../../dental_explorer/geometry/dentition_builder.dart';
import '../../dental_explorer/geometry/mesh.dart';

/// A 3D model of the Dentra Scan Pro: a slim intraoral wand with a white
/// shell, a mint grip underneath, a status light ring and a glass scan
/// window under the tip.
///
/// Built from cross-sections along the wand and drawn with the same
/// renderer as the teeth, which lights it like glossy plastic.
class ScannerModel {
  ScannerModel._(this.model, this.window, this.windowNormal);

  static final ScannerModel instance = _build();

  final DentitionModel model;

  /// Middle of the scan window, and the way it faces (down and out).
  final Vec3 window;
  final Vec3 windowNormal;

  /// Owners in the scene style.
  static const int body = 0;
  static const int light = 1;

  // Wand length and the tilt it's shown at (tip raised), radians.
  static const double _length = 120;
  static const double _tilt = 0.2;
  static const int _segments = 32;

  static const _shell = Rgb(0.96, 0.975, 0.975);
  static const _grip = Rgb(0.58, 0.87, 0.84);
  static const _button = Rgb(0.82, 0.91, 0.9);
  static const _glass = Rgb(0.11, 0.19, 0.22);
  static const _led = Rgb(0.3, 0.85, 0.8);

  static double _smooth(double t) {
    final c = t.clamp(0.0, 1.0);
    return c * c * (3 - 2 * c);
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  /// Half-height and half-depth of the cross-section at [x] along the
  /// wand: a rounded back, a gently swelling handle, a taper into the
  /// neck, then a slightly wider, flatter head.
  static (double, double) _radii(double x) {
    double handleY(double x) =>
        10.4 + 0.9 * math.sin(math.pi * ((x - 6) / 56).clamp(0.0, 1.0));
    double handleZ(double x) =>
        9.6 + 0.6 * math.sin(math.pi * ((x - 6) / 56).clamp(0.0, 1.0));

    if (x < 6) {
      final k = math.sqrt(1 - math.pow((6 - x) / 6, 2));
      return (handleY(6) * k, handleZ(6) * k);
    }
    if (x <= 62) return (handleY(x), handleZ(x));
    if (x <= 80) {
      final t = _smooth((x - 62) / 18);
      return (_lerp(handleY(62), 5.0, t), _lerp(handleZ(62), 4.6, t));
    }
    if (x <= 96) return (5.0 + 0.3 * (x - 80) / 16, 4.6);
    if (x <= 101) {
      final t = _smooth((x - 96) / 5);
      return (_lerp(5.3, 7.0, t), _lerp(4.6, 5.4, t));
    }
    if (x <= 114) return (7.0, 5.4);
    final k = math.sqrt(1 - math.pow(((x - 114) / 6).clamp(0.0, 1.0), 2));
    return (7.0 * k, 5.4 * k);
  }

  /// Positions along the wand, denser where the shape curves.
  static List<double> _stations() => [
        0.25, 0.8, 1.6, 2.6, 3.8, 5.2, //
        for (var x = 6.5; x < 62; x += 3) x,
        for (var x = 62.0; x < 80; x += 2) x,
        for (var x = 80.0; x < 96; x += 4) x,
        for (var x = 96.0; x < 102; x += 1.5) x,
        for (var x = 102.0; x < 114; x += 2.5) x,
        114.0, 115.5, 116.8, 117.9, 118.8, 119.4, 119.8,
      ];

  /// Centers the wand on the origin and raises the tip.
  static Vec3 _place(double x, double y, double z) {
    final cx = x - _length / 2;
    final c = math.cos(_tilt), s = math.sin(_tilt);
    return Vec3(cx * c - y * s, cx * s + y * c, z);
  }

  static Rgb _colorAt(double x, double up) {
    if (x > 102.5 && x < 112.5 && up < -0.55) return _glass;
    if (x > 44 && x < 50 && up > 0.88) return _button;
    if (x > 28 && x < 52 && up < 0.15) return _grip;
    return _shell;
  }

  static List<SurfaceVertex> _ring(double x, {double grow = 0, Rgb? color}) {
    final (ry, rz) = _radii(x);
    return [
      for (var k = 0; k < _segments; k++)
        () {
          final a = 2 * math.pi * k / _segments;
          final up = math.cos(a);
          return SurfaceVertex(
            _place(x, (ry + grow) * up, (rz + grow) * math.sin(a)),
            color ?? _colorAt(x, up),
          );
        }(),
    ];
  }

  static ScannerModel _build() {
    final out = MeshBuilder();
    out.addRingSurface(
      [for (final x in _stations()) _ring(x)],
      owner: body,
      startPole: SurfaceVertex(_place(0, 0, 0), _shell),
      endPole: SurfaceVertex(_place(_length, 0, 0), _shell),
    );
    // The light ring sits just proud of the shell where the handle
    // starts to taper.
    out.addRingSurface(
      [
        for (final x in const [56.6, 57.2, 57.8, 58.4])
          _ring(x, grow: 0.18, color: _led),
      ],
      owner: light,
    );

    final mesh = out.build();
    var radius = 0.0;
    for (var v = 0; v < mesh.vertexCount; v++) {
      final p = Vec3(mesh.positions[v * 3], mesh.positions[v * 3 + 1],
          mesh.positions[v * 3 + 2]);
      radius = math.max(radius, p.length);
    }

    const wx = 107.5;
    final (wy, _) = _radii(wx);
    final window = _place(wx, -wy, 0);
    final windowNormal = (_place(wx, -wy - 1, 0) - window).normalized();

    return ScannerModel._(
      DentitionModel(
        mesh: mesh,
        anchors: const [],
        center: Vec3.zero,
        radius: radius,
        rightMarker: Vec3.zero,
        leftMarker: Vec3.zero,
      ),
      window,
      windowNormal,
    );
  }
}
