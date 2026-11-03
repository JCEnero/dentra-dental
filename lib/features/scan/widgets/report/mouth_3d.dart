import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../dental_explorer/data/tooth_catalog.dart';
import '../../../dental_explorer/geometry/dentition_builder.dart';
import '../../../dental_explorer/rendering/dentition_renderer.dart';
import '../../../dental_explorer/rendering/orbit_camera.dart';
import '../../data/scan_outcomes.dart';
import '../../data/scan_report.dart';
import '../../rendering/scan_scene.dart';
import '../scan_motion.dart';
import '../visuals/dental_arch_painter.dart';
import 'report_motion.dart';
import 'report_style.dart';

/// The flat map's look for one area, wherever the map is drawn: until the 3D
/// model is ready, and on Home.
MouthMapStyle mouthMapStyle(AreaState state, {bool selected = false}) =>
    switch (state) {
      AreaState.strong ||
      AreaState.possible ||
      AreaState.faint =>
        MouthMapStyle(
          fill: ReportColors.of(state),
          outline: AppColors.white,
          selected: selected,
        ),
      AreaState.clear => MouthMapStyle(
          fill: ReportColors.clear,
          outline: AppColors.g2.withValues(alpha: 0.5),
          selected: selected,
        ),
      _ => MouthMapStyle(
          fill: ReportColors.hollow,
          outline: ReportColors.hollowEdge,
          selected: selected,
        ),
    };

/// A real 3D mouth with the flagged areas in teal. It's a general model, not
/// this person's teeth, which is why it colours areas and never single teeth.
/// It sways gently and turns under a finger. Given a [focus], it flies to the
/// view that sign's photo was taken from. Only runs while on screen; still
/// under reduced motion.
class Mouth3D extends ConsumerStatefulWidget {
  const Mouth3D({
    super.key,
    required this.report,
    required this.focus,
    this.onAreaTap,
  });

  final ScreeningReport report;

  /// The sign to show, or null for the whole mouth.
  final ValueListenable<ReportSpot?> focus;

  /// Hears which area a tap landed on.
  final ValueChanged<MouthArea>? onAreaTap;

  @override
  ConsumerState<Mouth3D> createState() => _Mouth3DState();
}

class _Mouth3DState extends ConsumerState<Mouth3D>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  final _motion = _MouthMotion();
  Duration _last = Duration.zero;
  bool _reduced = false;
  ScrollPosition? _position;

  @override
  void initState() {
    super.initState();
    widget.focus.addListener(_onFocus);
    _motion.report = widget.report;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = ScanMotion.reduced(context);
    _motion.still = _reduced;
    final next = Scrollable.maybeOf(context)?.position;
    if (next != _position) {
      _position?.removeListener(_syncTicker);
      _position = next?..addListener(_syncTicker);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncTicker());
  }

  @override
  void didUpdateWidget(Mouth3D old) {
    super.didUpdateWidget(old);
    _motion.report = widget.report;
    if (old.focus != widget.focus) {
      old.focus.removeListener(_onFocus);
      widget.focus.addListener(_onFocus);
    }
  }

  void _onFocus() => _motion.setFocus(widget.focus.value);

  /// The model is the heaviest thing on the page, so it rests off screen.
  void _syncTicker() {
    if (!mounted) return;
    final run = !_reduced && isOnScreen(context);
    if (run && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _motion.advance(math.min(dt, 0.05));
  }

  void _onTapUp(TapUpDetails d) {
    final owner = _motion.renderer?.hitTest(d.localPosition);
    if (owner == null) return;
    widget.onAreaTap?.call(MouthArea.of(ToothCatalog.byIndex(owner)));
  }

  @override
  void dispose() {
    widget.focus.removeListener(_onFocus);
    _position?.removeListener(_syncTicker);
    _ticker.dispose();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = ref.watch(scanDentitionProvider).valueOrNull;
    final report = widget.report;
    return AnimatedSwitcher(
      duration: ScanMotion.of(context, ScanMotion.slow),
      child: model == null
          // The flat map stands in while the model builds, or if it can't.
          ? Center(
              key: const ValueKey('flat'),
              child: AspectRatio(
                aspectRatio: kMouthMapCanvas.aspectRatio,
                child: CustomPaint(
                  painter: MouthMapPainter({
                    for (final a in MouthArea.values)
                      a: mouthMapStyle(report.areas[a]!.state),
                  }),
                ),
              ),
            )
          : GestureDetector(
              key: const ValueKey('model'),
              behavior: HitTestBehavior.opaque,
              onTapUp: _onTapUp,
              onHorizontalDragUpdate: (d) => _motion.drag(d.delta.dx),
              onHorizontalDragEnd: (_) => _motion.release(),
              child: RepaintBoundary(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _MouthPainter(model, _motion),
                ),
              ),
            ),
    );
  }
}

