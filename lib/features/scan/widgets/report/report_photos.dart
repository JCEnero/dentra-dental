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

/// The real photos in one sliding row, the teeth a person can't easily see for
/// themselves first: back molars and inner sides. Each can be opened and zoomed.
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
    final taken = [
      for (final region in regionsForSession(photoIds))
        if (photoIds.contains(region.id)) region,
    ];
    final hard = hardFirst(taken);
    return SizedBox(
      height: 158 + 40 * MediaQuery.textScalerOf(context).scale(1),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        clipBehavior: Clip.none,
        itemCount: hard.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) => SizedBox(
          width: 146,
          child: _PhotoTile(
            region: hard[i],
            image: imageOf(hard[i].id),
            outcome: report?.outcomes[hard[i].id],
            spots: [
              for (final s in report?.spots ?? const <ReportSpot>[])
                if (s.photoId == hard[i].id) s,
            ],
          ),
        ),
      ),
    );
  }

  /// [regions] with the hard-to-see views at the front, otherwise in order.
  static List<ScanRegion> hardFirst(List<ScanRegion> regions) {
    bool hard(ScanRegion r) => hardToSeeViews.contains(baseRegionId(r.id));
    return [...regions.where(hard), ...regions.where((r) => !hard(r))];
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.region,
    required this.image,
    required this.outcome,
    required this.spots,
  });

  final ScanRegion region;
  final ImageProvider? image;
  final ViewOutcome? outcome;
  final List<ReportSpot> spots;

  @override
  Widget build(BuildContext context) {
    final photo = image;
    final count = spots.length;
    final String status = count > 0
        ? '$count ${count == 1 ? 'sign' : 'signs'} marked'
        : switch (outcome) {
            ViewOutcome.retake => 'Needs a retake',
            ViewOutcome.notChecked => 'Not read yet',
            null => 'Saved',
            _ => 'Nothing flagged',
          };
    final markers = markersIn(spots, region.id);
    // A square crop could leave the marks out, so frame it on them.
    final focus = markers.isEmpty
        ? null
        : markers.map((m) => m.box).reduce((a, b) => a.expandToInclude(b));
    return Semantics(
      label: '${region.label}: $status',
      button: photo != null,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: photo == null
            ? null
            : () => openSpotPhoto(
                  context,
                  image: photo,
                  caption: region.label,
                  markers: markers,
                ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                height: 146,
                width: double.infinity,
                child: photo == null
                    ? const MissingPhoto()
                    : SpotPhoto(
                        image: photo,
                        markers: markers,
                        focus: focus,
                        decodeWidth: 600,
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              region.short,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            Text(
              status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 11.5,
                fontWeight: count > 0 ? FontWeight.w700 : FontWeight.w400,
                color:
                    count > 0 ? ScanColors.clearInk : AppColors.secondaryText,
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
      borderRadius: const BorderRadius.all(Radius.circular(24)),
      padding: const EdgeInsets.all(16),
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
