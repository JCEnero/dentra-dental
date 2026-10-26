import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../dental_explorer/geometry/dentition_builder.dart';
import '../../../dental_explorer/rendering/dentition_renderer.dart';
import '../../../dental_explorer/rendering/orbit_camera.dart';
import '../../data/capture_regions.dart';
import '../../rendering/scan_scene.dart';

/// A region's 3D view: the guide (target teeth glowing teal on a mint
/// stage) or, with [SceneLook.overlay], a see-through outline to lay
/// over a photo. Shows a quiet spinner while the model is still building.
class RegionGuideView extends ConsumerWidget {
  const RegionGuideView({
    super.key,
    required this.region,
    this.look = SceneLook.guide,
    this.fill = 0.84,
  });

  final CaptureRegion region;
  final SceneLook look;

  /// How much of the shorter side the target teeth fill.
  final double fill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(scanDentitionProvider).valueOrNull;
    final scene = model == null
        ? const Center(
            child: SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.lavender,
              ),
            ),
          )
        : RepaintBoundary(
            child: CustomPaint(
              size: Size.infinite,
              painter: RegionScenePainter(
                model: model,
                region: region,
                look: look,
                fill: fill,
              ),
            ),
          );
    if (look == SceneLook.overlay) return scene;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.1),
          radius: 0.95,
          colors: [AppColors.white, AppColors.lightLavender, Color(0xFFD6F2EF)],
          stops: [0, 0.65, 1],
        ),
      ),
      child: CustomPaint(painter: const _DotGridPainter(), child: scene),
    );
  }
}

/// Paints [region] from its guide camera. Poses and styles are cached,
/// so a repaint is just the render itself.
class RegionScenePainter extends CustomPainter {
  RegionScenePainter({
    required this.model,
    required this.region,
    required this.look,
    this.fill = 0.84,
  });

  final DentitionModel model;
  final CaptureRegion region;
  final SceneLook look;
  final double fill;

  static final _poses = <String, CameraPose>{};
  static final _styles = <String, SceneStyle>{};

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final pose = _poses.putIfAbsent(
      '${region.id}|$fill|${size.width.round()}x${size.height.round()}',
      () => regionPose(model, region, size, fill: fill),
    );
    final style = _styles.putIfAbsent('${region.id}|${look.name}', () {
      final s = SceneStyle();
      styleRegion(s, region, look);
      return s;
    });
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    stillRendererFor(model).paint(canvas, size, pose, style);
    canvas.restore();
  }

  @override
  bool shouldRepaint(RegionScenePainter old) =>
      old.model != model ||
      old.region != region ||
      old.look != look ||
      old.fill != fill;
}

/// Faint scanner dot grid behind guides.
class _DotGridPainter extends CustomPainter {
  const _DotGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const step = 12.0;
    final paint = Paint()
      ..color = AppColors.g2.withValues(alpha: 0.14)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final points = <Offset>[
      for (var y = step / 2; y < size.height; y += step)
        for (var x = step / 2; x < size.width; x += step) Offset(x, y),
    ];
    canvas.drawPoints(PointMode.points, points, paint);
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => false;
}
