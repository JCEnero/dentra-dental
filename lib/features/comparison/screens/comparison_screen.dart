import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_glass.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/dentra_dates.dart';
import '../../../shared/widgets/dentra_mascot.dart';
import '../../../shared/widgets/app_backdrop.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../../shared/widgets/dentra_image_viewer.dart';
import '../../../shared/widgets/dentra_page_header.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../dental_records/data/models/dental_record.dart';
import '../../dental_records/providers/dental_records_provider.dart';
import '../../dental_records/screens/record_editor_screen.dart';
import '../../dental_records/widgets/record_format.dart';
import '../../dental_records/widgets/record_source_label.dart';
import '../../history/widgets/screening_history_card.dart' show HistoryMessage;
import '../../history/widgets/tooth_history.dart';
import '../../scan/data/scan_regions.dart';
import '../../scan/widgets/scan_result_view.dart' show ScanDisclaimer;
import '../../screening/data/models/screening_session.dart';
import '../../screening/providers/screening_sessions_provider.dart';
import '../state/comparison_state.dart';
import '../widgets/image_comparison.dart';

/// Comparison (formerly Reports): choose an earlier and a later date,
/// pick a saved screening or photo from each, and see them side by side.
/// Shows what the stored records say; never concludes that something
/// improved or worsened.
class ComparisonScreen extends ConsumerWidget {
  const ComparisonScreen({super.key, this.onStartScreening});

  /// Opens the Scan tab, for users with nothing to compare yet.
  final VoidCallback? onStartScreening;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(comparableItemsProvider);
    final sel = ref.watch(comparisonControllerProvider);
    final controller = ref.read(comparisonControllerProvider.notifier);

    // A record deleted elsewhere drops out of the selection.
    ref.listen(comparableItemsProvider, (_, next) {
      if (next.hasValue) controller.prune(next.requireValue);
    });

