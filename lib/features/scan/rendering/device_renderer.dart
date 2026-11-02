import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/painting.dart'
    show Alignment, LinearGradient, RadialGradient;

import '../../../core/constants/app_colors.dart';
import '../../dental_explorer/geometry/mesh.dart';
import 'device_model.dart';

/// How the device is held in front of the camera: turned by [yaw] about its
/// own length (positive faces the lens to the right), tipped by [pitch] (tip
/// toward the viewer), then rolled by [roll] on screen (negative leans the
/// tip right). [center] is where the model's origin lands.
class DevicePose {
  DevicePose({
    required double yaw,
    required double pitch,
    required double roll,
    required this.distance,
    required this.focal,
    required this.center,
  }) {
    final cy = math.cos(yaw), sy = math.sin(yaw);
    final cp = math.cos(pitch), sp = math.sin(pitch);
    final cr = math.cos(roll), sr = math.sin(roll);
    final y0 = sp * sy, y2 = -sp * cy;
    m0 = cr * cy - sr * y0;
    m1 = -sr * cp;
    m2 = cr * sy - sr * y2;
    m3 = sr * cy + cr * y0;
    m4 = cr * cp;
    m5 = sr * sy + cr * y2;
    m6 = -cp * sy;
    m7 = sp;
    m8 = cp * cy;
  }

  final double distance;
  final double focal;
  final Offset center;

  // Rotation from the model to view space, row-major.
  late final double m0, m1, m2, m3, m4, m5, m6, m7, m8;

  Offset project(Vec3 p) {
    final d = distance - (m6 * p.x + m7 * p.y + m8 * p.z);
    final k = focal / d;
    return Offset(
      center.dx + (m0 * p.x + m1 * p.y + m2 * p.z) * k,
      center.dy - (m3 * p.x + m4 * p.y + m5 * p.z) * k,
    );
  }

  /// How squarely a surface at [p] with normal [n] faces the viewer, 0 to 1.
  double facing(Vec3 p, Vec3 n) {
    final vx = m0 * p.x + m1 * p.y + m2 * p.z;
    final vy = m3 * p.x + m4 * p.y + m5 * p.z;
    final vz = m6 * p.x + m7 * p.y + m8 * p.z;
    final view = Vec3(-vx, -vy, distance - vz).normalized();
    final nv = Vec3(
      m0 * n.x + m1 * n.y + m2 * n.z,
      m3 * n.x + m4 * n.y + m5 * n.z,
      m6 * n.x + m7 * n.y + m8 * n.z,
    );
    return nv.dot(view).clamp(0.0, 1.0);
  }
}

/// Draws [DeviceModel] like a studio product shot: white plastic lit by large
/// soft lights, with long highlights down the shell and a cool falloff at its
/// edges, so it stands out from the pale page. The teeth renderer is tuned for
/// enamel and washes a white shell flat.
///
/// Draws the rings from the base to the tip, which is far to near for every
/// pose where the tip leans toward the viewer, so nothing needs sorting.
class DeviceRenderer {
  DeviceRenderer(this.model)
      : _sx = Float32List(model.mesh.vertexCount),
        _sy = Float32List(model.mesh.vertexCount),
        _color = Int32List(model.mesh.vertexCount),
        _facesViewer = Uint8List(model.mesh.triangleCount),
        _outPos = Float32List(model.mesh.triangleCount * 6),
        _outColor = Int32List(model.mesh.triangleCount * 3);

  final DeviceModel model;

