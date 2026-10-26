import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../dental_explorer/data/tooth_catalog.dart';
import '../../../dental_explorer/geometry/dentition_builder.dart';
import '../../../dental_explorer/geometry/mesh.dart';
import '../../../dental_explorer/rendering/dentition_renderer.dart';
import '../../../dental_explorer/rendering/orbit_camera.dart';
import '../../data/capture_regions.dart';
import '../../data/mock_scan_report.dart';
import 'scan_sim_theme.dart';

/// When each part of the scan animation happens, as fractions (0–1) of
/// its run time. The painter and the HUD widgets read the same timings.
class ChamberTimeline {
  ChamberTimeline(this.captured);

  /// Captured regions, in guided order.
  final List<CaptureRegion> captured;

  /// Where each part of the animation starts: point cloud, wireframe,
  /// solid model, photo projection, area check, report.
  static const phaseStarts = [0.0, 0.15, 0.35, 0.55, 0.75, 0.90];

  /// The steps the status panel shows: one per phase, so the steps
  /// advance at an even pace.
  static const stepStarts = phaseStarts;
  static int get stepCount => stepStarts.length;

  String labelOf(int step) => switch (step) {
        0 => 'Initializing scanner…',
        1 => 'Mapping dental arches…',
        2 => 'Refining surface details…',
        3 => 'Analyzing ${captured.length} '
            'region${captured.length == 1 ? '' : 's'}…',
        4 => 'Checking each area…',
        _ => 'Generating report…',
      };

  int stepAt(double p) {
    for (var i = stepStarts.length - 1; i > 0; i--) {
      if (p >= stepStarts[i]) return i;
    }
    return 0;
  }

  /// 0–1 through animation [phase] at [p].
  double within(int phase, double p) {
    final start = phaseStarts[phase];
    final end =
        phase + 1 < phaseStarts.length ? phaseStarts[phase + 1] : 1.0;
    return ((p - start) / (end - start)).clamp(0.0, 1.0);
  }

  static const _flightLength = 0.06;

  /// Progress of the [i]-th captured photo's flight onto the model. It
  /// lands near 1 and keeps glowing a little past it.
  double flight(int i, double p) {
    final n = captured.length;
    final step = n > 1 ? (0.17 - _flightLength) / (n - 1) : 0.0;
    return (p - (0.56 + i * step)) / _flightLength;
  }

  bool landed(int i, double p) => flight(i, p) >= 0.92;

  int landedCount(double p) {
    var n = 0;
    for (var i = 0; i < captured.length; i++) {
      if (landed(i, p)) n++;
    }
    return n;
  }

  /// How far a tooth has filled in solid. [rank] is its place along the
  /// arches, 0–1.
  static double solid(double rank, double p) =>
      ((p - (0.36 + 0.15 * rank)) / 0.035).clamp(0.0, 1.0);

  /// How far an area's check has run; 0 before it starts.
  static double checked(MouthArea area, double p) =>
      ((p - (0.755 + 0.11 * area.index / (MouthArea.values.length - 1))) /
              0.03)
          .clamp(0.0, 1.0);
}

/// Model data the scan effects need, derived once per model.
class ChamberGeometry {
  ChamberGeometry._({
    required this.wireVerts,
    required this.pointVert,
    required this.pointFrom,
    required this.pointDelay,
    required this.gumPointStart,
    required this.edges,
    required this.edgeStart,
    required this.revealRank,
    required this.regionAnchors,
    required this.areaPins,
    required this.areaFacing,
  });

  static final _cache = Expando<ChamberGeometry>();

  static ChamberGeometry of(DentitionModel model) =>
      _cache[model] ??= _build(model);

  /// Vertices the wireframe uses, projected once per frame.
  final Int32List wireVerts;

  /// Point cloud: a mesh vertex per point, its scattered start position
  /// (xyz) and start delay. Points from [gumPointStart] on are gums.
  final Int32List pointVert;
  final Float32List pointFrom;
  final Float32List pointDelay;
  final int gumPointStart;

  /// Wireframe as vertex pairs, grouped by tooth: tooth i owns pairs
  /// [edgeStart[i], edgeStart[i + 1]).
  final Int32List edges;
  final Int32List edgeStart;

