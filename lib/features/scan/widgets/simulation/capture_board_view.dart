import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_glass.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../shared/widgets/dentra_glass_ui.dart';
import '../../../../shared/widgets/dentra_note_card.dart';
import '../../../../shared/widgets/dentra_page_header.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../data/capture_regions.dart';
import '../../providers/scan_flow_provider.dart';
import '../scan_motion.dart';
import 'region_capture_card.dart';
import 'region_detail_sheet.dart';
import 'scan_sim_theme.dart';

/// Capture step: a card per region, each with its guide, photo and
/// quality check, and a pinned bar to start the 3D scan.
class CaptureBoardView extends ConsumerWidget {
  const CaptureBoardView({
    super.key,
    required this.onBack,
    required this.onStartScan,
  });

  final VoidCallback onBack;
  final VoidCallback onStartScan;

  static const double _maxWidth = 1040;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flow = ref.watch(scanFlowProvider);

    Widget constrained(Widget child) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
              child: child,
            ),
          ),
        );

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DentraPageHeader(
                    title: 'Capture Regions',
                    onBack: onBack,
                    trailing: flow.photos.isEmpty
                        ? null
                        : TextButton(
                            onPressed: () => _confirmClear(context, ref),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.secondaryText,
                              minimumSize: const Size(48, 44),
                              textStyle: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            child: const Text('Clear all'),
                          ),
                    bottom: _CaptureProgress(count: flow.capturedCount),
                  ),
                  Divider(height: 1, thickness: 1, color: AppGlass.divider),
                  const SizedBox(height: 14),
                  constrained(_Toolbar(flow: flow)),
                  const SizedBox(height: 12),
                  constrained(_RegionGrid(
                    onOpen: (region) => showRegionDetail(context, region),
                  )),
                  const SizedBox(height: 16),
                  constrained(const DentraNoteCard(
                    message: 'Tap a card for its guide and step-by-step '
                        'positioning tips. Photos stay on this device.',
                  )),
                ],
              ),
            ),
          ),
          MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.5,
            child: _StartScanBar(flow: flow, onStart: onStartScan),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final count = ref.read(scanFlowProvider).capturedCount;
    final confirmed = await showGlassConfirmDialog(
      context: context,
      icon: Icons.delete_sweep_outlined,
      title: 'Clear all photos?',
      message: 'This removes the $count photo${count == 1 ? '' : 's'} '
          'added so far.',
      confirmLabel: 'Clear all',
      destructive: true,
    );
    if (confirmed) ref.read(scanFlowProvider.notifier).clearPhotos();
  }
}

class _CaptureProgress extends StatelessWidget {
  const _CaptureProgress({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final total = captureRegions.length;
    final done = count == total;
    final duration = ScanMotion.of(context, ScanMotion.medium);
    return Semantics(
      label: '$count of $total regions captured',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < total; i++) ...[
                if (i > 0) const SizedBox(width: 5),
                Expanded(
                  child: AnimatedContainer(
                    duration: duration,
                    curve: ScanMotion.curve,
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: i < count ? AppColors.primaryGradient : null,
                      color: i < count ? null : AppColors.border,
                      boxShadow: i < count
                          ? [
                              BoxShadow(
                                color: AppColors.g1.withValues(alpha: 0.45),
                                blurRadius: 6,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  done
                      ? 'All $total regions captured'
                      : '$count of $total regions captured',
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: done ? AppColors.primary : AppColors.secondaryText,
                  ),
                ),
              ),
              Text(
                '${(count / total * 100).round()}%',
                style: figureText(
                  size: 12.5,
                  color: done ? AppColors.g2 : AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Toolbar extends ConsumerWidget {
  const _Toolbar({required this.flow});
  final ScanFlowState flow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = flow.preparingSamples;
    final enabled = !busy && !flow.allCaptured;
    return Row(
      children: [
        const Expanded(child: SimSectionTitle('Guided views')),
        Semantics(
          button: true,
          enabled: enabled,
          label: 'Use sample photos for the empty regions',
          excludeSemantics: true,
          child: AnimatedOpacity(
            opacity: enabled || busy ? 1 : 0.45,
            duration: ScanMotion.of(context, ScanMotion.fast),
            child: Material(
              color: AppColors.white.withValues(alpha: 0.6),
              shape: const StadiumBorder(
                side: BorderSide(color: AppColors.lavender),
              ),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: enabled
                    ? () => ref.read(scanFlowProvider.notifier).useSamplePhotos()
                    : null,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 40),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        busy
                            ? const SizedBox.square(
                                dimension: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.g2,
                                ),
                              )
                            : const Icon(Icons.auto_awesome_rounded,
                                size: 16, color: AppColors.g2),
                        const SizedBox(width: 7),
                        Text(
                          busy ? 'Preparing…' : 'Use Sample Photos',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.g2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RegionGrid extends StatelessWidget {
  const _RegionGrid({required this.onOpen});

  final ValueChanged<CaptureRegion> onOpen;

  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 640 ? 4 : 2;
      final rows = (captureRegions.length / columns).ceil();
      return Column(
        children: [
          for (var row = 0; row < rows; row++) ...[
            if (row > 0) const SizedBox(height: _gap),
            // Equal heights per row, so buttons line up even when a
            // longer name wraps.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var col = 0; col < columns; col++) ...[
                    if (col > 0) const SizedBox(width: _gap),
                    Expanded(child: _cell(row * columns + col)),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    });
  }

  Widget _cell(int index) {
    if (index >= captureRegions.length) return const SizedBox.shrink();
    final region = captureRegions[index];
    return Reveal(
      delay: Duration(milliseconds: 50 * index),
      child: RegionCaptureCard(
        key: ValueKey(region.id),
        region: region,
        onOpen: () => onOpen(region),
      ),
    );
  }
}

class _StartScanBar extends StatelessWidget {
  const _StartScanBar({required this.flow, required this.onStart});

  final ScanFlowState flow;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final skipped = flow.skippedCount;
    final (IconData icon, Color color, String message) = flow.capturedCount == 0
        ? (
            Icons.info_outline_rounded,
            AppColors.secondaryText,
            'Add at least one photo to start',
          )
        : skipped > 0
            ? (
                Icons.error_outline_rounded,
                HealthColors.monitorInk,
                '$skipped region${skipped == 1 ? '' : 's'} skipped — results '
                    'will be less complete',
              )
            : (
                Icons.check_circle_outline_rounded,
                HealthColors.healthyInk,
                'All 8 regions ready for a full scan',
              );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH, 8, AppSpacing.screenH, 10),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: GlassCard(
            width: double.infinity,
            borderRadius: const BorderRadius.all(Radius.circular(28)),
            borderWidth: 1.2,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  liveRegion: true,
                  child: AnimatedSwitcher(
                    duration: ScanMotion.of(context, ScanMotion.medium),
                    transitionBuilder: ScanMotion.fadeRise,
                    child: Row(
                      key: ValueKey(message),
                      children: [
                        Icon(icon, size: 16, color: color),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            message,
                            style: GoogleFonts.outfit(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                GlowButton(
                  label: flow.allCaptured ? 'Start 3D Scan' : 'Start Scan',
                  icon: Icons.view_in_ar_rounded,
                  intensity: flow.allCaptured ? 1 : 0.35,
                  onTap: flow.canStartScan ? onStart : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
