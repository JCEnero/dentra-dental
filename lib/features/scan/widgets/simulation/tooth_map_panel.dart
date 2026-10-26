import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../dental_explorer/data/tooth_catalog.dart';
import '../../../dental_explorer/geometry/dentition_builder.dart';
import '../../../dental_explorer/rendering/dentition_renderer.dart';
import '../../../dental_explorer/state/explorer_camera.dart';
import '../../../dental_explorer/state/explorer_controller.dart';
import '../../data/capture_regions.dart';
import '../../data/mock_scan_report.dart';
import '../../providers/scan_flow_provider.dart';
import '../../rendering/scan_scene.dart';
import '../scan_motion.dart';
import 'scan_sim_theme.dart';

enum MapArches {
  upper('Upper'),
  both('Both'),
  lower('Lower');

  const MapArches(this.label);
  final String label;

  bool shows(ToothArch arch) => switch (this) {
        MapArches.upper => arch == ToothArch.upper,
        MapArches.lower => arch == ToothArch.lower,
        MapArches.both => true,
      };
}

/// The scanned model on a dark holo stage, coloured by tooth health.
/// Drag sideways to turn it, pinch to zoom, tap a tooth for its card.
class ToothMapPanel extends ConsumerStatefulWidget {
  const ToothMapPanel({
    super.key,
    required this.report,
    required this.selected,
    required this.onSelect,
  });

  final ScanReport report;

  /// FDI number of the selected tooth.
  final int? selected;
  final ValueChanged<int?> onSelect;

  @override
  ConsumerState<ToothMapPanel> createState() => _ToothMapPanelState();
}

