import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../dental_explorer/data/tooth_catalog.dart';
import '../../dental_explorer/geometry/dentition_builder.dart';
import '../../dental_explorer/geometry/mesh.dart';
import '../../dental_explorer/geometry/tooth_geometry.dart';
import '../../dental_explorer/rendering/dentition_renderer.dart';
import '../../dental_explorer/rendering/orbit_camera.dart';
import '../data/capture_regions.dart';

DentitionModel _buildScanModel(Object? _) => buildDentition(MeshDetail.low);

/// The 3D model behind the region guides, sample photos, scan animation
/// and results map. Built once in the background. The light mesh is
/// plenty at these sizes and leaves headroom for the scan effects.
final scanDentitionProvider = FutureProvider<DentitionModel>(
  (ref) => compute(_buildScanModel, null),
);

/// One shared renderer per model for still images. Painting is
/// synchronous, so its buffers are never used by two paints at once.
final _stillRenderers = Expando<DentitionRenderer>();

DentitionRenderer stillRendererFor(DentitionModel model) =>
    _stillRenderers[model] ??= DentitionRenderer(model);

/// How a region's 3D view is drawn.
enum SceneLook {
  /// Guide: the teeth to photograph glow teal, the rest stay pale.
  guide,

  /// Sample "photo": enamel and pink gums, like an intraoral photo.
  photo,

  /// Translucent outline laid over the user's own photo.
  overlay,
}

bool _isTooth(int owner) => owner < 32;

/// Owners a region's view shows: its arches' teeth and gums.
bool regionShowsOwner(CaptureRegion region, int owner) {
  if (_isTooth(owner)) {
    return region.arches.shows(ToothCatalog.byIndex(owner).arch);
  }
  return region.arches
      .shows(owner == kUpperGumOwner ? ToothArch.upper : ToothArch.lower);
}

/// Owners a region's view is framed on: the teeth it covers.
bool regionFramesOwner(CaptureRegion region, int owner) =>
    _isTooth(owner) && region.covers(ToothCatalog.byIndex(owner));

/// A camera at [yaw]/[pitch] that centers and fits the crowns of the
/// [include]d owners in [size], filling [fill] of the shorter side.
CameraPose fitPose(
  DentitionModel model, {
  required double yaw,
  required double pitch,
  required Size size,
  required bool Function(int owner) include,
  double fill = 0.84,
}) {
  final mesh = model.mesh;
  final pos = mesh.positions, owner = mesh.owner, flags = mesh.flags;
  bool used(int v) => flags[v] & kFlagRoot == 0 && include(owner[v]);

  var sx = 0.0, sy = 0.0, sz = 0.0;
  var n = 0;
  for (var v = 0; v < mesh.vertexCount; v++) {
    if (!used(v)) continue;
    sx += pos[v * 3];
    sy += pos[v * 3 + 1];
    sz += pos[v * 3 + 2];
    n++;
  }
  if (n == 0 || size.isEmpty) {
    return CameraPose(
        yaw: yaw, pitch: pitch, distance: 160, target: model.center);
  }

  var target = Vec3(sx / n, sy / n, sz / n);
  var distance = model.radius / math.sin(DentitionRenderer.fov / 2);
  final tanHalf = math.tan(DentitionRenderer.fov / 2);
  final shortest = math.min(size.width, size.height);
  // Screen offsets are x/d and y/d; these are the largest that still fit.
  final limitX = fill * size.width / shortest * tanHalf;
  final limitY = fill * size.height / shortest * tanHalf;

  // Recenter and rescale a few times: perspective shifts the outline a
  // little each time the camera moves.
  for (var pass = 0; pass < 4; pass++) {
    final pose =
        CameraPose(yaw: yaw, pitch: pitch, distance: distance, target: target);
    final r = pose.rotation;
    var minX = double.infinity, maxX = double.negativeInfinity;
    var minY = double.infinity, maxY = double.negativeInfinity;
    for (var v = 0; v < mesh.vertexCount; v++) {
      if (!used(v)) continue;
      final i = v * 3;
      final px = pos[i] - target.x,
          py = pos[i + 1] - target.y,
          pz = pos[i + 2] - target.z;
      final d = distance - (r[6] * px + r[7] * py + r[8] * pz);
      if (d <= 1) continue;
      final x = (r[0] * px + r[1] * py + r[2] * pz) / d;
      final y = (r[3] * px + r[4] * py + r[5] * pz) / d;
      minX = math.min(minX, x);
      maxX = math.max(maxX, x);
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
    }
    if (minX > maxX) break;
    final (right, up) = pose.screenAxes;
    target = target +
        right * ((minX + maxX) / 2 * distance) +
        up * ((minY + maxY) / 2 * distance);
    final need =
        math.max((maxX - minX) / 2 / limitX, (maxY - minY) / 2 / limitY);
    distance = math.max(distance * need, 12);
  }
  return CameraPose(
      yaw: yaw, pitch: pitch, distance: distance, target: target);
}

