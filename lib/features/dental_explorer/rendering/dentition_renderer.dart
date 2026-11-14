import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../geometry/dentition_builder.dart';
import '../geometry/mesh.dart';
import 'orbit_camera.dart';

/// Per-owner appearance for one frame (owners: teeth 0–31, gums 32–33).
class SceneStyle {
  final alpha = Float32List(kOwnerCount)..fillRange(0, kOwnerCount, 1);

  /// Colour mixed into the surface, and how strongly (0–1).
  final tintR = Float32List(kOwnerCount);
  final tintG = Float32List(kOwnerCount);
  final tintB = Float32List(kOwnerCount);
  final tint = Float32List(kOwnerCount);

  /// Overall lightness multiplier.
  final brightness = Float32List(kOwnerCount)..fillRange(0, kOwnerCount, 1);

  /// Evens out the shading toward full light (0–1), softening dark faces.
  final lift = Float32List(kOwnerCount);

  /// Loss of colour (0–1), used to recede unselected teeth.
  final desaturate = Float32List(kOwnerCount);

  /// Self-lit teal glow (0–1) for the selected tooth.
  final glow = Float32List(kOwnerCount);

  /// Hide root triangles entirely.
  bool hideRoots = false;

  /// How fully roots show: 1 draws them solid (gums hidden); 0 lets only
  /// the top of each root glow faintly through the see-through gums.
  double rootReveal = 1;
}

/// Software 3D renderer for [DentitionModel]: projects and lights every
/// vertex, culls back faces, sorts triangles far-to-near (painter's
/// algorithm) and draws them in one [Canvas.drawVertices] call.
///
/// Keeps the last frame's projection so taps can be resolved to teeth.
class DentitionRenderer {
  DentitionRenderer(this.model)
      : _sx = Float32List(model.mesh.vertexCount),
        _sy = Float32List(model.mesh.vertexCount),
        _depth = Float32List(model.mesh.vertexCount),
        _color = Int32List(model.mesh.vertexCount),
        _visible = Int32List(model.mesh.triangleCount),
        _keys = Float32List(model.mesh.triangleCount),
        _order = Int32List(model.mesh.triangleCount),
        _outPos = Float32List(model.mesh.triangleCount * 6),
        _outColor = Int32List(model.mesh.triangleCount * 3);

  final DentitionModel model;

  final Float32List _sx, _sy, _depth;
  final Int32List _color;
  final Int32List _visible;
  final Float32List _keys;
  final Int32List _order;
  final Float32List _outPos;
  final Int32List _outColor;
  static const _buckets = 4096;
  final _bucketCounts = Int32List(_buckets + 1);

  int _drawn = 0;
  Size _size = Size.zero;
  CameraPose? _pose;
  final _paint = Paint()..isAntiAlias = true;

  /// Vertical field of view used to fit the model.
  static const double fov = 30 * math.pi / 180;
  static const double _near = 4;

  /// Camera distance that frames the whole model.
  double get fitDistance => model.radius / math.sin(fov / 2) * 0.84;

  static double focalLength(Size size) =>
      math.min(size.width, size.height) / 2 / math.tan(fov / 2);

  // Lights, in view space.
  static final _key = const Vec3(-0.35, 0.55, 0.76).normalized();
  static final _fill = const Vec3(0.7, -0.15, 0.5).normalized();
  static final _half = (_key + const Vec3(0, 0, 1)).normalized();

