import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_glass.dart';
import '../../../../shared/widgets/app_backdrop.dart';
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
/// cloud → wireframe → solid model → photo projection → area check →
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
  late final ScanReport _preview;
  ChamberScene? _scene;
  bool _reduced = false;
  bool _started = false;
  bool _done = false;
  bool _sound = false;
  int _step = 0;
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
    // The same mock report the results will show, so the shades the scan
    // settles on match the map.
    _preview = ScanReport.generate(
      captured: flow.photos.keys.toSet(),
      completedAt: DateTime.now(),
      sequence: flow.completedScans + 1,
    );
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
      report: _preview,
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
    final step = _timeline.stepAt(p);
    if (step != _step) {
      _step = step;
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
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.lightLavender,
        body: AppBackdrop(
          child: Stack(
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
                          media.padding.top + 72,
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
                      color: AppColors.g2,
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
                                  width: 176,
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
                            scanId: _preview.id,
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
            tooltip:
                sound ? 'Turn sound and haptics off' : 'Turn sound and haptics on',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.white.withValues(alpha: 0.7),
              foregroundColor: sound ? AppColors.g2 : AppColors.secondaryText,
              fixedSize: const Size(44, 44),
              side: const BorderSide(color: AppGlass.border),
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
                'Scanning your teeth',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
              Text(
                'Dentra Scan Pro',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onSkip,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.secondaryText,
            minimumSize: const Size(48, 44),
            textStyle: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Skip'),
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
          for (final region in captureRegions) (region, _stateOf(region, p)),
        ];
        final landed = timeline.landedCount(p);
        final header = Text(
          'PHOTOS MATCHED  $landed/${timeline.captured.length}',
          style: capsLabel(),
        );
        return Semantics(
          label: '$landed of ${timeline.captured.length} photos matched',
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
              : GlassCard(
                  borderRadius: const BorderRadius.all(Radius.circular(18)),
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      header,
                      const SizedBox(height: 10),
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
    return timeline.flight(i, p) > 0
        ? _RegionState.active
        : _RegionState.pending;
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
            size: size, color: AppColors.secondaryText.withValues(alpha: 0.5));
      case _RegionState.pending:
        return Container(
          width: size - 4,
          height: size - 4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.lavender, width: 1.6),
          ),
        );
      case _RegionState.active:
        final glow = 0.5 + 0.5 * math.sin(pulse * 220);
        return Container(
          width: size - 4,
          height: size - 4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.g1.withValues(alpha: 0.45 + 0.5 * glow),
            boxShadow: [
              BoxShadow(
                color: AppColors.g1.withValues(alpha: 0.5 * glow),
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
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.cardGradient,
          ),
          child: const DrawnCheck(visible: true, size: 12, strokeWidth: 2),
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
    final skipped = state == _RegionState.skipped;
    return AnimatedContainer(
      duration: ScanMotion.of(context, ScanMotion.medium),
      height: 50,
      decoration: AppGlass.surface(
        borderRadius: BorderRadius.circular(12),
        borderColor: done ? AppColors.g1 : null,
        borderWidth: done ? 1.4 : 1,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            region.code,
            style: figureText(
              size: 11,
              weight: FontWeight.w800,
              color: skipped
                  ? AppColors.secondaryText.withValues(alpha: 0.5)
                  : AppColors.navy,
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
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 18,
            child: Center(child: _StatusIcon(state: state, pulse: pulse)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              skipped ? '${region.shortLabel} · skipped' : region.shortLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: skipped ? AppColors.secondaryText : AppColors.navy,
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
    return GlassCard(
      borderRadius: const BorderRadius.all(Radius.circular(24)),
      borderWidth: 1.4,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: ValueListenableBuilder<double>(
        valueListenable: progress,
        builder: (context, p, _) {
          final step = timeline.stepAt(p);
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
                          'STEP ${step + 1} OF ${ChamberTimeline.stepCount}',
                          style: capsLabel(color: AppColors.g2),
                        ),
                        const SizedBox(height: 5),
                        Semantics(
                          liveRegion: true,
                          child: AnimatedSwitcher(
                            duration: ScanMotion.of(context, ScanMotion.medium),
                            transitionBuilder: ScanMotion.fadeRise,
                            layoutBuilder: (current, previous) => Stack(
                              alignment: Alignment.centerLeft,
                              children: [
                                ...previous,
                                if (current != null) current,
                              ],
                            ),
                            child: Text(
                              done ? 'Report ready' : timeline.labelOf(step),
                              key: ValueKey(done ? -1 : step),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy,
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
                    style: figureText(
                      size: 30,
                      weight: FontWeight.w800,
                      color: AppColors.g2,
                      height: 1,
                    ),
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
                      'Scan #$scanId',
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ),
                  Text(
                    '${timeline.captured.length} of '
                    '${captureRegions.length} views',
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Progress track with a tick at each step and a soft glowing head.
class _TrackPainter extends CustomPainter {
  const _TrackPainter(this.p);
  final double p;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, y - 3, size.width, 6),
      const Radius.circular(3),
    );
    canvas.drawRRect(
        track, Paint()..color = AppColors.navy.withValues(alpha: 0.07));
    for (final s in ChamberTimeline.stepStarts.skip(1)) {
      final x = size.width * s;
      canvas.drawCircle(
        Offset(x, y),
        2,
        Paint()
          ..color = p >= s
              ? AppColors.white
              : AppColors.navy.withValues(alpha: 0.15),
      );
    }
    if (p <= 0) return;
    final fill = Rect.fromLTWH(0, y - 3, size.width * p, 6);
    final gradient = AppColors.primaryGradient
        .createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRRect(
      RRect.fromRectAndRadius(fill.inflate(2), const Radius.circular(4)),
      Paint()
        ..color = AppColors.g1.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(fill, const Radius.circular(3)),
      Paint()..shader = gradient,
    );
    for (final s in ChamberTimeline.stepStarts.skip(1)) {
      if (p < s) continue;
      canvas.drawCircle(Offset(size.width * s, y), 2,
          Paint()..color = AppColors.white.withValues(alpha: 0.9));
    }
    final head = Offset(size.width * p, y);
    canvas.drawCircle(head, 6, Paint()..color = AppColors.white);
    canvas.drawCircle(head, 3.2, Paint()..color = AppColors.g2);
  }

  @override
  bool shouldRepaint(_TrackPainter old) => old.p != p;
}
