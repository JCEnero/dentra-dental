import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/dentra_glass_ui.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../data/capture_regions.dart';
import '../../data/models/captured_image.dart';
import '../../providers/scan_flow_provider.dart';
import '../../services/phone_camera_service.dart';
import '../scan_motion.dart';
import 'region_guide_view.dart';
import 'scan_sim_theme.dart';

/// Adds a photo for [region]: camera or library where both exist,
/// otherwise the library (file picker on desktop and web).
Future<void> pickRegionPhoto(
  BuildContext context,
  WidgetRef ref,
  CaptureRegion region,
) async {
  final camera = ref.read(phoneCameraServiceProvider);
  var source = CaptureSource.photoLibrary;
  if (camera.supportsCamera) {
    final chosen = await showGlassSheet<CaptureSource>(
      context: context,
      title: 'Add ${region.label} photo',
      subtitle: region.instruction,
      builder: (sheetContext) => const _SourceChooser(),
    );
    if (chosen == null) return;
    source = chosen;
  }
  try {
    final image = await camera.capture(source);
    if (image == null) return; // closed without a photo
    ref.read(scanFlowProvider.notifier).setPhoto(region.id, image.bytes);
  } on CameraException catch (e) {
    if (!context.mounted) return;
    showDentraSnack(
      context,
      switch (e.failure) {
        CameraFailure.permissionDenied =>
          'Camera access is off. Allow it in Settings, or choose a photo.',
        CameraFailure.unavailable => 'No camera found. Choose a photo instead.',
        CameraFailure.failed => "Couldn't load that photo. Try another one.",
      },
      tone: DentraFeedbackTone.error,
    );
  }
}

class _SourceChooser extends StatelessWidget {
  const _SourceChooser();

  @override
  Widget build(BuildContext context) {
    Widget option(IconData icon, String label, CaptureSource source) {
      return GlassCard(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        onTap: () => Navigator.of(context).pop(source),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.cardGradient,
              ),
              child: Icon(icon, size: 20, color: AppColors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.secondaryText),
          ],
        ),
      );
    }

    return Column(
      children: [
        option(Icons.photo_camera_outlined, 'Take a photo',
            CaptureSource.phoneCamera),
        const SizedBox(height: 10),
        option(Icons.photo_library_outlined, 'Choose from library',
            CaptureSource.photoLibrary),
      ],
    );
  }
}

/// One region on the capture board: its guide until a photo is added,
/// then the photo with a quick quality check and a check badge.
class RegionCaptureCard extends ConsumerWidget {
  const RegionCaptureCard({
    super.key,
    required this.region,
    required this.onOpen,
  });

  final CaptureRegion region;

  /// Opens the region's detail view.
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo =
        ref.watch(scanFlowProvider.select((s) => s.photos[region.id]));
    final passed = photo?.check == PhotoCheck.passed;
    final status = photo == null
        ? 'no photo yet'
        : passed
            ? 'photo added, quality check passed'
            : 'photo added, checking quality';

