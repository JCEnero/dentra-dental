import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_glass.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../screens/record_editor_screen.dart';
import 'record_source_label.dart';

/// Lets the user pick what to add: a clinic visit, a photo or a note.
/// AI screenings come only from the Scan tab, so they aren't offered.
/// [teeth] pre-fills the tooth numbers (e.g. from a tooth's history).
Future<void> showAddRecordSheet(BuildContext context, {List<String>? teeth}) async {
  final source = await showGlassSheet<RecordSource>(
    context: context,
    title: 'Add to your history',
    subtitle: 'Each entry keeps its own label, apart from smart screenings.',
    builder: (sheetContext) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final s in RecordSource.userEntered) ...[
          _Option(
            source: s,
            onTap: () => Navigator.of(sheetContext).pop(s),
          ),
          if (s != RecordSource.userEntered.last)
            Divider(height: 1, color: AppGlass.divider),
        ],
      ],
    ),
  );
  if (source == null || !context.mounted) return;
  await Navigator.of(context, rootNavigator: true)
      .push(RecordEditorScreen.route(source, initialTeeth: teeth));
}

class _Option extends StatelessWidget {
  const _Option({required this.source, required this.onTap});

  final RecordSource source;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (title, icon) = switch (source) {
      RecordSource.clinicRecord => ('Clinic visit', Icons.local_hospital_outlined),
      RecordSource.personalPhoto => ('Personal photo', Icons.photo_outlined),
      _ => ('Personal note', Icons.edit_note_rounded),
    };
    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: recordSourceColor(source).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: AppColors.navy),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    Text(
                      source.description,
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.secondaryText),
            ],
          ),
        ),
      ),
    );
  }
}
