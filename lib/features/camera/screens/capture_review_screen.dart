import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_glass.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../shared/widgets/app_backdrop.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../../shared/widgets/dentra_page_header.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../scan/data/scan_regions.dart';
import '../../scan/widgets/scan_theme.dart';
import '../camera_strings.dart';
import '../state/guided_capture_controller.dart';
import '../widgets/shot_status.dart';

/// What the review page asks the camera to do next.
sealed class ReviewResult {
  const ReviewResult();
}

/// Save the kept photos and analyze them.
final class ReviewSave extends ReviewResult {
  const ReviewSave();
}

/// Back to the camera, at this area.
final class ReviewGoTo extends ReviewResult {
  const ReviewGoTo(this.areaId);
  final String areaId;
}

/// Every area with its photo and check, before the photos go on to the
/// scan's own saving and analysis.
class CaptureReviewScreen extends StatelessWidget {
  const CaptureReviewScreen({super.key, required this.guide});

  final GuidedCaptureController guide;

  static Route<ReviewResult> route(GuidedCaptureController guide) =>
      MaterialPageRoute<ReviewResult>(
        builder: (_) => CaptureReviewScreen(guide: guide),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightLavender,
      body: AppBackdrop(
        child: SafeArea(
          child: ListenableBuilder(
            listenable: guide,
            builder: (context, _) {
              final kept = guide.keptCount;
              final checking = guide.anyChecking;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DentraPageHeader(
                    title: CamText.reviewTitle,
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                  Divider(height: 1, thickness: 1, color: AppGlass.divider),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenH, 18, AppSpacing.screenH, 16),
                      children: [
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            CamText.reviewSummary(kept, guide.total),
                            style: figureText(
                              size: 15,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        GlassCard(
                          borderRadius: BorderRadius.circular(20),
                          child: Column(
                            children: [
                              for (var i = 0; i < guide.areas.length; i++) ...[
                                if (i > 0)
                                  Divider(
                                    height: 1,
                                    thickness: 1,
                                    indent: 92,
                                    color: AppGlass.divider,
                                  ),
                                _AreaRow(
                                  area: guide.areas[i],
                                  guide: guide,
                                  onGoTo: (id) =>
                                      Navigator.of(context).pop(ReviewGoTo(id)),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          CamText.reviewNote,
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            color: AppColors.secondaryText,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenH, 8, AppSpacing.screenH, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (kept == 0 && !checking)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              CamText.reviewNeedsPhoto,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ),
                        DentraButtonRow(
                          secondary: DentraPillButton(
                            label: CamText.backToCamera,
                            variant: DentraButtonVariant.outline,
                            onPressed: () => Navigator.of(context).maybePop(),
                          ),
                          primary: DentraPillButton(
                            label: CamText.saveAndAnalyze,
                            loading: checking,
                            loadingLabel: CamText.waitingForChecks,
                            onPressed: kept > 0 && !checking
                                ? () => Navigator.of(context)
                                    .pop(const ReviewSave())
                                : null,
                          ),
                        ),
                      ],
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

class _AreaRow extends StatelessWidget {
  const _AreaRow({
    required this.area,
    required this.guide,
    required this.onGoTo,
  });

  final ScanRegion area;
  final GuidedCaptureController guide;
  final ValueChanged<String> onGoTo;

  @override
  Widget build(BuildContext context) {
    final shot = guide.shotFor(area.id);
    final skipped = guide.isSkipped(area.id);
    final status = shotStatus(shot, skipped: skipped);
    final action = switch (shot?.check) {
      null => (CamText.takeNow, () => onGoTo(area.id)),
      ShotCheck.rejected => (CamText.retake, () => onGoTo(area.id)),
      ShotCheck.error => (CamText.checkAgain, () => guide.recheck(area.id)),
      ShotCheck.passed => (CamText.retake, () => onGoTo(area.id)),
      ShotCheck.checking => null,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      child: Row(
        children: [
          SizedBox(
            width: 68,
            height: 51,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: shot == null
                  ? const ColoredBox(
                      color: AppColors.lightLavender,
                      child: Icon(
                        Icons.photo_camera_outlined,
                        color: ScanColors.muted,
                        size: 22,
                      ),
                    )
                  : Image.memory(
                      shot.image.bytes,
                      fit: BoxFit.cover,
                      cacheWidth: 204,
                      gaplessPlayback: true,
                      excludeFromSemantics: true,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    area.label,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (status != null) ...[
                        if (shot?.check == ShotCheck.checking)
                          const SizedBox.square(
                            dimension: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.6,
                              color: AppColors.primary,
                            ),
                          )
                        else
                          Icon(status.icon, size: 14, color: status.color),
                        const SizedBox(width: 5),
                      ],
                      Flexible(
                        child: Text(
                          shot?.check == ShotCheck.passed
                              ? CamText.reviewReady
                              : status?.label ?? CamText.notTaken,
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: status?.color ?? AppColors.secondaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: action.$2,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                minimumSize: const Size(48, 44),
                textStyle: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(action.$1),
            ),
        ],
      ),
    );
  }
}