  /// By tooth index: place along the arches, left to right, 0–31.
  final Int32List revealRank;

  /// By [captureRegions] index: where that region's photo lands.
  final List<Vec3> regionAnchors;

  /// By [MouthArea] index: where its marker sits, just outside the gums,
  /// and the direction that side of the area faces.
  final List<Vec3> areaPins;
  final List<Vec3> areaFacing;

  static ChamberGeometry _build(DentitionModel model) {
    final mesh = model.mesh;
    final pos = mesh.positions;
    final rnd = math.Random(7);

    bool crown(int v) => mesh.owner[v] < 32 && mesh.flags[v] & kFlagRoot == 0;
    final crownVerts = <int>[
      for (var v = 0; v < mesh.vertexCount; v++)
        if (crown(v)) v,
    ];
    final points = <int>[
      for (var k = 0; k < crownVerts.length; k += 2) crownVerts[k],
    ];
    final gumStart = points.length;
    for (var v = 0; v < mesh.vertexCount; v += 5) {
      if (mesh.owner[v] >= 32) points.add(v);
    }

    final from = Float32List(points.length * 3);
    final delay = Float32List(points.length);
    final c = model.center;
    for (var k = 0; k < points.length; k++) {
      // Uniform direction on a sphere, well outside the model.
      final u = rnd.nextDouble() * 2 - 1;
      final a = rnd.nextDouble() * 2 * math.pi;
      final s = math.sqrt(1 - u * u);
      final dist = model.radius * (1.6 + rnd.nextDouble() * 1.6);
      from[k * 3] = c.x + s * math.cos(a) * dist;
      from[k * 3 + 1] = c.y + u * dist * 0.7;
      from[k * 3 + 2] = c.z + s * math.sin(a) * dist;
      // Lower teeth settle a touch later than upper ones.
      final y = pos[points[k] * 3 + 1];
      delay[k] = rnd.nextDouble() * 0.32 + (y < 0 ? 0.1 : 0);
    }

    // Wireframe: per triangle, its two shorter edges, which outlines the
    // quads the surface was built from instead of every diagonal.
    final perTooth = List.generate(32, (_) => <int>[]);
    final seen = <int>{};
    final tris = mesh.triangles;
    double len2(int a, int b) {
      final dx = pos[a * 3] - pos[b * 3],
          dy = pos[a * 3 + 1] - pos[b * 3 + 1],
          dz = pos[a * 3 + 2] - pos[b * 3 + 2];
      return dx * dx + dy * dy + dz * dz;
    }

    for (var t = 0; t < mesh.triangleCount; t++) {
      final owner = mesh.triOwner[t];
      if (owner >= 32 || mesh.triFlags[t] & kFlagRoot != 0) continue;
      final i0 = tris[t * 3], i1 = tris[t * 3 + 1], i2 = tris[t * 3 + 2];
      final sides = [(i0, i1), (i1, i2), (i2, i0)]
        ..sort((x, y) => len2(x.$1, x.$2).compareTo(len2(y.$1, y.$2)));
      for (final (a, b) in sides.take(2)) {
        final lo = math.min(a, b), hi = math.max(a, b);
        if (seen.add(lo * 65536 + hi)) perTooth[owner].addAll([lo, hi]);
      }
    }
    final edgeStart = Int32List(33);
    final edges = <int>[];
    for (var i = 0; i < 32; i++) {
      edgeStart[i] = edges.length ~/ 2;
      edges.addAll(perTooth[i]);
    }
    edgeStart[32] = edges.length ~/ 2;
    // Triangles at the gumline can reach a root vertex or two; those
    // need projecting too.
    final wireVerts = {...crownVerts, ...edges}.toList()..sort();

    final byX = [...ToothCatalog.all]..sort((a, b) =>
        model.anchors[a.index].crownCenter.x
            .compareTo(model.anchors[b.index].crownCenter.x));
    final rank = Int32List(32);
    for (var r = 0; r < byX.length; r++) {
      rank[byX[r].index] = r;
    }

    Vec3 average(Iterable<Vec3> points) {
      var sum = Vec3.zero;
      var n = 0;
      for (final p in points) {
        sum = sum + p;
        n++;
      }
      return n == 0 ? model.center : sum * (1 / n);
    }

    final anchors = model.anchors;
    return ChamberGeometry._(
      wireVerts: Int32List.fromList(wireVerts),
      pointVert: Int32List.fromList(points),
      pointFrom: from,
      pointDelay: delay,
      gumPointStart: gumStart,
      edges: Int32List.fromList(edges),
      edgeStart: edgeStart,
      revealRank: rank,
      regionAnchors: [
        for (final region in captureRegions)
          average([
            for (final t in ToothCatalog.all)
              if (region.covers(t) && region.arches.shows(t.arch))
                anchors[t.index].crownCenter,
          ]),
      ],
      areaPins: [
        for (final area in MouthArea.values)
          average([
            for (final t in ToothCatalog.all)
              if (area.contains(t)) anchors[t.index].label,
          ]),
      ],
      areaFacing: [
        for (final area in MouthArea.values)
          average([
            for (final t in ToothCatalog.all)
              if (area.contains(t)) anchors[t.index].buccal,
          ]).normalized(),
      ],
    );
  }
}