class _ToothMapPanelState extends ConsumerState<ToothMapPanel> {
  MapArches _arches = MapArches.both;
  final _camera = ExplorerCamera();

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  void _setArches(MapArches arches) {
    if (arches == _arches) return;
    setState(() => _arches = arches);
    _camera.showRegion(switch (arches) {
      MapArches.upper => ExplorerRegion.upper,
      MapArches.lower => ExplorerRegion.lower,
      MapArches.both => ExplorerRegion.all,
    });
    final selected = widget.selected;
    if (selected != null &&
        !arches.shows(ToothCatalog.byFdi(selected)!.arch)) {
      widget.onSelect(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = ref.watch(scanDentitionProvider).valueOrNull;
    final report = widget.report;
    final selected =
        widget.selected == null ? null : ToothCatalog.byFdi(widget.selected!);
    final width = MediaQuery.sizeOf(context).width;
    final height = (width * 0.82).clamp(260.0, 380.0);

    return HoloPanel(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        '3D TOOTH MAP',
                        style: hudText(
                          size: 11,
                          weight: FontWeight.w700,
                          color: HoloColors.cyan,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Drag to turn · Tap a tooth',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: HoloColors.textDim,
                      ),
                    ),
                  ],
                ),
              ),
              _ArchToggle(value: _arches, onChanged: _setArches),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: height,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const RepaintBoundary(
                    child: CustomPaint(painter: _StagePainter()),
                  ),
                  if (model == null)
                    const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: HoloColors.cyan,
                      ),
                    )
                  else
                    _ToothMapViewport(
                      model: model,
                      camera: _camera,
                      report: report,
                      arches: _arches,
                      selected: selected,
                      onTap: (tooth) => widget.onSelect(
                          tooth == null || tooth == selected ? null : tooth.fdi),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _Legend(report: report),
          AnimatedSize(
            duration: ScanMotion.of(context, ScanMotion.slow),
            curve: ScanMotion.curve,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: ScanMotion.of(context, ScanMotion.medium),
              transitionBuilder: ScanMotion.fadeRise,
              child: selected == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      key: ValueKey(selected.fdi),
                      padding: const EdgeInsets.only(top: 14),
                      child: ToothCard(
                        detail: report.toothReport(selected),
                        onClose: () => widget.onSelect(null),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchToggle extends StatelessWidget {
  const _ArchToggle({required this.value, required this.onChanged});

  final MapArches value;
  final ValueChanged<MapArches> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0x3314324A),
        border: Border.all(color: HoloColors.rim),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in MapArches.values)
            Semantics(
              button: true,
              selected: option == value,
              label: 'Show ${option.label.toLowerCase()} '
                  '${option == MapArches.both ? 'arches' : 'arch'}',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () => onChanged(option),
                child: AnimatedContainer(
                  duration: ScanMotion.of(context, ScanMotion.medium),
                  curve: ScanMotion.curve,
                  constraints: const BoxConstraints(minHeight: 34),
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    gradient: option == value
                        ? const LinearGradient(
                            colors: [AppColors.g1, AppColors.g2])
                        : null,
                    boxShadow: option == value
                        ? [
                            BoxShadow(
                              color: AppColors.g1.withValues(alpha: 0.4),
                              blurRadius: 10,
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    option.label,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: option == value
                          ? AppColors.white
                          : HoloColors.textDim,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.report});
  final ScanReport report;

  @override
  Widget build(BuildContext context) {
    final items = [
      ToothHealth.healthy,
      ToothHealth.monitor,
      ToothHealth.attention,
      if (report.countOf(ToothHealth.notAssessed) > 0) ToothHealth.notAssessed,
    ];
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final h in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: HealthColors.of(h),
                  boxShadow: [
                    BoxShadow(
                      color: HealthColors.of(h).withValues(alpha: 0.6),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${h.label} · ${report.countOf(h)}',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: HoloColors.text.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// What the report says about one tooth, on dark glass.
class ToothCard extends ConsumerWidget {
  const ToothCard({super.key, required this.detail, required this.onClose});

  final ToothReport detail;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = HealthColors.of(detail.health);
    final region =
        detail.regionId == null ? null : captureRegionById(detail.regionId!);
    final photo = region == null
        ? null
        : ref.watch(scanFlowProvider.select((s) => s.photos[region.id]));
    final dim = GoogleFonts.outfit(
      fontSize: 12.5,
      height: 1.45,
      color: HoloColors.textDim,
    );

    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
        decoration: holoGlass(
          borderRadius: const BorderRadius.all(Radius.circular(18)),
          borderColor: color.withValues(alpha: 0.55),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.14),
                    border: Border.all(color: color, width: 1.6),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Text(
                    '${detail.tooth.fdi}',
                    style: hudText(
                        size: 16, weight: FontWeight.w700, color: HoloColors.text),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tooth ${detail.tooth.fdi} · ${detail.tooth.name}',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: HoloColors.text,
                        ),
                      ),
                      const SizedBox(height: 5),
                      HealthChip(health: detail.health, dark: true),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  tooltip: 'Close tooth details',
                  color: HoloColors.textDim,
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail.condition,
                    style: GoogleFonts.outfit(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: HoloColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(detail.detail, style: dim),
                  if (detail.confidence case final confidence?) ...[
                    const SizedBox(height: 12),
                    ConfidenceBar(value: confidence, color: color, dark: true),
                  ],
                  if (region != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 64,
                            height: 48,
                            child: photo == null
                                ? const ColoredBox(color: Color(0x3314324A))
                                : Image.memory(
                                    photo.bytes,
                                    fit: BoxFit.cover,
                                    cacheWidth: 192,
                                    gaplessPlayback: true,
                                    excludeFromSemantics: true,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                detail.health == ToothHealth.healthy
                                    ? 'CHECKED IN'
                                    : 'FOUND IN',
                                style: capsLabel(color: HoloColors.textDim),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${region.label} photo',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: HoloColors.text,
                                ),
                              ),
                              Text(region.technical,
                                  style: dim.copyWith(fontSize: 11.5)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(Icons.tips_and_updates_outlined,
                            size: 16, color: HoloColors.cyan),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          detail.recommendation,
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            height: 1.45,
                            color: HoloColors.text.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Confidence as a thin bar that fills in, with the percentage.
class ConfidenceBar extends StatelessWidget {
  const ConfidenceBar({
    super.key,
    required this.value,
    required this.color,
    this.dark = false,
  });

  final double value;
  final Color color;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final percent = (value * 100).round();
    return Semantics(
      label: '$percent percent confidence',
      excludeSemantics: true,
      child: Row(
        children: [
          Text(
            'CONFIDENCE',
            style: capsLabel(
                color: dark ? HoloColors.textDim : AppColors.secondaryText),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value),
              duration: ScanMotion.of(context, const Duration(milliseconds: 900)),
              curve: ScanMotion.curve,
              builder: (context, v, _) => Container(
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: dark
                      ? HoloColors.cyan.withValues(alpha: 0.12)
                      : AppColors.navy.withValues(alpha: 0.07),
                ),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: v,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: LinearGradient(colors: [
                        color.withValues(alpha: 0.6),
                        color,
                      ]),
                      boxShadow: dark
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.5),
                                blurRadius: 6,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$percent%',
            style: hudText(
              size: 11,
              weight: FontWeight.w700,
              color: dark ? HoloColors.text : AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Viewport ──────────────────────────────────────────────────────

class _ToothMapViewport extends StatefulWidget {
  const _ToothMapViewport({
    required this.model,
    required this.camera,
    required this.report,
    required this.arches,
    required this.selected,
    required this.onTap,
  });

  final DentitionModel model;
  final ExplorerCamera camera;
  final ScanReport report;
  final MapArches arches;
  final ToothInfo? selected;
  final ValueChanged<ToothInfo?> onTap;

  @override
  State<_ToothMapViewport> createState() => _ToothMapViewportState();
}

class _ToothMapViewportState extends State<_ToothMapViewport>
    with SingleTickerProviderStateMixin {
  late final DentitionRenderer _renderer = DentitionRenderer(widget.model);
  late final Ticker _ticker = createTicker(_onTick);
  final _repaint = ValueNotifier<int>(0);
  final _style = SceneStyle();
  Duration _last = Duration.zero;
  double _time = 0;

  // Eased per-owner appearance and its targets.
  final _alpha = List<double>.filled(kOwnerCount, 0);
  final _alphaT = List<double>.filled(kOwnerCount, 0);
  final _glow = List<double>.filled(kOwnerCount, 0);
  final _glowT = List<double>.filled(kOwnerCount, 0);
  final _desat = List<double>.filled(kOwnerCount, 0);
  final _desatT = List<double>.filled(kOwnerCount, 0);

  /// Turns once on its own until the user takes over.
  bool _idle = true;
  double _idleTurned = 0;
  double _startDistance = 1;
  int _pointers = 0;

  bool get _reduced => ScanMotion.reduced(context);

  @override
  void initState() {
    super.initState();
    // A little further out than the explorer's fit, which assumes a tall
    // viewport: here the arches have to fit side-on in a short one too.
    widget.camera.attach(widget.model, _renderer.fitDistance * 1.25);
    widget.camera.addListener(_wake);
    _retarget(snap: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduced) _idle = false;
    _wake();
  }

  @override
  void didUpdateWidget(_ToothMapViewport old) {
    super.didUpdateWidget(old);
    if (old.arches != widget.arches) _idle = false;
    if (old.arches != widget.arches ||
        old.selected != widget.selected ||
        old.report != widget.report) {
      _retarget(snap: _reduced);
      _wake();
    }
  }

  @override
  void dispose() {
    widget.camera.removeListener(_wake);
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  void _retarget({required bool snap}) {
    final selected = widget.selected;
    for (final tooth in ToothCatalog.all) {
      final i = tooth.index;
      _alphaT[i] = widget.arches.shows(tooth.arch) ? 1 : 0;
      _glowT[i] = tooth == selected ? 1 : 0;
      _desatT[i] = selected != null && tooth != selected ? 0.25 : 0;
    }
    for (final (owner, arch) in const [
      (kUpperGumOwner, ToothArch.upper),
      (kLowerGumOwner, ToothArch.lower),
    ]) {
      _alphaT[owner] = widget.arches.shows(arch) ? 0.45 : 0;
    }
    if (snap) {
      _alpha.setAll(0, _alphaT);
      _glow.setAll(0, _glowT);
      _desat.setAll(0, _desatT);
    }
  }

  bool get _settled {
    for (var i = 0; i < kOwnerCount; i++) {
      if ((_alpha[i] - _alphaT[i]).abs() > 0.004 ||
          (_glow[i] - _glowT[i]).abs() > 0.004 ||
          (_desat[i] - _desatT[i]).abs() > 0.004) {
        return false;
      }
    }
    return true;
  }

  void _wake() {
    if (!mounted) return;
    _repaint.value++;
    final pulsing = widget.selected != null && !_reduced;
    if (!_ticker.isActive &&
        (_idle || pulsing || widget.camera.isAnimating || !_settled)) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 1 / 60
        : math.min((elapsed - _last).inMicroseconds / 1e6, 0.05);
    _last = elapsed;
    _time += dt;

    if (_idle) {
      const speed = 0.45; // rad/s
      widget.camera.rotateBy(speed * dt / ExplorerCamera.dragSpeed, 0);
      _idleTurned += speed * dt;
      if (_idleTurned >= 2 * math.pi) _idle = false;
    }
    final moved = widget.camera.tick(dt, reduceMotion: _reduced);

    final k = 1 - math.exp(-dt * 10);
    var changed = false;
    void ease(List<double> v, List<double> t) {
      for (var i = 0; i < kOwnerCount; i++) {
        if ((v[i] - t[i]).abs() <= 0.004) {
          v[i] = t[i];
        } else {
          v[i] += (t[i] - v[i]) * k;
          changed = true;
        }
      }
    }

    ease(_alpha, _alphaT);
    ease(_glow, _glowT);
    ease(_desat, _desatT);

    final pulsing = widget.selected != null && !_reduced;
    if (_idle || moved || changed || pulsing) {
      _repaint.value++;
    } else {
      _ticker.stop();
    }
  }

  void _applyStyle() {
    final s = _style
      ..hideRoots = true
      ..rootReveal = 0;
    final pulse = 0.75 + 0.25 * math.sin(_time * 4);
    for (final tooth in ToothCatalog.all) {
      final i = tooth.index;
      final health =
          widget.report.toothHealth[tooth.fdi] ?? ToothHealth.healthy;
      final color = HealthColors.of(health);
      s
        ..alpha[i] = _alpha[i]
        ..tintR[i] = color.r
        ..tintG[i] = color.g
        ..tintB[i] = color.b
        ..tint[i] = switch (health) {
          ToothHealth.healthy => 0.38,
          ToothHealth.monitor => 0.62,
          ToothHealth.attention => 0.74,
          ToothHealth.notAssessed => 0,
        }
        ..glow[i] = _glow[i] * pulse
        ..desaturate[i] = health == ToothHealth.notAssessed
            ? 0.75
            : _desat[i]
        ..brightness[i] = health == ToothHealth.notAssessed ? 0.72 : 1;
    }
    for (final o in const [kUpperGumOwner, kLowerGumOwner]) {
      s
        ..alpha[o] = _alpha[o]
        ..tint[o] = 0
        ..glow[o] = 0
        ..desaturate[o] = 0.1
        ..brightness[o] = 0.9;
    }
  }

  // ── Gestures ──────────────────────────────────────────────────

  void _onScaleStart(ScaleStartDetails d) {
    _idle = false;
    widget.camera.stop();
    _pointers = d.pointerCount;
    _startDistance = widget.camera.pose.distance;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (d.pointerCount != _pointers) {
      _pointers = d.pointerCount;
      _startDistance = widget.camera.pose.distance / d.scale;
    }
    if (d.pointerCount >= 2) {
      widget.camera.setDistance(_startDistance / d.scale);
    } else {
      widget.camera
          .rotateBy(d.focalPointDelta.dx, d.focalPointDelta.dy);
    }
  }

  void _onScaleEnd(ScaleEndDetails d) {
    if (_pointers == 1 && !_reduced) {
      final v = d.velocity.pixelsPerSecond;
      widget.camera.fling(v.dx, v.dy);
    }
    _pointers = 0;
  }

  /// The tooth under the finger, or the nearest visible crown within a
  /// finger's width.
  ToothInfo? _pick(Offset point) {
    final owner = _renderer.hitTest(point);
    if (owner != null) return ToothCatalog.byIndex(owner);
    ToothInfo? best;
    var bestDistance = 26.0;
    for (final tooth in ToothCatalog.all) {
      if (_alpha[tooth.index] < 0.5) continue;
      final p =
          _renderer.project(widget.model.anchors[tooth.index].crownCenter);
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
      label: '3D model of your teeth, coloured by health',
      hint: 'Drag sideways to turn it. The findings below list every flagged '
          'tooth.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        onTapUp: (d) {
          _idle = false;
          widget.onTap(_pick(d.localPosition));
        },
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: _MapPainter(
              renderer: _renderer,
              camera: widget.camera,
              report: widget.report,
              selected: widget.selected,
              alpha: _alpha,
              beforePaint: _applyStyle,
              style: _style,
              repaint: _repaint,
            ),
          ),
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter({
    required this.renderer,
    required this.camera,
    required this.report,
    required this.selected,
    required this.alpha,
    required this.beforePaint,
    required this.style,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final DentitionRenderer renderer;
  final ExplorerCamera camera;
  final ScanReport report;
  final ToothInfo? selected;
  final List<double> alpha;
  final VoidCallback beforePaint;
  final SceneStyle style;

  static final _labels = <String, TextPainter>{};

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    beforePaint();
    renderer.paint(canvas, size, camera.pose, style);

    // Numbers on flagged teeth and the selected one, nearest first.
    final candidates = <(ToothInfo, Offset, double)>[];
    for (final tooth in ToothCatalog.all) {
      final health = report.toothHealth[tooth.fdi]!;
      final isSelected = tooth == selected;
      final flagged =
          health == ToothHealth.monitor || health == ToothHealth.attention;
      if (!flagged && !isSelected) continue;
      if (alpha[tooth.index] < 0.5) continue;
      final anchor = renderer.model.anchors[tooth.index];
      if (!isSelected && renderer.toView(anchor.buccal).z < -0.2) continue;
      final p = renderer.project(anchor.label);
      if (p == null || !size.contains(p.$1)) continue;
      candidates.add((tooth, p.$1, isSelected ? -1 : p.$2));
    }
    candidates.sort((a, b) => a.$3.compareTo(b.$3));
    final placed = <Offset>[];
    for (final (tooth, at, _) in candidates) {
      if (placed.any((o) => (o - at).distance < 20)) continue;
      placed.add(at);
      final isSelected = tooth == selected;
      final color = HealthColors.of(report.toothHealth[tooth.fdi]!);
      final tp = _labels.putIfAbsent(
        '${tooth.fdi}|$isSelected',
        () => TextPainter(
          text: TextSpan(
            text: '${tooth.fdi}',
            style: hudText(
              size: isSelected ? 11 : 9,
              weight: FontWeight.w700,
              color: isSelected ? HoloColors.space : HoloColors.text,
              height: 1.1,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(),
      );
      final w = tp.width + (isSelected ? 16 : 10);
      final h = tp.height + (isSelected ? 8 : 5);
      final pill = RRect.fromRectAndRadius(
        Rect.fromCenter(center: at, width: w, height: h),
        Radius.circular(h / 2),
      );
      if (isSelected) {
        canvas.drawRRect(
          pill.inflate(2),
          Paint()
            ..color = color.withValues(alpha: 0.5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
        canvas.drawRRect(pill, Paint()..color = color);
      } else {
        canvas.drawRRect(pill, Paint()..color = const Color(0xD9041320));
        canvas.drawRRect(
          pill,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.1
            ..color = color,
        );
      }
      tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_MapPainter old) =>
      old.renderer != renderer ||
      old.report != report ||
      old.selected != selected;
}

/// Static stage behind the model: glow, grid floor and a holo pad.
class _StagePainter extends CustomPainter {
  const _StagePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final c = size.center(Offset.zero);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.1),
          radius: 0.9,
          colors: [Color(0xFF0E3048), Color(0xFF071726), Color(0xFF040D18)],
          stops: [0, 0.6, 1],
        ).createShader(rect),
    );
    final horizon = size.height * 0.72;
    final floor = Rect.fromLTRB(0, horizon, size.width, size.height);
    final line = Paint()
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          HoloColors.cyan.withValues(alpha: 0),
          HoloColors.cyan.withValues(alpha: 0.2),
        ],
      ).createShader(floor);
    for (var i = 1; i <= 7; i++) {
      final k = i / 7;
      final y = horizon + (size.height - horizon) * k * k;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    for (var j = -10; j <= 10; j++) {
      canvas.drawLine(
        Offset(c.dx + j * size.width * 0.04, horizon),
        Offset(c.dx + j * size.width * 0.22, size.height),
        line,
      );
    }
    final pad = Rect.fromCenter(
      center: Offset(c.dx, horizon),
      width: size.width * 0.8,
      height: size.height * 0.16,
    );
    canvas.drawOval(
      pad,
      Paint()
        ..shader = RadialGradient(colors: [
          HoloColors.cyan.withValues(alpha: 0.22),
          HoloColors.cyan.withValues(alpha: 0),
        ]).createShader(pad),
    );
  }

  @override
  bool shouldRepaint(_StagePainter old) => false;
}
