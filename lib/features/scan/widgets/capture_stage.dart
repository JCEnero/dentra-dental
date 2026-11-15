import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/models/captured_image.dart';
import '../data/scan_regions.dart';
import '../providers/scan_session_provider.dart';
import '../services/photo_check_service.dart';
import 'guide/guide_stage.dart';
import 'scan_feedback_panel.dart';
import 'scan_motion.dart';
import 'scan_theme.dart';

/// The selected view: its live 3D guide or real photo, and how to position
/// the camera.
class CaptureStage extends StatelessWidget {
  const CaptureStage({
    super.key,
    required this.session,
    required this.maxVisualHeight,
  });

  final ScanSessionState session;

  /// Keeps the controls reachable on short screens.
  final double maxVisualHeight;

  @override
  Widget build(BuildContext context) {
    final region = session.selectedRegion;
    final index = scanRegionIndex(region.id);
    final captured = session.captures[region.id];
    final reviewing = session.capturePhase == CapturePhase.reviewing;
    final caption = reviewing
        ? 'New photo'
        : captured != null && !session.isCaptureBusy
            ? 'Your photo'
            : 'What your device should see';

    return GlassCard(
      borderRadius: BorderRadius.circular(28),
      borderWidth: 1.4,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              caption,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.secondaryText,
              ),
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(builder: (context, constraints) {
            return SizedBox(
              width: constraints.maxWidth,
              height: math.min(constraints.maxWidth * 0.62, maxVisualHeight),
              child: _VisualFrame(
                session: session,
                region: region,
                captured: captured,
              ),
            );
          }),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: ScanMotion.of(context, ScanMotion.medium),
            transitionBuilder: ScanMotion.fadeRise,
            layoutBuilder: _topLeftStack,
            child: Column(
              key: ValueKey(region.id),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VIEW ${index + 1} OF ${scanRegions.length}',
                  style: capsLabel(),
                ),
                const SizedBox(height: 3),
                Semantics(
                  header: true,
                  child: Text(
                    region.label,
                    style: GoogleFonts.outfit(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                      letterSpacing: -0.3,
                      height: 1.15,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AnimatedSize(
            duration: ScanMotion.of(context, ScanMotion.medium),
            curve: ScanMotion.curve,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: ScanMotion.of(context, ScanMotion.medium),
              transitionBuilder: ScanMotion.fadeRise,
              layoutBuilder: _topLeftStack,
              child: _guidance(region, captured),
            ),
          ),
        ],
      ),
    );
  }

  Widget _guidance(ScanRegion region, CapturedImage? captured) {
    final failure = session.captureFailure;
    if (session.capturePhase == CapturePhase.failed && failure != null) {
      final copy = captureFailureCopy(failure);
      return ScanFeedbackPanel(
        key: ValueKey('fail-$failure'),
        title: copy.$1,
        message: copy.$2,
      );
    }
    if (session.capturePhase == CapturePhase.reviewing) {
      return _review();
    }
    if (captured != null && session.capturePhase == CapturePhase.idle) {
      return _Steps(
        key: ValueKey('done-${region.id}'),
        steps: const ['You can retake this view any time before you finish'],
        done: true,
      );
    }
    return _Steps(
      key: ValueKey('guide-${region.id}'),
      steps: [region.instruction, ...region.tips],
    );
  }

  /// The photo check on the photo under review: running, couldn't finish,
  /// passed, or rejected with what to do about it.
  Widget _review() {
    final error = session.pendingCheckError;
    if (error != null) {
      return ScanFeedbackPanel(
        key: const ValueKey('check-failed'),
        title: "Couldn't check this photo",
        message: error.message ??
            (error.offline
                ? 'You seem to be offline. Check your connection and try again.'
                : "The photo check isn't responding right now. Please try again."),
      );
    }
    final verdict = session.pendingVerdict;
    if (verdict == null) {
      return const _CheckLine(key: ValueKey('checking'), checking: true);
    }
    if (verdict.passed) {
      return Column(
        key: const ValueKey('passed'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CheckLine(checking: false, teethChecked: verdict.teethChecked),
          const SizedBox(height: 12),
          const _Steps(
            title: 'Check your photo',
            steps: [
              'Make sure it shows the teeth this view asks for',
              "Retake if they're cut off",
            ],
          ),
        ],
      );
    }
    final copy = photoProblemCopy(verdict.problem!, verdict.message);
    return Column(
      key: ValueKey('rejected-${verdict.problem}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ScanFeedbackPanel(title: copy.title, message: copy.why),
        const SizedBox(height: 12),
        _Steps(title: 'How to fix it', steps: copy.steps),
      ],
    );
  }
}

