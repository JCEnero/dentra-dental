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
import '../../data/scan_outcomes.dart';
import '../../data/scan_regions.dart';
import '../../data/scan_steps.dart';
import '../../providers/scan_session_provider.dart';
import '../../rendering/scan_scene.dart';
import '../scan_motion.dart';
import '../scan_theme.dart';
import 'scan_chamber_scene.dart';

/// Opens the full-screen 3D scan over the current run. It closes itself when
/// the results are in, zooming out into the page waiting underneath.
Future<void> showScanChamber(BuildContext context) {
  return Navigator.of(context).push(PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 650),
    reverseTransitionDuration: const Duration(milliseconds: 750),
    pageBuilder: (_, __, ___) => const ScanChamberScreen(),
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

/// The 3D scan while the real analysis runs. Everything it counts is real:
/// photos sent, photos the server has finished, and at the end what the
/// results said. Between those events the camera and scanning light keep
/// moving, but progress never gets ahead of the run.
class ScanChamberScreen extends ConsumerStatefulWidget {
  const ScanChamberScreen({super.key});

  @override
  ConsumerState<ScanChamberScreen> createState() => _ScanChamberScreenState();
}

class _ScanChamberScreenState extends ConsumerState<ScanChamberScreen>
    with SingleTickerProviderStateMixin {
  /// Shortest time a step stays up, long enough to read most of its sentences.
  /// A fast server finishes first, and the steps still play through.
  static const _stepSeconds = 3.0;
  static const _settleSeconds = 0.7;
  static const _photoSeconds = 0.5;

  /// How long the wait for the next real event takes to ease to its limit.
  static const _waitSeconds = 1.2;

  late final Ticker _ticker = createTicker(_onTick);
  final _clock = ValueNotifier<int>(0);
  late final _status = ValueNotifier<_ChamberStatus>(_statusFor(0));
  late final ChamberTimeline _timeline;
  ChamberScene? _scene;
  Duration _last = Duration.zero;
  double _p = 0;
  double _t = 0;

  // When the last real event happened, to pace the wait for the next one.
  double _lastEventAt = 0;
  Object? _lastEvent;
  int _landed = 0;
  bool _reduced = false;
  bool _started = false;
  bool _left = false;

  ScanSessionState get _session => ref.read(scanSessionProvider);

  @override
  void initState() {
    super.initState();
    _timeline = ChamberTimeline([
      for (final id in _session.photoIds) scanRegionById(id),
    ]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = ScanMotion.reduced(context);
    if (!_started) {
      _started = true;
      _ticker.start();
      _prepare();
    }
  }

  Future<void> _prepare() async {
    // Photos first: they're shown as soon as the first one is read.
    final thumbs = <String, ui.Image>{};
    final captures = _session.captures;
    () async {
      for (final entry in captures.entries) {
        try {
          final codec = await ui.instantiateImageCodec(entry.value.bytes,
              targetWidth: 520);
          final image = (await codec.getNextFrame()).image;
          codec.dispose();
          if (!mounted) {
            image.dispose();
            return;
          }
          thumbs[entry.key] = image;
        } catch (_) {
          // Drawn as a plain card instead.
        }
      }
    }();
    final model = await ref.read(scanDentitionProvider.future);
    if (!mounted) return;
    setState(() {
      _scene = ChamberScene(
        model: model,
        timeline: _timeline,
        thumbs: thumbs,
        reduced: _reduced,
      );
    });
  }

  void _onTick(Duration elapsed) {
    final dt = math.min((elapsed - _last).inMicroseconds / 1e6, 0.1);
    _last = elapsed;
    _t += dt;

    final session = _session;
    if (session.finishPhase == FinishPhase.analysisFailed ||
        session.finishPhase == FinishPhase.scanning) {
      _leave();
      return;
    }
    final finished = session.finishPhase == FinishPhase.done;
    if (finished && session.analysis?.analysis == null) {
      // Nothing to reveal: no analysis behind this run.
      _leave();
      return;
    }

    final event = (
      session.uploadedCount,
      session.uploadsDone,
      session.analysisProgress?.done
    );
    if (event != _lastEvent) {
      _lastEvent = event;
      _lastEventAt = _t;
    }

    final rate = _rateAt(_p) * (_reduced ? 2 : 1);
    _p = math.min(math.max(_p, _targetFor(session)), _p + rate * dt);
    _p = math.min(_p, 1);

    final landed = _timeline.landedCount(_p);
    if (landed != _landed) {
      _landed = landed;
      HapticFeedback.selectionClick();
    }
    final analysis = session.analysis?.analysis;
    if (analysis != null && _scene?.areas.isEmpty == true) {
      final outcomes = outcomesOf(analysis, session.photoIds);
      _scene?.areas = {
        for (final a in MouthArea.values) a: areaOutcome(a, outcomes),
      };
      _scene?.flagged = {
        for (final e in outcomes.entries)
          if (e.value == ViewOutcome.finding || e.value == ViewOutcome.urgent)
            e.key: e.value,
      };
    }
    final status = _statusFor(_p);
    if (status != _status.value) _status.value = status;
    _clock.value++;

    if (_p >= 1) {
      HapticFeedback.mediumImpact();
      _leave();
    }
  }

  /// The furthest the real run allows progress to be. Between real events it
  /// eases most of the way to the next one, and only an event finishes the job.
  double _targetFor(ScanSessionState session) {
    if (session.finishPhase == FinishPhase.done) return 1;
    final wait = 1 - math.exp(-(_t - _lastEventAt) / _waitSeconds);
    const start = 0.06;
    const build = ChamberTimeline.buildEnd;
    if (!session.uploadsDone) {
      final total = session.uploadTotal;
      if (total == 0) return start * wait;
      return start +
          (build - start) * ((session.uploadedCount + 0.85 * wait) / total);
    }
    const read = ChamberTimeline.readEnd - build;
    final n = math.max(1, _timeline.photos.length);
    final progress = session.analysisProgress;
    if (progress == null) {
      // No word yet, or a server that doesn't report it: approach the first
      // photo's reading point and wait there.
      return build + read * ChamberTimeline.readingHold / n * wait;
    }
    // Every photo read is as far as it goes: the reveal waits for the answer.
    if (progress.done >= n) return ChamberTimeline.readEnd;
    return build +
        read * (progress.done + ChamberTimeline.readingHold * wait) / n;
  }

  double _rateAt(double p) {
    if (p < ChamberTimeline.buildEnd) {
      return ChamberTimeline.buildEnd / (sendingSteps.length * _stepSeconds);
    }
    if (p < ChamberTimeline.readEnd) {
      final n = math.max(1, _timeline.photos.length);
      return (ChamberTimeline.readEnd - ChamberTimeline.buildEnd) /
          math.max(readingSteps.length * _stepSeconds, n * _photoSeconds);
    }
    if (p < ChamberTimeline.revealEnd) {
      return (ChamberTimeline.revealEnd - ChamberTimeline.readEnd) /
          (resultSteps.length * _stepSeconds);
    }
    return (1 - ChamberTimeline.revealEnd) / _settleSeconds;
  }

  /// What the panel shows, in step with what's on stage. The count is real:
  /// photos actually sent, then photos the server has actually finished.
  _ChamberStatus _statusFor(double p) {
    final session = _session;
    final n = _timeline.photos.length;
    final step = ChamberTimeline.stepAt(p);
    final total = session.uploadTotal;
    return _ChamberStatus(
      step: step,
      count: p < ChamberTimeline.buildEnd
          ? (total == 0 ? '' : '${session.uploadedCount} of $total sent')
          : '${_timeline.landedCount(p)} of $n read',
    );
  }

  void _leave() {
    if (_left) return;
    _left = true;
    _ticker.stop();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    _status.dispose();
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
                  label: 'Animation of your scan in progress',
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: ChamberPainter(
                        scene: scene,
                        clock: _clock,
                        progress: () => _p,
                        seconds: () => _t,
                        stageInsets: EdgeInsets.fromLTRB(
                          0,
                          media.padding.top + 66,
                          0,
                          media.padding.bottom + (wide ? 190 : 206),
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
                  child: MediaQuery.withClampedTextScaling(
                    maxScaleFactor: 1.3,
                    child: Column(
                      children: [
                        _TopBar(onClose: _left ? null : _leave),
                        const Spacer(),
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 560),
                            child: ValueListenableBuilder<_ChamberStatus>(
                              valueListenable: _status,
                              builder: (context, status, _) =>
                                  _StatusPanel(status: status),
                            ),
                          ),
                        ),
                      ],
                    ),
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

class _ChamberStatus {
  const _ChamberStatus({required this.step, required this.count});

  final int step;
  final String count;

  @override
  bool operator ==(Object other) =>
      other is _ChamberStatus && other.step == step && other.count == count;

  @override
  int get hashCode => Object.hash(step, count);
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onClose,
          tooltip: 'Keep going in the background',
          style: IconButton.styleFrom(
            backgroundColor: AppColors.white.withValues(alpha: 0.7),
            foregroundColor: AppColors.secondaryText,
            fixedSize: const Size(44, 44),
            side: const BorderSide(color: AppGlass.border),
          ),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 22),
        ),
        Expanded(
          child: Text(
            'Scanning your teeth',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
        ),
        // Balances the button so the title stays centered.
        const SizedBox(width: 44),
      ],
    );
  }
}