/// Draws one frame of the scan over the light backdrop.
///
/// Layers, back to front: a soft glow and the pad the model stands on,
/// the progress ring; the model as a point cloud, wireframe, then solid;
/// photo projections, area markers and the scanning light.
class ChamberScene {
  ChamberScene({
    required this.model,
    required this.timeline,
    required this.report,
    required this.thumbs,
    required this.reduced,
    required this.seconds,
  })  : _renderer = DentitionRenderer(model),
        _geo = ChamberGeometry.of(model),
        _sx = Float32List(model.mesh.vertexCount),
        _sy = Float32List(model.mesh.vertexCount),
        _sd = Float32List(model.mesh.vertexCount) {
    final rnd = math.Random(11);
    _motes = List.generate(
      26,
      (_) => (
        rnd.nextDouble(),
        rnd.nextDouble(),
        4 + rnd.nextDouble() * 10,
        2 + rnd.nextDouble() * 4,
      ),
    );
    final maxEdges =
        List.generate(32, (i) => _geo.edgeStart[i + 1] - _geo.edgeStart[i])
            .reduce(math.max);
    _lines = Float32List(maxEdges * 4);
    _points = Float32List(_geo.pointVert.length * 2);
  }

  final DentitionModel model;
  final ChamberTimeline timeline;

  /// The report the scan settles on, revealed area by area.
  final ScanReport report;

  /// Decoded photo thumbnails by region id. Filled in while the scan
  /// runs; a photo still decoding is drawn as a plain card.
  final Map<String, ui.Image> thumbs;
  final bool reduced;

  /// Run time, used for motion that is timed in seconds.
  final double seconds;

  final DentitionRenderer _renderer;
  final ChamberGeometry _geo;
  final _style = SceneStyle();
  final Float32List _sx, _sy, _sd;
  late final Float32List _lines;
  late final Float32List _points;
  late final List<(double, double, double, double)> _motes;

  static const _homeYaw = -0.34;

  // Projection for the current frame (see DentitionRenderer.paint).
  double _r0 = 1, _r1 = 0, _r2 = 0, _r3 = 0, _r4 = 1, _r5 = 0;
  double _r6 = 0, _r7 = 0, _r8 = 1;
  double _tx = 0, _ty = 0, _tz = 0, _dist = 1, _f = 1, _cx = 0, _cy = 0;
  double _ox = 0, _oy = 0;

  double get _fit =>
      model.radius / math.sin(DentitionRenderer.fov / 2) * 0.84;

  /// The camera at [p]: one slow turn that settles on the same view the
  /// results map opens with, pulling in a little at the end.
  CameraPose poseAt(double p) {
    final settle = timeline.within(5, p);
    final x = math.min(p / 0.95, 1.0);
    final spin = reduced ? 1.0 : 1 - math.pow(1 - x, 1.8).toDouble();
    final approach = reduced
        ? 1.0
        : Curves.easeOutCubic.transform(math.min(p / 0.2, 1.0));
    return CameraPose(
      yaw: _homeYaw + 2 * math.pi * (spin - 1),
      pitch: 0.2 +
          (reduced ? 0 : 0.1 * math.sin(p * 2 * math.pi) * (1 - settle)),
      distance: _fit *
          1.3 *
          (1.5 - 0.5 * approach) *
          (1 - 0.15 * Curves.easeInOutCubic.transform(settle)),
      target: model.center,
    );
  }

