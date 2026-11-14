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
import '../../data/scan_outcomes.dart';
import '../../data/scan_regions.dart';
import '../../data/scan_steps.dart';
import '../scan_theme.dart';

/// Where each part of the scan sits on its 0-1 progress. Progress follows the
/// real run: sending photos builds the model, each photo the server finishes
/// lands on it, and the results reveal only once they're in.
class ChamberTimeline {
  ChamberTimeline(this.photos);

  /// The photos in the run, in capture order.
  final List<ScanRegion> photos;

  static const double buildEnd = 0.36;
  static const double readEnd = 0.84;
  static const double revealEnd = 0.955;

  /// Point cloud, wireframe, solid model, photos, reveal, settle.
  static const phaseStarts = [0.0, 0.08, 0.22, buildEnd, readEnd, revealEnd];

  /// 0-1 through animation [phase] at [p].
  double within(int phase, double p) {
    final start = phaseStarts[phase];
    final end = phase + 1 < phaseStarts.length ? phaseStarts[phase + 1] : 1.0;
    return ((p - start) / (end - start)).clamp(0.0, 1.0);
  }

  double get _slot => (readEnd - buildEnd) / math.max(1, photos.length);

  /// Progress of the [i]-th photo: on stage from 0 to 1, with a ripple on the
  /// model carrying on a little past that.
  double flight(int i, double p) => (p - (buildEnd + i * _slot)) / _slot;

  /// A photo waits at this point of its flight, being read, until the server
  /// says it's finished. Only then does it fly to the model.
  static const double readingHold = 0.7;

  bool landed(int i, double p) => flight(i, p) >= 0.92;

  int landedCount(double p) {
    var n = 0;
    for (var i = 0; i < photos.length; i++) {
      if (landed(i, p)) n++;
    }
    return n;
  }

  /// The step to explain at [p]: saving and sending while the model builds,
  /// what happens to each photo while they're read, then the results.
  static int stepAt(double p) {
    final sending = sendingSteps.length, reading = readingSteps.length;
    if (p < buildEnd) return p < buildEnd / 2 ? 0 : 1;
    if (p < readEnd) {
      final part = (p - buildEnd) / (readEnd - buildEnd);
      return sending + math.min((part * reading).floor(), reading - 1);
    }
    return sending + reading + (p < (readEnd + revealEnd) / 2 ? 0 : 1);
  }

  /// How far a tooth has filled in solid. [rank] is its place along the
  /// arches, 0-1.
  static double solid(double rank, double p) =>
      ((p - (0.225 + 0.1 * rank)) / 0.03).clamp(0.0, 1.0);

  /// How far an area's reveal has run; 0 before it starts.
  static double revealed(MouthArea area, double p) =>
      ((p - (readEnd + 0.008 + 0.085 * area.index / (MouthArea.values.length - 1))) /
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

  /// By view id: where that view's photo lands.
  final Map<String, Vec3> regionAnchors;

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
      regionAnchors: {
        for (final region in [...scanRegions, ...legacyScanRegions])
          region.id: average([
            for (final t in ToothCatalog.all)
              if (region.covers(t)) anchors[t.index].crownCenter,
          ]),
      },
    );
  }
}

/// Draws one frame of the scan over the light backdrop.
///
/// Layers, back to front: a soft glow and the pad the model stands on, the
/// progress ring; the model as a point cloud, wireframe, then solid; the
/// user's photos being read, area markers and the scanning light.
///
/// The camera and light run on the clock, so the scene stays alive while
/// waiting for the server, but nothing it shows as done is ahead of the run.
class ChamberScene {
  ChamberScene({
    required this.model,
    required this.timeline,
    required this.thumbs,
    required this.reduced,
  })  : _renderer = DentitionRenderer(model),
        _geo = ChamberGeometry.of(model),
        _sx = Float32List(model.mesh.vertexCount),
        _sy = Float32List(model.mesh.vertexCount),
        _sd = Float32List(model.mesh.vertexCount) {
    final maxEdges =
        List.generate(32, (i) => _geo.edgeStart[i + 1] - _geo.edgeStart[i])
            .reduce(math.max);
    _lines = Float32List(maxEdges * 4);
    _points = Float32List(_geo.pointVert.length * 2);
  }