/// Where the camera and every tooth are headed, and how far along they are.
/// Everything eases toward its target each frame, so a new focus mid-flight
/// just changes course.
class _MouthMotion extends ChangeNotifier {
  late ScreeningReport report;
  bool still = false;
  ReportSpot? focus;
  DentitionRenderer? renderer;

  final style = SceneStyle()
    ..hideRoots = true
    ..rootReveal = 0;
  final _targetAlpha = List<double>.filled(kOwnerCount, 1);
  final _targetTint = List<double>.filled(kOwnerCount, 0);
  final _targetGlow = List<double>.filled(kOwnerCount, 0);
  final _targetLift = List<double>.filled(kOwnerCount, 0.72);

  CameraPose? _pose;
  double _time = 0;
  double _dragYaw = 0;
  double _sinceTouch = 99;
  bool _styled = false;

  // How long after a finger lifts before the model drifts back.
  static const _settleAfter = 3.5;

  void setFocus(ReportSpot? next) {
    focus = next;
    _dragYaw = 0;
    _styled = false;
    notifyListeners();
  }

  void drag(double dx) {
    _dragYaw += dx * 0.012;
    _sinceTouch = 0;
    notifyListeners();
  }

  void release() => _sinceTouch = 0;

  void advance(double dt) {
    _time += dt;
    _sinceTouch += dt;
    if (_sinceTouch > _settleAfter) {
      _dragYaw *= math.exp(-dt * 1.4);
    }
    notifyListeners();
  }

  void _target() {
    final spot = focus;
    final areas = report.areas;
    for (final tooth in ToothCatalog.all) {
      final i = tooth.index;
      final area = MouthArea.of(tooth);
      final state = areas[area]!.state;
      final shown = spot == null || regionShowsOwner(spot.photo, i);
      final AreaState paint;
      if (spot != null) {
        paint = spot.areas.contains(area) && spot.photo.covers(tooth)
            ? AreaState.of(spot.strength)
            : AreaState.clear;
      } else {
        paint = state;
      }
      _targetAlpha[i] = !shown ? 0 : (state.read ? 1 : 0.5);
      final flagged = paint.flagged;
      final color = switch (paint) {
        AreaState.strong => ReportColors.possible,
        AreaState.possible => ReportColors.faint,
        _ => AppColors.g1,
      };
      if (flagged) {
        style
          ..tintR[i] = color.r
          ..tintG[i] = color.g
          ..tintB[i] = color.b;
      }
      _targetTint[i] = flagged ? (paint == AreaState.faint ? 0.72 : 0.94) : 0;
      _targetGlow[i] = flagged ? 0.16 : 0;
      _targetLift[i] = flagged ? 0.3 : 0.72;
    }
    for (final o in const [kUpperGumOwner, kLowerGumOwner]) {
      final shown = spot == null || regionShowsOwner(spot.photo, o);
      _targetAlpha[o] = shown ? 0.24 : 0;
      _targetLift[o] = 0;
    }
    _styled = true;
  }

  /// The overview turns toward whichever side has more flagged areas.
  double get _overviewYaw {
    var lean = 0;
    report.areas.forEach((area, a) {
      if (a.state.flagged && !area.isFront) lean += area.isLeft ? -1 : 1;
    });
    return lean < 0 ? -0.5 : (lean > 0 ? 0.5 : 0.28);
  }

  CameraPose _goal(DentitionModel model, Size size) {
    final spot = focus;
    if (spot != null) {
      return cachedRegionPose(model, spot.photo, size, fill: 0.74);
    }
    return fitPose(
      model,
      yaw: 0,
      pitch: 0.14,
      size: size,
      include: (o) => o < 32,
      fill: 0.72,
    ).copyWith(yaw: _overviewYaw);
  }

