import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../geometry/dentition_builder.dart';
import '../geometry/mesh.dart';
import '../rendering/orbit_camera.dart';
import 'explorer_controller.dart';

/// Preset viewing directions, named from the patient's point of view.
enum CameraView {
  front('Front', 0, 0.06),
  back('Back', math.pi, 0.06),
  right('Right', math.pi / 2, 0.06),
  left('Left', -math.pi / 2, 0.06),
  top('Top', 0, math.pi / 2),
  bottom('Bottom', 0, -math.pi / 2);

  const CameraView(this.label, this.yaw, this.pitch);
  final String label;
  final double yaw;
  final double pitch;
}

/// Animated orbit camera. Commands set a goal that the viewport eases
/// toward each frame; drags move the pose directly and may leave a
/// spin that decays (inertia).
class ExplorerCamera extends ChangeNotifier {
  DentitionModel? _model;
  CameraPose _pose =
      const CameraPose(yaw: 0, pitch: 0, distance: 1, target: Vec3.zero);
  CameraPose _goal =
      const CameraPose(yaw: 0, pitch: 0, distance: 1, target: Vec3.zero);
  double _spinYaw = 0, _spinPitch = 0;
  double _fit = 1;

  static const double _homeYaw = -0.34;
  static const double _homePitch = 0.2;

  /// Radians of rotation per pixel dragged.
  static const double dragSpeed = 0.009;

  CameraPose get pose => _pose;
  bool get isAttached => _model != null;

  /// True while the pose is still moving toward its goal or spinning.
  bool get isAnimating =>
      !_pose.closeTo(_goal) || _spinYaw.abs() > 0.02 || _spinPitch.abs() > 0.02;

  double get minDistance => _fit * 0.22;
  double get maxDistance => _fit * 1.8;

  /// Binds to a model and frames it. Keeps the current view if the model
  /// is only swapped for another detail level.
  void attach(DentitionModel model, double fitDistance) {
    final first = _model == null;
    _model = model;
    _fit = fitDistance;
    if (first) {
      _pose = _home;
      _goal = _pose;
    }
    notifyListeners();
  }

  CameraPose get _home => CameraPose(
        yaw: _homeYaw,
        pitch: _homePitch,
        distance: _fit,
        target: _framedTarget(_homeYaw, _homePitch, _fit),
      );

  /// Target that centers the on-screen outline of the crowns and gums
  /// for a view. Aiming at the crown centroid alone leaves angled views
  /// lopsided, because the arch is U-shaped and seen in perspective.
  Vec3 _framedTarget(double yaw, double pitch, double distance) {
    final model = _model;
    if (model == null) return Vec3.zero;
    final mesh = model.mesh;
    final pos = mesh.positions, flags = mesh.flags;
    var target = model.center;
    // A second pass corrects the small perspective change from the shift.
    for (var pass = 0; pass < 2; pass++) {
      final pose = CameraPose(
          yaw: yaw, pitch: pitch, distance: distance, target: target);
      final r = pose.rotation;
      var minX = double.infinity, maxX = double.negativeInfinity;
      var minY = double.infinity, maxY = double.negativeInfinity;
      for (var v = 0; v < mesh.vertexCount; v++) {
        if (flags[v] & kFlagRoot != 0) continue;
        final i = v * 3;
        final px = pos[i] - target.x,
            py = pos[i + 1] - target.y,
            pz = pos[i + 2] - target.z;
        final d = distance - (r[6] * px + r[7] * py + r[8] * pz);
        if (d <= 1e-3) continue;
        final sx = (r[0] * px + r[1] * py + r[2] * pz) / d;
        final sy = (r[3] * px + r[4] * py + r[5] * pz) / d;
        minX = math.min(minX, sx);
        maxX = math.max(maxX, sx);
        minY = math.min(minY, sy);
        maxY = math.max(maxY, sy);
      }
      if (minX > maxX) break;
      // Screen offsets are in units of distance, so scale back to mm.
      final (right, up) = pose.screenAxes;
      target = target +
          right * ((minX + maxX) / 2 * distance) +
          up * ((minY + maxY) / 2 * distance);
    }
    return target;
  }

  void _setGoal(CameraPose goal) {
    _spinYaw = _spinPitch = 0;
    _goal =
        goal.copyWith(distance: goal.distance.clamp(minDistance, maxDistance));
    notifyListeners();
  }

  // ── Commands ──────────────────────────────────────────────────

  void reset() => _setGoal(_home);

  void zoomBy(double factor) =>
      _setGoal(_goal.copyWith(distance: _goal.distance / factor));

  void showView(CameraView view) => _setGoal(CameraPose(
        yaw: view.yaw,
        pitch: view.pitch,
        distance: _fit,
        target: _framedTarget(view.yaw, view.pitch, _fit),
      ));

