import 'package:flutter/material.dart';
import '../../../shared/widgets/glass_card.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../shared/widgets/primary_button.dart';
import '../data/models/captured_image.dart';
import '../data/scan_regions.dart';
import '../providers/scan_session_provider.dart';
import 'scan_motion.dart';
import 'scan_theme.dart';

/// Pinned above the tab bar so the next step is always reachable,
/// whatever the screen height.
class ScanActionBar extends StatelessWidget {
  const ScanActionBar({
    super.key,
    required this.session,
    required this.source,
    required this.onCapture,
    required this.onAccept,
    required this.onRetake,
    required this.onSelect,
    required this.onFinish,
    required this.onRetryAnalysis,
    required this.onSkipAnalysis,
    required this.onNewScan,
    required this.onStart,
    required this.onRetakeFlagged,
  });

  final ScanSessionState session;

  /// Where a new capture would come from right now.
  final CaptureSource source;
  final ValueChanged<CaptureSource> onCapture;
  final VoidCallback onAccept;
  final VoidCallback onRetake;
  final ValueChanged<String> onSelect;
  final VoidCallback onFinish;
  final VoidCallback onRetryAnalysis;
  final VoidCallback onSkipAnalysis;
  final VoidCallback onNewScan;
  final VoidCallback onStart;
  final VoidCallback onRetakeFlagged;

