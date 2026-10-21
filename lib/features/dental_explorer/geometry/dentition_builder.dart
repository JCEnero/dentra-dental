import 'dart:math' as math;

import '../data/tooth_catalog.dart';
import 'mesh.dart';
import 'tooth_geometry.dart';

/// Owner ids for non-tooth geometry (teeth use 0–31).
const int kUpperGumOwner = 32;
const int kLowerGumOwner = 33;
const int kOwnerCount = 34;

/// World-space reference points for one tooth.
class ToothAnchor {
  const ToothAnchor({
    required this.crownCenter,
    required this.label,
    required this.buccal,
    required this.occlusal,
  });

  /// Middle of the crown, used to aim the camera.
  final Vec3 crownCenter;

  /// Where the tooth's number is drawn: over the gum, just outside it.
  final Vec3 label;

  /// Unit vector out of the arch (toward lips or cheek).
  final Vec3 buccal;

  /// Unit vector from root toward crown tip.
  final Vec3 occlusal;
}

/// Everything the renderer needs for one level of detail.
class DentitionModel {
  const DentitionModel({
    required this.mesh,
    required this.anchors,
    required this.center,
    required this.radius,
    required this.rightMarker,
    required this.leftMarker,
  });

  final DentitionMesh mesh;

  /// Indexed by [ToothInfo.index].
  final List<ToothAnchor> anchors;
  final Vec3 center;

  /// Extent of what shows by default (crowns and gums, not roots).
  final double radius;

  /// Points beyond the last molars, labelled "R" and "L" on screen.
  final Vec3 rightMarker;
  final Vec3 leftMarker;
}

class DentitionAssets {
  const DentitionAssets({required this.high, required this.low});
  final DentitionModel high;
  final DentitionModel low;
}

/// Builds both detail levels. Top-level so it can run in an isolate.
DentitionAssets buildDentitionAssets(Object? _) => DentitionAssets(
      high: buildDentition(MeshDetail.high),
      low: buildDentition(MeshDetail.low),
    );

// ── Layout constants (mm) ───────────────────────────────────────

/// The mouth is shown slightly open so both chewing surfaces are visible.
const double _biteGap = 6;

/// The lower arch sits slightly behind the upper one (overjet).
const double _lowerArchShift = -1.8;

/// Crown inclination toward the lips/cheek, degrees, positions 1–8.
const _upperTorque = [14.0, 12.0, 8.0, 4.0, 4.0, 2.0, 2.0, 0.0];
const _lowerTorque = [6.0, 6.0, 4.0, -4.0, -6.0, -8.0, -10.0, -10.0];

/// Crown tip toward the midline, degrees, positions 1–8.
const _upperTip = [4.0, 7.0, 9.0, 5.0, 5.0, 4.0, 2.0, 0.0];
const _lowerTip = [2.0, 2.0, 5.0, 2.0, 2.0, 2.0, 1.0, 0.0];

// ── Gum colours ─────────────────────────────────────────────────
// Brand teal (between AppColors.lavender, g1 and g2), drawn translucent
// like frosted glass.
const _gumAttached = Rgb(0.580, 0.890, 0.855);
const _gumMucosa = Rgb(0.400, 0.820, 0.776);
const _gumMargin = Rgb(0.290, 0.725, 0.700);
const _palate = Rgb(0.640, 0.910, 0.880);

class _PlacedTooth {
  _PlacedTooth(this.tooth, this.shape, this.frame, this.level, this.levelAt);

  final ToothInfo tooth;
  final ToothShape shape;

  /// Inclined frame the crown is built in.
  final ToothFrame frame;

  /// Upright frame at the middle of the tooth.
  final ToothFrame level;

  /// Upright frame following the arch curve, [x] mm distal of the
  /// tooth's middle. Used for the gums so they bend smoothly.
  final ToothFrame Function(double x) levelAt;
}