    return PopScope(
      // Back from the result returns to the selection first.
      canPop: !sel.showingResult,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) controller.editSelection();
      },
      child: Scaffold(
        backgroundColor: AppColors.lightLavender,
        body: AppBackdrop(
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DentraPageHeader(
                  title: 'Comparison',
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                Divider(height: 1, thickness: 1, color: AppGlass.divider),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(AppSpacing.screenH, 18,
                        AppSpacing.screenH, 32 + MediaQuery.paddingOf(context).bottom),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: AnimatedSwitcher(
                          duration: dentraMotion(context, 220),
                          switchInCurve: Curves.easeOut,
                          layoutBuilder: (current, previous) => Stack(
                            alignment: Alignment.topCenter,
                            children: [...previous, if (current != null) current],
                          ),
                          child: _body(context, ref, items, sel),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<ComparableItem>> items,
    ComparisonSelection sel,
  ) {
    if (items.hasError && !items.hasValue) {
      return HistoryMessage(
        key: const ValueKey('error'),
        icon: Icons.cloud_off_rounded,
        mascot: MascotMood.worried,
        danger: true,
        title: "We couldn't load your history",
        message: 'Check your connection and try again.',
        actions: [
          DentraPillButton(
            label: 'Try again',
            onPressed: () {
              ref.invalidate(screeningSessionsProvider);
              ref.invalidate(dentalRecordsProvider);
            },
          ),
        ],
      );
    }
    if (!items.hasValue) {
      return const Padding(
        key: ValueKey('loading'),
        padding: EdgeInsets.only(top: 60),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    final all = items.requireValue;
    if (all.length < 2) {
      return HistoryMessage(
        key: const ValueKey('empty'),
        icon: Icons.compare_outlined,
        mascot: MascotMood.think,
        title: all.isEmpty ? 'Nothing to compare yet' : 'One more record needed',
        message: 'Comparison needs at least two saved screenings or photos. '
            '${all.isEmpty ? 'You have none yet.' : 'You have one so far.'}',
        actions: [
          if (onStartScreening != null)
            DentraPillButton(
              label: 'Start a screening',
              icon: Icons.document_scanner_outlined,
              onPressed: onStartScreening,
            ),
          DentraPillButton(
            label: 'Add a personal photo',
            variant: DentraButtonVariant.outline,
            icon: Icons.add_photo_alternate_outlined,
            onPressed: () => Navigator.of(context)
                .push(RecordEditorScreen.route(RecordSource.personalPhoto)),
          ),
        ],
      );
    }

    final earlier = _find(all, sel.earlierKey);
    final later = _find(all, sel.laterKey);
    if (sel.showingResult && earlier != null && later != null) {
      return _Result(key: const ValueKey('result'), all: all, earlier: earlier, later: later);
    }
    return _Selection(key: const ValueKey('selection'), all: all, sel: sel);
  }

  static ComparableItem? _find(List<ComparableItem> all, String? key) =>
      key == null ? null : all.where((i) => i.key == key).firstOrNull;
}

// ── Selection ───────────────────────────────────────────────────────────────

Future<void> _chooseDay(
  BuildContext context,
  WidgetRef ref,
  List<ComparableItem> all,
  ComparisonSlot slot,
) async {
  final sel = ref.read(comparisonControllerProvider);
  final days = selectableDays(all, sel, slot);
  final picked = await showGlassSheet<DateTime>(
    context: context,
    title: 'Choose the ${slot.label.toLowerCase()} date',
    subtitle: 'Only dates with saved screenings or photos are listed.',
    builder: (sheetContext) => _DayList(
      days: days,
      all: all,
      selected: sel.dayOf(slot),
      onPick: (d) => Navigator.of(sheetContext).pop(d),
    ),
  );
  if (picked != null) {
    ref.read(comparisonControllerProvider.notifier).setDay(slot, picked, all);
  }
}

class _Selection extends ConsumerWidget {
  const _Selection({super.key, required this.all, required this.sel});

  final List<ComparableItem> all;
  final ComparisonSelection sel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(comparisonControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Choose two dates, then the screening or photo from each to see '
          'them side by side.',
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: AppColors.secondaryText,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        for (final slot in ComparisonSlot.values) ...[
          _SlotCard(all: all, sel: sel, slot: slot),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 8),
        DentraPillButton(
          label: 'Compare',
          icon: Icons.compare_rounded,
          onPressed: sel.canCompare ? controller.showResult : null,
        ),
        if (!sel.canCompare) ...[
          const SizedBox(height: 8),
          Text(
            sel.earlierKey == null || sel.laterKey == null
                ? 'Choose a record for both dates to compare.'
                : 'Choose two different records.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 12, color: AppColors.secondaryText),
          ),
        ],
      ],
    );
  }
}

class _SlotCard extends ConsumerWidget {
  const _SlotCard({required this.all, required this.sel, required this.slot});

  final List<ComparableItem> all;
  final ComparisonSelection sel;
  final ComparisonSlot slot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = sel.dayOf(slot);
    final items = day == null ? const <ComparableItem>[] : itemsOnDay(all, day);
    final otherKey = sel.keyOf(slot.other);
    final chosen = sel.keyOf(slot);

    return GlassCard(
      borderRadius: BorderRadius.circular(20),
      borderColor: chosen != null ? AppColors.g2.withValues(alpha: 0.45) : null,
      borderWidth: chosen != null ? 1.5 : 1,
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slot.label.toUpperCase(),
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      day == null ? 'No date chosen' : DentraDates.full(day),
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: day == null ? AppColors.secondaryText : AppColors.navy,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _chooseDay(context, ref, all, slot),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.g2,
                  minimumSize: const Size(44, 44),
                ),
                child: Text(
                  day == null ? 'Choose date' : 'Change',
                  semanticsLabel: day == null
                      ? 'Choose the ${slot.label.toLowerCase()} date'
                      : 'Change the ${slot.label.toLowerCase()} date',
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (day != null) ...[
            const SizedBox(height: 10),
            if (items.isEmpty)
              Text(
                'No screenings or photos are saved on this date anymore. '
                'Choose another date.',
                style: GoogleFonts.outfit(fontSize: 13, color: AppColors.secondaryText),
              )
            else
              for (final item in items)
                _ItemOption(
                  item: item,
                  selected: item.key == chosen,
                  disabledReason: item.key == otherKey
                      ? 'Already chosen as ${slot.other.label.toLowerCase()}'
                      : null,
                  onTap: () => ref
                      .read(comparisonControllerProvider.notifier)
                      .setItem(slot, item.key),
                ),
          ],
        ],
      ),
    );
  }
}

class _ItemOption extends StatelessWidget {
  const _ItemOption({
    required this.item,
    required this.selected,
    required this.onTap,
    this.disabledReason,
  });