  void paint(Canvas canvas, Size size, Rect stage, double p) {
    final t = p * seconds;
    final pose = poseAt(p);
    _setProjection(pose, stage.size);
    // Rough on-screen half-width of the arches.
    final radius = model.radius * _f / pose.distance * 0.7;

    _paintMotes(canvas, size, t);
    canvas.save();
    canvas.translate(stage.left, stage.top);
    final center = Offset(_cx, _cy);
    _paintStage(canvas, center, radius, p, t);

    if (p > 0.355) {
      _applyStyle(p, t);
      _renderer.paint(canvas, stage.size, pose, _style);
    }
    if (p > 0.12 && p < 0.58) _paintWireframe(canvas, center, radius, p);
    if (p < 0.3) _paintPointCloud(canvas, p);
    _paintFlights(canvas, stage.size, p);
    if (p > 0.75) _paintMarkers(canvas, stage.size, p, t);
    if (!reduced) _paintScanLight(canvas, center, radius, p, t);
    canvas.restore();

    // The last moment washes to the mint of the results page.
    if (p > 0.965) {
      final q = Curves.easeIn.transform(((p - 0.965) / 0.035).clamp(0, 1));
      canvas.drawRect(Offset.zero & size,
          Paint()..color = AppColors.lightLavender.withValues(alpha: 0.85 * q));
    }
  }

  // ── Projection ─────────────────────────────────────────────────

  void _setProjection(CameraPose pose, Size s) {
    final r = pose.rotation;
    _r0 = r[0];
    _r1 = r[1];
    _r2 = r[2];
    _r3 = r[3];
    _r4 = r[4];
    _r5 = r[5];
    _r6 = r[6];
    _r7 = r[7];
    _r8 = r[8];
    _tx = pose.target.x;
    _ty = pose.target.y;
    _tz = pose.target.z;
    _dist = pose.distance;
    _f = DentitionRenderer.focalLength(s);
    _cx = s.width / 2;
    _cy = s.height / 2;
  }

  /// Projects into [_ox] and [_oy]; false when behind the camera.
  bool _project(double x, double y, double z) {
    final px = x - _tx, py = y - _ty, pz = z - _tz;
    final d = _dist - (_r6 * px + _r7 * py + _r8 * pz);
    if (d < 4) return false;
    final inv = _f / d;
    _ox = _cx + (_r0 * px + _r1 * py + _r2 * pz) * inv;
    _oy = _cy - (_r3 * px + _r4 * py + _r5 * pz) * inv;
    return true;
  }

  bool _projectVec(Vec3 v) => _project(v.x, v.y, v.z);

  /// How much a direction faces the viewer (view-space z).
  double _facing(Vec3 dir) => _r6 * dir.x + _r7 * dir.y + _r8 * dir.z;

  // ── Surroundings ───────────────────────────────────────────────

  /// Soft glass bubbles drifting up behind everything.
  void _paintMotes(Canvas canvas, Size size, double t) {
    for (final (x, y, speed, r) in _motes) {
      final py = (y * size.height - (reduced ? 0 : t * speed)) % size.height;
      canvas.drawCircle(
        Offset(x * size.width, py),
        r,
        Paint()..color = AppColors.white.withValues(alpha: 0.55),
      );
    }
  }

