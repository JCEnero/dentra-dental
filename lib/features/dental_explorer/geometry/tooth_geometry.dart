import 'dart:math' as math;

import '../data/tooth_catalog.dart';
import 'mesh.dart';

/// Mesh density. The renderer drops to [low] on slow devices.
class MeshDetail {
  const MeshDetail._(this.segments, this.wallRings, this.capRings,
      this.rootRings, this.rootSegments, this.gumSamples);

  /// Vertices around each tooth ring.
  final int segments;
  final int wallRings;
  final int capRings;
  final int rootRings;
  final int rootSegments;

  /// Gum cross-sections per tooth.
  final int gumSamples;

  static const high = MeshDetail._(36, 12, 9, 9, 16, 7);
  static const low = MeshDetail._(20, 7, 5, 5, 10, 4);
}

/// Places a tooth in the world. The tooth is built in local coordinates:
/// x runs mesial (−) to distal (+), z lingual (−) to buccal (+), and y
/// from the cusp tips (0) toward the root apex (+). [cej] is the world
/// position of the local point (0, crownLength, 0).
class ToothFrame {
  const ToothFrame({
    required this.cej,
    required this.distal,
    required this.apical,
    required this.buccal,
    required this.crownLength,
  });

  final Vec3 cej;
  final Vec3 distal;
  final Vec3 apical;
  final Vec3 buccal;
  final double crownLength;

  Vec3 toWorld(double x, double y, double z) =>
      cej + distal * x + apical * (y - crownLength) + buccal * z;
}

class _Cusp {
  const _Cusp(this.x, this.z, this.h, [this.sigma = 0.42]);

  /// Normalised position on the occlusal outline (−1 … 1).
  final double x, z;

  /// Relative height (1 = full cusp).
  final double h;
  final double sigma;
}

class _Root {
  const _Root(this.x, this.z, this.rx, this.rz, this.length,
      {this.splayX = 0, this.splayZ = 0});

  /// Base offset as a fraction of the cervical half-widths.
  final double x, z;

  /// Base radii as a fraction of the cervical half-widths.
  final double rx, rz;

  /// Length from the cementoenamel junction, as a fraction of root length.
  final double length;

  /// Sideways drift at the apex, in mm.
  final double splayX, splayZ;
}

/// Wall profile key: crown half-widths at fraction [t] from the occlusal
/// rim (0) to the cementoenamel junction (1), as fractions of the crown's
/// maximum half-widths.
class _Key {
  const _Key(this.t, this.a, this.bBuccal, this.bLingual);
  final double t, a, bBuccal, bLingual;
}

/// Procedural shape of one permanent tooth, from its type and the
/// reference measurements in [ToothDimensions].
class ToothShape {
  ToothShape(this.tooth) {
    final d = tooth.dimensions;
    halfMd = d.mesiodistal / 2;
    halfBl = d.buccolingual / 2;
    halfMdCervical = d.mesiodistalCervical / 2;
    halfBlCervical = d.buccolingualCervical / 2;
    crownLength = d.crownLength;
    rootLength = d.rootLength;
    _configure();
  }

  final ToothInfo tooth;
  late final double halfMd, halfBl, halfMdCervical, halfBlCervical;
  late final double crownLength, rootLength;

  // ── Type-specific parameters ──────────────────────────────────
  late final double _exponent;
  late final List<_Key> _wall;
  late final List<_Cusp> _cusps;

  /// Fossa depth below the cusp tips (posterior teeth).
  double _occlusalDepth = 0;

  /// Lingual fossa depth for front teeth (fraction of lingual width).
  double _lingualFossa = 0;

  /// Buccal ridge prominence (canines, premolars).
  double _buccalRidge = 0;

  /// Rounds the incisal edge of front teeth into a soft ridge.
  double _edgeBulge = 0;

  /// Upper molars have a rhomboid outline.
  double _skew = 0;

  /// Root bend toward distal, as a fraction of root length.
  double _rootCurve = 0.05;

  /// Root trunk length before the roots split (multi-rooted teeth).
  double _trunk = 0;
  List<_Root> _roots = const [];

  bool get _posterior => tooth.position >= 4;
  bool get _upper => tooth.arch == ToothArch.upper;