  void paint(Canvas canvas, Size size, CameraPose pose, SceneStyle style) {
    _size = size;
    _pose = pose;
    final mesh = model.mesh;
    final pos = mesh.positions, nrm = mesh.normals, alb = mesh.albedo;
    final owner = mesh.owner, flags = mesh.flags;
    final r = pose.rotation;
    final r0 = r[0], r1 = r[1], r2 = r[2];
    final r3 = r[3], r4 = r[4], r5 = r[5];
    final r6 = r[6], r7 = r[7], r8 = r[8];
    final tx = pose.target.x, ty = pose.target.y, tz = pose.target.z;
    final dist = pose.distance;
    final f = focalLength(size);
    final cx = size.width / 2, cy = size.height / 2;
    final hideRoots = style.hideRoots;
    final rootReveal = style.rootReveal;
    final rootDepth = mesh.rootDepth;

    final kx = _key.x, ky = _key.y, kz = _key.z;
    final fx = _fill.x, fy = _fill.y, fz = _fill.z;
    final hx = _half.x, hy = _half.y, hz = _half.z;

    // ── Vertices: project and light ───────────────────────────
    for (var i = 0; i < mesh.vertexCount; i++) {
      final o = owner[i];
      final a = style.alpha[o];
      if (a <= 0.004 || (hideRoots && flags[i] & kFlagRoot != 0)) {
        _depth[i] = -1;
        continue;
      }
      final i3 = i * 3;
      final px = pos[i3] - tx, py = pos[i3 + 1] - ty, pz = pos[i3 + 2] - tz;
      final vx = r0 * px + r1 * py + r2 * pz;
      final vy = r3 * px + r4 * py + r5 * pz;
      final vz = r6 * px + r7 * py + r8 * pz;
      final d = dist - vz;
      if (d < _near) {
        _depth[i] = -1;
        continue;
      }
      final inv = f / d;
      _sx[i] = cx + vx * inv;
      _sy[i] = cy - vy * inv;
      _depth[i] = d;

      final ox = nrm[i3], oy = nrm[i3 + 1], oz = nrm[i3 + 2];
      final nx = r0 * ox + r1 * oy + r2 * oz;
      final ny = r3 * ox + r4 * oy + r5 * oz;
      final nz = r6 * ox + r7 * oy + r8 * oz;

      final gum = o >= 32;
      final root = flags[i] & kFlagRoot != 0;
      var diffuse = nx * kx + ny * ky + nz * kz;
      if (diffuse < 0) diffuse = 0;
      var fill = nx * fx + ny * fy + nz * fz;
      if (fill < 0) fill = 0;
      var s = nx * hx + ny * hy + nz * hz;
      if (s < 0) s = 0;
      // s^32 (enamel) or s^16 (gum, root) by repeated squaring.
      s *= s;
      s *= s;
      s *= s;
      s *= s;
      if (!gum && !root) s *= s;
      final specular = s * (gum ? 0.3 : (root ? 0.08 : 0.5));
      // Sky/ground ambient plus a soft rim that reads as translucency.
      final ambient = 0.28 + 0.08 * ny;
      final facing = nz < 0 ? 0.0 : nz;
      final edge = 1 - facing;
      final rim = edge * edge * edge * (gum ? 0.24 : 0.16);
      // Key + fill, plus a soft headlight so faces turned toward the
      // viewer stay readable from any angle.
      var light = ambient + 0.55 * diffuse + 0.18 * fill + 0.16 * facing;
      final lift = style.lift[o];
      if (lift > 0 && light < 1) light += (1 - light) * lift;

      // Owner styling: tint, desaturation, brightness, glow.
      var br = alb[i3], bg = alb[i3 + 1], bb = alb[i3 + 2];
      final t = style.tint[o];
      if (t > 0) {
        br += (style.tintR[o] - br) * t;
        bg += (style.tintG[o] - bg) * t;
        bb += (style.tintB[o] - bb) * t;
      }
      final ds = style.desaturate[o];
      if (ds > 0) {
        final grey = br * 0.3 + bg * 0.59 + bb * 0.11;
        br += (grey - br) * ds;
        bg += (grey - bg) * ds;
        bb += (grey - bb) * ds;
      }
      final k = style.brightness[o];
      final g = style.glow[o];
      var cr = (br * light + rim * 0.9) * k + specular + g * 0.04;
      var cg = (bg * light + rim * 0.95) * k + specular + g * 0.14;
      var cb = (bb * light + rim) * k + specular + g * 0.13;
      if (cr > 1) cr = 1;
      if (cg > 1) cg = 1;
      if (cb > 1) cb = 1;
      // Glass gums: clearer where they face the viewer, denser at the
      // edges, so the shape still reads while the roots show through.
      var va = a;
      if (gum) {
        va = a * (0.7 + 0.6 * edge);
        if (va > 1) va = 1;
      } else if (root && rootReveal < 1) {
        // Under the gums, roots fade out toward the apex so they stay
        // inside the gum instead of poking out of it.
        var hint = 1 - rootDepth[i] / 9;
        if (hint < 0) hint = 0;
        va = a * (hint * 0.55 + (1 - hint * 0.55) * rootReveal);
      }
      _color[i] = ((va * 255).round() << 24) |
          ((cr * 255).round() << 16) |
          ((cg * 255).round() << 8) |
          (cb * 255).round();
    }

    // ── Triangles: cull and collect ───────────────────────────
    final tris = mesh.triangles,
        triOwner = mesh.triOwner,
        triFlags = mesh.triFlags;
    var count = 0;
    var minKey = double.infinity, maxKey = -double.infinity;
    for (var t = 0; t < mesh.triangleCount; t++) {
      if (style.alpha[triOwner[t]] <= 0.004) continue;
      if (hideRoots && triFlags[t] & kFlagRoot != 0) continue;
      final t3 = t * 3;
      final i0 = tris[t3], i1 = tris[t3 + 1], i2 = tris[t3 + 2];
      final d0 = _depth[i0], d1 = _depth[i1], d2 = _depth[i2];
      if (d0 < 0 || d1 < 0 || d2 < 0) continue;
      final x0 = _sx[i0], y0 = _sy[i0];
      final area =
          (_sx[i1] - x0) * (_sy[i2] - y0) - (_sy[i1] - y0) * (_sx[i2] - x0);
      if (area >= 0) continue; // back face
      var key = d0 + d1 + d2;
      if (triFlags[t] & kFlagSubRoot != 0) key += 4.5;
      // Gums win ties where they meet the tooth neck, keeping the gum
      // line clean instead of jagged.
      if (triOwner[t] >= 32) key -= 1.5;
      _visible[count] = t;
      _keys[count] = key;
      count++;
      if (key < minKey) minKey = key;
      if (key > maxKey) maxKey = key;
    }

    // ── Sort far → near with a counting sort on quantised depth ─
    _bucketCounts.fillRange(0, _buckets + 1, 0);
    final scale = maxKey > minKey ? (_buckets - 1) / (maxKey - minKey) : 0.0;
    for (var j = 0; j < count; j++) {
      final b = _buckets - 1 - ((_keys[j] - minKey) * scale).toInt();
      _bucketCounts[b + 1]++;
    }
    for (var b = 0; b < _buckets; b++) {
      _bucketCounts[b + 1] += _bucketCounts[b];
    }
    for (var j = 0; j < count; j++) {
      final b = _buckets - 1 - ((_keys[j] - minKey) * scale).toInt();
      _order[_bucketCounts[b]++] = _visible[j];
    }
    _drawn = count;

    // ── Emit and draw ─────────────────────────────────────────
    for (var j = 0; j < count; j++) {
      final t3 = _order[j] * 3;
      final p = j * 6, c = j * 3;
      for (var v = 0; v < 3; v++) {
        final i = tris[t3 + v];
        _outPos[p + v * 2] = _sx[i];
        _outPos[p + v * 2 + 1] = _sy[i];
        _outColor[c + v] = _color[i];
      }
    }
    if (count == 0) return;
    final vertices = Vertices.raw(
      VertexMode.triangles,
      Float32List.sublistView(_outPos, 0, count * 6),
      colors: Int32List.sublistView(_outColor, 0, count * 3),
    );
    canvas.drawVertices(vertices, BlendMode.dst, _paint);
    vertices.dispose();
  }

