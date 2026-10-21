import 'dart:math' as math;

import '../geometry/mesh.dart';

/// Orbit camera around [target]: [yaw] turns the model left/right,
/// [pitch] tilts it (positive looks from above), [distance] is in mm.
class CameraPose {
  const CameraPose({
    required this.yaw,
    required this.pitch,
    required this.distance,
    required this.target,
  });

  final double yaw;
  final double pitch;
  final double distance;
  final Vec3 target;

  static const double maxPitch = math.pi / 2;

  CameraPose copyWith({
    double? yaw,
    double? pitch,
    double? distance,
    Vec3? target,
  }) =>
      CameraPose(
        yaw: yaw ?? this.yaw,
        pitch: (pitch ?? this.pitch).clamp(-maxPitch, maxPitch),
        distance: distance ?? this.distance,
        target: target ?? this.target,
      );

  /// Moves a fraction [t] toward [goal], turning the short way round.
  CameraPose approach(CameraPose goal, double t) => CameraPose(
        yaw: yaw + wrapAngle(goal.yaw - yaw) * t,
        pitch: pitch + (goal.pitch - pitch) * t,
        distance: distance + (goal.distance - distance) * t,
        target: Vec3.lerp(target, goal.target, t),
      );

  bool closeTo(CameraPose o) =>
      wrapAngle(o.yaw - yaw).abs() < 1e-3 &&
      (o.pitch - pitch).abs() < 1e-3 &&
      (o.distance - distance).abs() < 0.05 &&
      (o.target - target).length < 0.02;

  /// Rotation from world to view space, row-major 3×3.
  List<double> get rotation {
    final cy = math.cos(yaw), sy = math.sin(yaw);
    final cp = math.cos(pitch), sp = math.sin(pitch);
    return [
      cy, 0, sy, //
      sp * sy, cp, -sp * cy,
      -cp * sy, sp, cp * cy,
    ];
  }

  /// World-space direction of the screen's x (right) and y (up) axes.
  (Vec3, Vec3) get screenAxes {
    final r = rotation;
    return (Vec3(r[0], r[1], r[2]), Vec3(r[3], r[4], r[5]));
  }
}

double wrapAngle(double a) {
  const tau = 2 * math.pi;
  a %= tau;
  if (a > math.pi) a -= tau;
  if (a < -math.pi) a += tau;
  return a;
}