  void _configure() {
    switch (tooth.type) {
      case ToothType.incisor:
        _exponent = 2.3;
        _lingualFossa = _upper ? 0.42 : 0.18;
        _wall = const [
          _Key(0.00, 0.94, 0.16, 0.16),
          _Key(0.18, 1.00, 0.48, 0.34),
          _Key(0.45, 0.97, 0.80, 0.70),
          _Key(0.75, 0.90, 0.98, 1.00),
          _Key(1.00, 0.0, 0.92, 0.88), // a set from cervical below
        ];
        _cusps = const [];
        _edgeBulge = 0.35;
        _rootCurve = 0.04;
      case ToothType.canine:
        _exponent = 2.2;
        _lingualFossa = _upper ? 0.22 : 0.12;
        _buccalRidge = 0.10;
        _wall = const [
          _Key(0.00, 0.80, 0.20, 0.20),
          _Key(0.25, 1.00, 0.64, 0.52),
          _Key(0.55, 0.95, 0.92, 0.88),
          _Key(0.80, 0.86, 1.00, 1.00),
          _Key(1.00, 0.0, 0.94, 0.90),
        ];
        _cusps = const [];
        _edgeBulge = 0.4;
        _rootCurve = 0.06;
      case ToothType.premolar:
        _exponent = 2.4;
        _buccalRidge = 0.05;
        _occlusalDepth = 2.3;
        _wall = const [
          _Key(0.00, 0.84, 0.66, 0.66),
          _Key(0.25, 1.00, 0.90, 0.92),
          _Key(0.50, 0.98, 0.99, 1.00),
          _Key(0.72, 0.92, 1.00, 0.96),
          _Key(1.00, 0.0, 0.90, 0.86),
        ];
        _cusps = switch ((tooth.arch, tooth.position)) {
          (ToothArch.upper, 4) => const [
              _Cusp(0, 0.48, 1.0),
              _Cusp(0, -0.48, 0.86)
            ],
          (ToothArch.upper, _) => const [
              _Cusp(0, 0.46, 0.96),
              _Cusp(0, -0.46, 0.94)
            ],
          (ToothArch.lower, 4) => const [
              _Cusp(0, 0.34, 1.05, 0.5),
              _Cusp(0, -0.6, 0.42, 0.34)
            ],
          _ => const [
              _Cusp(0, 0.42, 1.0),
              _Cusp(-0.36, -0.5, 0.84, 0.36),
              _Cusp(0.38, -0.5, 0.7, 0.34),
            ],
        };
        _rootCurve = 0.06;
        if (_upper && tooth.position == 4) {
          _trunk = 6.5;
          _roots = const [
            _Root(0, 0.44, 0.62, 0.34, 1.0, splayZ: 1.6),
            _Root(0, -0.44, 0.6, 0.33, 0.97, splayZ: -1.6),
          ];
        }
      case ToothType.molar:
        _exponent = _upper ? 2.9 : 3.3;
        _skew = _upper ? 0.13 : 0;
        _occlusalDepth = 2.6;
        _wall = const [
          _Key(0.00, 0.82, 0.68, 0.70),
          _Key(0.28, 1.00, 0.90, 0.94),
          _Key(0.52, 0.98, 0.98, 1.00),
          _Key(0.75, 0.93, 1.00, 0.96),
          _Key(1.00, 0.0, 0.89, 0.86),
        ];
        _cusps = _molarCusps();
        _rootCurve = 0.07;
        _trunk = tooth.position == 8 ? 0 : 3.6;
        _roots = _molarRoots();
    }
  }

