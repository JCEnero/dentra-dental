import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../dental_records/data/models/dental_record.dart';
import '../../scan/data/scan_regions.dart';
import '../../screening/data/models/screening_session.dart';
import '../state/history_controller.dart';
import '../state/history_query.dart';

/// Filters and sort for the history list. Changes apply immediately so the
/// result count below stays accurate.
Future<void> showHistoryFilterSheet(BuildContext context) {
  return showGlassSheet<void>(
    context: context,
    title: 'Filter & sort',
    subtitle: 'Narrow your dental history.',
    builder: (_) => const _FilterBody(),
  );
}

class _FilterBody extends ConsumerWidget {
  const _FilterBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(historyControllerProvider).filters;
    final controller = ref.read(historyControllerProvider.notifier);
    final count = ref.watch(historyResultsProvider).valueOrNull?.length;
    void set(HistoryFilters f) => controller.setFilters(f);

    Set<T> toggle<T>(Set<T> set, T value) =>
        set.contains(value) ? ({...set}..remove(value)) : {...set, value};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Label('Period'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final scope in HistoryScope.values)
              DentraChoiceChip(
                label: scope == HistoryScope.calendar
                    ? 'Selected month or day'
                    : scope.label,
                selected: filters.scope == scope,
                onSelected: () => set(filters.copyWith(scope: scope)),
              ),
          ],
        ),
        const _Label('Source'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            DentraChoiceChip(
              label: 'All sources',
              selected: filters.sources.isEmpty,
              onSelected: () => set(filters.copyWith(sources: const {})),
            ),
            for (final source in RecordSource.values)
              DentraChoiceChip(
                label: source.label,
                selected: filters.sources.contains(source),
                onSelected: () => set(filters.copyWith(
                  sources: toggle(filters.sources, source),
                )),
              ),
          ],
        ),
        const _Label('Screening status', hint: 'AI screenings only'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            DentraChoiceChip(
              label: 'Any',
              selected: filters.statuses.isEmpty,
              onSelected: () => set(filters.copyWith(statuses: const {})),
            ),
            for (final status in ScreeningStatus.values)
              DentraChoiceChip(
                label: status.label,
                selected: filters.statuses.contains(status),
                onSelected: () => set(filters.copyWith(
                  statuses: toggle(filters.statuses, status),
                )),
              ),
          ],
        ),
        const _Label('Region captured', hint: 'AI screenings only'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            DentraChoiceChip(
              label: 'Any',
              selected: filters.regions.isEmpty,
              onSelected: () => set(filters.copyWith(regions: const {})),
            ),
            for (final region in scanRegions)
              DentraChoiceChip(
                label: region.label,
                selected: filters.regions.contains(region.id),
                onSelected: () => set(filters.copyWith(
                  regions: toggle(filters.regions, region.id),
                )),
              ),
          ],
        ),
        const _Label('Sort'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final sort in HistorySort.values)
              DentraChoiceChip(
                label: sort.label,
                selected: filters.sort == sort,
                onSelected: () => set(filters.copyWith(sort: sort)),
              ),
          ],
        ),
        const SizedBox(height: 28),
        DentraButtonRow(
          secondary: DentraPillButton(
            label: 'Reset',
            variant: DentraButtonVariant.outline,
            onPressed: filters.isDefault
                ? null
                : () => set(HistoryFilters.defaults),
          ),
          primary: DentraPillButton(
            label: count == null
                ? 'Done'
                : 'Show $count ${count == 1 ? 'result' : 'results'}',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.hint});

  final String text;

  /// Short qualifier after the label, e.g. which records it applies to.
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Semantics(
        header: true,
        child: Text.rich(
          TextSpan(
            text: text.toUpperCase(),
            children: [
              if (hint != null)
                TextSpan(
                  text: '  ·  $hint',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                  ),
                ),
            ],
          ),
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: AppColors.secondaryText,
          ),
        ),
      ),
    );
  }
}
