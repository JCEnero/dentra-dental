import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_glass.dart';
import '../../../core/utils/dentra_dates.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../dental_explorer/data/tooth_catalog.dart';
import '../../dental_records/screens/record_detail_screen.dart';
import '../../dental_records/widgets/add_record_sheet.dart';
import '../../dental_records/widgets/record_source_label.dart';
import '../../screening/data/models/screening_session.dart';
import '../screens/screening_detail_screen.dart';
import '../state/history_entry.dart';

/// Opens the details page for a timeline item.
void openHistoryEntry(BuildContext context, HistoryEntry entry) {
  final navigator = Navigator.of(context, rootNavigator: true);
  switch (entry) {
    case ScreeningEntry(:final session):
      navigator.push(ScreeningDetailScreen.route(session.id));
    case RecordEntry(:final record):
      navigator.push(RecordDetailScreen.route(record.id));
  }
}

/// Tooth [fdi]'s history in a sheet, e.g. from a record's tooth chips.
Future<void> showToothHistorySheet(BuildContext context, int fdi) {
  final tooth = ToothCatalog.byFdi(fdi)!;
  return showGlassSheet<void>(
    context: context,
    title: 'Tooth $fdi history',
    subtitle: tooth.name,
    builder: (sheetContext) => ToothHistoryList(
      fdi: fdi,
      onOpen: (entry) {
        Navigator.of(sheetContext).pop();
        openHistoryEntry(context, entry);
      },
    ),
  );
}

/// Every history item for one tooth, each with its source. Screenings are
/// listed only through the AI findings that name this tooth; nothing is
/// assigned to a tooth by the app.
class ToothHistoryList extends ConsumerWidget {
  const ToothHistoryList({
    super.key,
    required this.fdi,
    required this.onOpen,
  });

  final int fdi;
  final ValueChanged<HistoryEntry> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(toothHistoryProvider(fdi));

    final Widget body;
    if (async.hasError && !async.hasValue) {
      body = const _Message(
        text: "Your history couldn't load. Check your connection and try again.",
      );
    } else if (!async.hasValue) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.4),
        ),
      );
    } else if (async.requireValue.isEmpty) {
      body = _Message(
        text: 'Nothing recorded for tooth $fdi yet. Items appear here when you '
            'add this tooth to a visit, photo or note, or when an AI '
            'screening finding names it.',
      );
    } else {
      final entries = async.requireValue;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) Divider(height: 1, color: AppGlass.divider),
            _Row(entry: entries[i], fdi: fdi, onTap: () => onOpen(entries[i])),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        body,
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => showAddRecordSheet(context, teeth: ['$fdi']),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              minimumSize: const Size(44, 44),
              textStyle: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text('Add for tooth $fdi'),
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.entry, required this.fdi, required this.onTap});

  final HistoryEntry entry;
  final int fdi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (title, detail) = switch (entry) {
      ScreeningEntry(:final session) => _screeningText(session),
      RecordEntry(:final record) => (record.displayTitle, null),
    };
    final date = switch (entry) {
      RecordEntry(:final record) when record.dateUnknown =>
        'Date taken unknown · added ${DentraDates.medium(record.recordDate)}',
      _ => DentraDates.medium(entry.at),
    };

    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        RecordSourceLabel(source: entry.source),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            date,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                                fontSize: 12, color: AppColors.secondaryText),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.navy,
                      ),
                    ),
                    if (detail != null)
                      Text(
                        detail,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: AppColors.secondaryText,
                          height: 1.4,
                        ),
                      ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 18),
                child: Icon(Icons.chevron_right_rounded, color: AppColors.secondaryText),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The AI findings for this tooth, worded as the model reported them.
  (String, String?) _screeningText(ScreeningSession s) {
    final findings = [
      for (final f in s.analysis?.findings ?? const <ScreeningFinding>[])
        if (f.tooth?.trim() == '$fdi') f,
    ];
    final title = findings.map((f) => f.label).join(', ');
    final confidence = [
      for (final f in findings)
        if (f.confidence != null) '${(f.confidence! * 100).round()}%',
    ];
    return (
      title.isEmpty ? 'Dental screening' : title,
      'AI-reported finding${findings.length == 1 ? '' : 's'}, not a diagnosis'
          '${confidence.isEmpty ? '' : ' · reported confidence ${confidence.join(', ')}'}',
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 13,
          color: AppColors.secondaryText,
          height: 1.5,
        ),
      ),
    );
  }
}