  List<_Cusp> _molarCusps() {
    if (_upper) {
      return switch (tooth.position) {
        6 => const [
            _Cusp(-0.45, 0.5, 0.95),
            _Cusp(0.45, 0.5, 0.88),
            _Cusp(-0.32, -0.46, 1.06, 0.48),
            _Cusp(0.52, -0.52, 0.72, 0.36),
            _Cusp(-0.58, -0.92, 0.38, 0.22), // cusp of Carabelli
          ],
        7 => const [
            _Cusp(-0.45, 0.5, 0.95),
            _Cusp(0.42, 0.46, 0.8),
            _Cusp(-0.28, -0.46, 1.0, 0.48),
            _Cusp(0.56, -0.56, 0.48, 0.3),
          ],
        _ => const [
            _Cusp(-0.42, 0.46, 0.9),
            _Cusp(0.36, 0.46, 0.74),
            _Cusp(-0.12, -0.46, 0.95, 0.5),
          ],
      };
    }
    return switch (tooth.position) {
      6 => const [
          _Cusp(-0.6, 0.5, 0.84, 0.36),
          _Cusp(-0.04, 0.56, 0.82, 0.36),
          _Cusp(0.62, 0.36, 0.6, 0.3),
          _Cusp(-0.48, -0.5, 1.0, 0.4),
          _Cusp(0.28, -0.5, 0.95, 0.4),
        ],
      7 => const [
          _Cusp(-0.45, 0.5, 0.86),
          _Cusp(0.45, 0.5, 0.84),
          _Cusp(-0.45, -0.5, 1.0),
          _Cusp(0.45, -0.5, 0.95),
        ],
      _ => const [
          _Cusp(-0.5, 0.5, 0.8, 0.36),
          _Cusp(0.1, 0.52, 0.78, 0.36),
          _Cusp(0.6, 0.2, 0.5, 0.3),
          _Cusp(-0.45, -0.5, 0.95, 0.38),
          _Cusp(0.35, -0.5, 0.88, 0.38),
        ],
    };
  }

  List<_Root> _molarRoots() {
    if (tooth.position == 8) return const []; // fused, single cone
    if (_upper) {
      final s = tooth.position == 6 ? 1.0 : 0.6; // second molar: closer
      return [
        _Root(-0.44, 0.44, 0.34, 0.32, 0.92, splayX: -1.6 * s, splayZ: 1.2 * s),
        _Root(0.44, 0.44, 0.3, 0.3, 0.86, splayX: 1.0 * s, splayZ: 1.2 * s),
        _Root(0, -0.46, 0.34, 0.36, 1.0, splayZ: -2.6 * s),
      ];
    }
    final s = tooth.position == 6 ? 1.0 : 0.55;
    return [
      _Root(-0.46, 0, 0.3, 0.78, 1.0, splayX: -1.4 * s),
      _Root(0.46, 0, 0.27, 0.72, 0.92, splayX: 1.4 * s),
    ];
  }

  // ── Profile queries ───────────────────────────────────────────

  static double _smooth(double t) => t * t * (3 - 2 * t);

  /// Crown half-widths (mesiodistal, buccal, lingual) at wall fraction t.
  /// Interpolated with a Catmull-Rom spline through the keys, so the
  /// slope is continuous and the walls shade without banding.
  (double, double, double) wallAt(double t) {
    t = t.clamp(0.0, 1.0);
    var i = 0;
    while (i < _wall.length - 2 && _wall[i + 1].t < t) {
      i++;
    }
    final k0 = _wall[i], k1 = _wall[i + 1];
    final f = ((t - k0.t) / (k1.t - k0.t)).clamp(0.0, 1.0);
    final prev = _wall[math.max(0, i - 1)];
    final next = _wall[math.min(_wall.length - 1, i + 2)];

    double aOf(_Key k) => k.t == 1 ? halfMdCervical : k.a * halfMd;
    double bbOf(_Key k) =>
        k.t == 1 ? k.bBuccal * halfBlCervical : k.bBuccal * halfBl;
    double blOf(_Key k) =>
        k.t == 1 ? k.bLingual * halfBlCervical : k.bLingual * halfBl;

    // Hermite segment with tangents scaled to this segment's length.
    double spline(double Function(_Key) v) {
      final h = k1.t - k0.t;
      final m0 = (v(k1) - v(prev)) / math.max(k1.t - prev.t, 1e-6) * h;
      final m1 = (v(next) - v(k0)) / math.max(next.t - k0.t, 1e-6) * h;
      final f2 = f * f, f3 = f2 * f;
      return (2 * f3 - 3 * f2 + 1) * v(k0) +
          (f3 - 2 * f2 + f) * m0 +
          (-2 * f3 + 3 * f2) * v(k1) +
          (f3 - f2) * m1;
    }

    return (spline(aOf), spline(bbOf), spline(blOf));
  }

