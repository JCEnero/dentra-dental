import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../dental_explorer/data/tooth_catalog.dart';
import '../../../dental_explorer/geometry/dentition_builder.dart';
import '../../../dental_explorer/rendering/dentition_renderer.dart';
import '../../../dental_explorer/rendering/orbit_camera.dart';
import '../../data/scan_regions.dart';
import '../../rendering/scan_scene.dart';
import '../scan_motion.dart';

/// The live 3D guide: what the phone should see for [region]. The camera
/// flies to each new view, so moving on reads as moving around the mouth,
/// and the target teeth pulse gently outward from the midline. Still under
/// reduced motion.
class GuideStage extends ConsumerStatefulWidget {
  const GuideStage({super.key, required this.region});

  final ScanRegion region;

  @override
  ConsumerState<GuideStage> createState() => _GuideStageState();
}

class _GuideStageState extends ConsumerState<GuideStage>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  late final _GuideMotion _motion = _GuideMotion(widget.region);
  Duration _last = Duration.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motion.still = ScanMotion.reduced(context);
    if (_motion.still) {
      if (_ticker.isActive) _ticker.stop();
    } else if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  @override
  void didUpdateWidget(GuideStage old) {
    super.didUpdateWidget(old);
    if (old.region.id != widget.region.id) _motion.retarget(widget.region);
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _motion.advance(math.min(dt, 0.05));
  }

  @override
  void dispose() {
    _ticker.dispose();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = ref.watch(scanDentitionProvider).valueOrNull;
    if (model == null) {
      return const Center(
        child: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: AppColors.lavender,
          ),
        ),
      );
    }
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _GuideStagePainter(model: model, motion: _motion),
      ),
    );
  }
}

/// Where the guide camera is headed and how far along it is.
class _GuideMotion extends ChangeNotifier {
  _GuideMotion(this.region) {
    styleRegion(_to, region);
    _copy(_to, _shown);
  }

  ScanRegion region;
  bool still = false;

  static const _flightSeconds = 0.85;

  final SceneStyle _from = SceneStyle();
  final SceneStyle _to = SceneStyle();
  final SceneStyle _shown = SceneStyle()..hideRoots = true;
  CameraPose? _fromPose;
  CameraPose? lastPose;
  double flight = 1;
  double time = 0;

  void retarget(ScanRegion next) {
    _copy(_shown, _from);
    _fromPose = lastPose;
    region = next;
    styleRegion(_to, region);
    flight = still ? 1 : 0;
    notifyListeners();
  }

  void advance(double dt) {
    time += dt;
    if (flight < 1) flight = math.min(1, flight + dt / _flightSeconds);
    notifyListeners();
  }

  /// The camera this frame: flying to [goal], pulling back a little on the
  /// way, then swaying just enough to read as 3D.
  CameraPose poseFor(CameraPose goal) {
    final e = Curves.easeInOutCubic.transform(flight);
    final from = _fromPose;
    final base = from == null || flight >= 1 ? goal : from.approach(goal, e);
    lastPose = base;
    if (still) return base;
    final pullBack = 1 + 0.22 * math.sin(math.pi * e);
    return base.copyWith(
      distance: base.distance * pullBack,
      yaw: base.yaw + 0.08 * math.sin(time * 0.7),
      pitch: base.pitch + 0.03 * math.sin(time * 0.53),
    );
  }

  SceneStyle styleForFrame() {
    final e = Curves.easeInOut.transform(flight);
    final s = _shown;
    for (var o = 0; o < kOwnerCount; o++) {
      double mix(double a, double b) => a + (b - a) * e;
      s.alpha[o] = mix(_from.alpha[o], _to.alpha[o]);
      s.glow[o] = mix(_from.glow[o], _to.glow[o]);
      s.desaturate[o] = mix(_from.desaturate[o], _to.desaturate[o]);
      s.brightness[o] = mix(_from.brightness[o], _to.brightness[o]);
      s.tint[o] = mix(_from.tint[o], _to.tint[o]);
      // A surface with no tint yet takes the other side's colour, so
      // fading a tint in or out doesn't pass through black.
      s.tintR[o] = mix(_from.tint[o] > 0 ? _from.tintR[o] : _to.tintR[o],
          _to.tint[o] > 0 ? _to.tintR[o] : _from.tintR[o]);
      s.tintG[o] = mix(_from.tint[o] > 0 ? _from.tintG[o] : _to.tintG[o],
          _to.tint[o] > 0 ? _to.tintG[o] : _from.tintG[o]);
      s.tintB[o] = mix(_from.tint[o] > 0 ? _from.tintB[o] : _to.tintB[o],
          _to.tint[o] > 0 ? _to.tintB[o] : _from.tintB[o]);
    }
    if (!still) {
      for (final tooth in ToothCatalog.all) {
        if (!region.covers(tooth)) continue;
        final wave = 0.5 + 0.5 * math.sin(time * 2.2 - tooth.position * 0.7);
        s.glow[tooth.index] =
            (s.glow[tooth.index] + 0.3 * wave * e).clamp(0.0, 1.0);
      }
    }
    return s;
  }

  static void _copy(SceneStyle a, SceneStyle b) {
    b
      ..hideRoots = true
      ..rootReveal = 0;
    b.alpha.setAll(0, a.alpha);
    b.glow.setAll(0, a.glow);
    b.desaturate.setAll(0, a.desaturate);
    b.brightness.setAll(0, a.brightness);
    b.tint.setAll(0, a.tint);
    b.tintR.setAll(0, a.tintR);
    b.tintG.setAll(0, a.tintG);
    b.tintB.setAll(0, a.tintB);
  }
}

class _GuideStagePainter extends CustomPainter {
  _GuideStagePainter({required this.model, required this.motion})
      : super(repaint: motion);

  final DentitionModel model;
  final _GuideMotion motion;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final goal = cachedRegionPose(model, motion.region, size, fill: 0.66);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    stillRendererFor(model)
        .paint(canvas, size, motion.poseFor(goal), motion.styleForFrame());
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GuideStagePainter old) =>
      old.model != model || old.motion != motion;
}
