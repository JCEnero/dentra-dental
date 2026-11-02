import 'dart:math' as math;

import '../../dental_explorer/geometry/mesh.dart';

/// A flat patch on the device's surface, where an inset or printed part sits.
class DeviceFrame {
  const DeviceFrame({
    required this.center,
    required this.right,
    required this.up,
  });

  final Vec3 center;
  final Vec3 right;
  final Vec3 up;

  /// The way the patch faces, out of the shell.
  Vec3 get normal => right.cross(up).normalized();
}

/// A 3D model of the DENTRA intraoral camera, laid out from its schematic: a
/// handle sized for the 2000 mAh cell and the ESP32-S3 board, a slim neck for
/// the camera's ribbon cable, and a round head for the OV5640 lens inside its
/// ten LEDs. The controls on it are the schematic's own: Capture and Light on
/// the front, Power on the side.
///
/// One closed lofted shell, in millimetres, with the tip along +y and the lens
/// facing +z. The lens and buttons are drawn onto it by `DeviceArt`, so they
/// stay crisp at any size.
class DeviceModel {
  DeviceModel._(this.mesh, this.ringCount);

  static final DeviceModel instance = _build();

  final DentitionMesh mesh;

  /// Rings along the shell, from the base up. Each has [segments] vertices.
  final int ringCount;

  static const int segments = 72;

  static const double baseY = -88;
  static const double tipY = 88;

  /// Center of the round head, which the lens sits in.
  static const double headY = 80;
  static const double headRadius = 8;
  static const double headDepth = 5.2;

  /// Where the base starts rounding off, just under its seam.
  static const double _capY = -72;

  // The two seams: the charging base, and the accent band at the shoulder.
  static const double _baseSeam = -71;
  static const double _bandBottom = 11;
  static const double _bandTop = 13.2;

  static const _shell = Rgb(0.955, 0.972, 0.972);
  static const _accent = Rgb(0.173, 0.651, 0.643); // AppColors.g2
  static const _seam = Rgb(0.55, 0.65, 0.67);

  // Half-width, half-depth and squareness along the axis, up to the head.
  static const _width = [
    (_capY, 16.2),
    (-62.0, 16.9),
    (-38.0, 16.6),
    (-12.0, 15.4),
    (6.0, 13.4),
    (20.0, 10.4),
    (34.0, 8.0),
    (48.0, 6.6),
    (58.0, 6.2),
    (66.0, 6.3),
    (72.0, 6.9),
    (77.0, 7.7),
    (headY, headRadius),
  ];
  static const _depth = [
    (_capY, 11.4),
    (-62.0, 12.0),
    (-38.0, 11.8),
    (-12.0, 11.0),
    (6.0, 9.6),
    (20.0, 7.6),
    (34.0, 5.9),
    (48.0, 5.0),
    (58.0, 5.0),
    (68.0, 5.0),
    (74.0, 5.1),
    (headY, headDepth),
  ];
  static const _square = [
    (_capY, 3.2),
    (6.0, 3.2),
    (34.0, 2.5),
    (58.0, 2.5),
    (68.0, 4.0),
    (tipY, 4.0),
  ];

  /// Smooth curve through [keys] (Hermite, flat at both ends).
  static double _spline(List<(double, double)> keys, double y) {
    if (y <= keys.first.$1) return keys.first.$2;
    if (y >= keys.last.$1) return keys.last.$2;
    var i = 0;
    while (y > keys[i + 1].$1) {
      i++;
    }
    double slope(int k) {
      if (k <= 0 || k >= keys.length - 1) return 0;
      return (keys[k + 1].$2 - keys[k - 1].$2) /
          (keys[k + 1].$1 - keys[k - 1].$1);
    }

    final (x0, v0) = keys[i];
    final (x1, v1) = keys[i + 1];
    final h = x1 - x0, t = (y - x0) / h;
    final t2 = t * t, t3 = t2 * t;
    return (2 * t3 - 3 * t2 + 1) * v0 +
        (t3 - 2 * t2 + t) * h * slope(i) +
        (3 * t2 - 2 * t3) * v1 +
        (t3 - t2) * h * slope(i + 1);
  }