  /// Distance of the occlusal surface below the cusp-tip plane at a
  /// normalised outline position.
  double occlusalY(double xn, double zn) {
    switch (tooth.type) {
      case ToothType.incisor:
        // Straight edge with rounded corners; the distal corner is rounder.
        final rounding = (xn > 0 ? 2.4 : 1.4) *
            (tooth.position == 2 || !_upper ? 1.25 : 1.0);
        final e = math.max(0.0, xn.abs() - 0.5) / 0.5;
        return 0.15 + rounding * e * e * e;
      case ToothType.canine:
        // Single cusp; the mesial slope is shorter than the distal one.
        const tip = -0.12;
        final slope = (xn < tip ? 2.3 : 2.9) * (_upper ? 1.0 : 0.85);
        final e = (xn - tip).abs() / (xn < tip ? 0.88 : 1.12);
        final corner = math.max(0.0, e - 0.75) / 0.25;
        return slope * math.pow(e, 1.15).toDouble() + 0.6 * corner * corner;
      case ToothType.premolar:
      case ToothType.molar:
        return _occlusalDepth * (1 - _elevation(xn, zn));
    }
  }

  /// 0 at the fossa floor, about 1 at the cusp tips.
  double _elevation(double xn, double zn) {
    // Soft maximum of the cusps: valleys between them read as grooves.
    var sum = 0.0;
    for (final c in _cusps) {
      final dx = xn - c.x, dz = zn - c.z;
      final v = c.h * math.exp(-(dx * dx + dz * dz) / (2 * c.sigma * c.sigma));
      sum += math.pow(v, 6).toDouble();
    }
    var e = math.pow(sum, 1 / 6).toDouble();

    // Marginal ridges close the table at the rim.
    final r = math.sqrt(xn * xn + zn * zn).clamp(0.0, 1.2);
    final ridge = 0.5 * _smooth(((r - 0.62) / 0.33).clamp(0.0, 1.0));
    e = math.max(e, ridge);

    // Upper first and second molars: oblique ridge from the
    // mesiopalatal cusp to the distobuccal cusp.
    if (_upper && tooth.type == ToothType.molar && tooth.position < 8) {
      final d = _segmentDistance(xn, zn, -0.3, -0.42, 0.42, 0.46);
      e = math.max(e, 0.62 * math.exp(-d * d / 0.02));
    }

    // Fine central groove along the mesiodistal axis.
    final groove = math.exp(-zn * zn / 0.012) *
        (1 - _smooth(((xn.abs() - 0.55) / 0.3).clamp(0.0, 1.0)));
    e -= 0.12 * groove;

    // Third molars: wrinkled, irregular surface.
    if (tooth.position == 8) {
      e -= 0.05 * math.sin(xn * 13 + zn * 7) * math.sin(zn * 11 - xn * 5);
    }
    return e.clamp(-0.1, 1.1);
  }

  static double _segmentDistance(
      double px, double pz, double ax, double az, double bx, double bz) {
    final vx = bx - ax, vz = bz - az;
    final t = (((px - ax) * vx + (pz - az) * vz) / (vx * vx + vz * vz))
        .clamp(0.0, 1.0);
    final dx = px - (ax + vx * t), dz = pz - (az + vz * t);
    return math.sqrt(dx * dx + dz * dz);
  }

  /// Wall fraction for a local height (approximate, for the gums).
  double _wallFraction(double y) {
    final rim = occlusalY(0, 1);
    return ((y - rim) / (crownLength - rim)).clamp(0.0, 1.0);
  }

  /// Buccal and lingual surface offsets of the crown at local (x, y).
  /// Used to fit the gum margin snugly around the neck of the tooth.
  (double, double) surfaceOffsets(double x, double y) {
    final (a, bb, bl) = wallAt(_wallFraction(y));
    final xs = (x / a).abs();
    if (xs >= 1) return (0, 0);
    final zs = math.pow(1 - math.pow(xs, _exponent), 1 / _exponent).toDouble();
    return (bb * zs, bl * zs);
  }

  // ── Mesh generation ───────────────────────────────────────────

