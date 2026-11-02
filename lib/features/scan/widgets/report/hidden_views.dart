import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/scan_outcomes.dart';
import '../../data/scan_regions.dart';
import '../../data/scan_report.dart';
import 'report_style.dart';
import 'spot_photo.dart';

/// The places a mirror can't show: back molars and inner sides. Large, because
/// for many people this is the first good look they've had at these teeth.
/// Open on the page rather than in a card, photos first.
class HiddenViews extends StatelessWidget {
  const HiddenViews({super.key, required this.report, required this.imageOf});

  final ScreeningReport report;
  final ImageProvider? Function(String photoId) imageOf;

  /// The hard-to-see photos this scan has.
  static List<String> photosIn(ScreeningReport report) => [
        for (final id in report.photoIds)
          if (hardToSeeViews.contains(baseRegionId(id))) id,
      ];

  @override
  Widget build(BuildContext context) {
    final photos = photosIn(report);
    return LayoutBuilder(builder: (context, c) {
      const gap = 12.0;
      final columns = c.maxWidth < 280 ? 1 : 2;
      final width = (c.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: 14,
        children: [
          for (final id in photos)
            SizedBox(
              width: width,
              child: _HiddenPhoto(
                region: findScanRegion(id)!,
                image: imageOf(id),
                outcome: report.outcomes[id],
                spots: [
                  for (final s in report.spots)
                    if (s.photoId == id) s,
                ],
              ),
            ),
        ],
      );
    });
  }
}

class _HiddenPhoto extends StatelessWidget {
  const _HiddenPhoto({
    required this.region,
    required this.image,
    required this.outcome,
    required this.spots,
  });

  final ScanRegion region;
  final ImageProvider? image;
  final ViewOutcome? outcome;
  final List<ReportSpot> spots;

  String get _status {
    if (spots.isNotEmpty) {
      final n = spots.length;
      return '$n ${n == 1 ? 'sign' : 'signs'} marked';
    }
    return switch (outcome) {
      ViewOutcome.notChecked => 'Saved. Not read yet',
      ViewOutcome.retake => 'Needs a retake',
      null => 'Saved',
      _ => 'Read. Nothing flagged',
    };
  }

  @override
  Widget build(BuildContext context) {
    final photo = image;
    final markers = markersIn(spots, region.id);
    // A square crop could leave the marks out, so frame it on them.
    final focus = markers.isEmpty
        ? null
        : markers.map((m) => m.box).reduce((a, b) => a.expandToInclude(b));
    return Semantics(
      button: photo != null,
      label: '${region.label}: $_status.'
          '${photo == null ? '' : ' Opens full size.'}',
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
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 1,
                child: photo == null
                    ? const MissingPhoto()
                    : SpotPhoto(
                        image: photo,
                        markers: markers,
                        focus: focus,
                        decodeWidth: 900,
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              region.short,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            Text(_status, style: reportNote),
          ],
        ),
      ),
    );
  }
}