  /// Frames a quick-view region.
  void showRegion(ExplorerRegion region) {
    final model = _model;
    if (model == null) return;
    Vec3 centerOf(bool Function(int index) include) {
      var c = Vec3.zero;
      var n = 0;
      for (var i = 0; i < model.anchors.length; i++) {
        if (!include(i)) continue;
        c = c + model.anchors[i].crownCenter;
        n++;
      }
      return n == 0 ? model.center : c * (1 / n);
    }

    switch (region) {
      case ExplorerRegion.all:
        reset();
      case ExplorerRegion.upper:
        // From below, looking up at the chewing surfaces.
        _setGoal(CameraPose(
          yaw: 0,
          pitch: -1.0,
          distance: _fit * 0.82,
          target: centerOf((i) => i < 16),
        ));
      case ExplorerRegion.lower:
        _setGoal(CameraPose(
          yaw: 0,
          pitch: 1.0,
          distance: _fit * 0.82,
          target: centerOf((i) => i >= 16),
        ));
      case ExplorerRegion.front:
        _setGoal(CameraPose(
          yaw: 0,
          pitch: 0.12,
          distance: _fit * 0.6,
          target: centerOf((i) => i % 8 < 3),
        ));
      case ExplorerRegion.back:
        _setGoal(CameraPose(
          yaw: math.pi / 2 - 0.35,
          pitch: 0.28,
          distance: _fit * 0.72,
          target: centerOf((i) => i % 8 >= 3),
        ));
    }
  }

  /// Turns the tooth's outer face toward the viewer and moves in close.
  void focusTooth(int index) {
    final model = _model;
    if (model == null) return;
    final a = model.anchors[index];
    final upper = index < 16;
    _setGoal(CameraPose(
      yaw: math.atan2(-a.buccal.x, a.buccal.z),
      pitch: upper ? -0.22 : 0.32,
      distance: _fit * 0.58,
      target: a.crownCenter,
    ));
  }

  // ── Direct manipulation ───────────────────────────────────────

  void rotateBy(double dx, double dy) {
    _spinYaw = _spinPitch = 0;
    _pose = _pose.copyWith(
      yaw: _pose.yaw + dx * dragSpeed,
      pitch: _pose.pitch + dy * dragSpeed,
    );
    _goal = _pose;
    notifyListeners();
  }

  /// Pans by a screen delta; [focal] converts pixels to world units.
  void panBy(double dx, double dy, double focal) {
    _spinYaw = _spinPitch = 0;
    final (right, up) = _pose.screenAxes;
    final k = _pose.distance / focal;
    var target = _pose.target - right * (dx * k) + up * (dy * k);
    // Keep the model within reach.
    final model = _model;
    if (model != null) {
      final off = target - model.center;
      final limit = model.radius * 1.2;
      if (off.length > limit) target = model.center + off.normalized() * limit;
    }
    _pose = _pose.copyWith(target: target);
    _goal = _pose;
    notifyListeners();
  }

  void setDistance(double distance) {
    _pose = _pose.copyWith(distance: distance.clamp(minDistance, maxDistance));
    _goal = _pose;
    notifyListeners();
  }

  /// Starts a decaying spin after a drag, in pixels per second.
  void fling(double vx, double vy) {
    _spinYaw = vx * dragSpeed;
    _spinPitch = vy * dragSpeed;
    if (_spinYaw.abs() < 0.3 && _spinPitch.abs() < 0.3) {
      _spinYaw = _spinPitch = 0;
    }
    notifyListeners();
  }

  void stop() {
    _spinYaw = _spinPitch = 0;
    _goal = _pose;
  }

  /// Advances animations by [dt] seconds. Returns whether anything moved.
  bool tick(double dt, {required bool reduceMotion}) {
    if (_spinYaw != 0 || _spinPitch != 0) {
      if (reduceMotion) {
        _spinYaw = _spinPitch = 0;
      } else {
        _pose = _pose.copyWith(
          yaw: _pose.yaw + _spinYaw * dt,
          pitch: _pose.pitch + _spinPitch * dt,
        );
        _goal = _pose;
        final decay = math.exp(-dt * 4.5);
        _spinYaw *= decay;
        _spinPitch *= decay;
        if (_spinYaw.abs() < 0.02 && _spinPitch.abs() < 0.02) {
          _spinYaw = _spinPitch = 0;
        }
        return true;
      }
    }
    if (_pose.closeTo(_goal)) {
      if (_pose == _goal) return false;
      _pose = _goal;
      return true;
    }
    _pose = reduceMotion ? _goal : _pose.approach(_goal, 1 - math.exp(-dt * 8));
    return true;
  }
}