/// The fitted guide camera for [region] in [size].
CameraPose regionPose(DentitionModel model, CaptureRegion region, Size size,
    {double fill = 0.84}) {
  final pose = fitPose(
    model,
    yaw: region.yaw,
    pitch: region.pitch,
    size: size,
    include: (o) => regionFramesOwner(region, o),
    fill: fill,
  );
  return region.zoom == 1
      ? pose
      : pose.copyWith(distance: pose.distance * region.zoom);
}

// Enamel and gum tones for sample photos, in linear 0–1 RGB. The gums
// sit between the palette's peach and coral, tinted strongly enough to
// cover the model's teal glass gums.
const _ivory = (1.0, 0.96, 0.88);
const _gumPeach = (0.95, 0.72, 0.64);

/// Writes [region]'s [look] into [style].
void styleRegion(SceneStyle style, CaptureRegion region, SceneLook look) {
  style
    ..hideRoots = true
    ..rootReveal = 0;
  const teal = AppColors.g1;
  for (var o = 0; o < kOwnerCount; o++) {
    final shown = regionShowsOwner(region, o);
    style
      ..glow[o] = 0
      ..desaturate[o] = 0
      ..brightness[o] = 1
      ..tint[o] = 0;
    if (!shown) {
      style.alpha[o] = 0;
      continue;
    }
    if (!_isTooth(o)) {
      // Gums.
      switch (look) {
        case SceneLook.guide:
          style.alpha[o] = 0.4;
        case SceneLook.photo:
          style.alpha[o] = 1;
          _tint(style, o, _gumPeach, 0.92);
        case SceneLook.overlay:
          style.alpha[o] = 0;
      }
      continue;
    }
    final target = region.covers(ToothCatalog.byIndex(o));
    switch (look) {
      case SceneLook.guide:
        style.alpha[o] = 1;
        if (target) {
          _tint(style, o, (teal.r, teal.g, teal.b), 0.5);
          style.glow[o] = 0.55;
        } else {
          style
            ..desaturate[o] = 0.6
            ..brightness[o] = 0.97;
        }
      case SceneLook.photo:
        style.alpha[o] = 1;
        _tint(style, o, _ivory, 0.35);
      case SceneLook.overlay:
        style.alpha[o] = target ? 0.5 : 0.2;
        _tint(style, o, (teal.r, teal.g, teal.b), 0.85);
        style.glow[o] = 1;
    }
  }
}

void _tint(SceneStyle s, int owner, (double, double, double) rgb, double k) {
  s
    ..tintR[owner] = rgb.$1
    ..tintG[owner] = rgb.$2
    ..tintB[owner] = rgb.$3
    ..tint[owner] = k;
}

// ── Sample photos ─────────────────────────────────────────────────

final _sampleCache = <String, Uint8List>{};

/// Placeholder photos for [regions]: renders of the 3D model from each
/// view, lit like an intraoral photo and marked "SAMPLE". PNG bytes by
/// region id, cached for the app run.
Future<Map<String, Uint8List>> renderSamplePhotos(
  DentitionModel model,
  Iterable<CaptureRegion> regions,
) async {
  final renderer = stillRendererFor(model);
  return {
    for (final r in regions)
      r.id: _sampleCache[r.id] ??= await _renderSample(renderer, r),
  };
}

Future<Uint8List> _renderSample(
    DentitionRenderer renderer, CaptureRegion region) async {
  const size = Size(720, 540);
  final rect = Offset.zero & size;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, rect);

  // A light studio backdrop in the brand mint.
  canvas.drawRect(
    rect,
    Paint()
      ..shader = const RadialGradient(
        radius: 0.9,
        colors: [AppColors.white, AppColors.lightLavender, Color(0xFFCDEDE9)],
        stops: [0, 0.6, 1],
      ).createShader(rect),
  );

  final style = SceneStyle();
  styleRegion(style, region, SceneLook.photo);
  renderer.paint(canvas, size,
      regionPose(renderer.model, region, size, fill: 0.9), style);

  _paintSampleTag(canvas);

  final picture = recorder.endRecording();
  final image =
      await picture.toImage(size.width.toInt(), size.height.toInt());
  picture.dispose();
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

/// Marks samples so they are never mistaken for real photos.
void _paintSampleTag(Canvas canvas) {
  final tp = TextPainter(
    text: TextSpan(
      text: 'SAMPLE',
      style: GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: 3,
        color: AppColors.g2,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final box = RRect.fromRectAndRadius(
    Rect.fromLTWH(22, 22, tp.width + 28, tp.height + 12),
    const Radius.circular(8),
  );
  canvas.drawRRect(box, Paint()..color = const Color(0xD9FFFFFF));
  canvas.drawRRect(
    box,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = AppColors.lavender,
  );
  tp.paint(canvas, const Offset(36, 28));
}