/// What a rejected photo's notice says: the problem, why it matters, and
/// what to do. A problem the app has no words for shows the server's.
({String title, String why, List<String> steps}) photoProblemCopy(
  PhotoProblem problem, [
  String? serverMessage,
]) =>
    switch (problem) {
      PhotoProblem.noTeeth => (
          title: 'No teeth found',
          why: "This photo doesn't show your teeth clearly enough to check.",
          steps: const [
            'Point the device at your teeth',
            'Lift your lips so your teeth show',
            'Keep fingers and tongue out of the way',
          ],
        ),
      PhotoProblem.blurry => (
          title: 'Photo is blurry',
          why: 'Blurry photos can hide early signs, so this one can’t be '
              'checked.',
          steps: const [
            'Hold the device steady',
            'Let it focus for a moment before you capture',
            'Wipe the lens if it’s misty',
          ],
        ),
      PhotoProblem.tooDark => (
          title: 'Too dark',
          why: 'Your teeth need more light to be checked.',
          steps: const [
            'Turn on the device light',
            'Move somewhere brighter',
            'Hold the device a little closer',
          ],
        ),
      PhotoProblem.tooBright => (
          title: 'Too much glare',
          why: 'Bright reflections hide the surface of your teeth.',
          steps: const [
            'Dry your teeth gently with a tissue',
            'Tilt the device slightly',
          ],
        ),
      PhotoProblem.tooSmall => (
          title: 'Photo is too small',
          why: "There isn't enough detail in it to check.",
          steps: const [
            'Take the photo again with the device',
            'Or choose the original full-size photo',
          ],
        ),
      PhotoProblem.unreadable => (
          title: "Couldn't open this photo",
          why: 'The file may be damaged, or in a format DENTRA can’t read.',
          steps: const ['Take the photo again'],
        ),
      PhotoProblem.other => (
          title: "This photo can't be used",
          why: serverMessage ?? 'It didn’t pass the photo check.',
          steps: const ['Take the photo again'],
        ),
    };

/// One line on the photo check: running, or passed.
class _CheckLine extends StatelessWidget {
  const _CheckLine({
    super.key,
    required this.checking,
    this.teethChecked = true,
  });
  final bool checking;

  /// A check that only looked at light and focus doesn't claim teeth.
  final bool teethChecked;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          SizedBox.square(
            dimension: 18,
            child: checking
                ? const Padding(
                    padding: EdgeInsets.all(2.5),
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      color: AppColors.g2,
                    ),
                  )
                : const Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: ScanColors.clearInk,
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              checking
                  ? 'Checking your photo…'
                  : teethChecked
                      ? 'Teeth found, photo is clear'
                      : 'Photo is clear',
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: checking ? AppColors.secondaryText : ScanColors.clearInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _topLeftStack(Widget? current, List<Widget> previous) => Stack(
      alignment: Alignment.topLeft,
      children: [...previous, if (current != null) current],
    );

/// User-facing wording for capture failures. No internal details.
(String, String) captureFailureCopy(CaptureFailure failure) =>
    switch (failure) {
      CaptureFailure.permissionDenied => (
          'Camera access is off',
          'Allow camera access for DENTRA in Settings, then try again.',
        ),
      CaptureFailure.cameraUnavailable => (
          'No camera available',
          "A camera can't be opened right now. Choose a photo instead.",
        ),
      CaptureFailure.captureFailed => (
          "Couldn't get that photo",
          'Something went wrong while capturing. Please try again.',
        ),
      CaptureFailure.deviceTimeout => (
          "The device didn't send the image",
          'Hold the device steady and try again.',
        ),
      CaptureFailure.transferInterrupted => (
          'Image transfer interrupted',
          "Check your device's Wi-Fi connection and try again.",
        ),
    };

// ── Visual frame ────────────────────────────────────────────────

class _VisualFrame extends StatelessWidget {
  const _VisualFrame({
    required this.session,
    required this.region,
    required this.captured,
  });

  final ScanSessionState session;
  final ScanRegion region;
  final CapturedImage? captured;