  final ComparableItem item;
  final bool selected;
  final VoidCallback onTap;
  final String? disabledReason;

  @override
  Widget build(BuildContext context) {
    final disabled = disabledReason != null;
    final thumb = item.images.firstOrNull?.image;
    return Semantics(
      button: true,
      selected: selected,
      enabled: !disabled,
      inMutuallyExclusiveGroup: true,
      label: '${item.source.label}, ${item.title}, ${item.when}'
          '${disabled ? '. $disabledReason' : ''}',
      excludeSemantics: true,
      child: Opacity(
        opacity: disabled ? 0.45 : 1,
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: dentraMotion(context, 160),
            margin: const EdgeInsets.only(top: 6, right: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.g2.withValues(alpha: 0.08)
                  : AppColors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? AppColors.g2.withValues(alpha: 0.6)
                    : AppColors.g2.withValues(alpha: 0.14),
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox.square(
                    dimension: 48,
                    child: thumb == null
                        ? const ColoredBox(
                            color: AppColors.lightLavender,
                            child: Icon(Icons.image_not_supported_outlined,
                                size: 20, color: AppColors.secondaryText),
                          )
                        : DentraCoverImage(image: thumb),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RecordSourceLabel(source: item.source),
                      const SizedBox(height: 4),
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy,
                        ),
                      ),
                      Text(
                        disabledReason ??
                            '${item.when} · ${item.images.length} '
                                '${item.images.length == 1 ? 'image' : 'images'}',
                        style: GoogleFonts.outfit(
                            fontSize: 12, color: AppColors.secondaryText),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 20,
                  color: selected ? AppColors.g2 : AppColors.secondaryText,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DayList extends StatelessWidget {
  const _DayList({
    required this.days,
    required this.all,
    required this.selected,
    required this.onPick,
  });

  final List<DateTime> days;
  final List<ComparableItem> all;
  final DateTime? selected;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
      return Text(
        'No dates fit here. The earlier date has to come before the later '
        'one; choose a different date on the other side first.',
        style: GoogleFonts.outfit(fontSize: 14, color: AppColors.secondaryText, height: 1.5),
      );
    }
    final rows = <Widget>[];
    DateTime? month;
    for (final d in days) {
      final m = DentraDates.monthOf(d);
      if (m != month) {
        rows.add(Padding(
          padding: EdgeInsets.fromLTRB(4, rows.isEmpty ? 0 : 14, 4, 6),
          child: Text(
            DentraDates.monthYear(m).toUpperCase(),
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: AppColors.secondaryText,
            ),
          ),
        ));
        month = m;
      }
      final items = itemsOnDay(all, d);
      final sources = {for (final i in items) i.source};
      final isSelected = selected != null && DentraDates.sameDay(d, selected!);
      rows.add(MergeSemantics(
        child: ListTile(
          onTap: () => onPick(d),
          selected: isSelected,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          selectedTileColor: AppColors.g2.withValues(alpha: 0.08),
          title: Text(
            DentraDates.full(d),
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [for (final s in sources) RecordSourceLabel(source: s)],
            ),
          ),
          trailing: Text(
            '${items.length}',
            semanticsLabel: '${items.length} ${items.length == 1 ? 'record' : 'records'}',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.secondaryText,
            ),
          ),
        ),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }
}

// ── Result ──────────────────────────────────────────────────────────────────

class _Result extends ConsumerWidget {
  const _Result({
    super.key,
    required this.all,
    required this.earlier,
    required this.later,
  });

  final List<ComparableItem> all;
  final ComparableItem earlier;
  final ComparableItem later;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(comparisonControllerProvider.notifier);
    final days = DentraDates.dateOnly(later.at)
        .difference(DentraDates.dateOnly(earlier.at))
        .inDays;
    final mixed = earlier.source != later.source;
    final bothImages = earlier.images.isNotEmpty && later.images.isNotEmpty;
    final s1 = earlier.screening, s2 = later.screening;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _SideHeader(
                slot: ComparisonSlot.earlier,
                item: earlier,
                onChange: () => _change(context, ref, ComparisonSlot.earlier),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SideHeader(
                slot: ComparisonSlot.later,
                item: later,
                onChange: () => _change(context, ref, ComparisonSlot.later),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          days == 0 ? 'Same day' : '$days ${days == 1 ? 'day' : 'days'} apart',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.secondaryText,
          ),
        ),
        if (mixed) ...[
          const SizedBox(height: 12),
          _Note(
            icon: Icons.info_outline_rounded,
            text: 'These are different kinds of records: '
                '${_kind(earlier.source)} and ${_kind(later.source)}. They are '
                "shown together for reference and aren't directly equivalent.",
          ),
        ],
        const _SectionTitle('Images'),
        if (bothImages) ...[
          GlassCard(
            borderRadius: BorderRadius.circular(20),
            padding: const EdgeInsets.all(14),
            child: ImageComparison(earlier: earlier, later: later),
          ),
          const SizedBox(height: 10),
          const _Note(
            icon: Icons.photo_camera_outlined,
            text: 'Lighting, angle and camera can make photos look different. '
                "A visual difference alone doesn't show that anything changed "
                'in your teeth.',
          ),
        ] else
          _Note(
            icon: Icons.image_not_supported_outlined,
            text: earlier.images.isEmpty && later.images.isEmpty
                ? 'Neither record has stored images, so there are no photos to '
                    'compare.'
                : 'Only the ${earlier.images.isEmpty ? 'later' : 'earlier'} '
                    "record has stored images, so photos can't be shown side "
                    'by side.',
          ),
        if (s1 != null || s2 != null) ...[
          const _SectionTitle('Smart screening details'),
          _ScreeningComparison(earlier: s1, later: s2),
        ],
        if (earlier.record != null || later.record != null) ...[
          const _SectionTitle('Record details'),
          _RecordDetails(earlier: earlier.record, later: later.record),
        ],
        const SizedBox(height: 20),
        const ScanDisclaimer(),
        const SizedBox(height: 16),
        DentraPillButton(
          label: 'Change selection',
          variant: DentraButtonVariant.outline,
          icon: Icons.tune_rounded,
          onPressed: controller.editSelection,
        ),
      ],
    );
  }