  final Float32List _sx, _sy;
  final Int32List _color;
  final Uint8List _facesViewer;
  final Float32List _outPos;
  final Int32List _outColor;
  final _edgePoints = Float32List(_maxEdges * 4);
  final _paint = Paint();
  static final _edgePaint = Paint()
    ..strokeWidth = 1.3
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xFF7E9EA3).withValues(alpha: 0.45);

  // Far more than a silhouette can have, in any pose.
  static const _maxEdges = 2000;

  // Lights and reflections, in view space. The handle's normals sweep through
  // one plane, so the reflections are aimed at that plane in the resting pose,
  // which runs them down the length of the shell.
  static final _key = const Vec3(-0.5, 0.62, 0.6).normalized();
  static final _fill = const Vec3(0.75, 0.05, 0.66).normalized();
  static final _streak = const Vec3(-0.8, 0.01, 0.6).normalized();
  static final _sheen = const Vec3(-0.62, -0.08, 0.78).normalized();
  static final _sideStrip = const Vec3(0.61, -0.52, 0.6).normalized();

  void paint(Canvas canvas, DevicePose pose) {
    final mesh = model.mesh;
    final pos = mesh.positions, nrm = mesh.normals, alb = mesh.albedo;
    final m0 = pose.m0, m1 = pose.m1, m2 = pose.m2;
    final m3 = pose.m3, m4 = pose.m4, m5 = pose.m5;
    final m6 = pose.m6, m7 = pose.m7, m8 = pose.m8;
    final cx = pose.center.dx, cy = pose.center.dy;
    final dist = pose.distance, f = pose.focal;

    final kx = _key.x, ky = _key.y, kz = _key.z;
    final fx = _fill.x, fy = _fill.y, fz = _fill.z;
    final sx = _streak.x, sy = _streak.y, sz = _streak.z;
    final hx = _sheen.x, hy = _sheen.y, hz = _sheen.z;
    final gx = _sideStrip.x, gy = _sideStrip.y, gz = _sideStrip.z;

    for (var i = 0; i < mesh.vertexCount; i++) {
      final i3 = i * 3;
      final px = pos[i3], py = pos[i3 + 1], pz = pos[i3 + 2];
      final inv = f / (dist - (m6 * px + m7 * py + m8 * pz));
      _sx[i] = cx + (m0 * px + m1 * py + m2 * pz) * inv;
      _sy[i] = cy - (m3 * px + m4 * py + m5 * pz) * inv;

      final ox = nrm[i3], oy = nrm[i3 + 1], oz = nrm[i3 + 2];
      final nx = m0 * ox + m1 * oy + m2 * oz;
      final ny = m3 * ox + m4 * oy + m5 * oz;
      final nz = m6 * ox + m7 * oy + m8 * oz;

      // Large, soft lights wrap well round the form.
      var key = (nx * kx + ny * ky + nz * kz + 0.4) / 1.4;
      if (key < 0) key = 0;
      var fill = (nx * fx + ny * fy + nz * fz + 0.5) / 1.5;
      if (fill < 0) fill = 0;
      final facing = nz < 0 ? 0.0 : nz;
      final edge = 1 - facing;

      final light =
          (0.7 + 0.34 * key + 0.09 * fill) * (1 - 0.36 * edge * edge * edge);

      // Reflections: a crisp strip down the near edge, a broad sheen on the
      // front, and a soft strip along the shaded side.
      var streak = nx * sx + ny * sy + nz * sz;
      if (streak < 0) streak = 0;
      streak *= streak;
      streak *= streak;
      streak *= streak;
      streak *= streak;
      streak *= streak;
      streak *= streak;
      var sheen = nx * hx + ny * hy + nz * hz;
      if (sheen < 0) sheen = 0;
      sheen *= sheen;
      sheen *= sheen;
      sheen *= sheen;
      sheen *= sheen;
      var strip = nx * gx + ny * gy + nz * gz;
      if (strip < 0) strip = 0;
      strip *= strip;
      strip *= strip;
      strip *= strip;
      strip *= strip;
      strip *= strip;
      final gloss = 0.5 * streak + 0.05 * sheen + 0.16 * strip;

      // Shade falls toward cool teal rather than grey, like the page around
      // it, with a little mint bounced up from below.
      final shade = light < 1 ? 1 - light : 0.0;
      final under = ny < 0 ? -ny : 0.0;
      var cr = alb[i3] * light * (1 - 0.3 * shade) + gloss;
      var cg = alb[i3 + 1] * light + gloss + 0.012 * under;
      var cb = alb[i3 + 2] * light + gloss + 0.01 * under;
      if (cr > 1) cr = 1;
      if (cg > 1) cg = 1;
      if (cb > 1) cb = 1;
      _color[i] = (255 << 24) |
          ((cr * 255).round() << 16) |
          ((cg * 255).round() << 8) |
          (cb * 255).round();
    }

    final tris = mesh.triangles;
    var count = 0;
    for (var t = 0; t < mesh.triangleCount; t++) {
      final t3 = t * 3;
      final i0 = tris[t3], i1 = tris[t3 + 1], i2 = tris[t3 + 2];
      final x0 = _sx[i0], y0 = _sy[i0];
      final x1 = _sx[i1], y1 = _sy[i1];
      final x2 = _sx[i2], y2 = _sy[i2];
      final front = (x1 - x0) * (y2 - y0) - (y1 - y0) * (x2 - x0) < 0;
      _facesViewer[t] = front ? 1 : 0;
      if (!front) continue;
      final p = count * 6, c = count * 3;
      _outPos[p] = x0;
      _outPos[p + 1] = y0;
      _outPos[p + 2] = x1;
      _outPos[p + 3] = y1;
      _outPos[p + 4] = x2;
      _outPos[p + 5] = y2;
      _outColor[c] = _color[i0];
      _outColor[c + 1] = _color[i1];
      _outColor[c + 2] = _color[i2];
      count++;
    }
    if (count == 0) return;
    _paintEdge(canvas);
    final vertices = Vertices.raw(
      VertexMode.triangles,
      Float32List.sublistView(_outPos, 0, count * 6),
      colors: Int32List.sublistView(_outColor, 0, count * 3),
    );
    canvas.drawVertices(vertices, BlendMode.dst, _paint);
    vertices.dispose();
  }

  /// Strokes every edge between a triangle facing the viewer and one facing
  /// away. Triangles are drawn without antialiasing, so this goes under them:
  /// the shell covers what's inside its outline, and only the outer sliver of
  /// the stroke shows, softening the edge against the pale card.
  void _paintEdge(Canvas canvas) {
    const n = DeviceModel.segments;
    final rows = model.ringCount - 1;
    final faces = _facesViewer;
    var used = 0;
    void edge(int a, int b) {
      if (used == _edgePoints.length) return;
      _edgePoints[used++] = _sx[a];
      _edgePoints[used++] = _sy[a];
      _edgePoints[used++] = _sx[b];
      _edgePoints[used++] = _sy[b];
    }

    // Each quad between two rings is two triangles, in ring order (see
    // MeshBuilder.addRingSurface).
    for (var r = 0; r < rows; r++) {
      final a = r * n, b = a + n;
      for (var s = 0; s < n; s++) {
        final s1 = (s + 1) % n;
        final first = (a + s) * 2, second = first + 1;
        if (faces[first] != faces[second]) edge(b + s, a + s1);
        if (faces[second] != faces[(a + s1) * 2]) edge(a + s1, b + s1);
        if (r + 1 < rows && faces[second] != faces[(b + s) * 2]) {
          edge(b + s, b + s1);
        }
      }
    }
    canvas.drawRawPoints(
      PointMode.lines,
      Float32List.sublistView(_edgePoints, 0, used),
      _edgePaint,
    );
  }

  /// The shell's outline in [pose], for its shadow.
  Path outline(DevicePose pose) {
    final pos = model.mesh.positions;
    final base = pose.project(const Vec3(0, DeviceModel.baseY, 0));
    final tip = pose.project(const Vec3(0, DeviceModel.tipY, 0));
    final axis = tip - base;
    final length = axis.distance;
    if (length == 0) return Path();
    final px = -axis.dy / length, py = axis.dx / length;

    final m0 = pose.m0, m1 = pose.m1, m2 = pose.m2;
    final m3 = pose.m3, m4 = pose.m4, m5 = pose.m5;
    final m6 = pose.m6, m7 = pose.m7, m8 = pose.m8;
    final cx = pose.center.dx, cy = pose.center.dy;
    final left = <Offset>[], right = <Offset>[];
    for (var r = 0; r < model.ringCount; r++) {
      var low = double.infinity, high = -double.infinity;
      var lowX = 0.0, lowY = 0.0, highX = 0.0, highY = 0.0;
      for (var k = 0; k < DeviceModel.segments; k += 2) {
        final i3 = (r * DeviceModel.segments + k) * 3;
        final x = pos[i3], y = pos[i3 + 1], z = pos[i3 + 2];
        final inv = pose.focal / (pose.distance - (m6 * x + m7 * y + m8 * z));
        final sx = cx + (m0 * x + m1 * y + m2 * z) * inv;
        final sy = cy - (m3 * x + m4 * y + m5 * z) * inv;
        final d = sx * px + sy * py;
        if (d < low) {
          low = d;
          lowX = sx;
          lowY = sy;
        }
        if (d > high) {
          high = d;
          highX = sx;
          highY = sy;
        }
      }
      left.add(Offset(lowX, lowY));
      right.add(Offset(highX, highY));
    }
    return Path()..addPolygon([...left, ...right.reversed], true);
  }

  /// The lens, buttons, power switch and name, on the shell drawn by [paint].
  /// [lit] and [shine] are as in [DeviceArt.head].
  static void paintParts(
    Canvas canvas,
    DevicePose pose, {
    double lit = 0,
    double shine = 0,
  }) {
    void place(
      DeviceFrame frame,
      double w,
      double h,
      void Function(Canvas) draw,
    ) =>
        onFrame(canvas, pose, frame, w, h, draw);

    place(
      DeviceModel.front(DeviceModel.headY),
      DeviceArt.windowSize,
      DeviceArt.windowSize,
      (c) => DeviceArt.head(c, lit: lit, shine: shine),
    );
    place(DeviceModel.front(-5), DeviceArt.captureSize.width,
        DeviceArt.captureSize.height, DeviceArt.captureButton);
    place(DeviceModel.front(-28), DeviceArt.lightSize, DeviceArt.lightSize,
        DeviceArt.lightButton);
    place(DeviceModel.patch(-30, 0.22), DeviceArt.switchSize.width,
        DeviceArt.switchSize.height, DeviceArt.powerSwitch);

    // The name reads along the handle, up toward the head.
    final name = DeviceModel.front(-50);
    place(
      DeviceFrame(
        center: name.center,
        right: name.up,
        up: -name.right,
      ),
      DeviceArt.wordSize.width,
      DeviceArt.wordSize.height,
      DeviceArt.wordmark,
    );
  }

  /// Runs [draw] on the flat patch [frame], [w] x [h] mm with y down, mapped
  /// onto the device in perspective. Skipped when the patch turns away.
  static void onFrame(
    Canvas canvas,
    DevicePose pose,
    DeviceFrame frame,
    double w,
    double h,
    void Function(Canvas canvas) draw,
  ) {
    if (pose.facing(frame.center, frame.normal) < 0.06) return;
    final r = frame.right * (w / 2), u = frame.up * (h / 2);
    canvas.save();
    canvas.transform(_mapRect(
      w,
      h,
      pose.project(frame.center - r + u),
      pose.project(frame.center + r + u),
      pose.project(frame.center + r - u),
      pose.project(frame.center - r - u),
    ));
    draw(canvas);
    canvas.restore();
  }

  /// The matrix that maps a flat [w] x [h] rectangle onto the four projected
  /// corners, perspective included.
  static Float64List _mapRect(
      double w, double h, Offset tl, Offset tr, Offset br, Offset bl) {
    final dx1 = tr.dx - br.dx, dx2 = bl.dx - br.dx;
    final dy1 = tr.dy - br.dy, dy2 = bl.dy - br.dy;
    final sx = tl.dx - tr.dx + br.dx - bl.dx;
    final sy = tl.dy - tr.dy + br.dy - bl.dy;
    final det = dx1 * dy2 - dx2 * dy1;
    final g = (sx * dy2 - dx2 * sy) / det;
    final k = (dx1 * sy - sx * dy1) / det;
    final a = tr.dx - tl.dx + g * tr.dx;
    final b = bl.dx - tl.dx + k * bl.dx;
    final d = tr.dy - tl.dy + g * tr.dy;
    final e = bl.dy - tl.dy + k * bl.dy;
    return Float64List.fromList([
      a / w, d / w, 0, g / w, //
      b / h, e / h, 0, k / h,
      0, 0, 1, 0,
      tl.dx, tl.dy, 0, 1,
    ]);
  }
}