DentitionModel buildDentition(MeshDetail detail) {
  final builder = MeshBuilder();
  final placed = <int, _PlacedTooth>{};

  for (final arch in ToothArch.values) {
    for (final t in _placeArch(arch)) {
      placed[t.tooth.index] = t;
      t.shape.build(builder, t.frame, detail);
    }
  }

  for (final arch in ToothArch.values) {
    final order = [
      for (var p = 8; p >= 1; p--)
        placed[ToothCatalog.byFdi((arch == ToothArch.upper ? 10 : 40) + p)!
            .index]!,
      for (var p = 1; p <= 8; p++)
        placed[ToothCatalog.byFdi((arch == ToothArch.upper ? 20 : 30) + p)!
            .index]!,
    ];
    _buildGum(builder, order, arch, detail);
  }

  final mesh = builder.build();

  final anchors = <ToothAnchor>[];
  var center = Vec3.zero;
  for (final tooth in ToothCatalog.all) {
    final t = placed[tooth.index]!;
    final s = t.shape;
    final crown = t.frame.toWorld(0, s.crownLength * 0.45, 0);
    center = center + crown;
    anchors.add(ToothAnchor(
      crownCenter: crown,
      label: t.level.toWorld(0, s.crownLength + 4.5, s.halfBlCervical + 3.2),
      buccal: t.frame.buccal,
      occlusal: -t.frame.apical,
    ));
  }
  center = center * (1 / ToothCatalog.all.length);

  var radius = 0.0;
  final pos = mesh.positions;
  for (var v = 0; v < mesh.vertexCount; v++) {
    if (mesh.flags[v] & kFlagRoot != 0) continue;
    final i = v * 3;
    final d =
        Vec3(pos[i] - center.x, pos[i + 1] - center.y, pos[i + 2] - center.z)
            .length;
    radius = math.max(radius, d);
  }

  Vec3 marker(int upperFdi, int lowerFdi, double side) {
    final u = placed[ToothCatalog.byFdi(upperFdi)!.index]!;
    final l = placed[ToothCatalog.byFdi(lowerFdi)!.index]!;
    final p = (u.level.toWorld(u.shape.halfMd + 3, 0, 0) +
            l.level.toWorld(l.shape.halfMd + 3, 0, 0)) *
        0.5;
    return Vec3(p.x + side * 4, 0, p.z);
  }

  return DentitionModel(
    mesh: mesh,
    anchors: anchors,
    center: center,
    radius: radius,
    rightMarker: marker(18, 48, -1),
    leftMarker: marker(28, 38, 1),
  );
}

// ── Arch layout ─────────────────────────────────────────────────

/// Half-arch centreline for the patient's left side, from the midline
/// backward, in (x, z) with z pointing out of the mouth.
class _ArchCurve {
  _ArchCurve(List<(double, double)> c, double length) {
    const n = 600;
    final pts = <(double, double)>[];
    for (var i = 0; i <= n; i++) {
      final t = i / n, u = 1 - t;
      final b0 = u * u * u,
          b1 = 3 * u * u * t,
          b2 = 3 * u * t * t,
          b3 = t * t * t;
      pts.add((
        c[0].$1 * b0 + c[1].$1 * b1 + c[2].$1 * b2 + c[3].$1 * b3,
        -(c[0].$2 * b0 + c[1].$2 * b1 + c[2].$2 * b2 + c[3].$2 * b3),
      ));
    }
    var total = 0.0;
    _lengths.add(0);
    for (var i = 1; i < pts.length; i++) {
      total += _dist(pts[i], pts[i - 1]);
      _lengths.add(total);
    }
    final k = length / total;
    _points.addAll([for (final p in pts) (p.$1 * k, p.$2 * k)]);
    for (var i = 0; i < _lengths.length; i++) {
      _lengths[i] *= k;
    }
  }

  final _points = <(double, double)>[];
  final _lengths = <double>[];

  static double _dist((double, double) a, (double, double) b) =>
      math.sqrt(math.pow(a.$1 - b.$1, 2) + math.pow(a.$2 - b.$2, 2));

  /// Position and unit tangent (pointing distally) at arc length [s].
  ((double, double), (double, double)) at(double s) {
    var i = 1;
    while (i < _lengths.length - 1 && _lengths[i] < s) {
      i++;
    }
    final f = ((s - _lengths[i - 1]) / (_lengths[i] - _lengths[i - 1]))
        .clamp(0.0, 1.0);
    final a = _points[i - 1], b = _points[i];
    final pos = (a.$1 + (b.$1 - a.$1) * f, a.$2 + (b.$2 - a.$2) * f);
    final d = _dist(a, b);
    return (pos, ((b.$1 - a.$1) / d, (b.$2 - a.$2) / d));
  }
}