  @override
  Widget build(BuildContext context) {
    final content = _content();
    return AnimatedSize(
      duration: ScanMotion.of(context, ScanMotion.medium),
      curve: ScanMotion.curve,
      alignment: Alignment.bottomCenter,
      // The start button's glow reaches past the bar.
      clipBehavior: Clip.none,
      child: switch (content) {
        null => const SizedBox(width: double.infinity),
        // The start page's one action stands on its own, with no card round it.
        _ when _isIntro => Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH, 8, AppSpacing.screenH, 12),
            child: content,
          ),
        // Floating glass card, inset like the tab bar pill below it,
        // with clear space between the two.
        _ => Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH, 8, AppSpacing.screenH, 10),
            child: GlassCard(
              width: double.infinity,
              borderRadius: const BorderRadius.all(Radius.circular(28)),
              borderWidth: 1.2,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: AnimatedSwitcher(
                duration: ScanMotion.of(context, ScanMotion.fast),
                child: content,
              ),
            ),
          ),
      },
    );
  }

  bool get _isIntro =>
      !session.started && session.finishPhase == FinishPhase.scanning;

  Widget? _content() {
    if (_isIntro) {
      return GlowButton(
        key: const ValueKey('start'),
        label: 'Start scan',
        icon: Icons.arrow_forward_rounded,
        intensity: 0.7,
        onTap: onStart,
      );
    }
    switch (session.finishPhase) {
      case FinishPhase.saving:
      case FinishPhase.analyzing:
        return null;
      case FinishPhase.analysisFailed:
        return _pair(
          key: 'analysis-failed',
          secondary: ('Skip for now', onSkipAnalysis),
          primary: ('Try again', onRetryAnalysis),
        );
      case FinishPhase.done:
        final retakes = session.analysis?.analysis?.qualityIssues
                .where((i) => i.modality == 'rgb')
                .map((i) => i.regionId)
                .toSet()
                .length ??
            0;
        if (retakes > 0) {
          return _pair(
            key: 'retake-flagged',
            secondary: ('New scan', onNewScan),
            primary: (
              'Retake $retakes photo${retakes == 1 ? '' : 's'}',
              onRetakeFlagged,
            ),
          );
        }
        return PrimaryButton(
          key: const ValueKey('new'),
          label: 'Start new scan',
          onTap: onNewScan,
        );
      case FinishPhase.scanning:
        break;
    }

    final region = session.selectedRegion;
    switch (session.capturePhase) {
      case CapturePhase.awaitingCamera:
        return const _BusyButton(
            key: ValueKey('wait'), label: 'Waiting for device…');
      case CapturePhase.receiving:
        return const _BusyButton(
            key: ValueKey('recv'), label: 'Receiving image…');
      case CapturePhase.reviewing:
        return _pair(
          key: 'review',
          secondary: ('Retake', onRetake),
          primary: ('Use photo', onAccept),
        );
      case CapturePhase.failed:
        final failure = session.captureFailure;
        final retrySource = session.pendingSource ?? source;
        if (failure == CaptureFailure.cameraUnavailable) {
          return _withCaption(
            key: 'no-camera',
            button: PrimaryButton(
              label: 'Choose a photo',
              onTap: () => onCapture(CaptureSource.photoLibrary),
            ),
          );
        }
        if (failure == CaptureFailure.permissionDenied) {
          return _pair(
            key: 'denied',
            secondary: (
              'Choose a photo',
              () => onCapture(CaptureSource.photoLibrary),
            ),
            primary: ('Try again', () => onCapture(retrySource)),
          );
        }
        return PrimaryButton(
          key: const ValueKey('retry'),
          label: 'Try again',
          onTap: () => onCapture(retrySource),
        );
      case CapturePhase.idle:
        break;
    }

    // Not while an empty second photo is open: that's still to capture.
    if (session.allCaptured && session.isCaptured(region.id)) {
      return _withCaption(
        key: 'finish-all-${region.id}',
        button: GlowButton(
          label: 'Finish scan',
          icon: Icons.arrow_forward_rounded,
          intensity: 1,
          onTap: onFinish,
        ),
        region: region,
      );
    }

    final next = _nextOpen();
    if (session.isCaptured(region.id) && next != null) {
      return _withCaption(
        key: 'next-${region.id}',
        button: _pairRow(
          secondary: ('Retake', () => onCapture(source)),
          primary: ('Next: ${next.label}', () => onSelect(next.id)),
        ),
        region: region,
      );
    }

    return _withCaption(
      key: 'capture-${region.id}-$source',
      button: Row(
        children: [
          Expanded(
            child: GlowButton(
              label: source == CaptureSource.photoLibrary
                  ? 'Choose a photo'
                  : 'Capture with device',
              icon: source == CaptureSource.photoLibrary
                  ? Icons.photo_library_outlined
                  : Icons.photo_camera_outlined,
              intensity: 0.7,
              onTap: () => onCapture(source),
            ),
          ),
          if (source == CaptureSource.phoneCamera) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => onCapture(CaptureSource.photoLibrary),
              tooltip: 'Choose a photo instead',
              style: IconButton.styleFrom(
                backgroundColor: AppColors.white.withValues(alpha: 0.6),
                foregroundColor: AppColors.g2,
                fixedSize: const Size(54, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.lavender),
                ),
              ),
              icon: const Icon(Icons.photo_library_outlined, size: 20),
            ),
          ],
        ],
      ),
    );
  }

  ScanRegion? _nextOpen() {
    final start = scanRegionIndex(session.selectedRegionId);
    for (var i = 1; i <= scanRegions.length; i++) {
      final r = scanRegions[(start + i) % scanRegions.length];
      if (!session.isCaptured(r.id)) return r;
    }
    return null;
  }

  /// Once something is captured, adds a way to finish early with partial
  /// coverage and to add a second photo of this view.
  Widget _withCaption({
    required String key,
    required Widget button,
    ScanRegion? region,
  }) {
    final canFinishEarly = session.canFinish &&
        (!session.allCaptured || !session.isCaptured(session.selectedRegionId));
    final second = region == null || isSecondPhoto(region.id)
        ? null
        : secondPhotoId(region.id);
    TextButton link(String label, VoidCallback onPressed) => TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            minimumSize: const Size(48, 40),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            textStyle: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: Text(label),
        );
    return Column(
      key: ValueKey(key),
      mainAxisSize: MainAxisSize.min,
      children: [
        button,
        if (canFinishEarly || second != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            // Wraps onto two lines with large text instead of overflowing.
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (second != null)
                  link(
                    session.isCaptured(second)
                        ? 'See second photo'
                        : 'Add another photo',
                    () => onSelect(second),
                  ),
                if (canFinishEarly)
                  link(
                    'Finish with ${session.capturedViewCount} of '
                    '${scanRegions.length}',
                    onFinish,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _pair({
    required String key,
    required (String, VoidCallback) secondary,
    required (String, VoidCallback) primary,
  }) =>
      KeyedSubtree(
        key: ValueKey(key),
        child: _pairRow(secondary: secondary, primary: primary),
      );

  Widget _pairRow({
    required (String, VoidCallback) secondary,
    required (String, VoidCallback) primary,
  }) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: PrimaryButton(
            label: secondary.$1,
            variant: ButtonVariant.secondary,
            onTap: secondary.$2,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 3,
          child: PrimaryButton(label: primary.$1, onTap: primary.$2),
        ),
      ],
    );
  }
}

/// A primary button that is visibly busy and not tappable.
class _BusyButton extends StatelessWidget {
  const _BusyButton({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Opacity(
        opacity: 0.7,
        child: PrimaryButton(
          label: label,
          trailing: const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.white,
            ),
          ),
        ),
      ),
    );
  }
}