  /// Point on the crown at wall fraction [t] and outline angle [phi];
  /// [r] < 1 shrinks it onto the occlusal table.
  ({double x, double y, double z, double xs, double zs}) _crownPoint(
      double t, double phi, double r) {
    final c = math.cos(phi), s = math.sin(phi);
    final e = 2 / _exponent;
    final xs = c.sign * math.pow(c.abs(), e).toDouble();
    final zs = s.sign * math.pow(s.abs(), e).toDouble();
    // Widths follow absolute height, so low incisal corners (canines,
    // rounded incisors) widen at the right level instead of folding.
    final yRim = occlusalY(xs, zs);
    final y = r < 1
        ? occlusalY(xs * r, zs * r) - _edgeBulge * (1 - r * r)
        : yRim + (crownLength - yRim) * t;
    final tw = (math.max(r < 1 ? yRim : y, 0.0) / crownLength).clamp(0.0, 1.0);
    final (a, bb, bl) = wallAt(tw);

    var x = a * xs * r;
    double z;
    if (zs >= 0) {
      // Vertical buccal/labial ridge down the middle of the crown.
      z = bb * zs * r * (1 + _buccalRidge * math.exp(-xs * xs / 0.08));
    } else {
      // Shovel-shaped lingual fossa between the marginal ridges,
      // deepest in the incisal half, with a central ridge on canines.
      final along = math.exp(-math.pow((tw - 0.35) / 0.28, 2).toDouble());
      var across = 1 - math.pow(xs.abs(), 4).toDouble();
      if (tooth.type == ToothType.canine) {
        across *= 1 - math.exp(-xs * xs / 0.03);
      }
      z = bl * zs * r * (1 - _lingualFossa * along * across);
    }
    x += _skew * z;
    return (x: x, y: y, z: z, xs: xs, zs: zs);
  }

  Rgb _enamel(double y, {double ao = 1}) {
    final f = (y / crownLength).clamp(0.0, 1.0);
    Rgb c;
    if (!_posterior && f < 0.3) {
      // Incisal third: thinner, slightly translucent enamel.
      c = Rgb.lerp(_incisal, _enamelBody, _smooth(f / 0.3));
    } else {
      c = Rgb.lerp(_enamelBody, _enamelCervical,
          _smooth(((f - 0.45) / 0.55).clamp(0.0, 1.0)));
    }
    return c * ao;
  }

  /// Darkens fossae and grooves on the chewing surface.
  double _occlusalShade(double y) {
    if (!_posterior) return 1;
    final f = (y / _occlusalDepth).clamp(0.0, 1.2);
    return 1 - 0.3 * _smooth(((f - 0.5) / 0.5).clamp(0.0, 1.0));
  }

  void build(MeshBuilder out, ToothFrame frame, MeshDetail detail) {
    final owner = tooth.index;
    final segs = detail.segments;
    final rings = <List<SurfaceVertex>>[];
    double phiOf(int s) => 2 * math.pi * s / segs;

    SurfaceVertex vert(double x, double y, double z, Rgb color) {
      final root = y > crownLength + 0.25 ? kFlagRoot : 0;
      return SurfaceVertex(
          frame.toWorld(x, y, z), color, root, math.max(0.0, y - crownLength));
    }

    // Occlusal pole down to the rim, then the wall down to the CEJ.
    final capY = occlusalY(0, 0);
    final endPole = vert(0, capY, 0, _enamel(0, ao: _occlusalShade(capY)));
    for (var k = 1; k < detail.capRings; k++) {
      final r = k / detail.capRings;
      rings.add([
        for (var s = 0; s < segs; s++)
          () {
            final p = _crownPoint(0, phiOf(s), r);
            return vert(
                p.x, p.y, p.z, _enamel(p.y * 0.4, ao: _occlusalShade(p.y)));
          }(),
      ]);
    }
    for (var j = 0; j <= detail.wallRings; j++) {
      final t = math.pow(j / detail.wallRings, 1.2).toDouble();
      rings.add([
        for (var s = 0; s < segs; s++)
          () {
            final p = _crownPoint(t, phiOf(s), 1);
            final shade = t == 0 ? _occlusalShade(p.y) : 1.0;
            return vert(p.x, p.y, p.z, _enamel(p.y, ao: shade));
          }(),
      ]);
    }

    // Below the CEJ: a single tapering root, or a short trunk that the
    // separate roots grow out of.
    final cejY = crownLength;
    final single = _roots.isEmpty;
    final span = single ? rootLength : _trunk;
    final steps = single ? detail.rootRings : 3;
    for (var j = 1; j <= steps; j++) {
      final f = j / (steps + (single ? 0.0 : 1.0));
      if (single && j == steps) break; // apex pole closes it
      final y = cejY + span * f;
      final scale = single ? _rootTaper(f) : 1 - 0.08 * f;
      final bend = single ? _rootCurve * rootLength * f * f : 0.0;
      rings.add([
        for (var s = 0; s < segs; s++)
          () {
            final phi = phiOf(s);
            final c = math.cos(phi), sn = math.sin(phi);
            // Roots round off toward the apex.
            final n = _exponent + (2 - _exponent) * f;
            final x = halfMdCervical *
                scale *
                c.sign *
                math.pow(c.abs(), 2 / n).toDouble();
            final z = halfBlCervical *
                scale *
                sn.sign *
                math.pow(sn.abs(), 2 / n).toDouble();
            return vert(x + bend + _skew * z * (1 - f), y, z,
                Rgb.lerp(_cementum, _apex, f * f));
          }(),
      ]);
    }
    final SurfaceVertex startPole;
    if (single) {
      startPole = vert(_rootCurve * rootLength, cejY + rootLength, 0, _apex);
    } else {
      // Rounded floor of the trunk, hidden among the roots.
      final y = cejY + _trunk;
      for (final (dy, sc) in const [(0.6, 0.78), (1.0, 0.45)]) {
        rings.add([
          for (var s = 0; s < segs; s++)
            () {
              final phi = phiOf(s);
              return vert(halfMdCervical * 0.92 * sc * math.cos(phi), y + dy,
                  halfBlCervical * 0.92 * sc * math.sin(phi), _cementum);
            }(),
        ]);
      }
      startPole = vert(0, y + 1.2, 0, _cementum);
    }

    // Rings run apex → occlusal for a consistent order.
    out.addRingSurface(
      rings.reversed.toList(),
      owner: owner,
      startPole: startPole,
      endPole: endPole,
    );

    for (final root in _roots) {
      _buildRoot(out, frame, detail, root, vert);
    }
  }

