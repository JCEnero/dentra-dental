import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../data/capture_regions.dart';
import '../../data/mock_scan_report.dart';
import '../../providers/scan_flow_provider.dart';
import '../../rendering/scan_scene.dart';
import '../scan_motion.dart';
import 'scan_chamber_scene.dart';
import 'scan_sim_theme.dart';

/// Opens the full-screen 3D scan. It fades in over the capture board and,
/// once done (or skipped), calls [onComplete] and zooms out into the
/// results waiting underneath.
Future<void> showScanChamber(BuildContext context,
    {required VoidCallback onComplete}) {
  return Navigator.of(context).push(PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 650),
    reverseTransitionDuration: const Duration(milliseconds: 750),
    pageBuilder: (_, __, ___) => ScanChamberScreen(onComplete: onComplete),
    transitionsBuilder: (context, animation, _, child) => AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final leaving = animation.status == AnimationStatus.reverse;
        final v = leaving
            ? Curves.easeInCubic.transform(animation.value)
            : Curves.easeOutCubic.transform(animation.value);
        // In: settles from slightly large. Out: keeps zooming as it fades.
        final scale = leaving ? 1 + 0.12 * (1 - v) : 1.06 - 0.06 * v;
        return Opacity(
          opacity: v,
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: child,
    ),
  ));
}

/// The scan animation, about 13 seconds (6 with reduced motion): point
/// cloud → wireframe → solid model → photo projection → anomaly check →
/// report. Mock throughout; nothing is sent anywhere.
class ScanChamberScreen extends ConsumerStatefulWidget {
  const ScanChamberScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  ConsumerState<ScanChamberScreen> createState() => _ScanChamberScreenState();
}