  @override
  Widget build(BuildContext context) {
    final pending = session.pending;
    final reviewing = session.capturePhase == CapturePhase.reviewing;
    final busy = session.isCaptureBusy;

    Widget? photo;
    if (reviewing && pending != null) {
      photo = _Photo(
        key: ValueKey('pending-${pending.capturedAt.microsecondsSinceEpoch}'),
        bytes: pending.bytes,
        label: 'Photo of ${region.label} waiting for review',
      );
    } else if (captured != null && !busy) {
      photo = _Photo(
        key: ValueKey('cap-${region.id}-'
            '${captured!.capturedAt.microsecondsSinceEpoch}'),
        bytes: captured!.bytes,
        label: 'Captured photo of ${region.label}',
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Stays up under the photo, so the camera flies on from where it
          // was. Paused while covered.
          TickerMode(
            enabled: photo == null,
            child: Semantics(
              image: true,
              label: '${region.label}: ${region.description.toLowerCase()}, '
                  'highlighted on a dental arch illustration',
              child: ExcludeSemantics(child: GuideStage(region: region)),
            ),
          ),
          AnimatedSwitcher(
            duration: ScanMotion.of(context, ScanMotion.slow),
            switchInCurve: ScanMotion.curve,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween(begin: 0.98, end: 1.0).animate(animation),
                child: child,
              ),
            ),
            layoutBuilder: (current, previous) => Stack(
              fit: StackFit.expand,
              children: [...previous, if (current != null) current],
            ),
            child: photo ?? const SizedBox.shrink(key: ValueKey('none')),
          ),
          if (session.isCheckingPending)
            const IgnorePointer(child: _PhotoSweep()),
          if (reviewing && session.pendingVerdict?.passed == false)
            const IgnorePointer(child: _RejectedVeil()),
          if (busy)
            _BusyVeil(
              receiving: session.capturePhase == CapturePhase.receiving,
              progress: session.transferProgress,
            ),
        ],
      ),
    );
  }
}

/// A soft line passing over the photo while it's being measured.
class _PhotoSweep extends StatefulWidget {
  const _PhotoSweep();

  @override
  State<_PhotoSweep> createState() => _PhotoSweepState();
}

class _PhotoSweepState extends State<_PhotoSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ScanMotion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) =>
          CustomPaint(painter: PhotoSweepPainter(_c.value)),
    );
  }
}

/// One pass of the scanning line over a photo, [t] from 0 to 1.
class PhotoSweepPainter extends CustomPainter {
  const PhotoSweepPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * t;
    final trail = Rect.fromLTRB(0, math.max(0, y - 56), size.width, y);
    final a = math.sin(math.pi * t);
    canvas.drawRect(
      trail,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.g1.withValues(alpha: 0),
            AppColors.g1.withValues(alpha: 0.32 * a),
          ],
        ).createShader(trail),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, y - 1, size.width, 2),
      Paint()..color = AppColors.white.withValues(alpha: 0.95 * a),
    );
  }

  @override
  bool shouldRepaint(PhotoSweepPainter old) => old.t != t;
}

/// Fades a photo the check rejected, so it doesn't read as kept.
class _RejectedVeil extends StatelessWidget {
  const _RejectedVeil();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.white.withValues(alpha: 0.55),
      child: const Center(
        child: ScanIconDisc(Icons.refresh_rounded, size: 46, iconSize: 24),
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({super.key, required this.bytes, required this.label});

  final Uint8List bytes;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: label,
      child: LayoutBuilder(builder: (context, constraints) {
        // Decode at display size rather than full camera resolution.
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final width = constraints.maxWidth.isFinite
            ? (constraints.maxWidth * dpr).round()
            : null;
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          cacheWidth: width,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => const ColoredBox(
            color: AppColors.lightLavender,
            child: Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: AppColors.secondaryText,
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Shown while waiting on a capture or an image is transferring.
class _BusyVeil extends StatelessWidget {
  const _BusyVeil({required this.receiving, required this.progress});

  final bool receiving;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final percent = progress == null ? null : (progress! * 100).round();
    final label = receiving
        ? percent == null
            ? 'Receiving image…'
            : 'Receiving image… $percent%'
        : 'Waiting for the device…';
    return Semantics(
      liveRegion: true,
      label: label,
      excludeSemantics: true,
      child: ColoredBox(
        color: AppColors.white.withValues(alpha: 0.72),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            // Never outgrows a small frame at large text sizes.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (receiving)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          color: AppColors.g2,
                          backgroundColor: AppColors.lavender,
                        ),
                      )
                    else
                      const SizedBox.square(
                        dimension: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.6,
                          color: AppColors.g2,
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.navy,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Guidance ────────────────────────────────────────────────────

class _Steps extends StatelessWidget {
  const _Steps({
    super.key,
    this.title,
    required this.steps,
    this.done = false,
  });

  final String? title;
  final List<String> steps;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(
            title!,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 8),
        ],
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.lightLavender,
                  ),
                  alignment: Alignment.center,
                  child: done
                      ? const Icon(Icons.check_rounded,
                          size: 12, color: AppColors.primary)
                      : Text(
                          '${i + 1}',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    steps[i],
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppColors.secondaryText,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
