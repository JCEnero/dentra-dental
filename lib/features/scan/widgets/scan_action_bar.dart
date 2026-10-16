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

  @override
  Widget build(BuildContext context) {
    final content = _content();
    return AnimatedSize(
      duration: ScanMotion.of(context, ScanMotion.medium),
      curve: ScanMotion.curve,
      alignment: Alignment.bottomCenter,
      child: content == null
          ? const SizedBox(width: double.infinity)
          : GlassBar(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH, 12, AppSpacing.screenH, 12),
                child: AnimatedSwitcher(
                  duration: ScanMotion.of(context, ScanMotion.fast),
                  child: content,
                ),
              ),
            ),
    );
  }

  Widget? _content() {
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
            key: ValueKey('wait'), label: 'Waiting for camera…');
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

    if (session.allCaptured) {
      return _withCaption(
        key: 'finish-all',
        button: PrimaryButton(label: 'Finish scan', onTap: onFinish),
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
      );
    }

    return _withCaption(
      key: 'capture-${region.id}-$source',
      button: PrimaryButton(
        label: switch (source) {
          CaptureSource.photoLibrary => 'Choose ${region.label} photo',
          _ => 'Capture ${region.label}',
        },
        trailing: Icon(
          source == CaptureSource.photoLibrary
              ? Icons.photo_library_outlined
              : Icons.photo_camera_outlined,
          size: 18,
          color: AppColors.white,
        ),
        onTap: () => onCapture(source),
      ),
      caption: switch (source) {
        CaptureSource.device => 'Uses your DENTRA device',
        CaptureSource.phoneCamera => 'Opens your phone camera',
        CaptureSource.photoLibrary => 'Camera not available on this device',
      },
    );
  }

  ScanRegion? _nextOpen() {
    final start = scanRegions.indexOf(session.selectedRegion);
    for (var i = 1; i <= scanRegions.length; i++) {
      final r = scanRegions[(start + i) % scanRegions.length];
      if (!session.isCaptured(r.id)) return r;
    }
    return null;
  }

  /// Adds the source caption and, once something is captured, a way to
  /// finish early with partial coverage.
  Widget _withCaption({
    required String key,
    required Widget button,
    String? caption,
  }) {
    final canFinishEarly = session.canFinish && !session.allCaptured;
    return Column(
      key: ValueKey(key),
      mainAxisSize: MainAxisSize.min,
      children: [
        button,
        if (caption != null || canFinishEarly)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            // Wraps onto two lines with large text instead of overflowing.
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  caption ?? '',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                  ),
                ),
                if (canFinishEarly)
                  TextButton(
                    onPressed: onFinish,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      minimumSize: const Size(48, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      textStyle: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: Text(
                      'Finish with ${session.capturedCount} of '
                      '${scanRegions.length}',
                    ),
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