class _ScanChamberScreenState extends ConsumerState<ScanChamberScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  final _progress = ValueNotifier<double>(0);
  late final ChamberTimeline _timeline;
  late final Map<int, ToothHealth> _health;
  late final String _scanId;
  ChamberScene? _scene;
  bool _reduced = false;
  bool _started = false;
  bool _done = false;
  bool _sound = false;
  int _stage = 0;
  int _landed = 0;
  Duration _length = const Duration(seconds: 13);

  @override
  void initState() {
    super.initState();
    final flow = ref.read(scanFlowProvider);
    _timeline = ChamberTimeline([
      for (final r in captureRegions)
        if (flow.photos.containsKey(r.id)) r,
    ]);
    // The same mock report the results will show, so the colours the
    // scan settles on match the tooth map.
    final preview = ScanReport.generate(
      captured: flow.photos.keys.toSet(),
      completedAt: DateTime.now(),
      sequence: flow.completedScans + 1,
    );
    _health = preview.toothHealth;
    _scanId = preview.id;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = ScanMotion.reduced(context);
    if (!_started) {
      _started = true;
      _prepare();
    }
  }

  Future<void> _prepare() async {
    final photos = ref.read(scanFlowProvider).photos;
    final model = await ref.read(scanDentitionProvider.future);
    if (!mounted) return;
    _length = Duration(seconds: _reduced ? 6 : 13);
    final scene = ChamberScene(
      model: model,
      timeline: _timeline,
      health: _health,
      thumbs: {},
      reduced: _reduced,
      seconds: _length.inMilliseconds / 1000,
    );
    setState(() => _scene = scene);
    _ticker.start();

    // Thumbnails are only needed once the photos fly in, past halfway,
    // so they decode while the scan is already running.
    for (final entry in photos.entries) {
      try {
        final codec = await ui.instantiateImageCodec(entry.value.bytes,
            targetWidth: 240);
        final image = (await codec.getNextFrame()).image;
        codec.dispose();
        if (!mounted) {
          image.dispose();
          return;
        }
        scene.thumbs[entry.key] = image;
      } catch (_) {
        // Drawn as a plain card instead.
      }
    }
  }

  void _onTick(Duration elapsed) {
    final p = (elapsed.inMicroseconds / _length.inMicroseconds).clamp(0.0, 1.0);
    _progress.value = p;
    final stage = _timeline.stageAt(p);
    if (stage != _stage) {
      _stage = stage;
      _cue(HapticFeedback.lightImpact);
    }
    final landed = _timeline.landedCount(p);
    if (landed != _landed) {
      _landed = landed;
      _cue(HapticFeedback.selectionClick);
    }
    if (p >= 1 && !_done) _finish();
  }

  /// Sound and haptic cues, only when the user turned them on.
  void _cue(Future<void> Function() haptic) {
    if (!_sound) return;
    haptic();
    SystemSound.play(SystemSoundType.click);
  }

  void _finish() {
    _done = true;
    _ticker.stop();
    _cue(HapticFeedback.mediumImpact);
    widget.onComplete();
    Future<void>.delayed(const Duration(milliseconds: 280), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _skip() {
    if (_done) return;
    _done = true;
    _ticker.stop();
    widget.onComplete();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _progress.dispose();
    _scene?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final wide = media.size.width >= 720;
    final scene = _scene;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: HoloColors.space,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (scene != null)
              Semantics(
                image: true,
                label: '3D scan animation of your teeth',
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: ChamberPainter(
                      scene: scene,
                      progress: _progress,
                      stageInsets: EdgeInsets.fromLTRB(
                        wide ? 180 : 0,
                        media.padding.top + 64,
                        wide ? 40 : 0,
                        media.padding.bottom + (wide ? 190 : 250),
                      ),
                    ),
                  ),
                ),
              )
            else
              const Center(
                child: SizedBox.square(
                  dimension: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: HoloColors.cyan,
                  ),
                ),
              ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Column(
                  children: [
                    _TopBar(
                      sound: _sound,
                      onSound: () => setState(() => _sound = !_sound),
                      onSkip: _skip,
                    ),
                    Expanded(
                      child: wide
                          ? Align(
                              alignment: Alignment.centerLeft,
                              child: SizedBox(
                                width: 168,
                                child: _RegionChecklist(
                                  timeline: _timeline,
                                  progress: _progress,
                                  compact: false,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    if (!wide) ...[
                      _RegionChecklist(
                        timeline: _timeline,
                        progress: _progress,
                        compact: true,
                      ),
                      const SizedBox(height: 10),
                    ],
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: _StatusPanel(
                          timeline: _timeline,
                          progress: _progress,
                          scanId: _scanId,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.sound,
    required this.onSound,
    required this.onSkip,
  });

  final bool sound;
  final VoidCallback onSound;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Semantics(
          toggled: sound,
          child: IconButton(
            onPressed: onSound,
            tooltip: sound ? 'Turn sound and haptics off' : 'Turn sound and haptics on',
            style: IconButton.styleFrom(
              backgroundColor: const Color(0x2914324A),
              foregroundColor: sound ? HoloColors.cyan : HoloColors.textDim,
              fixedSize: const Size(44, 44),
              side: const BorderSide(color: HoloColors.rim),
            ),
            icon: Icon(
              sound ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              size: 20,
            ),
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                'DENTRA SCAN PRO',
                style: hudText(
                  size: 9.5,
                  weight: FontWeight.w700,
                  color: HoloColors.cyan.withValues(alpha: 0.8),
                  letterSpacing: 2.6,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: HealthColors.attention,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'LIVE 3D SCAN',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: HoloColors.text,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onSkip,
          style: TextButton.styleFrom(
            foregroundColor: HoloColors.textDim,
            minimumSize: const Size(48, 44),
            textStyle: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Skip animation'),
              SizedBox(width: 2),
              Icon(Icons.chevron_right_rounded, size: 18),
            ],
          ),
        ),
      ],
    );
  }
}

/// Regions ticking off as their photos land on the model. A row of
/// small tiles on phones, a list down the side on wide screens.
class _RegionChecklist extends StatelessWidget {
  const _RegionChecklist({
    required this.timeline,
    required this.progress,
    required this.compact,
  });

  final ChamberTimeline timeline;
  final ValueNotifier<double> progress;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: progress,
      builder: (context, p, _) {
        final rows = [
          for (final region in captureRegions)
            (region, _stateOf(region, p)),
        ];
        final landed = timeline.landedCount(p);
        final header = Text(
          'REGIONS  $landed/${timeline.captured.length}',
          style: hudText(
              size: 9, color: HoloColors.textDim, letterSpacing: 1.6),
        );
        return Semantics(
          label: '$landed of ${timeline.captured.length} regions analyzed',
          excludeSemantics: true,
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 2, bottom: 6),
                      child: header,
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < rows.length; i++) ...[
                          if (i > 0) const SizedBox(width: 5),
                          Expanded(
                            child: _RegionTile(
                              key: ValueKey(rows[i].$1.id),
                              region: rows[i].$1,
                              state: rows[i].$2,
                              pulse: p,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                )
              : Container(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                  decoration: holoGlass(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      header,
                      const SizedBox(height: 8),
                      for (final (region, state) in rows)
                        _RegionRow(
                          key: ValueKey(region.id),
                          region: region,
                          state: state,
                          pulse: p,
                        ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  _RegionState _stateOf(CaptureRegion region, double p) {
    final i = timeline.captured.indexOf(region);
    if (i < 0) return _RegionState.skipped;
    if (timeline.landed(i, p)) return _RegionState.done;
    return timeline.flight(i, p) > 0 ? _RegionState.active : _RegionState.pending;
  }
}

enum _RegionState { skipped, pending, active, done }

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.state, required this.pulse});

  final _RegionState state;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    const size = 16.0;
    switch (state) {
      case _RegionState.skipped:
        return Icon(Icons.remove_rounded,
            size: size, color: HoloColors.textDim.withValues(alpha: 0.5));
      case _RegionState.pending:
        return Container(
          width: size - 4,
          height: size - 4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: HoloColors.textDim, width: 1.4),
          ),
        );
      case _RegionState.active:
        final glow = 0.5 + 0.5 * math.sin(pulse * 220);
        return Container(
          width: size - 4,
          height: size - 4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: HoloColors.cyan.withValues(alpha: 0.4 + 0.5 * glow),
            boxShadow: [
              BoxShadow(
                color: HoloColors.cyan.withValues(alpha: 0.6 * glow),
                blurRadius: 8,
              ),
            ],
          ),
        );
      case _RegionState.done:
        return Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: HoloColors.cyan,
            boxShadow: [
              BoxShadow(
                color: HoloColors.cyan.withValues(alpha: 0.6),
                blurRadius: 8,
              ),
            ],
          ),
          child: const DrawnCheck(
            visible: true,
            size: 12,
            strokeWidth: 2,
            color: HoloColors.space,
          ),
        );
    }
  }
}

