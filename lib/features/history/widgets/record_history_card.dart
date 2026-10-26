import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/dentra_image_viewer.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../dental_records/data/models/dental_record.dart';
import '../../dental_records/widgets/record_format.dart';
import '../../dental_records/widgets/record_source_label.dart';

/// One clinic visit, personal photo or personal note on the timeline.
/// Lighter than a screening card: source, date, title, one detail line
/// and a small preview when there is a photo.
class RecordHistoryCard extends StatelessWidget {
  const RecordHistoryCard({
    super.key,
    required this.record,
    required this.onTap,
  });

  final DentalRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final detail = recordDetailLine(record);
    final preview = record.images.firstOrNull;
    final previewImage = preview == null ? null : attachmentImage(preview);
    final files = record.attachments.length;

    return Semantics(
      button: true,
      label: '${record.source.label}. ${record.displayTitle}, '
          '${recordDateLabel(record)}.'
          '${detail != null ? ' $detail.' : ''}'
          '${record.toothNumbers.isNotEmpty ? ' ${teethLabel(record.toothNumbers)}.' : ''}'
          ' Opens details.',
      excludeSemantics: true,
      child: GlassCard(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RecordSourceLabel(source: record.source),
                  const SizedBox(height: 8),
                  Text(
                    recordDateLabel(record),
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.navy.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    record.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  if (detail != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppColors.navy.withValues(alpha: 0.6),
                        height: 1.4,
                      ),
                    ),
                  ],
                  if (record.toothNumbers.isNotEmpty || files > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      [
                        if (record.toothNumbers.isNotEmpty)
                          teethLabel(record.toothNumbers),
                        if (files > 0) '$files ${files == 1 ? 'file' : 'files'}',
                      ].join(' · '),
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.g2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (previewImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox.square(
                  dimension: 56,
                  child: DentraCoverImage(image: previewImage),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: AppColors.g2.withValues(alpha: 0.8),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
