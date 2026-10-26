import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/models/captured_image.dart';
import '../data/scan_regions.dart';
import '../providers/scan_session_provider.dart';
import 'scan_feedback_panel.dart';
import 'scan_motion.dart';
import 'visuals/region_visual.dart';

/// The selected region: its guide visual or real photo, positioning
/// guidance, and feedback for the capture in progress.
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
    final index = scanRegions.indexOf(region);
    final captured = session.captures[region.id];

    return GlassCard(
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: ScanMotion.of(context, ScanMotion.medium),
                  transitionBuilder: ScanMotion.fadeRise,
                  layoutBuilder: _topLeftStack,
                  child: Column(
                    key: ValueKey(region.id),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'REGION ${index + 1} OF ${scanRegions.length}',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: AppColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Semantics(
                        header: true,
                        child: Text(
                          region.label,
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _StatusChip(session: session, captured: captured != null),
            ],
          ),
          _SavedNotice(
            regionId: session.lastSavedRegionId,
            savedCount: session.savedCount,
          ),
          const SizedBox(height: 12),
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: maxVisualHeight,
                maxWidth: maxVisualHeight * kStageAspect,
              ),
              child: AspectRatio(
                aspectRatio: kStageAspect,
                child: _VisualFrame(
                  session: session,
                  region: region,
                  captured: captured,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
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
      return _Steps(
        key: const ValueKey('review'),
        title: 'Check your photo',
        steps: [
          'Make sure your ${region.label.toLowerCase()} teeth are sharp '
              'and centered',
          "Retake if they're cut off, dark or blurry",
        ],
      );
    }
    if (captured != null && session.capturePhase == CapturePhase.idle) {
      return _Steps(
        key: ValueKey('done-${region.id}'),
        title: 'Captured',
        steps: const ['You can retake this region any time before you finish'],
        done: true,
      );
    }
    return _Steps(
      key: ValueKey('guide-${region.id}'),
      title: 'How to position',
      steps: [
        region.instruction,
        'Center the highlighted teeth in the frame',
        'Use good light and hold steady',
      ],
    );
  }
}

const double kStageAspect = 10 / 7;

Widget _topLeftStack(Widget? current, List<Widget> previous) => Stack(
      alignment: Alignment.topLeft,
      children: [...previous, if (current != null) current],
    );

/// User-facing wording for capture failures. No internal details.
(String, String) captureFailureCopy(CaptureFailure failure) =>
    switch (failure) {
      CaptureFailure.permissionDenied => (
          'Camera access is off',
          "Allow camera access for DENTRA in your phone's Settings, "
              'then try again.',
        ),
      CaptureFailure.cameraUnavailable => (
          'No camera available',
          "This device can't open a camera. Choose a photo instead.",
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
          'Check the device connection and try again.',
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

    final Widget content;
    final String tag;
    if (reviewing && pending != null) {
      content = _Photo(
        key: ValueKey('pending-${pending.capturedAt.microsecondsSinceEpoch}'),
        bytes: pending.bytes,
        label: 'Photo of ${region.label} waiting for review',
      );
      tag = 'New photo';
    } else if (captured != null && !busy) {
      content = _Photo(
        key: ValueKey('cap-${region.id}-'
            '${captured!.capturedAt.microsecondsSinceEpoch}'),
        bytes: captured!.bytes,
        label: 'Captured photo of ${region.label}',
      );
      tag = 'Your photo';
    } else {
      content = DecoratedBox(
        key: ValueKey('ref-${region.id}'),
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.2, -0.3),
            radius: 1.0,
            colors: [AppColors.white, AppColors.lightLavender],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 22, 10, 8),
          child: Center(child: RegionVisual(region: region)),
        ),
      );
      tag = 'Guide';
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        fit: StackFit.expand,
        children: [
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
            child: content,
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.lavender),
              ),
            ),
          ),
          Positioned(
            top: 10,
            left: 10,
            child: ExcludeSemantics(child: _FrameTag(tag)),
          ),
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

class _FrameTag extends StatelessWidget {
  const _FrameTag(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lavender),
      ),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

/// Shown while the system camera is open or an image is transferring.
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
        : 'Waiting for the camera…';
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

// ── Header chips and notices ────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.session, required this.captured});

  final ScanSessionState session;
  final bool captured;

  @override
  Widget build(BuildContext context) {
    final (label, icon, strong) = switch (session.capturePhase) {
      CapturePhase.awaitingCamera => ('Camera open', null, false),
      CapturePhase.receiving => ('Receiving', null, false),
      CapturePhase.reviewing => ('Review', Icons.visibility_outlined, false),
      CapturePhase.failed => ('Not captured', null, false),
      CapturePhase.idle when captured => (
          'Captured',
          Icons.check_rounded,
          true
        ),
      CapturePhase.idle => ('To capture', null, false),
    };
    return AnimatedSwitcher(
      duration: ScanMotion.of(context, ScanMotion.fast),
      child: Container(
        key: ValueKey(label),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          gradient: strong ? AppColors.primaryGradient : null,
          color: strong ? null : AppColors.lightLavender,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 13,
                  color: strong ? AppColors.white : AppColors.primary),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: strong ? AppColors.white : AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Brief confirmation after a region is accepted. Purely a notice; nothing
/// waits on it.
class _SavedNotice extends StatefulWidget {
  const _SavedNotice({required this.regionId, required this.savedCount});

  final String? regionId;
  final int savedCount;

  @override
  State<_SavedNotice> createState() => _SavedNoticeState();
}

class _SavedNoticeState extends State<_SavedNotice> {
  Timer? _hide;
  bool _visible = false;

  @override
  void didUpdateWidget(_SavedNotice old) {
    super.didUpdateWidget(old);
    if (widget.savedCount > old.savedCount && widget.regionId != null) {
      _hide?.cancel();
      setState(() => _visible = true);
      _hide = Timer(const Duration(milliseconds: 2600), () {
        if (mounted) setState(() => _visible = false);
      });
    } else if (widget.savedCount == 0 && _visible) {
      _hide?.cancel();
      setState(() => _visible = false);
    }
  }

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.regionId;
    return AnimatedSize(
      duration: ScanMotion.of(context, ScanMotion.medium),
      curve: ScanMotion.curve,
      child: !_visible || id == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Semantics(
                liveRegion: true,
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.lightLavender,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      TweenAnimationBuilder<double>(
                        key: ValueKey(widget.savedCount),
                        tween: Tween(begin: 0.5, end: 1),
                        duration: ScanMotion.of(context, ScanMotion.slow),
                        curve: ScanMotion.curve,
                        builder: (context, s, child) =>
                            Transform.scale(scale: s, child: child),
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.primaryGradient,
                          ),
                          child: const Icon(Icons.check_rounded,
                              size: 13, color: AppColors.white),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${scanRegionById(id).label} saved',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                    ],
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
    required this.title,
    required this.steps,
    this.done = false,
  });

  final String title;
  final List<String> steps;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 8),
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
