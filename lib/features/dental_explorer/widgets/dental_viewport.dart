import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../data/tooth_catalog.dart';
import '../geometry/dentition_builder.dart';
import '../rendering/dentition_renderer.dart';
import '../state/explorer_camera.dart';
import '../state/explorer_controller.dart';
import '../state/tooth_type_colors.dart';

/// The interactive 3D view: drag to rotate, pinch or scroll to zoom,
/// two-finger drag to pan, tap a tooth to select it.
class DentalViewport extends StatefulWidget {
  const DentalViewport({
    super.key,
    required this.assets,
    required this.controller,
    required this.camera,
    required this.onToothTap,
    this.onInteract,
    this.onRenderFailed,
  });

  final DentitionAssets assets;
  final ExplorerController controller;
  final ExplorerCamera camera;

  /// A tooth was tapped, or empty space (null).
  final ValueChanged<ToothInfo?> onToothTap;

  /// First drag, pinch or scroll, used to retire the gesture hint.
  final VoidCallback? onInteract;

  /// Drawing failed; the caller should fall back to a non-3D view.
  final ValueChanged<Object>? onRenderFailed;

  @override
  State<DentalViewport> createState() => _DentalViewportState();
}

class _DentalViewportState extends State<DentalViewport>
    with SingleTickerProviderStateMixin {
  late DentitionRenderer _renderer;
  late final Ticker _ticker;
  final _repaint = ValueNotifier<int>(0);
  final _style = SceneStyle();
  final _visuals = _OwnerVisuals();
  Duration _lastTick = Duration.zero;

  // Gesture bookkeeping.
  double _scaleStartDistance = 1;
  int _pointers = 0;

  // Adaptive detail: drop to the light mesh if frames run long.
  bool _lowDetail = false;
  double _frameCostMs = 0;
  int _measuredFrames = 0;

  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _renderer = DentitionRenderer(widget.assets.high);
    widget.camera.attach(_renderer.model, _renderer.fitDistance);
    _ticker = createTicker(_onTick);
    widget.camera.addListener(_wake);
    widget.controller.addListener(_onControllerChanged);
    _visuals.retarget(widget.controller, snap: true);
    _visuals.apply(_style);
  }

  @override
  void didUpdateWidget(DentalViewport old) {
    super.didUpdateWidget(old);
    if (old.camera != widget.camera) {
      old.camera.removeListener(_wake);
      widget.camera.addListener(_wake);
    }
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.camera.removeListener(_wake);
    widget.controller.removeListener(_onControllerChanged);
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  void _onControllerChanged() {
    _visuals.retarget(widget.controller, snap: _reduceMotion);
    _wake();
  }

  /// Starts the frame loop if anything needs to move, and repaints once.
  void _wake() {
    if (!mounted) return;
    _repaint.value++;
    if (!_ticker.isActive && (widget.camera.isAnimating || !_visuals.settled)) {
      _lastTick = Duration.zero;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    final dt = _lastTick == Duration.zero
        ? 1 / 60
        : math.min((elapsed - _lastTick).inMicroseconds / 1e6, 0.05);
    _lastTick = elapsed;
    final moved = widget.camera.tick(dt, reduceMotion: _reduceMotion);
    final styled = _visuals.step(dt);
    if (styled) _visuals.apply(_style);
    if (moved || styled) {
      _repaint.value++;
    } else {
      _ticker.stop();
    }
  }

  void _recordFrameCost(double ms) {
    if (_lowDetail || kDebugMode) return;
    _measuredFrames++;
    _frameCostMs = _measuredFrames == 1 ? ms : _frameCostMs * 0.9 + ms * 0.1;
    // Sustained cost above ~2/3 of a 60 Hz frame: switch to the light mesh.
    if (_measuredFrames > 20 && _frameCostMs > 11) {
      _lowDetail = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _renderer = DentitionRenderer(widget.assets.low));
        widget.camera.attach(_renderer.model, _renderer.fitDistance);
      });
    }
  }

  void _reportFailure(Object error) {
    if (_failed) return;
    _failed = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onRenderFailed?.call(error);
    });
  }

  // ── Gestures ──────────────────────────────────────────────────

  void _onScaleStart(ScaleStartDetails d) {
    widget.camera.stop();
    _pointers = d.pointerCount;
    _scaleStartDistance = widget.camera.pose.distance;
  }

  void _onScaleUpdate(ScaleUpdateDetails d, Size size) {
    if (d.pointerCount != _pointers) {
      // A finger was added or lifted: restart the pinch from here.
      _pointers = d.pointerCount;
      _scaleStartDistance = widget.camera.pose.distance / d.scale;
    }
    if (d.pointerCount >= 2) {
      widget.camera.setDistance(_scaleStartDistance / d.scale);
      widget.camera.panBy(d.focalPointDelta.dx, d.focalPointDelta.dy,
          DentitionRenderer.focalLength(size));
    } else {
      widget.camera.rotateBy(d.focalPointDelta.dx, d.focalPointDelta.dy);
    }
    widget.onInteract?.call();
  }

  void _onScaleEnd(ScaleEndDetails d) {
    if (_pointers == 1 && !_reduceMotion) {
      final v = d.velocity.pixelsPerSecond;
      widget.camera.fling(v.dx, v.dy);
    }
    _pointers = 0;
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final factor = math.exp(-event.scrollDelta.dy / 400);
      widget.camera.zoomBy(factor);
      widget.onInteract?.call();
    }
  }

  void _onTapUp(TapUpDetails d) {
    widget.onToothTap(_pick(d.localPosition));
  }

  /// Resolves a tap to a tooth: the tooth under the finger, or failing
  /// that the nearest visible crown within a finger's width.
  ToothInfo? _pick(Offset point) {
    final owner = _renderer.hitTest(point);
    if (owner != null) return ToothCatalog.byIndex(owner);
    ToothInfo? best;
    var bestDistance = 28.0;
    for (final tooth in ToothCatalog.all) {
      if (_style.alpha[tooth.index] < 0.5) continue;
      final p =
          _renderer.project(_renderer.model.anchors[tooth.index].crownCenter);
      if (p == null) continue;
      final d = (p.$1 - point).distance;
      if (d < bestDistance) {
        bestDistance = d;
        best = tooth;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Interactive 3D model of the upper and lower teeth',
      hint: 'Drag to rotate and pinch to zoom. The tooth chart lists every '
          'tooth for selection.',
      child: LayoutBuilder(builder: (context, constraints) {
        final size = constraints.biggest;
        return Listener(
          onPointerSignal: _onPointerSignal,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: _onScaleStart,
            onScaleUpdate: (d) => _onScaleUpdate(d, size),
            onScaleEnd: _onScaleEnd,
            onTapUp: _onTapUp,
            child: RepaintBoundary(
              child: CustomPaint(
                size: size,
                painter: _ScenePainter(
                  renderer: _renderer,
                  camera: widget.camera,
                  controller: widget.controller,
                  style: _style,
                  repaint: _repaint,
                  onFrameCost: _recordFrameCost,
                  onError: _reportFailure,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ── Per-owner animated appearance ─────────────────────────────────

/// Eases each tooth's and gum's look (opacity, tint, emphasis) toward
/// targets derived from the explorer state.
class _OwnerVisuals {
  static const _n = kOwnerCount;
  final _alpha = List<double>.filled(_n, 1);
  final _tint = List<double>.filled(_n, 0);
  final _brightness = List<double>.filled(_n, 1);
  final _desat = List<double>.filled(_n, 0);
  final _glow = List<double>.filled(_n, 0);

  final _alphaT = List<double>.filled(_n, 1);
  final _tintT = List<double>.filled(_n, 0);
  final _brightnessT = List<double>.filled(_n, 1);
  final _desatT = List<double>.filled(_n, 0);
  final _glowT = List<double>.filled(_n, 0);

  final _tintColor = List<Color>.filled(_n, AppColors.g1);

  /// The gums are drawn as translucent glass, so the roots show through.
  static const _gumOpacity = 0.68;

  bool get settled {
    for (var i = 0; i < _n; i++) {
      if ((_alpha[i] - _alphaT[i]).abs() > 0.004 ||
          (_tint[i] - _tintT[i]).abs() > 0.004 ||
          (_brightness[i] - _brightnessT[i]).abs() > 0.004 ||
          (_desat[i] - _desatT[i]).abs() > 0.004 ||
          (_glow[i] - _glowT[i]).abs() > 0.004) {
        return false;
      }
    }
    return true;
  }

  void retarget(ExplorerController c, {required bool snap}) {
    final selected = c.selected;
    for (final tooth in ToothCatalog.all) {
      final i = tooth.index;
      final isSelected = selected == tooth;
      final archShown = c.region.showsArch(tooth.arch);
      final inFocus = c.region.includes(tooth) || isSelected;
      _alphaT[i] = !archShown ? 0 : (inFocus ? 1 : 0.26);

      if (c.colorByType) {
        _tintColor[i] = ToothTypeColors.of(tooth.type);
        _tintT[i] = isSelected ? 0.4 : 0.5;
      } else {
        _tintColor[i] = AppColors.g1;
        _tintT[i] = isSelected ? 0.2 : 0;
      }
      // Selection: the chosen tooth glows; the rest recede but stay
      // visible for context.
      _glowT[i] = isSelected ? 1 : 0;
      _brightnessT[i] = selected == null || isSelected ? 1 : 0.9;
      _desatT[i] = selected == null || isSelected ? 0 : 0.22;
    }
    for (final (owner, arch) in const [
      (kUpperGumOwner, ToothArch.upper),
      (kLowerGumOwner, ToothArch.lower),
    ]) {
      _alphaT[owner] = c.showGums && c.region.showsArch(arch) ? _gumOpacity : 0;
      _desatT[owner] = c.colorByType ? 0.35 : (selected != null ? 0.18 : 0);
      _brightnessT[owner] = selected != null ? 0.95 : 1;
      _tintT[owner] = 0;
      _glowT[owner] = 0;
    }
    if (snap) {
      for (var i = 0; i < _n; i++) {
        _alpha[i] = _alphaT[i];
        _tint[i] = _tintT[i];
        _brightness[i] = _brightnessT[i];
        _desat[i] = _desatT[i];
        _glow[i] = _glowT[i];
      }
    }
  }

  /// Eases toward the targets; returns whether anything changed.
  bool step(double dt) {
    final k = 1 - math.exp(-dt * 10);
    var changed = false;
    double ease(double v, double t) {
      if ((v - t).abs() <= 0.004) return t;
      changed = true;
      return v + (t - v) * k;
    }

    for (var i = 0; i < _n; i++) {
      _alpha[i] = ease(_alpha[i], _alphaT[i]);
      _tint[i] = ease(_tint[i], _tintT[i]);
      _brightness[i] = ease(_brightness[i], _brightnessT[i]);
      _desat[i] = ease(_desat[i], _desatT[i]);
      _glow[i] = ease(_glow[i], _glowT[i]);
    }
    return changed;
  }

  void apply(SceneStyle s) {
    for (var i = 0; i < _n; i++) {
      s.alpha[i] = _alpha[i];
      s.tint[i] = _tint[i];
      s.tintR[i] = _tintColor[i].r;
      s.tintG[i] = _tintColor[i].g;
      s.tintB[i] = _tintColor[i].b;
      s.brightness[i] = _brightness[i];
      s.desaturate[i] = _desat[i];
      s.glow[i] = _glow[i];
    }
    // Roots glow faintly through the glass gums, and come in fully as
    // the gums fade out.
    final gum = math.max(_alpha[kUpperGumOwner], _alpha[kLowerGumOwner]);
    s.rootReveal = (1 - gum / _gumOpacity).clamp(0.0, 1.0);
  }
}

// ── Painter ───────────────────────────────────────────────────────

class _ScenePainter extends CustomPainter {
  _ScenePainter({
    required this.renderer,
    required this.camera,
    required this.controller,
    required this.style,
    required this.onFrameCost,
    required this.onError,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final DentitionRenderer renderer;
  final ExplorerCamera camera;
  final ExplorerController controller;
  final SceneStyle style;
  final ValueChanged<double> onFrameCost;
  final ValueChanged<Object> onError;

  static final Map<String, TextPainter> _labelCache = {};

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    try {
      final sw = Stopwatch()..start();
      renderer.paint(canvas, size, camera.pose, style);
      onFrameCost(sw.elapsedMicroseconds / 1000);
      _paintSideMarkers(canvas);
      _paintLabels(canvas, size);
    } catch (error) {
      onError(error);
    }
  }

  /// "R" and "L" beside the last molars, from the patient's point of view.
  /// Hidden when zoomed in, where they would sit on top of teeth.
  void _paintSideMarkers(Canvas canvas) {
    if (camera.pose.distance < renderer.fitDistance * 0.75) return;
    final model = renderer.model;
    for (final (point, text) in [
      (model.rightMarker, 'R'),
      (model.leftMarker, 'L'),
    ]) {
      final p = renderer.project(point);
      if (p == null) continue;
      final tp = _text(text, 12, FontWeight.w700,
          AppColors.secondaryText.withValues(alpha: 0.8));
      tp.paint(canvas, p.$1 - Offset(tp.width / 2, tp.height / 2));
    }
  }

  void _paintLabels(Canvas canvas, Size size) {
    final model = renderer.model;
    final selected = controller.selected;
    final candidates = <(ToothInfo, Offset, double)>[];
    for (final tooth in ToothCatalog.all) {
      final isSelected = tooth == selected;
      if (!controller.showNumbers && !isSelected) continue;
      if (style.alpha[tooth.index] < 0.5) continue;
      final anchor = model.anchors[tooth.index];
      // Skip numbers on the far side of the arch.
      if (!isSelected && renderer.toView(anchor.buccal).z < -0.25) continue;
      final p = renderer.project(anchor.label);
      if (p == null) continue;
      candidates.add((tooth, p.$1, isSelected ? -1 : p.$2));
    }
    // Nearest first, so overlapping far labels are the ones dropped.
    candidates.sort((a, b) => a.$3.compareTo(b.$3));
    final placed = <Offset>[];
    for (final (tooth, at, _) in candidates) {
      if (!size.contains(at)) continue;
      if (placed.any((o) => (o - at).distance < 19)) continue;
      placed.add(at);
      _paintLabel(canvas, tooth, at, tooth == selected);
    }
  }

  void _paintLabel(Canvas canvas, ToothInfo tooth, Offset at, bool selected) {
    final tp = _text(
        '${tooth.fdi}',
        selected ? 13 : 10,
        selected ? FontWeight.w800 : FontWeight.w700,
        selected ? AppColors.white : AppColors.navy);
    final w = tp.width + (selected ? 16 : 10);
    final h = tp.height + (selected ? 8 : 4);
    final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: at, width: w, height: h),
        Radius.circular(h / 2));
    if (selected) {
      canvas.drawRRect(
        rect.shift(const Offset(0, 2)),
        Paint()
          ..color = AppColors.g2.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawRRect(
          rect,
          Paint()
            ..shader = AppColors.cardGradient.createShader(rect.outerRect));
    } else {
      canvas.drawRRect(
          rect, Paint()..color = AppColors.white.withValues(alpha: 0.82));
      canvas.drawRRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = AppColors.g2.withValues(alpha: 0.25),
      );
    }
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  static TextPainter _text(
      String text, double size, FontWeight weight, Color color) {
    final key = '$text|$size|${weight.value}|${color.toARGB32()}';
    return _labelCache.putIfAbsent(key, () {
      return TextPainter(
        text: TextSpan(
          text: text,
          style: GoogleFonts.outfit(
              fontSize: size, fontWeight: weight, color: color, height: 1.1),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }

  @override
  bool shouldRepaint(_ScenePainter old) =>
      old.renderer != renderer || old.style != style;
}
