import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../dental_explorer/geometry/dentition_builder.dart';
import '../../../dental_explorer/rendering/dentition_renderer.dart';
import '../../data/scan_regions.dart';
import '../../rendering/scan_scene.dart';

/// A view's still 3D picture, for tiles: all its teeth plain white. Shows a
/// quiet spinner while the model is still building.
class RegionGuideView extends ConsumerWidget {
  const RegionGuideView({super.key, required this.region, this.fill = 0.84});

  final ScanRegion region;

  /// How much of the shorter side the target teeth fill.
  final double fill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(scanDentitionProvider).valueOrNull;
    if (model == null) {
      return const Center(
        child: SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.lavender,
          ),
        ),
      );
    }
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: RegionScenePainter(model: model, region: region, fill: fill),
      ),
    );
  }
}

/// Paints [region] from its guide camera. Poses and styles are cached, so a
/// repaint is just the render itself.
class RegionScenePainter extends CustomPainter {
  RegionScenePainter({
    required this.model,
    required this.region,
    this.fill = 0.84,
  });

  final DentitionModel model;
  final ScanRegion region;
  final double fill;

  static final _styles = <String, SceneStyle>{};

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final pose = cachedRegionPose(model, region, size, fill: fill);
    final style = _styles.putIfAbsent(region.id, () {
      final s = SceneStyle();
      styleRegionPlain(s, region);
      return s;
    });
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    stillRendererFor(model).paint(canvas, size, pose, style);
    canvas.restore();
  }

  @override
  bool shouldRepaint(RegionScenePainter old) =>
      old.model != model || old.region != region || old.fill != fill;
}