  final _goalCache = <String, CameraPose>{};

  void paint(Canvas canvas, Size size, DentitionModel model) {
    renderer ??= DentitionRenderer(model);
    if (!_styled) _target();
    final key =
        '${focus?.photoId}|${size.width.round()}x${size.height.round()}';
    final goal = _goalCache.putIfAbsent(key, () => _goal(model, size));
    final firstFrame = _pose == null;
    // Eased here so it stays in step with the frames actually drawn.
    final rate = firstFrame || still ? 1.0 : 1 - math.exp(-0.05 * 4.2);
    _pose = (_pose ?? goal).approach(goal, rate);
    final styleRate = firstFrame || still ? 1.0 : 1 - math.exp(-0.05 * 6);
    final pulse = still ? 0.0 : 0.5 + 0.5 * math.sin(_time * 2);
    for (var o = 0; o < kOwnerCount; o++) {
      style
        ..alpha[o] += (_targetAlpha[o] - style.alpha[o]) * styleRate
        ..tint[o] += (_targetTint[o] - style.tint[o]) * styleRate
        ..lift[o] += (_targetLift[o] - style.lift[o]) * styleRate
        ..desaturate[o] = o < 32 ? 1 - (style.tint[o] > 0.05 ? 1 : 0) : 0
        ..brightness[o] = o < 32 ? 1.08 : 1
        ..glow[o] = _targetGlow[o] * (0.6 + 0.8 * pulse);
    }
    final sway = still ? 0.0 : 0.14 * math.sin(_time * 0.5);
    final stage = Offset.zero & size;
    // A close view runs past the stage, so its edges fade instead of cutting off.
    canvas.saveLayer(stage, Paint());
    renderer!.paint(
      canvas,
      size,
      _pose!.copyWith(yaw: _pose!.yaw + _dragYaw + sway),
      style,
    );
    for (final (from, to) in const [
      (Alignment.centerLeft, Alignment.centerRight),
      (Alignment.topCenter, Alignment.bottomCenter),
    ]) {
      canvas.drawRect(
        stage,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = LinearGradient(
            begin: from,
            end: to,
            colors: const [
              Color(0x00FFFFFF),
              Color(0xFFFFFFFF),
              Color(0xFFFFFFFF),
              Color(0x00FFFFFF),
            ],
            stops: const [0, 0.1, 0.9, 1],
          ).createShader(stage),
      );
    }
    canvas.restore();
  }
}

class _MouthPainter extends CustomPainter {
  _MouthPainter(this.model, this.motion) : super(repaint: motion);

  final DentitionModel model;
  final _MouthMotion motion;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    motion.paint(canvas, size, model);
  }

  @override
  bool shouldRepaint(_MouthPainter old) =>
      old.model != model || old.motion != motion;
}

/// A small still of the mouth from the view a sign's photo was taken from, with
/// its area lit: where in the mouth this photo is.
class SpotLocator extends ConsumerWidget {
  const SpotLocator({super.key, required this.spot});

  final ReportSpot spot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(scanDentitionProvider).valueOrNull;
    if (model == null) return const SizedBox.shrink();
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _LocatorPainter(model, spot),
      ),
    );
  }
}

class _LocatorPainter extends CustomPainter {
  _LocatorPainter(this.model, this.spot);

  final DentitionModel model;
  final ReportSpot spot;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final region = spot.photo;
    final style = SceneStyle();
    styleRegionPlain(style, region);
    for (final tooth in ToothCatalog.all) {
      if (!spot.areas.contains(MouthArea.of(tooth)) || !region.covers(tooth)) {
        continue;
      }
      final i = tooth.index;
      style
        ..tintR[i] = ReportColors.possible.r
        ..tintG[i] = ReportColors.possible.g
        ..tintB[i] = ReportColors.possible.b
        ..tint[i] = 0.94
        ..desaturate[i] = 0
        ..lift[i] = 0.3;
    }
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    stillRendererFor(model).paint(
      canvas,
      size,
      cachedRegionPose(model, region, size, fill: 0.86),
      style,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LocatorPainter old) =>
      old.model != model || !identical(old.spot.finding, spot.finding);
}