  /// A white glow behind the model, the pad it stands on, a slow dashed
  /// ring and a ring that fills with progress.
  void _paintStage(
      Canvas canvas, Offset c, double radius, double p, double t) {
    final appear = (p / 0.08).clamp(0.0, 1.0);
    canvas.drawCircle(
      c,
      radius * 1.9,
      Paint()
        ..shader = RadialGradient(colors: [
          AppColors.white.withValues(alpha: 0.75 * appear),
          AppColors.white.withValues(alpha: 0.25 * appear),
          AppColors.white.withValues(alpha: 0),
        ], stops: const [0, 0.55, 1])
            .createShader(Rect.fromCircle(center: c, radius: radius * 1.9)),
    );

    final pad = Rect.fromCenter(
      center: c.translate(0, radius * 0.8),
      width: radius * 2.5,
      height: radius * 0.46,
    );
    canvas.drawOval(
      pad,
      Paint()
        ..shader = RadialGradient(colors: [
          AppColors.g2.withValues(alpha: 0.2 * appear),
          AppColors.g1.withValues(alpha: 0.06 * appear),
          AppColors.g1.withValues(alpha: 0),
        ], stops: const [0, 0.6, 1])
            .createShader(pad),
    );

    final settle = timeline.within(5, p);
    final rings = appear * (1 - 0.4 * settle);
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = AppColors.g2.withValues(alpha: 0.28 * rings);
    final r1 = radius * 1.28;
    final spin = reduced ? 0.0 : t * 0.15;
    for (var i = 0; i < 48; i++) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: r1),
          i / 48 * 2 * math.pi + spin, 0.05, false, dash);
    }

    final r2 = radius * 1.14;
    final ring = Rect.fromCircle(center: c, radius: r2);
    canvas.drawCircle(
      c,
      r2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppColors.white.withValues(alpha: 0.7 * rings),
    );
    final sweep = 2 * math.pi * p;
    final shader = const SweepGradient(
      endAngle: 2 * math.pi,
      colors: [AppColors.g1, AppColors.g2, AppColors.g1],
      transform: GradientRotation(-math.pi / 2),
    ).createShader(ring);
    canvas.drawArc(
      ring,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..color = AppColors.g1.withValues(alpha: 0.3 * rings)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawArc(
      ring,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..shader = shader,
    );
    final head = c +
        Offset(math.cos(-math.pi / 2 + sweep), math.sin(-math.pi / 2 + sweep)) *
            r2;
    canvas.drawCircle(head, 5, Paint()..color = AppColors.white);
    canvas.drawCircle(head, 2.6, Paint()..color = AppColors.g2);
  }

  // ── The model ──────────────────────────────────────────────────

  void _applyStyle(double p, double t) {
    final s = _style
      ..hideRoots = true
      ..rootReveal = 0;

    // Each landed photo lights up the teeth its view covers, briefly.
    final photoGlow = List<double>.filled(32, 0);
    for (var i = 0; i < timeline.captured.length; i++) {
      final f = timeline.flight(i, p);
      if (f < 0.8 || f > 1.4) continue;
      final bump = math.sin(math.pi * ((f - 0.8) / 0.6));
      final region = timeline.captured[i];
      for (final tooth in ToothCatalog.all) {
        if (region.covers(tooth) && region.arches.shows(tooth.arch)) {
          photoGlow[tooth.index] = math.max(photoGlow[tooth.index], bump);
        }
      }
    }

    for (final tooth in ToothCatalog.all) {
      final i = tooth.index;
      final rank = _geo.revealRank[i] / 31;
      final solid = reduced
          ? ((p - 0.35) / 0.2).clamp(0.0, 1.0)
          : ChamberTimeline.solid(rank, p);
      // A teal flash as the tooth fills in, fading as it settles.
      final filledAt = 0.36 + 0.15 * rank + 0.035;
      final flash =
          solid <= 0 ? 0.0 : 1 - ((p - filledAt) / 0.05).clamp(0.0, 1.0);

      var glow = 0.8 * flash + 0.6 * photoGlow[i];
      var tint = 0.4 * flash + 0.25 * photoGlow[i];
      var color = AppColors.g1;
      var desaturate = 0.0, brightness = 1.0;

      // Each area flashes as it is checked, then settles into the shade
      // of its result.
      final area = MouthArea.of(tooth);
      final u = ChamberTimeline.checked(area, p);
      if (u > 0) {
        final h = report.areaHealth[area]!;
        final e = Curves.easeOutCubic.transform(u);
        glow += 0.8 * (1 - u);
        if (h == AreaHealth.notChecked) {
          desaturate = 0.8 * e;
          brightness = 1 - 0.1 * e;
        } else {
          color = HealthColors.modelOf(h);
          tint = HealthColors.tintOf(h) * e;
          if (h == AreaHealth.attention && !reduced) {
            glow += 0.25 * (0.5 + 0.5 * math.sin(t * 5));
          }
        }
      }
      s
        ..alpha[i] = solid
        ..glow[i] = glow.clamp(0.0, 1.0)
        ..tint[i] = tint.clamp(0.0, 1.0)
        ..tintR[i] = color.r
        ..tintG[i] = color.g
        ..tintB[i] = color.b
        ..desaturate[i] = desaturate
        ..brightness[i] = brightness;
    }

    // Glass gums come in once most teeth are solid.
    final gums = ((p - 0.46) / 0.12).clamp(0.0, 1.0) * 0.45;
    for (final o in const [kUpperGumOwner, kLowerGumOwner]) {
      s
        ..alpha[o] = gums
        ..glow[o] = 0
        ..tint[o] = 0
        ..desaturate[o] = 0
        ..brightness[o] = 1;
    }
  }

  void _paintPointCloud(Canvas canvas, double p) {
    final fade = 1 - ((p - 0.18) / 0.1).clamp(0.0, 1.0);
    if (fade <= 0) return;
    final converge = (p / 0.17).clamp(0.0, 1.0);
    final pos = model.mesh.positions;
    final from = _geo.pointFrom;
    final out = _points;

    void batch(int start, int end, Color color, double width) {
      var n = 0;
      for (var k = start; k < end; k++) {
        final v = _geo.pointVert[k] * 3;
        final local = reduced
            ? 1.0
            : ((converge - _geo.pointDelay[k]) / 0.58).clamp(0.0, 1.0);
        final e = Curves.easeOutCubic.transform(local);
        final x = from[k * 3] + (pos[v] - from[k * 3]) * e;
        final y = from[k * 3 + 1] + (pos[v + 1] - from[k * 3 + 1]) * e;
        final z = from[k * 3 + 2] + (pos[v + 2] - from[k * 3 + 2]) * e;
        if (!_project(x, y, z)) continue;
        out[n * 2] = _ox;
        out[n * 2 + 1] = _oy;
        n++;
      }
      if (n == 0) return;
      canvas.drawRawPoints(
        ui.PointMode.points,
        Float32List.sublistView(out, 0, n * 2),
        Paint()
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
    }

    final appear = reduced ? converge : 1.0;
    batch(_geo.gumPointStart, _geo.pointVert.length,
        AppColors.g1.withValues(alpha: 0.5 * fade * appear), 1.8);
    batch(0, _geo.gumPointStart,
        AppColors.g2.withValues(alpha: 0.85 * fade * appear), 2.2);
  }

  void _paintWireframe(Canvas canvas, Offset c, double radius, double p) {
    final appear = ((p - 0.12) / 0.05).clamp(0.0, 1.0);
    // While mapping, the wireframe is revealed by the scanning light's
    // first pass.
    final sweep = timeline.within(1, p);
    final revealY = p < 0.35
        ? c.dy - radius * 1.05 + radius * 2.1 * sweep
        : double.infinity;

    final pos = model.mesh.positions;
    for (final v in _geo.wireVerts) {
      if (_project(pos[v * 3], pos[v * 3 + 1], pos[v * 3 + 2])) {
        _sx[v] = _ox;
        _sy[v] = _oy;
        _sd[v] = 1;
      } else {
        _sd[v] = -1;
      }
    }

    final paint = Paint()..strokeWidth = 0.9;
    final edges = _geo.edges;
    for (var tooth = 0; tooth < 32; tooth++) {
      final rank = _geo.revealRank[tooth] / 31;
      final solid = reduced
          ? ((p - 0.35) / 0.2).clamp(0.0, 1.0)
          : ChamberTimeline.solid(rank, p);
      final alpha = appear * (1 - solid);
      if (alpha < 0.02) continue;
      var n = 0;
      for (var e = _geo.edgeStart[tooth]; e < _geo.edgeStart[tooth + 1]; e++) {
        final a = edges[e * 2], b = edges[e * 2 + 1];
        if (_sd[a] < 0 || _sd[b] < 0) continue;
        if (math.min(_sy[a], _sy[b]) > revealY) continue;
        _lines[n * 4] = _sx[a];
        _lines[n * 4 + 1] = _sy[a];
        _lines[n * 4 + 2] = _sx[b];
        _lines[n * 4 + 3] = _sy[b];
        n++;
      }
      if (n == 0) continue;
      paint.color = AppColors.g2.withValues(alpha: 0.5 * alpha);
      canvas.drawRawPoints(ui.PointMode.lines,
          Float32List.sublistView(_lines, 0, n * 4), paint);
    }
  }

  /// Photo cards fly in from the sides and project onto the part of the
  /// model their view covers.
  void _paintFlights(Canvas canvas, Size s, double p) {
    final captured = timeline.captured;
    final n = captured.length;
    for (var i = 0; i < n; i++) {
      final f = timeline.flight(i, p);
      if (f <= 0 || f >= 1.4) continue;
      final region = captured[i];
      if (!_projectVec(_geo.regionAnchors[captureRegions.indexOf(region)])) {
        continue;
      }
      final target = Offset(_ox, _oy);

      if (f < 1) {
        final e = reduced ? 1.0 : Curves.easeInOutCubic.transform(f);
        final left = i.isEven;
        final rows = math.max(1, (n - 1) ~/ 2);
        final start = Offset(
          left ? -50 : s.width + 50,
          s.height * (0.14 + 0.72 * ((i ~/ 2) / rows)),
        );
        final control = Offset(
          start.dx + (target.dx - start.dx) * 0.3,
          math.min(start.dy, target.dy) - 60,
        );
        final u = 1 - e;
        final pos = start * (u * u) + control * (2 * u * e) + target * (e * e);
        final shrink = math.pow(e, 1.6).toDouble();
        final w = 92 - 76 * shrink;
        final h = w * 0.75;
        final alpha = (f / 0.12).clamp(0.0, 1.0) *
            (1 - ((f - 0.82) / 0.18).clamp(0.0, 1.0));
        final rect = Rect.fromCenter(center: pos, width: w, height: h);
        final rrect = RRect.fromRectAndRadius(rect, Radius.circular(w * 0.12));

        // A soft beam from the card onto the model.
        if (f > 0.18) {
          final beamAlpha = alpha * ((f - 0.18) / 0.2).clamp(0.0, 1.0);
          final near = left ? rect.right : rect.left;
          final beam = Path()
            ..moveTo(near, rect.top)
            ..lineTo(target.dx, target.dy)
            ..lineTo(near, rect.bottom)
            ..close();
          canvas.drawPath(
            beam,
            Paint()
              ..shader = ui.Gradient.linear(
                Offset(near, pos.dy),
                target,
                [
                  AppColors.g1.withValues(alpha: 0.32 * beamAlpha),
                  AppColors.g1.withValues(alpha: 0.04 * beamAlpha),
                ],
              ),
          );
        }

        // Glass card: soft shadow, white rim, the photo inside.
        canvas.drawRRect(
          rrect.shift(const Offset(0, 4)),
          Paint()
            ..color = AppColors.navy.withValues(alpha: 0.16 * alpha)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
        final image = thumbs[region.id];
        canvas.save();
        canvas.clipRRect(rrect);
        if (image != null) {
          canvas.drawImageRect(
            image,
            _coverSource(image, rect.size),
            rect,
            Paint()
              ..filterQuality = FilterQuality.medium
              ..color = AppColors.white.withValues(alpha: alpha),
          );
        } else {
          canvas.drawRect(rect,
              Paint()..color = AppColors.lavender.withValues(alpha: alpha));
        }
        canvas.restore();
        canvas.drawRRect(
          rrect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = AppColors.white.withValues(alpha: 0.95 * alpha),
        );
      }

      // Landing ripple.
      if (f > 0.8) {
        final q = ((f - 0.8) / 0.6).clamp(0.0, 1.0);
        canvas.drawCircle(
          target,
          4 + 34 * q,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = AppColors.g2.withValues(alpha: 0.7 * (1 - q)),
        );
        canvas.drawCircle(target, 3,
            Paint()..color = AppColors.g2.withValues(alpha: 1 - q));
      }
    }
  }

  /// Source rect that crops [image] to cover [box] like BoxFit.cover.
  static Rect _coverSource(ui.Image image, Size box) {
    final iw = image.width.toDouble(), ih = image.height.toDouble();
    final scale = math.max(box.width / iw, box.height / ih);
    final w = box.width / scale, h = box.height / scale;
    return Rect.fromLTWH((iw - w) / 2, (ih - h) / 2, w, h);
  }

  /// A soft dot pops in on each area with a finding as it is checked.
  /// No numbers: results describe areas, not individual teeth.
  void _paintMarkers(Canvas canvas, Size s, double p, double t) {
    for (final finding in report.findings) {
      final area = finding.area;
      final u = ChamberTimeline.checked(area, p);
      if (u <= 0) continue;
      final facing = _facing(_geo.areaFacing[area.index]);
      if (facing < -0.35) continue;
      if (!_projectVec(_geo.areaPins[area.index])) continue;
      final at = Offset(_ox, _oy);
      if (!(Offset.zero & s).contains(at)) continue;
      final alpha =
          (u * 3).clamp(0.0, 1.0) * ((facing + 0.35) / 0.3).clamp(0.0, 1.0);
      final scale = reduced
          ? 1.0
          : Curves.easeOutBack.transform((u * 1.6).clamp(0.0, 1.0));
      final pulse = reduced ? 0.5 : 0.5 + 0.5 * math.sin(t * 4 + area.index);
      final color = HealthColors.of(finding.health);
      canvas.drawCircle(
        at,
        (11 + 3 * pulse) * scale,
        Paint()
          ..color = color.withValues(alpha: (0.16 + 0.1 * pulse) * alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(at, 7 * scale,
          Paint()..color = AppColors.white.withValues(alpha: 0.95 * alpha));
      canvas.drawCircle(at, 3.6 * scale,
          Paint()..color = color.withValues(alpha: alpha));
    }
  }

  /// The scanning light: a soft teal line sweeping top to bottom with a
  /// glow trailing behind. Its pass during mapping reveals the wireframe.
  void _paintScanLight(
      Canvas canvas, Offset c, double radius, double p, double t) {
    final settle = timeline.within(5, p);
    final fade = (p / 0.05).clamp(0.0, 1.0) * (1 - settle);
    if (fade <= 0) return;
    final period = (ChamberTimeline.phaseStarts[2] -
            ChamberTimeline.phaseStarts[1]) *
        seconds;
    final phase =
        (((t - ChamberTimeline.phaseStarts[1] * seconds) / period) % 1 + 1) % 1;
    final a = math.sqrt(math.sin(math.pi * phase)) * fade;
    final top = c.dy - radius * 1.05, bottom = c.dy + radius * 1.05;
    final y = top + (bottom - top) * phase;
    final x0 = c.dx - radius * 1.3, x1 = c.dx + radius * 1.3;

    final trail = Rect.fromLTRB(x0, y - 48, x1, y);
    canvas.drawRect(
      trail,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.g1.withValues(alpha: 0),
            AppColors.g1.withValues(alpha: 0.2 * a),
          ],
        ).createShader(trail),
    );
    final across = ui.Gradient.linear(
      Offset(x0, y),
      Offset(x1, y),
      [
        AppColors.g2.withValues(alpha: 0),
        AppColors.g2.withValues(alpha: 0.8 * a),
        AppColors.g1.withValues(alpha: a),
        AppColors.g2.withValues(alpha: 0.8 * a),
        AppColors.g2.withValues(alpha: 0),
      ],
      const [0, 0.2, 0.5, 0.8, 1],
    );
    canvas.drawLine(
      Offset(x0, y),
      Offset(x1, y),
      Paint()
        ..strokeWidth = 7
        ..shader = across
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawLine(
        Offset(x0, y),
        Offset(x1, y),
        Paint()
          ..strokeWidth = 1.8
          ..shader = across);
  }

  void dispose() {
    for (final image in thumbs.values) {
      image.dispose();
    }
  }
}

/// Repaints the scan whenever [progress] moves.
class ChamberPainter extends CustomPainter {
  ChamberPainter({
    required this.scene,
    required this.progress,
    required this.stageInsets,
  }) : super(repaint: progress);

  final ChamberScene scene;
  final ValueNotifier<double> progress;

  /// Room taken by the top bar and the bottom panel; the model is
  /// centered in what remains.
  final EdgeInsets stageInsets;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    scene.paint(canvas, size, stageInsets.deflateRect(Offset.zero & size),
        progress.value);
  }

  @override
  bool shouldRepaint(ChamberPainter old) =>
      old.scene != scene || old.stageInsets != stageInsets;
}