/// The parts on the shell, drawn flat in millimetres: the lens behind its
/// window, the two buttons, the power switch and the printed name.
abstract class DeviceArt {
  /// The round glass window on the head.
  static const double windowRadius = 6.6;
  static const double windowSize = _drawnSize * windowRadius / _drawnRadius;

  // The window is drawn at this size, then scaled to fit the head.
  static const double _drawnRadius = 10.6;
  static const double _drawnSize = (_drawnRadius + 0.6) * 2;

  static const Size captureSize = Size(13.6, 25);
  static const double lightSize = 13;
  static const Size switchSize = Size(4, 13);
  static const Size wordSize = Size(29, 4.4);

  // The schematic's LEDs, in order round the lens: four NIR among six white.
  static const _nirLeds = {0, 3, 5, 8};
  static const _ledCount = 10;
  static const _ledRing = 7.75;

  static const Color _glassDeep = Color(0xFF0E1B20); // navy toward black
  static const Color _glassLight = Color(0xFF2B4A52); // navy toward g2
  static const Color _led = Color(0xFFBFE3DF); // lavender, dimmed
  static const Color _deepTeal = Color(0xFF17807D); // g2, deeper

  /// A sunken rim: shaded on the side away from the light, bright on the other.
  static Paint _rim(Rect r) => Paint()
    ..shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        AppColors.navy.withValues(alpha: 0.26),
        AppColors.white.withValues(alpha: 0.95),
      ],
    ).createShader(r);

  /// The glass window with the LEDs and lens. [lit] is how brightly the white
  /// LEDs are firing, 0-1; [shine] slides the reflection as the device turns.
  static void head(Canvas canvas,
      {required double lit, required double shine}) {
    canvas.scale(windowRadius / _drawnRadius);
    const c = Offset(_drawnSize / 2, _drawnSize / 2);
    const r = _drawnRadius;
    final box = Rect.fromCircle(center: c, radius: r);

    canvas.drawCircle(c, r + 0.42, _rim(box.inflate(0.42)));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.15, -0.2),
          colors: [_glassLight, AppColors.navy, _glassDeep],
          stops: [0, 0.5, 1],
        ).createShader(box),
    );

    // The reflection on the glass, a soft crescent under the parts.
    canvas.save();
    canvas.clipPath(Path()..addOval(box));
    final sheen = Rect.fromCircle(
      center: c + Offset(-r * 0.32 + r * 0.25 * shine, -r * 1.02),
      radius: r * 0.98,
    );
    canvas.drawOval(
      sheen,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.white.withValues(alpha: 0.05),
            AppColors.white.withValues(alpha: 0.2),
          ],
        ).createShader(sheen),
    );
    canvas.restore();

    for (var i = 0; i < _ledCount; i++) {
      final a = -math.pi / 2 + (i + 0.5) * 2 * math.pi / _ledCount;
      final at = c + Offset(math.cos(a), math.sin(a)) * _ledRing;
      if (_nirLeds.contains(i)) {
        _nirLed(canvas, at);
      } else {
        _whiteLed(canvas, at, lit);
      }
    }

    _lens(canvas, c);
  }

  /// NIR LEDs give off nothing the eye can see, so they stay dark domes.
  static void _nirLed(Canvas canvas, Offset at) {
    canvas.drawCircle(at, 1.2, Paint()..color = const Color(0xFF3A5A63));
    canvas.drawCircle(at, 0.92, Paint()..color = const Color(0xFF12262C));
    canvas.drawCircle(
      at + const Offset(-0.28, -0.3),
      0.24,
      Paint()..color = AppColors.white.withValues(alpha: 0.5),
    );
  }

  static void _whiteLed(Canvas canvas, Offset at, double lit) {
    if (lit > 0) {
      final glow = Rect.fromCircle(center: at, radius: 3.1);
      canvas.drawCircle(
        at,
        3.1,
        Paint()
          ..shader = RadialGradient(colors: [
            AppColors.white.withValues(alpha: 0.95 * lit),
            AppColors.white.withValues(alpha: 0.28 * lit),
            AppColors.white.withValues(alpha: 0),
          ], stops: const [
            0.3,
            0.55,
            1
          ]).createShader(glow),
      );
    }
    canvas.drawCircle(at, 1.2, Paint()..color = const Color(0xFF55747C));
    canvas.drawCircle(
      at,
      0.92,
      Paint()..color = Color.lerp(_led, AppColors.white, lit)!,
    );
  }

  static void _lens(Canvas canvas, Offset c) {
    final bezel = Rect.fromCircle(center: c, radius: 4.7);
    canvas.drawCircle(
      c,
      4.7,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF4F9F9),
            Color(0xFF6F878D),
            Color(0xFFCFDEDE),
          ],
          stops: [0, 0.55, 1],
        ).createShader(bezel),
    );
    canvas.drawCircle(c, 3.95, Paint()..color = const Color(0xFF050C0F));
    // The coating: a teal glint on the far side of the glass.
    final coat = Rect.fromCircle(center: c, radius: 3.4);
    canvas.drawCircle(
      c,
      3.4,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.45, 0.5),
          radius: 0.9,
          colors: [
            AppColors.g2.withValues(alpha: 0.85),
            const Color(0xFF123A44).withValues(alpha: 0.55),
            const Color(0xFF050C0F).withValues(alpha: 0),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(coat),
    );
    canvas.drawCircle(c, 1.5, Paint()..color = const Color(0xFF02070A));
    canvas.drawCircle(
      c + const Offset(-1.45, -1.55),
      0.52,
      Paint()..color = AppColors.white.withValues(alpha: 0.95),
    );
    canvas.drawCircle(
      c + const Offset(-0.5, -2.3),
      0.2,
      Paint()..color = AppColors.white.withValues(alpha: 0.55),
    );
  }

  /// The Capture button: the one teal control, where the thumb rests.
  static void captureButton(Canvas canvas) {
    final w = captureSize.width, h = captureSize.height;
    final outer = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      Radius.circular(w / 2),
    );
    final body = outer.deflate(0.34);
    canvas.drawRRect(outer, _rim(outer.outerRect));
    canvas.drawRRect(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5DE0D0), AppColors.g2, _deepTeal],
          stops: [0, 0.55, 1],
        ).createShader(body.outerRect),
    );
    // Light along the top of the dish.
    final top = Rect.fromLTWH(body.left, body.top, body.width, body.height / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(top.deflate(0.7), Radius.circular(w / 2)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.white.withValues(alpha: 0.24),
            AppColors.white.withValues(alpha: 0),
          ],
        ).createShader(top),
    );
    // A shutter mark.
    final c = Offset(w / 2, h / 2);
    canvas.drawCircle(
      c,
      3.1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.85
        ..color = AppColors.white,
    );
    canvas.drawCircle(c, 1.5, Paint()..color = AppColors.white);
  }

  /// The Light button: a small white disc with a sun on it.
  static void lightButton(Canvas canvas) {
    const size = lightSize;
    const c = Offset(size / 2, size / 2);
    final box = Rect.fromCircle(center: c, radius: size / 2);
    canvas.drawCircle(c, size / 2, _rim(box));
    canvas.drawCircle(
      c,
      size / 2 - 0.34,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.white, Color(0xFFDCEBEA)],
        ).createShader(box),
    );
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.72
      ..strokeCap = StrokeCap.round
      ..color = _deepTeal;
    canvas.drawCircle(c, 1.55, ink);
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + d * 2.75, c + d * 3.85, ink);
    }
  }

  /// The Power switch, a small slider in a slot on the side.
  static void powerSwitch(Canvas canvas) {
    final w = switchSize.width, h = switchSize.height;
    final slot = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      Radius.circular(w / 2),
    );
    canvas.drawRRect(slot, Paint()..color = const Color(0xFF3F5A62));
    final thumb = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.55, 0.7, w - 1.1, h * 0.52),
      Radius.circular((w - 1.1) / 2),
    );
    canvas.drawRRect(
      thumb,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.white, Color(0xFFCADADA)],
        ).createShader(thumb.outerRect),
    );
  }

  static final Path _word = _wordPath();

  /// "DENTRA" printed along the handle, as strokes so it needs no font.
  static void wordmark(Canvas canvas) {
    canvas.scale(0.88);
    canvas.translate(wordSize.width * 0.06, wordSize.height * 0.06);
    canvas.drawPath(
      _word,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.66
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.navy.withValues(alpha: 0.72),
    );
  }

  static Path _wordPath() {
    const h = 4.4, mid = h / 2, gap = 1.75;
    final p = Path();
    var x = 0.0;

    // D
    p
      ..moveTo(x, 0)
      ..lineTo(x, h)
      ..lineTo(x + 1.1, h)
      ..cubicTo(x + 4.0, h, x + 4.0, 0, x + 1.1, 0)
      ..close();
    x += 3.25 + gap;
    // E
    p
      ..moveTo(x + 2.5, 0)
      ..lineTo(x, 0)
      ..lineTo(x, h)
      ..lineTo(x + 2.5, h)
      ..moveTo(x, mid)
      ..lineTo(x + 2.15, mid);
    x += 2.5 + gap;
    // N
    p
      ..moveTo(x, h)
      ..lineTo(x, 0)
      ..lineTo(x + 3.1, h)
      ..lineTo(x + 3.1, 0);
    x += 3.1 + gap;
    // T
    p
      ..moveTo(x, 0)
      ..lineTo(x + 3.1, 0)
      ..moveTo(x + 1.55, 0)
      ..lineTo(x + 1.55, h);
    x += 3.1 + gap;
    // R
    p
      ..moveTo(x, h)
      ..lineTo(x, 0)
      ..lineTo(x + 1.5, 0)
      ..cubicTo(x + 3.45, 0, x + 3.45, 2.5, x + 1.5, 2.5)
      ..lineTo(x, 2.5)
      ..moveTo(x + 1.5, 2.5)
      ..lineTo(x + 2.95, h);
    x += 2.95 + gap;
    // A
    p
      ..moveTo(x, h)
      ..lineTo(x + 1.7, 0)
      ..lineTo(x + 3.4, h)
      ..moveTo(x + 0.62, 2.95)
      ..lineTo(x + 2.78, 2.95);
    return p;
  }
}