List<_PlacedTooth> _placeArch(ToothArch arch) {
  final upper = arch == ToothArch.upper;
  final shapes = [
    for (var p = 1; p <= 8; p++)
      ToothShape(ToothCatalog.byFdi((upper ? 20 : 30) + p)!),
  ];
  const contactGap = 0.1;
  final length =
      shapes.fold<double>(0, (s, t) => s + t.halfMd * 2 + contactGap);
  final curve = _ArchCurve(
    upper
        ? const [(0, 0), (10, 0), (21, 10), (23, 40)]
        : const [(0, 0), (8, 0), (18, 9), (21, 40)],
    length,
  );

  final apical = Vec3(0, upper ? 1 : -1, 0);
  final occlusalPlane = upper ? _biteGap / 2 : -_biteGap / 2;
  final zShift = upper ? 0.0 : _lowerArchShift;
  final torque = upper ? _upperTorque : _lowerTorque;
  final tip = upper ? _upperTip : _lowerTip;

  final result = <_PlacedTooth>[];
  var cursor = contactGap / 2;
  for (var i = 0; i < 8; i++) {
    final left = shapes[i];
    final width = left.halfMd * 2;
    final arc = cursor + width / 2;
    final ((px, pz), (tx, tz)) = curve.at(arc);
    cursor += width + contactGap;

    for (final side in ToothSide.values) {
      final m = side == ToothSide.left ? 1.0 : -1.0;
      final crownLength = left.crownLength;
      ToothFrame levelAt(double x) {
        final ((qx, qz), (ux, uz)) = curve.at(arc + x);
        return ToothFrame(
          cej:
              Vec3(m * qx, occlusalPlane + apical.y * crownLength, qz + zShift),
          distal: Vec3(m * ux, 0, uz),
          apical: apical,
          buccal: Vec3(-m * uz, 0, ux),
          crownLength: crownLength,
        );
      }

      final quadrant = switch ((arch, side)) {
        (ToothArch.upper, ToothSide.right) => 1,
        (ToothArch.upper, ToothSide.left) => 2,
        (ToothArch.lower, ToothSide.left) => 3,
        (ToothArch.lower, ToothSide.right) => 4,
      };
      final tooth = ToothCatalog.byFdi(quadrant * 10 + i + 1)!;
      final shape = side == ToothSide.left ? left : ToothShape(tooth);

      final distal = Vec3(m * tx, 0, tz);
      final buccal = Vec3(-m * tz, 0, tx);
      final cej = Vec3(
          m * px, occlusalPlane + apical.y * shape.crownLength, pz + zShift);

      final level = ToothFrame(
        cej: cej,
        distal: distal,
        apical: apical,
        buccal: buccal,
        crownLength: shape.crownLength,
      );

      // Incline the crown outward (torque), then toward the midline (tip),
      // pivoting at the neck of the tooth.
      final th = torque[i] * math.pi / 180, ph = tip[i] * math.pi / 180;
      final a1 = apical * math.cos(th) - buccal * math.sin(th);
      final b1 = buccal * math.cos(th) + apical * math.sin(th);
      final a2 = a1 * math.cos(ph) + distal * math.sin(ph);
      final d2 = distal * math.cos(ph) - a1 * math.sin(ph);

      result.add(_PlacedTooth(
        tooth,
        shape,
        ToothFrame(
          cej: cej,
          distal: d2,
          apical: a2,
          buccal: b1,
          crownLength: shape.crownLength,
        ),
        level,
        levelAt,
      ));
    }
  }
  return result;
}

// ── Gums ────────────────────────────────────────────────────────

/// Index of the lingual-wall point the palate starts from (profile point
/// 8, after the six midpoints inserted before it).
const _palateEdgeIndex = 8 + 6;