class _RegionTile extends StatelessWidget {
  const _RegionTile({
    super.key,
    required this.region,
    required this.state,
    required this.pulse,
  });

  final CaptureRegion region;
  final _RegionState state;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    final done = state == _RegionState.done;
    return AnimatedContainer(
      duration: ScanMotion.of(context, ScanMotion.medium),
      height: 48,
      decoration: holoGlass(
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        borderColor: done
            ? HoloColors.cyan.withValues(alpha: 0.7)
            : state == _RegionState.skipped
                ? HoloColors.rim.withValues(alpha: 0.15)
                : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            region.code,
            style: hudText(
              size: 9,
              weight: FontWeight.w700,
              color: state == _RegionState.skipped
                  ? HoloColors.textDim.withValues(alpha: 0.45)
                  : HoloColors.text,
            ),
          ),
          const SizedBox(height: 4),
          _StatusIcon(state: state, pulse: pulse),
        ],
      ),
    );
  }
}

class _RegionRow extends StatelessWidget {
  const _RegionRow({
    super.key,
    required this.region,
    required this.state,
    required this.pulse,
  });

  final CaptureRegion region;
  final _RegionState state;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    final skipped = state == _RegionState.skipped;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 18,
            child: Center(child: _StatusIcon(state: state, pulse: pulse)),
          ),
          const SizedBox(width: 8),
          Text(
            region.code,
            style: hudText(
              size: 9,
              color: skipped
                  ? HoloColors.textDim.withValues(alpha: 0.45)
                  : HoloColors.cyan,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              skipped ? '${region.shortLabel} · skipped' : region.shortLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: skipped
                    ? HoloColors.textDim.withValues(alpha: 0.5)
                    : HoloColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.timeline,
    required this.progress,
    required this.scanId,
  });

  final ChamberTimeline timeline;
  final ValueNotifier<double> progress;
  final String scanId;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(22));
    return ClipRRect(
      borderRadius: radius,
      child: GlassBlur(
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          decoration: holoGlass(borderRadius: radius),
          child: ValueListenableBuilder<double>(
            valueListenable: progress,
            builder: (context, p, _) {
              final stage = timeline.stageAt(p);
              final done = p >= 1;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'STAGE ${stage + 1} / ${ChamberTimeline.stageCount}',
                              style: hudText(
                                size: 9,
                                color: HoloColors.cyan.withValues(alpha: 0.8),
                                letterSpacing: 1.6,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Semantics(
                              liveRegion: true,
                              child: AnimatedSwitcher(
                                duration:
                                    ScanMotion.of(context, ScanMotion.medium),
                                transitionBuilder: ScanMotion.fadeRise,
                                layoutBuilder: (current, previous) => Stack(
                                  alignment: Alignment.centerLeft,
                                  children: [
                                    ...previous,
                                    if (current != null) current,
                                  ],
                                ),
                                child: Text(
                                  done ? 'Report ready' : timeline.labelOf(stage),
                                  key: ValueKey(done ? -1 : stage),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: HoloColors.text,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${(p * 100).floor()}%',
                        style: hudText(
                          size: 30,
                          weight: FontWeight.w700,
                          color: HoloColors.text,
                          letterSpacing: 0,
                          height: 1,
                        ).copyWith(shadows: [
                          Shadow(
                            color: HoloColors.cyan.withValues(alpha: 0.7),
                            blurRadius: 16,
                          ),
                        ]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 10,
                    child: CustomPaint(painter: _TrackPainter(p)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'SCAN #$scanId',
                          style: hudText(
                              size: 8.5,
                              color: HoloColors.textDim,
                              letterSpacing: 1.2),
                        ),
                      ),
                      Text(
                        '${timeline.captured.length}/${captureRegions.length} VIEWS',
                        style: hudText(
                            size: 8.5,
                            color: HoloColors.textDim,
                            letterSpacing: 1.2),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Progress track with a tick at each stage and a glowing head.
class _TrackPainter extends CustomPainter {
  const _TrackPainter(this.p);
  final double p;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, y - 2.5, size.width, 5),
      const Radius.circular(2.5),
    );
    canvas.drawRRect(
        track, Paint()..color = HoloColors.cyan.withValues(alpha: 0.12));
    for (final s in ChamberTimeline.stageStarts.skip(1)) {
      final x = size.width * s;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..strokeWidth = 1
          ..color = HoloColors.cyan.withValues(alpha: p >= s ? 0.6 : 0.2),
      );
    }
    if (p <= 0) return;
    final fill = Rect.fromLTWH(0, y - 2.5, size.width * p, 5);
    final gradient = const LinearGradient(
      colors: [AppColors.g2, AppColors.g1, HoloColors.cyan],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRRect(
      RRect.fromRectAndRadius(fill.inflate(2), const Radius.circular(4)),
      Paint()
        ..shader = gradient
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(fill, const Radius.circular(2.5)),
      Paint()..shader = gradient,
    );
    canvas.drawCircle(Offset(size.width * p, y), 3.5,
        Paint()..color = AppColors.white);
  }

  @override
  bool shouldRepaint(_TrackPainter old) => old.p != p;
}
