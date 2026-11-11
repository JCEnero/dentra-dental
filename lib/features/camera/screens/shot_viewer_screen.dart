import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_glass.dart';
import '../../../shared/widgets/app_backdrop.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../scan/data/scan_regions.dart';
import '../../scan/widgets/capture_stage.dart' show photoProblemCopy;
import '../camera_strings.dart';
import '../state/guided_capture_controller.dart';
import '../widgets/camera_bits.dart';
import '../widgets/shot_status.dart';

enum ShotAction { retake, delete }

/// One area's photo, full screen, with what the check said and Retake or
/// Delete. "Check again" works in place.
class ShotViewerScreen extends StatelessWidget {
  const ShotViewerScreen({super.key, required this.area, required this.guide});

  final ScanRegion area;
  final GuidedCaptureController guide;

  static Route<ShotAction> route({
    required ScanRegion area,
    required GuidedCaptureController guide,
  }) =>
      MaterialPageRoute<ShotAction>(
        builder: (_) => ShotViewerScreen(area: area, guide: guide),
      );

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showGlassConfirmDialog(
      context: context,
      icon: Icons.delete_outline_rounded,
      title: CamText.deleteTitle,
      message: CamText.deleteBody,
      confirmLabel: CamText.delete,
      destructive: true,
    );
    if (confirmed && context.mounted) {
      Navigator.of(context).pop(ShotAction.delete);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightLavender,
      body: AppBackdrop(
        child: SafeArea(
          child: ListenableBuilder(
            listenable: guide,
            builder: (context, _) {
              final shot = guide.shotFor(area.id);
              // Deleted elsewhere, e.g. replaced while this was open.
              if (shot == null) return const SizedBox.shrink();
              final status = shotStatus(shot)!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          tooltip: CamText.close,
                          style: IconButton.styleFrom(
                            backgroundColor:
                                AppColors.white.withValues(alpha: 0.7),
                            foregroundColor: AppColors.navy,
                            fixedSize: const Size(44, 44),
                          ),
                          icon: const Icon(Icons.close_rounded, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Semantics(
                            header: true,
                            child: Text(
                              area.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, thickness: 1, color: AppGlass.divider),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: InteractiveViewer(
                        maxScale: 4,
                        child: Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.memory(
                              shot.image.bytes,
                              fit: BoxFit.contain,
                              gaplessPlayback: true,
                              semanticLabel: CamText.thumbSemantics(
                                area.label,
                                status.label,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: _Verdict(
                      shot: shot,
                      onRecheck: () => guide.recheck(area.id),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: DentraButtonRow(
                      secondary: DentraPillButton(
                        label: CamText.delete,
                        icon: Icons.delete_outline_rounded,
                        variant: DentraButtonVariant.outline,
                        onPressed: () => _delete(context),
                      ),
                      primary: DentraPillButton(
                        label: CamText.retake,
                        icon: Icons.photo_camera_outlined,
                        onPressed: () =>
                            Navigator.of(context).pop(ShotAction.retake),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// What the photo check said, and how to fix it when it said no.
class _Verdict extends StatelessWidget {
  const _Verdict({required this.shot, required this.onRecheck});

  final AreaShot shot;
  final VoidCallback onRecheck;

  @override
  Widget build(BuildContext context) {
    final status = shotStatus(shot)!;
    final Widget body = switch (shot.check) {
      ShotCheck.checking => const CamBusyLine(CamText.checking),
      ShotCheck.passed => CamInfoRow(
          icon: status.icon,
          title: CamText.checkPassed,
        ),
      ShotCheck.rejected => () {
          final copy = photoProblemCopy(
            shot.verdict!.problem!,
            shot.verdict!.message,
          );
          return CamInfoRow(
            icon: status.icon,
            title: copy.title,
            body: [copy.why, ...copy.steps.map((s) => '• $s')].join('\n'),
          );
        }(),
      ShotCheck.error => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CamInfoRow(
              icon: status.icon,
              title: CamText.checkError,
              body: shot.error?.message ?? CamText.checkErrorBody,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onRecheck,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  textStyle: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text(CamText.checkAgain),
              ),
            ),
          ],
        ),
    };
    return Semantics(
      liveRegion: true,
      child: GlassCard(
        borderRadius: BorderRadius.circular(20),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: AnimatedSize(
          duration: dentraMotion(context),
          alignment: Alignment.topCenter,
          child: body,
        ),
      ),
    );
  }
}