  /// Screen position and depth of a world point in the last frame.
  (Offset, double)? project(Vec3 p) {
    final pose = _pose;
    if (pose == null) return null;
    final r = pose.rotation;
    final px = p.x - pose.target.x,
        py = p.y - pose.target.y,
        pz = p.z - pose.target.z;
    final vx = r[0] * px + r[1] * py + r[2] * pz;
    final vy = r[3] * px + r[4] * py + r[5] * pz;
    final vz = r[6] * px + r[7] * py + r[8] * pz;
    final d = pose.distance - vz;
    if (d < _near) return null;
    final f = focalLength(_size) / d;
    return (Offset(_size.width / 2 + vx * f, _size.height / 2 - vy * f), d);
  }

  /// Rotates a world direction into view space (z toward the viewer).
  Vec3 toView(Vec3 v) {
    final r = (_pose ??
            const CameraPose(yaw: 0, pitch: 0, distance: 1, target: Vec3.zero))
        .rotation;
    return Vec3(
      r[0] * v.x + r[1] * v.y + r[2] * v.z,
      r[3] * v.x + r[4] * v.y + r[5] * v.z,
      r[6] * v.x + r[7] * v.y + r[8] * v.z,
    );
  }

  /// Owner of the front-most tooth triangle under [point] in the last
  /// frame, or null if no tooth was hit. The see-through gums are
  /// skipped, so a tap on the gum selects the tooth behind it.
  int? hitTest(Offset point) {
    final tris = model.mesh.triangles;
    final px = point.dx, py = point.dy;
    for (var j = _drawn - 1; j >= 0; j--) {
      final t = _order[j];
      final i0 = tris[t * 3], i1 = tris[t * 3 + 1], i2 = tris[t * 3 + 2];
      final x0 = _sx[i0], y0 = _sy[i0];
      final x1 = _sx[i1], y1 = _sy[i1];
      final x2 = _sx[i2], y2 = _sy[i2];
      final d0 = (x1 - x0) * (py - y0) - (y1 - y0) * (px - x0);
      final d1 = (x2 - x1) * (py - y1) - (y2 - y1) * (px - x1);
      final d2 = (x0 - x2) * (py - y2) - (y0 - y2) * (px - x2);
      final hasNeg = d0 < 0 || d1 < 0 || d2 < 0;
      final hasPos = d0 > 0 || d1 > 0 || d2 > 0;
      if (!(hasNeg && hasPos)) {
        final owner = model.mesh.triOwner[t];
        if (owner < 32) return owner;
      }
    }
    return null;
  }
}