/// One step at a time: what we're doing and why, in everyday words.
class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.status});

  final _ChamberStatus status;

  @override
  Widget build(BuildContext context) {
    final step = allScanSteps[status.step];
    return GlassCard(
      borderRadius: const BorderRadius.all(Radius.circular(24)),
      borderWidth: 1.4,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'STEP ${status.step + 1} OF ${allScanSteps.length}',
                  style: capsLabel(color: AppColors.g2),
                ),
              ),
              Text(
                status.count,
                style: figureText(
                  size: 12,
                  weight: FontWeight.w600,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _StepBar(step: status.step),
          const SizedBox(height: 12),
          // Room for the longest step, so the panel doesn't jump between them.
          ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: 110 * MediaQuery.textScalerOf(context).scale(1),
            ),
            child: Semantics(
              liveRegion: true,
              child: AnimatedSwitcher(
                // The old step clears first, so the sentences never overlap.
                duration: ScanMotion.of(context, ScanMotion.slow),
                reverseDuration: ScanMotion.of(context, ScanMotion.fast),
                switchInCurve: const Interval(0.4, 1, curve: ScanMotion.curve),
                transitionBuilder: ScanMotion.fadeRise,
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.topLeft,
                  children: [...previous, if (current != null) current],
                ),
                child: Column(
                  key: ValueKey(status.step),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      step.body,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        height: 1.45,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A segment per step, filled as far as the scan has got.
class _StepBar extends StatelessWidget {
  const _StepBar({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    final duration = ScanMotion.of(context, ScanMotion.medium);
    return ExcludeSemantics(
      child: Row(
        children: [
          for (var i = 0; i < allScanSteps.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: AnimatedContainer(
                duration: duration,
                curve: ScanMotion.curve,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: i <= step ? AppColors.primaryGradient : null,
                  color:
                      i <= step ? null : AppColors.navy.withValues(alpha: 0.08),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
