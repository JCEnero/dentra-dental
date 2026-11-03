import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_glass.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../shared/widgets/dentra_page_header.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../dental_profile/providers/dental_profile_providers.dart';
import '../../dental_records/providers/dental_records_provider.dart';
import '../../screening/providers/screening_sessions_provider.dart';
import '../data/check_in_plan.dart';
import '../data/models/captured_image.dart';
import '../providers/device_connection_provider.dart';
import '../providers/scan_session_provider.dart';
import '../rendering/scan_scene.dart';
import '../services/phone_camera_service.dart';
import '../services/screening_analysis_service.dart';
import '../widgets/capture_stage.dart';
import '../widgets/chamber/scan_chamber_screen.dart';
import '../widgets/check_in_sheet.dart';
import '../widgets/device_status_card.dart';
import '../widgets/region_selector.dart';
import '../widgets/scan_action_bar.dart';
import '../widgets/scan_header.dart';
import '../widgets/scan_intro_view.dart';
import '../widgets/scan_motion.dart';
import '../widgets/scan_result_view.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';

/// Guided dental scan: an intro, the guided views with their live 3D guides,
/// then the 3D scan while the real analysis runs, and its results.
///
/// All state lives in [scanSessionProvider] and [deviceConnectionProvider];
/// this screen only lays it out. Progress survives switching tabs.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key, this.onNavigate});

  /// Switches app tabs, e.g. to Clinics from the results.
  final ValueChanged<int>? onNavigate;

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  bool _chamberOpen = false;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// The 3D scan opens as a run starts or restarts, whenever there's a real
  /// analysis to show. Closing it leaves the run going behind this screen.
  void _openChamberOnRun(FinishPhase? previous, FinishPhase next) {
    final starting = next == FinishPhase.saving ||
        (previous == FinishPhase.analysisFailed &&
            next == FinishPhase.analyzing);
    if (!starting || _chamberOpen) return;
    if (ref.read(screeningAnalysisServiceProvider) == null) return;
    _chamberOpen = true;
    showScanChamber(context).whenComplete(() => _chamberOpen = false);
  }

  /// Start asks only what isn't known yet, once per scan. Closing the sheet
  /// without choosing stays on the start page.
  Future<void> _start() async {
    final scan = ref.read(scanSessionProvider.notifier);
    if (ref.read(scanSessionProvider).checkInSeen) {
      scan.start();
      return;
    }
    final plan = CheckInPlan.of(
      now: DateTime.now(),
      profile: ref.read(dentalProfileProvider).valueOrNull,
      sessions: ref.read(screeningSessionsProvider).valueOrNull ?? const [],
      records: ref.read(dentalRecordsProvider).valueOrNull ?? const [],
    );
    if (plan.isEmpty) {
      scan.start();
      return;
    }
    final result = await showCheckInSheet(context, plan);
    if (result == null || !mounted) return;
    scan.start(checkIn: result.answers);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(scanSessionProvider);
    final device = ref.watch(deviceConnectionProvider);
    final camera = ref.watch(phoneCameraServiceProvider);
    final analysisAvailable =
        ref.watch(screeningAnalysisServiceProvider) != null;
    final scan = ref.read(scanSessionProvider.notifier);
    // Start building the 3D model now, so the guides are ready when shown.
    ref.watch(scanDentitionProvider);
    // Load what the check-in needs to know, so Start doesn't have to wait.
    ref.watch(dentalProfileProvider);
    ref.watch(dentalRecordsProvider);

    ref.listen(scanSessionProvider.select((s) => s.historySaveFailed),
        (_, failed) {
      if (!failed) return;
      ScaffoldMessenger.of(context).showSnackBar(dentraSnackBar(
        "Couldn't save this screening to your history.",
        tone: DentraFeedbackTone.error,
      ));
      scan.acknowledgeHistoryError();
    });
    ref.listen(
      scanSessionProvider.select((s) => s.finishPhase),
      _openChamberOnRun,
    );
    // Start may be tapped from far down the start page: begin at the top.
    ref.listen(scanSessionProvider.select((s) => s.started), (_, __) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
    // A tile may be far below the guide it changes, so bring the guide back.
    ref.listen(scanSessionProvider.select((s) => s.selectedRegionId), (_, __) {
      if (!_scroll.hasClients) return;
      final duration = ScanMotion.of(context, ScanMotion.slow);
      if (duration == Duration.zero) {
        _scroll.jumpTo(0);
      } else {
        _scroll.animateTo(0, duration: duration, curve: ScanMotion.curve);
      }
    });

    final source = device.isConnected
        ? CaptureSource.device
        : camera.supportsCamera
            ? CaptureSource.phoneCamera
            : CaptureSource.photoLibrary;
    final scanning = session.finishPhase == FinishPhase.scanning;
    final intro = scanning && !session.started;
    // Nothing to say about the device in builds that can't pair with one.
    final deviceStatus = device.status == DeviceStatus.unsupported
        ? null
        : DeviceStatusCard(
            state: device,
            onConnect: () =>
                ref.read(deviceConnectionProvider.notifier).connect(),
            onCancel: () =>
                ref.read(deviceConnectionProvider.notifier).disconnect(),
          );

    // The start page scrolls on under the status bar, so nothing is cut off
    // at its edge.
    final topInset = intro ? MediaQuery.paddingOf(context).top : 0.0;

    return SafeArea(
      top: !intro,
      bottom: false,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: LayoutBuilder(builder: (context, constraints) {
                    // The header scrolls with the content and the visual
                    // yields space on short screens; only the action bar is
                    // pinned, so the next step is always reachable.
                    final maxVisual =
                        (constraints.maxHeight * 0.34).clamp(140.0, 260.0);
                    final heroHeight =
                        ((constraints.maxHeight - topInset) * 0.47)
                            .clamp(236.0, 340.0);
                    return SingleChildScrollView(
                      controller: _scroll,
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.only(
                        top: topInset,
                        // Clears the fade above the start button.
                        bottom: intro ? 52 : 24,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 640),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (intro)
                                const DentraPageHeader(title: 'Dental Scan')
                              else
                                ScanHeader(
                                  capturedIds: session.captures.keys.toSet(),
                                  selectedId: session.selectedRegionId,
                                  showProgress: scanning,
                                  onBack: scanning ? scan.showIntro : null,
                                  onStartOver: scanning &&
                                          session.captures.isNotEmpty
                                      ? () => _confirmStartOver(context, ref)
                                      : null,
                                ),
                              // The start page's device rises into the header.
                              if (!intro)
                                Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: AppGlass.divider,
                                ),
                              SizedBox(height: intro ? 10 : 16),
                              ...switch ((intro, scanning)) {
                                (true, _) => [
                                    _padded(ScanIntroView(
                                      source: source,
                                      heroHeight: heroHeight,
                                      deviceStatus: deviceStatus,
                                    )),
                                  ],
                                (false, true) => [
                                    _padded(CaptureStage(
                                      session: session,
                                      maxVisualHeight: maxVisual,
                                    )),
                                    const SizedBox(height: 12),
                                    RegionSelector(
                                      selectedId: session.selectedRegionId,
                                      photos: {
                                        for (final e
                                            in session.captures.entries)
                                          e.key: e.value.bytes,
                                      },
                                      enabled: session.canChangeRegion,
                                      onSelect: scan.selectRegion,
                                    ),
                                    if (deviceStatus != null)
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            AppSpacing.screenH,
                                            16,
                                            AppSpacing.screenH,
                                            0),
                                        child: deviceStatus,
                                      ),
                                  ],
                                _ => [
                                    _padded(ScanResultView(
                                      session: session,
                                      analysisAvailable: analysisAvailable,
                                      onNavigate: widget.onNavigate,
                                    )),
                                  ],
                              },
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                // With no card round the start button, content fades into
                // the page above it instead of being cut off.
                if (intro)
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: -14,
                    height: 66,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x00E8F8F7),
                              Color(0xF5E8F8F7),
                              Color(0x00E8F8F7),
                            ],
                            stops: [0, 0.79, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Like the tab bar, text grows here only so far, so the pinned
          // bar can't crowd out the content on small screens.
          MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.5,
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
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
                  onStart: _start,
                  onRetakeFlagged: scan.retakeFlagged,
                ),
              ),
            ),
          ),
        ],
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
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      barrierColor: AppGlass.barrier,
      builder: (context) => GlassSurface(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border:
            const Border(top: BorderSide(color: AppGlass.border, width: 1.2)),
        child: SafeArea(
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
      ),
    );
    if (confirmed == true) ref.read(scanSessionProvider.notifier).reset();
  }
}