  /// The neck leans forward, so the head reaches the teeth ahead of the hand.
  static double _lean(double y) {
    final t = ((y - 6) / 56).clamp(0.0, 1.0);
    return 5.5 * t * t * (3 - 2 * t);
  }

  static (double, double) _radii(double y) {
    if (y < _capY) {
      final k = ((_capY - y) / (_capY - baseY)).clamp(0.0, 1.0);
      // Curvature grows from nothing, so no line shows where it starts.
      final s = math.pow(1 - k * k * k, 1 / 3).toDouble();
      return (_spline(_width, _capY) * s, _spline(_depth, _capY) * s);
    }
    if (y <= headY) return (_spline(_width, y), _spline(_depth, y));
    // A flat-faced disc: full depth almost to its rim.
    final k = ((y - headY) / headRadius).clamp(0.0, 1.0);
    return (
      headRadius * math.sqrt(1 - k * k),
      headDepth * math.pow(1 - math.pow(k, 5), 0.2).toDouble(),
    );
  }

  /// The point on the shell at height [y] and [angle] round it (0 is the +x
  /// side, pi/2 is the front), [inset] under the surface.
  static Vec3 surface(double y, double angle, {double inset = 0}) {
    final (a, b) = _radii(y);
    final e = 2 / _spline(_square, y);
    final c = math.cos(angle), s = math.sin(angle);
    return Vec3(
      (a - inset) * c.sign * math.pow(c.abs(), e).toDouble(),
      y,
      _lean(y) + (b - inset) * s.sign * math.pow(s.abs(), e).toDouble(),
    );
  }

  /// The flat patch touching the shell at height [y] and [angle] round it.
  static DeviceFrame patch(double y, double angle) {
    const dy = 0.5, da = 0.04;
    return DeviceFrame(
      center: surface(y, angle),
      // The angle grows from the +x side toward the front, so against it is
      // to the right when looking at the shell from outside.
      right: (surface(y, angle - da) - surface(y, angle + da)).normalized(),
      up: (surface(y + dy, angle) - surface(y - dy, angle)).normalized(),
    );
  }

  /// A patch on the very front of the shell, where the lens and buttons sit.
  static DeviceFrame front(double y) => patch(y, math.pi / 2);

  static Rgb _colorAt(double y) =>
      y < _baseSeam || (y > _bandBottom && y < _bandTop) ? _accent : _shell;

  static List<SurfaceVertex> _ring(double y, Rgb color, {double inset = 0}) => [
        for (var k = 0; k < segments; k++)
          SurfaceVertex(
            surface(y, 2 * math.pi * k / segments, inset: inset),
            color,
          ),
      ];

  /// Heights of the rings, denser where the shape curves.
  static List<double> _stations() => [
        for (var k = 23; k >= 1; k--)
          _capY - (_capY - baseY) * math.sin(k / 24 * math.pi / 2),
        for (var y = _capY; y < 6; y += 3) y,
        for (var y = 6.0; y < 62; y += 2) y,
        for (var y = 62.0; y < headY; y += 1) y,
        for (var k = 0; k < 28; k++)
          headY + headRadius * math.sin(k / 28 * math.pi / 2),
      ];

  static DeviceModel _build() {
    const seams = [_baseSeam, _bandBottom, _bandTop];
    final rings = <List<SurfaceVertex>>[];
    var next = 0;
    for (final y in _stations()) {
      // A seam is a thin groove, with a hard colour change on either side.
      while (next < seams.length && seams[next] - 0.7 < y) {
        final at = seams[next++];
        rings
          ..add(_ring(at - 0.3, _colorAt(at - 0.5)))
          ..add(_ring(at - 0.14, _seam, inset: 0.28))
          ..add(_ring(at + 0.14, _seam, inset: 0.28))
          ..add(_ring(at + 0.3, _colorAt(at + 0.5)));
      }
      if (seams.any((at) => (y - at).abs() < 0.7)) continue;
      rings.add(_ring(y, _colorAt(y)));
    }

    final out = MeshBuilder()
      ..addRingSurface(
        rings,
        owner: 0,
        startPole: SurfaceVertex(Vec3(0, baseY, _lean(baseY)), _accent),
        endPole: SurfaceVertex(Vec3(0, tipY, _lean(tipY)), _shell),
      );
    return DeviceModel._(out.build(), rings.length);
  }
}