  Future<void> _change(BuildContext context, WidgetRef ref, ComparisonSlot slot) async {
    await _chooseDay(context, ref, all, slot);
    // No single record on the new date: finish choosing on the selection.
    if (!ref.read(comparisonControllerProvider).canCompare) {
      ref.read(comparisonControllerProvider.notifier).editSelection();
    }
  }

  static String _kind(RecordSource s) => switch (s) {
        RecordSource.aiScreening => 'a smart screening',
        RecordSource.clinicRecord => 'a clinic record you entered',
        RecordSource.personalPhoto => 'a photo you uploaded',
        RecordSource.personalNote => 'a note you wrote',
      };
}

class _SideHeader extends StatelessWidget {
  const _SideHeader({required this.slot, required this.item, required this.onChange});

  final ComparisonSlot slot;
  final ComparableItem item;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            slot.label.toUpperCase(),
            style: GoogleFonts.outfit(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            DentraDates.medium(item.at),
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 6),
          RecordSourceLabel(source: item.source),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.secondaryText),
            ),
          ),
          TextButton(
            onPressed: onChange,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.g2,
              minimumSize: const Size(44, 40),
              padding: const EdgeInsets.symmetric(horizontal: 0),
            ),
            child: Text(
              'Change date',
              semanticsLabel: 'Change the ${slot.label.toLowerCase()} date',
              style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Stored screening data side by side. Only fields both records hold are
/// lined up; findings are listed as reported, never matched or scored.
class _ScreeningComparison extends StatelessWidget {
  const _ScreeningComparison({required this.earlier, required this.later});

  final ScreeningSession? earlier;
  final ScreeningSession? later;

  @override
  Widget build(BuildContext context) {
    String regions(ScreeningSession? s) =>
        s == null ? '—' : '${s.capturedViewCount} of ${s.totalRegions}';
    String analysis(ScreeningSession? s) =>
        s == null ? 'Not a screening' : (s.analysis == null ? 'Not run' : 'Saved');

    final a1 = earlier?.analysis, a2 = later?.analysis;
    final String note;
    if (earlier == null || later == null) {
      note = 'Only one side is a smart screening, so screening results are shown '
          'for that side only.';
    } else if (a1 == null && a2 == null) {
      note = 'Neither screening has an analysis saved, so there are no '
          'findings to compare. Only the captured regions can be shown.';
    } else if (a1 == null || a2 == null) {
      note = 'Only the ${a1 == null ? 'later' : 'earlier'} screening has an '
          "analysis, so findings can't be compared.";
    } else {
      note = 'Findings are listed as the screening reported them for each screening. '
          "A finding that appears in one and not the other doesn't show that a "
          'condition improved or worsened.';
    }

    return GlassCard(
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PairRow('Regions captured', regions(earlier), regions(later)),
          if (earlier != null && later != null)
            _PairRow(
              'Regions in both',
              _names(earlier!.capturedRegions.toSet().intersection(later!.capturedRegions.toSet())),
              null,
            ),
          _PairRow('Analysis', analysis(earlier), analysis(later), last: a1 == null && a2 == null),
          if (a1 != null || a2 != null) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _Findings(analysis: a1, present: earlier != null)),
                const SizedBox(width: 12),
                Expanded(child: _Findings(analysis: a2, present: later != null)),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Text(
            note,
            style: GoogleFonts.outfit(fontSize: 12, color: AppColors.secondaryText, height: 1.45),
          ),
        ],
      ),
    );
  }

  static String _names(Set<String> ids) => ids.isEmpty
      ? 'None'
      : [for (final id in ids) if (findScanRegion(id) case final r?) r.label].join(', ');
}

