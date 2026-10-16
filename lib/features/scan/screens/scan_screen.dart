import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../shared/widgets/primary_button.dart';
import '../data/models/captured_image.dart';
import '../providers/device_connection_provider.dart';
import '../providers/scan_session_provider.dart';
import '../services/phone_camera_service.dart';
import '../services/screening_analysis_service.dart';
import '../widgets/capture_stage.dart';
import '../widgets/device_status_card.dart';
import '../widgets/region_selector.dart';
import '../widgets/scan_action_bar.dart';
import '../widgets/scan_header.dart';
import '../widgets/scan_result_view.dart';

/// Guided dental scan: device status, region choice, capture and review,
/// then saving (and analysis, when a backend is configured).
///
/// All state lives in [scanSessionProvider] and [deviceConnectionProvider];
/// this screen only lays it out. Progress survives switching tabs.
class ScanScreen extends ConsumerWidget {
  const ScanScreen({super.key, this.onBack});

  /// Called by the header's back button; hidden when null.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(scanSessionProvider);
    final device = ref.watch(deviceConnectionProvider);
    final camera = ref.watch(phoneCameraServiceProvider);
    final analysisAvailable =
        ref.watch(screeningAnalysisServiceProvider) != null;
    final scan = ref.read(scanSessionProvider.notifier);

    ref.listen(scanSessionProvider.select((s) => s.historySaveFailed),
        (_, failed) {
      if (!failed) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't save this screening to your history."),
          behavior: SnackBarBehavior.floating,
        ),
      );
      scan.acknowledgeHistoryError();
    });

    final source = device.isConnected
        ? CaptureSource.device
        : camera.supportsCamera
            ? CaptureSource.phoneCamera
            : CaptureSource.photoLibrary;
    final scanning = session.finishPhase == FinishPhase.scanning;

    return ColoredBox(
      color: AppColors.white,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(builder: (context, constraints) {
                // The header scrolls with the content and the visual yields
                // space on short screens; only the action bar is pinned, so
                // the next step is always reachable.
                final maxVisual =
                    (constraints.maxHeight * 0.36).clamp(150.0, 300.0);
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ScanHeader(
                        capturedIds: session.captures.keys.toSet(),
                        selectedId: session.selectedRegionId,
                        showProgress: scanning,
                        onBack: onBack,
                        onStartOver: scanning && session.captures.isNotEmpty
                            ? () => _confirmStartOver(context, ref)
                            : null,
                      ),
                      const Divider(
                          height: 1, thickness: 1, color: AppColors.border),
                      const SizedBox(height: 16),
                      ...scanning
                          ? [
                              _padded(DeviceStatusCard(
                                state: device,
                                onConnect: () => ref
                                    .read(deviceConnectionProvider.notifier)
                                    .connect(),
                                onCancel: () => ref
                                    .read(deviceConnectionProvider.notifier)
                                    .disconnect(),
                              )),
                              const SizedBox(height: 22),
                              _padded(const _SectionTitle('Choose a region')),
                              const SizedBox(height: 10),
                              RegionSelector(
                                selectedId: session.selectedRegionId,
                                capturedIds: session.captures.keys.toSet(),
                                enabled: session.canChangeRegion,
                                onSelect: scan.selectRegion,
                              ),
                              _padded(CaptureStage(
                                session: session,
                                maxVisualHeight: maxVisual,
                              )),
                              const SizedBox(height: 16),
                              _padded(const ScanDisclaimer()),
                            ]
                          : [
                              _padded(ScanResultView(
                                session: session,
                                analysisAvailable: analysisAvailable,
                              )),
                            ],
                    ],
                  ),
                );
              }),
            ),
            // Like the tab bar, text grows here only so far, so the pinned
            // bar can't crowd out the content on small screens.
            MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.5,
              child: ScanActionBar(
                session: session,
                source: source,
                onCapture: scan.capture,
                onAccept: scan.acceptPending,
                onRetake: scan.retake,
                onSelect: scan.selectRegion,
                onFinish: scan.finish,
                onRetryAnalysis: scan.retryAnalysis,
                onSkipAnalysis: scan.skipAnalysis,
                onNewScan: scan.reset,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _padded(Widget child) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
        child: child,
      );

  Future<void> _confirmStartOver(BuildContext context, WidgetRef ref) async {
    final count = ref.read(scanSessionProvider).capturedCount;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Start over?',
                style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'This removes the $count image${count == 1 ? '' : 's'} '
                'captured in this session.',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: AppColors.secondaryText,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Keep scanning',
                onTap: () => Navigator.of(context).pop(false),
              ),
              const SizedBox(height: 10),
              PrimaryButton(
                label: 'Start over',
                variant: ButtonVariant.secondary,
                onTap: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true) ref.read(scanSessionProvider.notifier).reset();
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.navy,
        ),
      ),
    );
  }
}