  final DentitionModel model;
  final ChamberTimeline timeline;

  /// What the real results say about each area of the mouth, revealed area
  /// by area. Empty until the analysis finishes.
  Map<MouthArea, ViewOutcome?> areas = const {};

  /// The photos with findings, by id. Empty until the analysis finishes.
  Map<String, ViewOutcome> flagged = const {};

  /// Decoded photos by region id. Filled in while the scan runs; a photo
  /// still decoding is drawn as a plain card.
  final Map<String, ui.Image> thumbs;
  final bool reduced;

  final DentitionRenderer _renderer;
  final ChamberGeometry _geo;
  final _style = SceneStyle();
  final Float32List _sx, _sy, _sd;
  late final Float32List _lines;
  late final Float32List _points;

  static const _homeYaw = -0.34;

  // Projection for the current frame (see DentitionRenderer.paint).
  double _r0 = 1, _r1 = 0, _r2 = 0, _r3 = 0, _r4 = 1, _r5 = 0;
  double _r6 = 0, _r7 = 0, _r8 = 1;
  double _tx = 0, _ty = 0, _tz = 0, _dist = 1, _f = 1, _cx = 0, _cy = 0;
  double _ox = 0, _oy = 0;

  // Where the free-running camera was when the reveal began.
  double? _settleFrom;

  static const double _orbitPerSecond = 2 * math.pi / 26;
  static const double _lightPassSeconds = 3.2;

  double get _fit =>
      model.radius / math.sin(DentitionRenderer.fov / 2) * 0.84;

  /// The camera: orbiting on the clock, then easing round to the home view as
  /// the results come in, pulling in a little.
  CameraPose poseAt(double p, double t) {
    final settle = Curves.easeInOutCubic.transform(timeline.within(4, p));
    final free = _homeYaw + _orbitPerSecond * t - math.pi * 0.5;
    var yaw = reduced ? _homeYaw : free;
    if (!reduced && settle > 0) {
      final from = _settleFrom ??= free;
      yaw = from + wrapAngle(_homeYaw - from) * settle;
    }
    final approach =
        reduced ? 1.0 : Curves.easeOutCubic.transform(math.min(p / 0.14, 1.0));
    return CameraPose(
      yaw: yaw,
      pitch: 0.2 + (reduced ? 0 : 0.08 * math.sin(t * 0.45) * (1 - settle)),
      distance: _fit * 1.3 * (1.5 - 0.5 * approach) * (1 - 0.1 * settle),
      target: model.center,
    );
  }

  /// [p] is the run's progress, [t] the seconds since the scan opened.
  void paint(Canvas canvas, Size size, Rect stage, double p, double t) {
    final pose = poseAt(p, t);
    _setProjection(pose, stage.size);
    // Rough on-screen half-width of the arches.
    final radius = model.radius * _f / pose.distance * 0.7;
    final lightY = _lightY(_cy, radius, t);

    canvas.save();
    canvas.translate(stage.left, stage.top);
    final center = Offset(_cx, _cy);
    _paintStage(canvas, center, radius, p);

    if (p > 0.215) {
      _applyStyle(p, t, lightY, radius);
      _renderer.paint(canvas, stage.size, pose, _style);
    }
    if (p > 0.07 && p < 0.4) _paintWireframe(canvas, center, radius, p);
    if (p < 0.2) _paintPointCloud(canvas, p);
    if (!reduced) _paintScanLight(canvas, center, radius, p, t, lightY);
    if (p > ChamberTimeline.readEnd) _paintMarkers(canvas, stage.size, p, t);
    _paintPhotos(canvas, stage.size, p, t);
    canvas.restore();

    // The last moment washes to the mint of the results page.
    if (p > 0.975) {
      final q = Curves.easeIn.transform(((p - 0.975) / 0.025).clamp(0, 1));
      canvas.drawRect(Offset.zero & size,
          Paint()..color = AppColors.lightLavender.withValues(alpha: 0.85 * q));
    }
  }