class _Findings extends StatelessWidget {
  const _Findings({required this.analysis, required this.present});

  final ScreeningAnalysis? analysis;
  final bool present;

  @override
  Widget build(BuildContext context) {
    final a = analysis;
    final style = GoogleFonts.outfit(fontSize: 12, color: AppColors.secondaryText);
    if (!present) return Text('—', style: style);
    if (a == null) return Text('No findings saved', style: style);
    if (a.findings.isEmpty) {
      return Text('No structured findings reported', style: style);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final f in a.findings)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  f.label,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
                Text(
                  [
                    if (f.tooth != null) 'Tooth ${f.tooth}',
                    if (f.regionId != null)
                      findScanRegion(f.regionId!)?.label,
                    // Only a confidence the service reported.
                    if (f.confidence != null)
                      '${(f.confidence! * 100).round()}% reported confidence',
                  ].whereType<String>().join(' · '),
                  style: style,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RecordDetails extends StatelessWidget {
  const _RecordDetails({required this.earlier, required this.later});

  final DentalRecord? earlier;
  final DentalRecord? later;

  @override
  Widget build(BuildContext context) {
    Widget side(DentalRecord? r) {
      final style = GoogleFonts.outfit(fontSize: 12, color: AppColors.secondaryText, height: 1.4);
      if (r == null) return Text('Smart screening', style: style);
      final lines = [
        recordDateLabel(r),
        if (r.source == RecordSource.clinicRecord) ...[
          if (r.clinicName != null) r.clinicName!,
          if (r.procedure != null) r.procedure!,
        ],
        if (r.notes != null) r.notes!,
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(l, maxLines: 4, overflow: TextOverflow.ellipsis, style: style),
            ),
          if (r.teeth.isNotEmpty)
            Wrap(
              spacing: 4,
              children: [
                for (final t in r.teeth)
                  TextButton(
                    onPressed: () => showToothHistorySheet(context, t),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.g2,
                      minimumSize: const Size(44, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    child: Text('Tooth $t',
                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
        ],
      );
    }

    return GlassCard(
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: side(earlier)),
              const SizedBox(width: 12),
              Expanded(child: side(later)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Entered by you. Not verified by DENTRA or a dentist.',
            style: GoogleFonts.outfit(fontSize: 11.5, color: AppColors.secondaryText),
          ),
        ],
      ),
    );
  }
}

// ── Small pieces ────────────────────────────────────────────────────────────

class _PairRow extends StatelessWidget {
  const _PairRow(this.label, this.earlier, this.later, {this.last = false});

  final String label;
  final String earlier;

  /// Null spans [earlier] across both columns.
  final String? later;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final value = GoogleFonts.outfit(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AppColors.navy,
    );
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: AppGlass.divider)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.secondaryText)),
            const SizedBox(height: 3),
            if (later == null)
              Text(earlier, style: value)
            else
              Row(
                children: [
                  Expanded(child: Text(earlier, semanticsLabel: 'Earlier: $earlier', style: value)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(later!, semanticsLabel: 'Later: $later', style: value)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.lightLavender,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.primary.withValues(alpha: 0.85)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.outfit(fontSize: 12.5, color: AppColors.navy, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Semantics(
        header: true,
        child: Text(
          text.toUpperCase(),
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