    return Semantics(
      container: true,
      label: '${region.label}, region ${region.number} of '
          '${captureRegions.length}, $status',
      child: GlassCard(
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        borderColor: passed ? AppColors.g2.withValues(alpha: 0.55) : null,
        borderWidth: passed ? 1.4 : 1,
        onTap: onOpen,
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AnimatedSwitcher(
                      duration: ScanMotion.of(context, ScanMotion.slow),
                      child: photo == null
                          ? RegionGuideView(
                              key: const ValueKey('guide'), region: region)
                          : Image.memory(
                              photo.bytes,
                              key: ObjectKey(photo.bytes),
                              fit: BoxFit.cover,
                              cacheWidth: 480,
                              gaplessPlayback: true,
                              semanticLabel: '${region.label} photo',
                            ),
                    ),
                    Positioned(
                      top: 6,
                      left: 6,
                      child: _CodeChip(region.code, onPhoto: photo != null),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: _CheckBadge(visible: passed),
                    ),
                    if (photo != null)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: _QualityStrip(check: photo.check),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                region.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: AppColors.navy,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                region.technical,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: AppColors.secondaryText,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Spacer(),
            photo == null
                ? _CardButton(
                    icon: Icons.add_a_photo_outlined,
                    label: 'Add Photo',
                    semantic: 'Add ${region.label} photo',
                    filled: true,
                    onTap: () => pickRegionPhoto(context, ref, region),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: _CardButton(
                          icon: Icons.cached_rounded,
                          label: 'Replace',
                          semantic: 'Replace ${region.label} photo',
                          onTap: () => pickRegionPhoto(context, ref, region),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _RemoveButton(
                        semantic: 'Remove ${region.label} photo',
                        onTap: () => ref
                            .read(scanFlowProvider.notifier)
                            .removePhoto(region.id),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}

class _CodeChip extends StatelessWidget {
  const _CodeChip(this.code, {required this.onPhoto});

  final String code;
  final bool onPhoto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: onPhoto
            ? const Color(0x73000000)
            : AppColors.white.withValues(alpha: 0.8),
        border: Border.all(
          color: onPhoto
              ? AppColors.white.withValues(alpha: 0.25)
              : AppColors.lavender,
        ),
      ),
      child: Text(
        code,
        style: hudText(
          size: 9.5,
          weight: FontWeight.w700,
          color: onPhoto ? AppColors.white : AppColors.g2,
        ),
      ),
    );
  }
}

/// Green check that pops and draws in once the quality check passes.
class _CheckBadge extends StatelessWidget {
  const _CheckBadge({required this.visible});
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: visible ? 1 : 0.4,
      duration: ScanMotion.of(context, ScanMotion.medium),
      curve: Curves.easeOutBack,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: ScanMotion.of(context, ScanMotion.fast),
        child: Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: HealthColors.healthy,
            border: Border.all(color: AppColors.white, width: 1.6),
            boxShadow: [
              BoxShadow(
                color: HealthColors.healthy.withValues(alpha: 0.5),
                blurRadius: 8,
              ),
            ],
          ),
          child: DrawnCheck(visible: visible, size: 15, strokeWidth: 2.2),
        ),
      ),
    );
  }
}

/// Mock quality check over the bottom of a photo: a moment of
/// "checking", then three passes.
class _QualityStrip extends StatelessWidget {
  const _QualityStrip({required this.check});
  final PhotoCheck check;

  @override
  Widget build(BuildContext context) {
    final checking = check == PhotoCheck.checking;
    final text = GoogleFonts.outfit(
      fontSize: 10.5,
      fontWeight: FontWeight.w600,
      color: AppColors.white,
    );
    Widget pass(String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: text),
            const SizedBox(width: 2),
            const Icon(Icons.check_rounded,
                size: 12, color: HealthColors.healthy),
          ],
        );
    Widget dot() => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('·', style: text),
        );

    return Semantics(
      liveRegion: true,
      label: checking
          ? 'Checking photo quality'
          : 'Sharp, well-lit and aligned',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x00000000), Color(0xB3000000)],
          ),
        ),
        child: AnimatedSwitcher(
          duration: ScanMotion.of(context, ScanMotion.medium),
          transitionBuilder: ScanMotion.fadeRise,
          child: checking
              ? Row(
                  key: const ValueKey('checking'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox.square(
                      dimension: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.6,
                        color: AppColors.g1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('Checking quality…', style: text),
                  ],
                )
              : FittedBox(
                  key: const ValueKey('passed'),
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      pass('Sharp'),
                      dot(),
                      pass('Well-lit'),
                      dot(),
                      pass('Aligned'),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _CardButton extends StatelessWidget {
  const _CardButton({
    required this.icon,
    required this.label,
    required this.semantic,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final String semantic;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final color = filled ? AppColors.g2 : AppColors.navy;
    return Semantics(
      button: true,
      label: semantic,
      excludeSemantics: true,
      child: Material(
        color: filled
            ? AppColors.lightLavender
            : AppColors.white.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: filled ? AppColors.lavender : AppColors.border,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.semantic, required this.onTap});

  final String semantic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: semantic,
      style: IconButton.styleFrom(
        backgroundColor: AppColors.white.withValues(alpha: 0.5),
        foregroundColor: AppColors.secondaryText,
        fixedSize: const Size(44, 44),
        minimumSize: const Size(44, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      icon: const Icon(Icons.close_rounded, size: 18),
    );
  }
}