/// Builds the gum around one arch as a tube of cross-sections that hug
/// each tooth's neck, rise into papillae between teeth, and (for the
/// upper arch) roof over into the palate.
void _buildGum(MeshBuilder out, List<_PlacedTooth> order, ToothArch arch,
    MeshDetail detail) {
  final owner = arch == ToothArch.upper ? kUpperGumOwner : kLowerGumOwner;
  final rings = <List<SurfaceVertex>>[];
  final palateEdge = <Vec3>[];
  final k = detail.gumSamples;

  // Per-tooth values, blended halfway into each neighbour at the contacts.
  double crownOf(_PlacedTooth t) => t.shape.crownLength;
  double buccalOf(_PlacedTooth t) => t.shape.halfBlCervical + 0.8;
  double lingualOf(_PlacedTooth t) => t.shape.halfBlCervical + 1.1;
  double papillaOf(_PlacedTooth t) => t.tooth.isFront ? 3.2 : 2.2;

  for (var i = 0; i < order.length; i++) {
    final t = order[i];
    final right = t.tooth.side == ToothSide.right;
    // Walking right → left, right-side teeth are crossed distal → mesial.
    final dir = right ? -1.0 : 1.0;
    final prev = i > 0 ? order[i - 1] : null;
    final next = i + 1 < order.length ? order[i + 1] : null;
    final mesialNeighbour = right ? next : prev;
    final distalNeighbour = right ? prev : next;

    double blend(double Function(_PlacedTooth) f, double xn) {
      final own = f(t);
      final n = xn < 0 ? mesialNeighbour : distalNeighbour;
      if (n == null) return own;
      final e = xn.abs();
      return own + ((f(n) - own) / 2) * (e * e * (3 - 2 * e));
    }

    for (var j = 0; j < k; j++) {
      final xn = dir * (-1 + (2 * j + 1) / k);
      final x = xn * t.shape.halfMd;
      final crown = blend(crownOf, xn);
      final wb = blend(buccalOf, xn);
      final wl = blend(lingualOf, xn);
      final pap = blend(papillaOf, xn);

      final yc = crown - 0.7; // margin at the middle of the tooth
      final hm = yc - pap * math.pow(xn.abs(), 2.2);
      final (sb, sl) = t.shape.surfaceOffsets(x, hm);
      final mb = math.max(0.2, sb - 0.15), ml = math.max(0.2, sl - 0.15);
      double lerp(double a, double b, double f) => a + (b - a) * f;
      final mid = lerp(hm, yc, 0.5);

      // (outward offset, height toward the root), buccal → over → lingual
      // → back under the tooth.
      final profile = <(double, double, Rgb)>[
        (mb, hm, _gumMargin),
        (lerp(mb, wb, 0.6), hm + 0.8, _gumAttached),
        (lerp(mb, wb, 0.92), mid + 2.0, _gumAttached),
        (wb, yc + 4.0, Rgb.lerp(_gumAttached, _gumMucosa, 0.5)),
        (wb + 0.35, yc + 7.5, _gumMucosa),
        (wb, yc + 10.5, _gumMucosa),
        ((wb - wl) / 2, yc + 12, _gumMucosa),
        (-(wl + 0.2), yc + 10.5, _gumMucosa),
        (-(wl + 0.4), yc + 7.5, _gumMucosa),
        (-wl, yc + 4.0, Rgb.lerp(_gumAttached, _gumMucosa, 0.5)),
        (-lerp(ml, wl, 0.92), mid + 2.0, _gumAttached),
        (-lerp(ml, wl, 0.6), hm + 0.8, _gumAttached),
        (-ml, hm, _gumMargin),
        (-ml * 0.4, hm + 0.6, _gumMargin),
        (mb * 0.4, hm + 0.6, _gumMargin),
      ];
      final along = t.levelAt(x);
      final ring = <SurfaceVertex>[];
      for (var p = 0; p < profile.length; p++) {
        final (z, y, color) = profile[p];
        // The margin hugs the inclined tooth; the rest follows the arch.
        final pos = p == 0 || p == 12
            ? t.frame.toWorld(x, y, z)
            : along.toWorld(0, y, z);
        ring.add(SurfaceVertex(pos, color));
        // Split the long spans over the ridge so triangles stay small,
        // which keeps the depth sort stable in the folds of the gum.
        if (p >= 2 && p < 10) {
          final (z2, y2, c2) = profile[p + 1];
          ring.add(SurfaceVertex(
            along.toWorld(0, (y + y2) / 2, (z + z2) / 2),
            Rgb.lerp(color, c2, 0.5),
          ));
        }
      }
      rings.add(ring);
      palateEdge.add(ring[_palateEdgeIndex].p);
    }
  }

  // Round off both ends behind the last molars.
  List<SurfaceVertex> shrink(List<SurfaceVertex> ring, double s, Vec3 shift) {
    var c = Vec3.zero;
    for (final v in ring) {
      c = c + v.p;
    }
    c = c * (1 / ring.length);
    return [
      for (final v in ring) SurfaceVertex(c + (v.p - c) * s + shift, v.color),
    ];
  }

  Vec3 centroid(List<SurfaceVertex> ring) {
    var c = Vec3.zero;
    for (final v in ring) {
      c = c + v.p;
    }
    return c * (1 / ring.length);
  }

  (List<List<SurfaceVertex>>, SurfaceVertex) cap(
      List<SurfaceVertex> end, List<SurfaceVertex> inner) {
    final dir = (centroid(end) - centroid(inner)).normalized();
    return (
      [shrink(end, 0.82, dir * 1.6), shrink(end, 0.5, dir * 3.0)],
      SurfaceVertex(centroid(end) + dir * 3.6, _gumMucosa),
    );
  }

  final (startRings, startPole) = cap(rings.first, rings[1]);
  final (endRings, endPole) = cap(rings.last, rings[rings.length - 2]);
  out.addRingSurface(
    [...startRings.reversed, ...rings, ...endRings],
    owner: owner,
    startPole: startPole,
    endPole: endPole,
  );

  if (arch == ToothArch.upper) {
    _buildPalate(out, palateEdge, detail, owner);
  }
}