  double _lightY(double cy, double radius, double t) {
    final phase = (t % _lightPassSeconds) / _lightPassSeconds;
    return cy - radius * 1.05 + radius * 2.1 * phase;
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

  // ── Surroundings ───────────────────────────────────────────────

  /// A white glow behind the model, the pad it stands on, and a ring that
  /// fills with progress.
  void _paintStage(Canvas canvas, Offset c, double radius, double p) {
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

  void _applyStyle(double p, double t, double lightY, double radius) {
    final s = _style
      ..hideRoots = true
      ..rootReveal = 0;

    // Each landed photo lights up the teeth its view covers, briefly.
    final photoGlow = List<double>.filled(32, 0);
    final photos = timeline.photos;
    for (var i = 0; i < photos.length; i++) {
      final f = timeline.flight(i, p);
      if (f < 0.8 || f > 1.6) continue;
      final bump = math.sin(math.pi * ((f - 0.8) / 0.8));
      for (final tooth in ToothCatalog.all) {
        if (photos[i].covers(tooth)) {
          photoGlow[tooth.index] = math.max(photoGlow[tooth.index], bump);
        }
      }
    }

    // The scanning light wakes the teeth it's passing over.
    final lightFade = reduced ? 0.0 : 1 - timeline.within(4, p);

    for (final tooth in ToothCatalog.all) {
      final i = tooth.index;
      final rank = _geo.revealRank[i] / 31;
      final solid = reduced
          ? ((p - 0.22) / 0.14).clamp(0.0, 1.0)
          : ChamberTimeline.solid(rank, p);
      // A teal flash as the tooth fills in, fading as it settles.
      final filledAt = 0.225 + 0.1 * rank + 0.03;
      final flash =
          solid <= 0 ? 0.0 : 1 - ((p - filledAt) / 0.04).clamp(0.0, 1.0);

      var near = 0.0;
      if (lightFade > 0 && _projectVec(model.anchors[i].crownCenter)) {
        near = (1 - (_oy - lightY).abs() / (radius * 0.26)).clamp(0.0, 1.0);
      }
      var glow = 0.8 * flash + 0.6 * photoGlow[i] + 0.55 * near * lightFade;
      var tint = 0.4 * flash + 0.25 * photoGlow[i] + 0.22 * near * lightFade;
      var color = AppColors.g1;
      var desaturate = 0.0, brightness = 1.0;

      // Each area flashes as it's revealed, then settles into the shade of
      // what the real results said about it.
      final area = MouthArea.of(tooth);
      final u = ChamberTimeline.revealed(area, p);
      if (u > 0) {
        final outcome = areas[area];
        final e = Curves.easeOutCubic.transform(u);
        glow += 0.8 * (1 - u);
        if (outcome == null || !outcome.checked) {
          desaturate = 0.8 * e;
          brightness = 1 - 0.1 * e;
        } else {
          color = _modelColor(outcome);
          tint = _modelTint(outcome) * e;
          if (outcome != ViewOutcome.clear && !reduced) {
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
    final gums = ((p - 0.3) / 0.08).clamp(0.0, 1.0) * 0.45;
    for (final o in const [kUpperGumOwner, kLowerGumOwner]) {
      s
        ..alpha[o] = gums
        ..glow[o] = 0
        ..tint[o] = 0
        ..desaturate[o] = 0
        ..brightness[o] = 1;
    }
  }

  /// Shade used on the model. Lighter than the dots, so a mouth with several
  /// findings still looks calm.
  static Color _modelColor(ViewOutcome outcome) => switch (outcome) {
        ViewOutcome.urgent => const Color(0xFF215E61), // g2 toward navy
        ViewOutcome.finding => AppColors.g2,
        _ => AppColors.g1,
      };

  static double _modelTint(ViewOutcome outcome) => switch (outcome) {
        ViewOutcome.urgent => 0.58,
        ViewOutcome.finding => 0.5,
        _ => 0.18,
      };

  void _paintPointCloud(Canvas canvas, double p) {
    final fade = 1 - ((p - 0.12) / 0.07).clamp(0.0, 1.0);
    if (fade <= 0) return;
    final converge = (p / 0.11).clamp(0.0, 1.0);
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
    final appear = ((p - 0.07) / 0.04).clamp(0.0, 1.0);
    // While mapping, the wireframe is revealed by the scanning light's
    // first pass.
    final sweep = timeline.within(1, p);
    final revealY = p < 0.22
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
          ? ((p - 0.22) / 0.14).clamp(0.0, 1.0)
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

  /// The user's own photos, one at a time: each comes up large and is read,
  /// with a line of light passing over it until the server has finished with
  /// it, then flies to the part of the model its view covers.
  void _paintPhotos(Canvas canvas, Size s, double p, double t) {
    final photos = timeline.photos;
    for (var i = 0; i < photos.length; i++) {
      final f = timeline.flight(i, p);
      if (f <= 0 || f >= 1.6) continue;
      final region = photos[i];
      final anchor = _geo.regionAnchors[baseRegionId(region.id)];
      if (anchor == null || !_projectVec(anchor)) continue;
      final target = Offset(_ox, _oy);

      if (f < 1) _paintPhotoCard(canvas, s, region, f, target, t);

      // Landing ripple.
      if (f > 0.9 && !reduced) {
        final q = ((f - 0.9) / 0.7).clamp(0.0, 1.0);
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

  void _paintPhotoCard(Canvas canvas, Size s, ScanRegion region, double f,
      Offset target, double t) {
    final width = math.min(s.width * 0.6, 250.0);
    final home = Offset(s.width / 2, s.height * 0.42);

    // In, read, then away to the model.
    const flyFrom = 0.74;
    final fly = reduced
        ? 0.0
        : Curves.easeInOutCubic
            .transform(((f - flyFrom) / (1 - flyFrom)).clamp(0.0, 1.0));
    final entrance = Curves.easeOutCubic.transform((f / 0.12).clamp(0.0, 1.0));
    final alpha = entrance * (1 - ((f - 0.94) / 0.06).clamp(0.0, 1.0));
    if (alpha <= 0) return;
    final arc = Offset(0, -24 * math.sin(math.pi * fly));
    final pos = Offset.lerp(home, target, fly)! + arc;
    final w = (width + (16 - width) * math.pow(fly, 1.3).toDouble()) *
        (0.94 + 0.06 * entrance);
    final rect = Rect.fromCenter(center: pos, width: w, height: w * 0.75);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(w * 0.09));

    // A soft beam from the card onto the model as it leaves.
    if (fly > 0.02) {
      final beam = Path()
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(target.dx, target.dy)
        ..lineTo(rect.right, rect.bottom)
        ..close();
      canvas.drawPath(
        beam,
        Paint()
          ..shader = ui.Gradient.linear(
            pos,
            target,
            [
              AppColors.g1.withValues(alpha: 0.3 * alpha),
              AppColors.g1.withValues(alpha: 0.04 * alpha),
            ],
          ),
      );
    }

    // Glass card: soft shadow, white rim, the photo inside.
    canvas.drawRRect(
      rrect.shift(const Offset(0, 6)),
      Paint()
        ..color = AppColors.navy.withValues(alpha: 0.18 * alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
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

    // The reading light passes over the photo for as long as it's being read.
    if (!reduced && fly <= 0 && region.checked) {
      const passSeconds = 1.25;
      final q = (t % passSeconds) / passSeconds;
      final a = math.sin(math.pi * q) * alpha;
      final y = rect.top + rect.height * q;
      final trail = Rect.fromLTRB(rect.left, y - 50, rect.right, y);
      canvas.drawRect(
        trail,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.g1.withValues(alpha: 0),
              AppColors.g1.withValues(alpha: 0.34 * a),
            ],
          ).createShader(trail),
      );
      canvas.drawRect(
        Rect.fromLTWH(rect.left, y - 1, rect.width, 2),
        Paint()..color = AppColors.white.withValues(alpha: 0.95 * a),
      );
    }
    canvas.restore();

    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = AppColors.white.withValues(alpha: 0.95 * alpha),
    );
    if (fly < 0.3) {
      _paintCorners(canvas, rect.deflate(9), alpha * (1 - fly / 0.3));
    }
  }

  /// Camera framing on the photo being read.
  static void _paintCorners(Canvas canvas, Rect r, double alpha) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = AppColors.white.withValues(alpha: 0.9 * alpha);
    const arm = 14.0;
    for (final (corner, dx, dy) in [
      (r.topLeft, 1.0, 1.0),
      (r.topRight, -1.0, 1.0),
      (r.bottomLeft, 1.0, -1.0),
      (r.bottomRight, -1.0, -1.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(corner.dx, corner.dy + dy * arm)
          ..lineTo(corner.dx, corner.dy)
          ..lineTo(corner.dx + dx * arm, corner.dy),
        paint,
      );
    }
  }

  /// Source rect that crops [image] to cover [box] like BoxFit.cover.
  static Rect _coverSource(ui.Image image, Size box) {
    final iw = image.width.toDouble(), ih = image.height.toDouble();
    final scale = math.max(box.width / iw, box.height / ih);
    final w = box.width / scale, h = box.height / scale;
    return Rect.fromLTWH((iw - w) / 2, (ih - h) / 2, w, h);
  }

  /// A soft dot pops in for each view with a real finding, where that view
  /// looks. One per view, however many areas it shows, since a finding says
  /// which photo, not which tooth. No numbers.
  void _paintMarkers(Canvas canvas, Size s, double p, double t) {
    final u = timeline.within(4, p);
    if (u <= 0) return;
    var n = 0;
    for (final entry in flagged.entries) {
      n++;
      final anchor = _geo.regionAnchors[baseRegionId(entry.key)];
      if (anchor == null || !_projectVec(anchor)) continue;
      final at = Offset(_ox, _oy);
      if (!(Offset.zero & s).contains(at)) continue;
      final alpha = (u * 3).clamp(0.0, 1.0);
      final scale = reduced
          ? 1.0
          : Curves.easeOutBack.transform((u * 1.6).clamp(0.0, 1.0));
      final pulse = reduced ? 0.5 : 0.5 + 0.5 * math.sin(t * 4 + n);
      final color = entry.value == ViewOutcome.urgent
          ? ScanColors.urgent
          : ScanColors.check;
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
  /// glow trailing behind. It runs on the clock, so it keeps moving while the
  /// server is working.
  void _paintScanLight(Canvas canvas, Offset c, double radius, double p,
      double t, double y) {
    final settle = timeline.within(4, p);
    final fade = (p / 0.05).clamp(0.0, 1.0) * (1 - settle);
    if (fade <= 0) return;
    final phase = (t % _lightPassSeconds) / _lightPassSeconds;
    final a = math.sqrt(math.sin(math.pi * phase)) * fade;
    final x0 = c.dx - radius * 1.3, x1 = c.dx + radius * 1.3;

    final glow = Rect.fromCenter(
      center: Offset(c.dx, y - 16),
      width: radius * 2.7,
      height: 76,
    );
    canvas.drawOval(
      glow,
      Paint()
        ..shader = RadialGradient(colors: [
          AppColors.g1.withValues(alpha: 0.26 * a),
          AppColors.g1.withValues(alpha: 0),
        ]).createShader(glow),
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

/// Repaints the scan on every tick of the chamber's clock.
class ChamberPainter extends CustomPainter {
  ChamberPainter({
    required this.scene,
    required Listenable clock,
    required this.progress,
    required this.seconds,
    required this.stageInsets,
  }) : super(repaint: clock);

  final ChamberScene scene;
  final double Function() progress;
  final double Function() seconds;

  /// Room taken by the top bar and the bottom panel; the model is
  /// centered in what remains.
  final EdgeInsets stageInsets;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    scene.paint(canvas, size, stageInsets.deflateRect(Offset.zero & size),
        progress(), seconds());
  }

  @override
  bool shouldRepaint(ChamberPainter old) =>
      old.scene != scene || old.stageInsets != stageInsets;
}
