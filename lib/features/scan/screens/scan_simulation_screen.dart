import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/scan_flow_provider.dart';
import '../rendering/scan_scene.dart';
import '../widgets/scan_motion.dart';
import '../widgets/simulation/capture_board_view.dart';
import '../widgets/simulation/device_hub_view.dart';
import '../widgets/simulation/scan_chamber_screen.dart';
import '../widgets/simulation/scan_report_view.dart';

/// The Scan tab as a full simulation: a connected scanner, guided photo
/// capture of eight regions, a 3D scan animation and a mock report.
///
/// Everything runs on the device with mock data. The real capture flow
/// for DENTRA hardware is `ScanScreen`, kept for when a device driver and
/// analysis backend are available.
class ScanSimulationScreen extends ConsumerWidget {
  const ScanSimulationScreen({super.key, this.onNavigate});

  /// Switches app tabs, e.g. to Clinics from the results.
  final ValueChanged<int>? onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Start building the 3D model now, so guides and samples are ready
    // by the time they're needed.
    ref.watch(scanDentitionProvider);
    final flow = ref.watch(scanFlowProvider);
    final notifier = ref.read(scanFlowProvider.notifier);
    final report = flow.report;

    final Widget page = switch (flow.stage) {
      ScanFlowStage.device => DeviceHubView(
          key: const ValueKey('device'),
          onStart: notifier.openCapture,
        ),
      ScanFlowStage.capture => CaptureBoardView(
          key: const ValueKey('capture'),
          onBack: notifier.backToDevice,
          onStartScan: () =>
              showScanChamber(context, onComplete: notifier.completeScan),
        ),
      ScanFlowStage.results => ScanReportView(
          key: ValueKey('results-${report!.id}'),
          report: report,
          onNavigate: onNavigate,
          onScanAgain: notifier.restart,
        ),
    };

    return AnimatedSwitcher(
      duration: ScanMotion.of(context, ScanMotion.slow),
      switchInCurve: ScanMotion.curve,
      transitionBuilder: ScanMotion.fadeRise,
      child: page,
    );
  }
}
