import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../dental_explorer/data/tooth_catalog.dart';
import '../../dental_explorer/geometry/dentition_builder.dart';
import '../../dental_explorer/geometry/mesh.dart';
import '../../dental_explorer/geometry/tooth_geometry.dart';
import '../../dental_explorer/rendering/dentition_renderer.dart';
import '../../dental_explorer/rendering/orbit_camera.dart';
import '../data/scan_regions.dart';

DentitionModel _buildScanModel(Object? _) => buildDentition(MeshDetail.low);

/// The 3D model behind the view guides and the scan animation. Built once
/// in the background. The light mesh is plenty at these sizes and leaves
/// headroom for the scan effects.
final scanDentitionProvider = FutureProvider<DentitionModel>(
  (ref) => compute(_buildScanModel, null),
);

/// One shared renderer per model for still images. Painting is
/// synchronous, so its buffers are never used by two paints at once.
final _stillRenderers = Expando<DentitionRenderer>();

DentitionRenderer stillRendererFor(DentitionModel model) =>
    _stillRenderers[model] ??= DentitionRenderer(model);

bool _isTooth(int owner) => owner < 32;

/// Owners a region's view shows: its arches' teeth and gums.
bool regionShowsOwner(ScanRegion region, int owner) {
  if (_isTooth(owner)) {
    return region.view.shows(ToothCatalog.byIndex(owner).arch);
  }
  return region.view
      .shows(owner == kUpperGumOwner ? ToothArch.upper : ToothArch.lower);
}

/// Owners a region's view is framed on: the teeth it covers.
bool regionFramesOwner(ScanRegion region, int owner) =>
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
  return CameraPose(yaw: yaw, pitch: pitch, distance: distance, target: target);
}

/// The fitted guide camera for [region] in [size].
CameraPose regionPose(DentitionModel model, ScanRegion region, Size size,
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

final _poseCache = <String, CameraPose>{};

/// [regionPose], remembered per view and size: fitting walks the whole mesh.
CameraPose cachedRegionPose(
  DentitionModel model,
  ScanRegion region,
  Size size, {
  double fill = 0.84,
}) =>
    _poseCache.putIfAbsent(
      '${region.id}|$fill|${size.width.round()}x${size.height.round()}',
      () => regionPose(model, region, size, fill: fill),
    );

/// Screen position of world point [p] seen from [pose], or null when it's
/// behind the camera. Same projection as `DentitionRenderer.paint`.
Offset? projectPoint(CameraPose pose, Size size, Vec3 p) {
  final r = pose.rotation;
  final px = p.x - pose.target.x,
      py = p.y - pose.target.y,
      pz = p.z - pose.target.z;
  final d = pose.distance - (r[6] * px + r[7] * py + r[8] * pz);
  if (d < 4) return null;
  final f = DentitionRenderer.focalLength(size) / d;
  return Offset(
    size.width / 2 + (r[0] * px + r[1] * py + r[2] * pz) * f,
    size.height / 2 - (r[3] * px + r[4] * py + r[5] * pz) * f,
  );
}

/// Writes [region]'s guide into [style]: the teeth to photograph take the
/// button color, the rest fade back so they don't compete.
void styleRegion(SceneStyle style, ScanRegion region) {
  style
    ..hideRoots = true
    ..rootReveal = 0;
  // The middle of the button gradient. Lifted below, as shading darkens it.
  const teal = AppColors.cardSolid;
  for (var o = 0; o < kOwnerCount; o++) {
    style
      ..glow[o] = 0
      ..desaturate[o] = 0
      ..brightness[o] = 1
      ..tint[o] = 0;
    if (!regionShowsOwner(region, o)) {
      style.alpha[o] = 0;
    } else if (!_isTooth(o)) {
      style.alpha[o] = 0.3; // gums
    } else {
      if (region.covers(ToothCatalog.byIndex(o))) {
        style
          ..alpha[o] = 1
          ..brightness[o] = 1.15
          ..glow[o] = 0.2;
        _tint(style, o, (teal.r, teal.g, teal.b), 0.94);
      } else {
        style
          ..alpha[o] = 0.35
          ..desaturate[o] = 0.6
          ..brightness[o] = 0.97;
      }
    }
  }
}

/// Writes [region]'s view into [style] with nothing singled out: every tooth
/// it shows is plain white.
void styleRegionPlain(SceneStyle style, ScanRegion region) {
  styleRegion(style, region);
  for (var o = 0; o < kOwnerCount; o++) {
    if (!_isTooth(o) || !regionShowsOwner(region, o)) continue;
    style
      ..alpha[o] = 1
      ..tint[o] = 0
      ..glow[o] = 0
      ..desaturate[o] = 1
      ..brightness[o] = 1.08
      ..lift[o] = 0.72;
  }
}

void _tint(SceneStyle s, int owner, (double, double, double) rgb, double k) {
  s
    ..tintR[owner] = rgb.$1
    ..tintG[owner] = rgb.$2
    ..tintB[owner] = rgb.$3
    ..tint[owner] = k;
}