/// Domed roof of the mouth inside the upper arch, with soft rugae
/// (ridges) behind the front teeth. Built double-sided so the arch never
/// looks hollow from above.
void _buildPalate(
    MeshBuilder out, List<Vec3> edge, MeshDetail detail, int owner) {
  // Close the loop across the back of the mouth, then resample it evenly
  // so the dome has no long, thin triangles.
  final raw = [...edge, edge.first];
  final lengths = <double>[0];
  for (var i = 1; i < raw.length; i++) {
    lengths.add(lengths.last + (raw[i] - raw[i - 1]).length);
  }
  final samples = detail.segments * 2;
  final loop = <Vec3>[];
  var seg = 1;
  for (var i = 0; i < samples; i++) {
    final s = lengths.last * i / samples;
    while (lengths[seg] < s) {
      seg++;
    }
    final f = (s - lengths[seg - 1]) / (lengths[seg] - lengths[seg - 1]);
    loop.add(Vec3.lerp(raw[seg - 1], raw[seg], f));
  }

  // Each ring shrinks toward the midline, so the vault rises to a
  // ridge along the middle of the palate (the palatine raphe).
  const vault = 4.5;
  const up = Vec3(0, 1, 0);
  final front = loop.map((p) => p.z).reduce(math.max);
  final ringsCount = detail.gumSamples + 2;
  final rings = <List<SurfaceVertex>>[];
  final topRings = <List<SurfaceVertex>>[];
  for (var k = 0; k <= ringsCount; k++) {
    // The last ring collapses onto the midline, where both halves meet.
    final r = 1 - k / ringsCount;
    final ring = <SurfaceVertex>[];
    final top = <SurfaceVertex>[];
    for (final b in loop) {
      final p = Vec3(b.x * r, b.y, b.z);
      final dome = vault * math.pow(1 - r * r, 0.6);
      // Rugae: soft transverse ridges behind the front teeth.
      final frontness = ((p.z - (front - 20)) / 10).clamp(0.0, 1.0);
      final ridge = r > 0.25 && r < 0.9
          ? 0.3 * math.sin(p.z * 1.4) * frontness * math.sin(r * math.pi)
          : 0.0;
      ring.add(
          SurfaceVertex(p + up * (dome - ridge), _palate * (0.95 + 0.05 * r)));
      top.add(SurfaceVertex(p + up * dome, _gumMucosa * 0.92));
    }
    rings.add(ring);
    topRings.add(top);
  }
  out.addRingSurface(
    rings,
    owner: owner,
    closed: false,
    outwardHint: const Vec3(0, -1, 0),
  );
  out.addRingSurface(
    topRings,
    owner: owner,
    closed: false,
    outwardHint: up,
  );
}