  /// Rounded taper from the CEJ (f = 0) to the apex (f = 1).
  static double _rootTaper(double f) =>
      (1 - 0.32 * f) * math.sqrt(math.max(0.0, 1 - math.pow(f, 5)));

  void _buildRoot(
    MeshBuilder out,
    ToothFrame frame,
    MeshDetail detail,
    _Root root,
    SurfaceVertex Function(double x, double y, double z, Rgb c) vert,
  ) {
    final segs = detail.rootSegments;
    final top = crownLength + _trunk - 1.6;
    final apex = crownLength + rootLength * root.length;
    final baseX = root.x * halfMdCervical, baseZ = root.z * halfBlCervical;
    final rx = root.rx * halfMdCervical, rz = root.rz * halfBlCervical;

    (double, double) center(double f) => (
          baseX + root.splayX * f * f + _rootCurve * rootLength * f * f * 0.5,
          baseZ + root.splayZ * f,
        );

    final rings = <List<SurfaceVertex>>[];
    for (var j = 0; j < detail.rootRings; j++) {
      final f = j / detail.rootRings;
      final y = top + (apex - top) * f;
      final (cx, cz) = center(f);
      final sc = _rootTaper(f);
      rings.add([
        for (var s = 0; s < segs; s++)
          () {
            final phi = 2 * math.pi * s / segs;
            return vert(
                cx + rx * sc * math.cos(phi),
                y,
                cz + rz * sc * math.sin(phi),
                Rgb.lerp(_cementum, _apex, f * f));
          }(),
      ]);
    }
    final (ax, az) = center(1);
    // Every vertex of a separate root is flagged as root, including the
    // part tucked inside the trunk, so it never shows through the crown.
    SurfaceVertex flagged(SurfaceVertex v) =>
        SurfaceVertex(v.p, v.color, kFlagRoot | kFlagSubRoot, v.rootDepth);
    final (tx, tz) = center(0);
    out.addRingSurface(
      [
        for (final ring in rings) [for (final v in ring) flagged(v)]
      ],
      owner: tooth.index,
      startPole: flagged(vert(tx, top - 0.3, tz, _cementum)),
      endPole: flagged(vert(ax, apex, az, _apex)),
    );
  }

  // ── Materials ─────────────────────────────────────────────────

  static const _incisal = Rgb(0.91, 0.92, 0.91);
  static const _enamelBody = Rgb(0.96, 0.94, 0.88);
  static const _enamelCervical = Rgb(0.93, 0.86, 0.72);
  static const _cementum = Rgb(0.90, 0.81, 0.64);
  static const _apex = Rgb(0.80, 0.68, 0.52);
}
