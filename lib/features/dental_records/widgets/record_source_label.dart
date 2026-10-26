import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../data/models/dental_record.dart';

export '../data/models/dental_record.dart' show RecordSource;

/// Accent per source, from the existing palette. Used only for the small
/// dot and tint beside the label; the text itself stays navy so it reads
/// at full contrast.
Color recordSourceColor(RecordSource source) => switch (source) {
      RecordSource.aiScreening => AppColors.g2,
      RecordSource.clinicRecord => AppColors.navy,
      RecordSource.personalPhoto => AppColors.coral,
      RecordSource.personalNote => AppColors.secondaryText,
    };

/// Compact source label shown on every history item, e.g. "AI Screening".
class RecordSourceLabel extends StatelessWidget {
  const RecordSourceLabel({super.key, required this.source});

  final RecordSource source;

  @override
  Widget build(BuildContext context) {
    final color = recordSourceColor(source);
    return Semantics(
      label: 'Source: ${source.label}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(7, 3, 8, 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                source.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Source label with its one-line description, for the top of a record's
/// detail page ("AI Screening · AI-assisted visual screening result").
class RecordSourceHeader extends StatelessWidget {
  const RecordSourceHeader({super.key, required this.source});

  final RecordSource source;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          RecordSourceLabel(source: source),
          Text(
            source.description,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}
