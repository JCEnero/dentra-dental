import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/dentra_dates.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../dental_records/screens/record_detail_screen.dart';
import '../../../dental_records/widgets/record_source_label.dart';
import '../../data/care_plan.dart';
import '../../data/patient_context.dart';
import '../scan_theme.dart';
import 'report_style.dart';

/// Reported signs that shouldn't wait, above everything else on the page. Solid
/// deep teal: the one loud thing here. An old scan says so, since what someone
/// told us then may not be true today.
class EmergencyBanner extends StatelessWidget {
  const EmergencyBanner({super.key, required this.plan, required this.at});

  final CarePlan plan;
  final DateTime at;

  @override
  Widget build(BuildContext context) {
    final recent = DateTime.now().difference(at).inHours <= 48;
    final step = plan.steps.first;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ReportColors.strong,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.emergency_outlined,
              color: AppColors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recent
                        ? step.title
                        : 'At this scan, you needed emergency care',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    recent
                        ? step.detail
                        : 'On ${DentraDates.medium(at)} ${step.detail[0].toLowerCase()}'
                            '${step.detail.substring(1)} If you still have '
                            'these signs, get help now.',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      height: 1.45,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'From what you told us. Not something the check saw.',
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.lavender,
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

/// How the check, the user's answers and their records relate, each under a
/// heading of its own so nothing reads as more than it is.
class ContextSection extends StatelessWidget {
  const ContextSection({super.key, required this.plan, required this.patient});

  final CarePlan plan;
  final PatientContext patient;

  // Most shown here, so the page stays easy to read. All go in the PDF.
  static const int _maxLinks = 3;
  static const int _maxFacts = 6;
  static const int _maxRecords = 3;

  @override
  Widget build(BuildContext context) {
    final told = [...patient.symptomFacts, ...patient.treatmentFacts];
    final background = patient.backgroundFacts;
    final shownFacts = [...told, ...background].take(_maxFacts);
    final areas = {
      for (final s in plan.report.spots) ...s.areas,
      ...?patient.symptoms?.areas,
    };
    final records = patient.relevantRecords(areas);
    final blocks = <Widget>[
      if (plan.links.isNotEmpty)
        _Block(
          icon: Icons.link_rounded,
          title: 'How they connect',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, link) in plan.links.take(_maxLinks).indexed) ...[
                if (i > 0) const SizedBox(height: 9),
                _LinkRow(link: link),
              ],
              if (plan.links.length > _maxLinks) ...[
                const SizedBox(height: 5),
                Text(
                  'And ${plan.links.length - _maxLinks} more in your PDF.',
                  style: reportNote,
                ),
              ],
            ],
          ),
        ),
      if (told.isNotEmpty || background.isNotEmpty)
        _Block(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'You told us',
          note: 'Your own answers, not something the check saw.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final fact in shownFacts) _FactRow(fact: fact),
            ],
          ),
        ),
      if (records.isNotEmpty)
        _Block(
          icon: Icons.folder_outlined,
          title: 'Your records',
          note: 'Entries you added. Dentra hasn\'t checked them.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final r in records.take(_maxRecords)) _RecordRow(record: r),
              if (records.length > _maxRecords)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'And ${records.length - _maxRecords} more in your PDF.',
                    style: reportNote,
                  ),
                ),
            ],
          ),
        )
      else if (patient.recordsUnavailable)
        _Block(
          icon: Icons.folder_outlined,
          title: 'Your records',
          child: Text(
            'They couldn\'t be loaded just now, so they aren\'t part of this '
            'view.',
            style: reportBody,
          ),
        ),
    ];
    return GlassCard(
      width: double.infinity,
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.fromLTRB(14, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, block) in blocks.indexed) ...[
            if (i > 0) ...[
              const SizedBox(height: 13),
              Divider(height: 1, thickness: 1, color: ReportColors.rule),
              const SizedBox(height: 13),
            ],
            block,
          ],
        ],
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({
    required this.icon,
    required this.title,
    required this.child,
    this.note,
  });

  final IconData icon;
  final String title;
  final String? note;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ScanIconDisc(icon),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(title, style: reportCardTitle),
                ),
                if (note != null) Text(note!, style: reportNote),
                const SizedBox(height: 6),
                child,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.link});

  final ContextLink link;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          link.title,
          style: GoogleFonts.outfit(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: ScanColors.clearInk,
          ),
        ),
        Text(link.text, style: reportBody),
      ],
    );
  }
}

/// A label and what they answered.
class _FactRow extends StatelessWidget {
  const _FactRow({required this.fact});

  final ContextFact fact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Text.rich(
        TextSpan(
          style: reportBody,
          children: [
            TextSpan(text: '${fact.label}  '),
            TextSpan(
              text: fact.value,
              style: GoogleFonts.outfit(
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One record, its source always on show, opening its own page.
class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.record});

  final ContextRecord record;

  @override
  Widget build(BuildContext context) {
    final areas = record.areas;
    final detail = [
      record.dateLabel,
      if (record.teeth.isNotEmpty) teethInWords(record.teeth, capital: true),
      if (areas.length == 1) areas.single.label,
    ].join(' · ');
    return Semantics(
      button: true,
      label: '${record.source.label}. ${record.title}. $detail.',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => Navigator.of(context)
            .push(RecordDetailScreen.route(record.record.id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RecordSourceLabel(source: record.source),
                    const SizedBox(height: 3),
                    Text(
                      record.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                        color: AppColors.navy,
                      ),
                    ),
                    Text(detail, style: reportNote),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.g2,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
