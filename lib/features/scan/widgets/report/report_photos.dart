import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/dentra_image_viewer.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../screening/data/models/screening_session.dart';
import '../../data/scan_outcomes.dart';
import '../../data/scan_regions.dart';
import '../../data/scan_report.dart';
import '../scan_theme.dart';
import 'report_style.dart';
import 'spot_photo.dart';

/// Every view and what came of it, in one sliding row of the real photos.
class ReportPhotoRow extends StatelessWidget {
  const ReportPhotoRow({
    super.key,
    required this.photoIds,
    required this.imageOf,
    this.report,
  });

  final List<String> photoIds;
  final ImageProvider? Function(String photoId) imageOf;

  /// What the analysis said, once it has.
  final ScreeningReport? report;

  @override
  Widget build(BuildContext context) {
    final rows = regionsForSession(photoIds);
    return SizedBox(
      height: 92 + 44 * MediaQuery.textScalerOf(context).scale(1),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        clipBehavior: Clip.none,
        itemCount: rows.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) => SizedBox(
          width: 112,
          child: _PhotoTile(
            region: rows[i],
            image: photoIds.contains(rows[i].id) ? imageOf(rows[i].id) : null,
            taken: photoIds.contains(rows[i].id),
            outcome: report?.outcomes[rows[i].id],
            spots: [
              for (final s in report?.spots ?? const <ReportSpot>[])
                if (s.photoId == rows[i].id) s,
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.region,
    required this.image,
    required this.taken,
    required this.outcome,
    required this.spots,
  });

  final ScanRegion region;
  final ImageProvider? image;
  final bool taken;
  final ViewOutcome? outcome;
  final List<ReportSpot> spots;

  @override
  Widget build(BuildContext context) {
    final photo = image;
    final finding = spots.isEmpty ? null : spots.first;
    final (String status, Color color) = switch (outcome) {
      ViewOutcome.clear when finding != null =>
        (finding.strength.label, AppColors.secondaryText),
      ViewOutcome.clear => ('No concerns seen', ScanColors.clearInk),
      ViewOutcome.finding =>
        (finding?.strength.label ?? 'Worth checking', ScanColors.check),
      ViewOutcome.urgent =>
        (finding?.strength.label ?? 'Worth checking', AppColors.navy),
      ViewOutcome.retake => ('Needs a retake', AppColors.secondaryText),
      ViewOutcome.notChecked => ('Not read yet', AppColors.secondaryText),
      null => (taken ? 'Saved' : 'Not taken', AppColors.secondaryText),
    };
    return Semantics(
      label: '${region.label}: $status',
      button: photo != null,
      excludeSemantics: true,
      child: GlassCard(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        padding: const EdgeInsets.all(5),
        onTap: photo == null
            ? null
            : () => openSpotPhoto(
                  context,
                  image: photo,
                  caption: region.label,
                  markers: markersIn(spots, region.id),
                ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: photo != null
                    ? DentraCoverImage(image: photo)
                    : ColoredBox(
                        color: AppColors.navy.withValues(alpha: 0.05),
                        child: Icon(
                          Icons.hide_image_outlined,
                          size: 18,
                          color: AppColors.secondaryText.withValues(alpha: 0.6),
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(3, 5, 3, 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    region.short,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: taken ? AppColors.navy : AppColors.secondaryText,
                    ),
                  ),
                  Text(
                    status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Photos the quality check couldn't use, each beside how to take it again.
class RetakeList extends StatelessWidget {
  const RetakeList({super.key, required this.issues, required this.imageOf});

  final List<ScreeningQualityIssue> issues;
  final ImageProvider? Function(String photoId) imageOf;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      width: double.infinity,
      borderRadius: const BorderRadius.all(Radius.circular(20)),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Retake for a better check', style: reportCardTitle),
          for (final issue in issues)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imageOf(issue.regionId) case final image?) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox.square(
                        dimension: 48,
                        child: DentraCoverImage(image: image),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      '${scanRegionById(issue.regionId).label}'
                      '${issue.modality == 'nir' ? ' (light scan)' : ''}: '
                      '${issue.message}',
                      style: reportBody,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
