import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/dentra_glass_ui.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../data/care_plan.dart';
import '../../data/patient_context.dart';
import '../../data/tooth_guidance.dart';
import '../scan_theme.dart';
import 'report_motion.dart';
import 'report_style.dart';

/// What to do, as a short path: each step and where it came from, what to ask
/// at the visit, and every day. Urgency is spelled out in words.
class NextSteps extends StatelessWidget {
  const NextSteps({
    super.key,
    required this.plan,
    required this.context_,
    required this.date,
  });

  final CarePlan plan;
  final PatientContext context_;
  final String date;

  void _copy(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    final text = plan.report.summaryForDentist(
      date,
      reported: [...context_.reportedLines, ...plan.toothAnswerLines],
    );
    Clipboard.setData(ClipboardData(text: text)).then(
      (_) => messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(dentraSnackBar('Copied. Paste it into a message.')),
    );
  }

  /// Most steps shown here, so the path stays short. All go in the PDF.
  static const int _maxSteps = 3;

  static IconData _iconOf(CareStep step) => switch (step.level) {
        CareLevel.emergency => Icons.emergency_outlined,
        CareLevel.prompt => Icons.priority_high_rounded,
        _
            when !step.sources.contains(CareSource.check) &&
                step.sources.contains(CareSource.records) =>
          Icons.folder_outlined,
        _ => Icons.event_available_outlined,
      };

  static String? _whenOf(CareLevel level) => switch (level) {
        CareLevel.emergency => 'Get help now',
        CareLevel.prompt => 'See a dentist promptly',
        CareLevel.soon => 'Book a visit soon',
        CareLevel.nextVisit => 'At your next check-up',
        CareLevel.routine => null,
      };

  @override
  Widget build(BuildContext context) {
    final braces = plan.report.analysis.recommendations
        .where((r) => r.code == 'braces_seen');
    return GlassCard(
      width: double.infinity,
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.fromLTRB(14, 16, 16, 12),
      child: InViewAnimation(
        duration: const Duration(milliseconds: 900),
        builder: (context, t) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (plan.steps.isEmpty)
              _Stop(
                icon: Icons.event_available_outlined,
                title: 'Keep your regular check-ups',
                t: t,
                child: Text(
                  'A dentist can see what photos can\'t.',
                  style: reportBody,
                ),
              )
            else
              for (final step in plan.steps.take(_maxSteps))
                _Stop(
                  icon: _iconOf(step),
                  title: step.title,
                  t: t,
                  subtitle: _whenOf(step.level),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(step.detail, style: reportBody),
                      const SizedBox(height: 2),
                      Text(careSourcesInWords(step.sources), style: reportNote),
                    ],
                  ),
                ),
            if (plan.steps.length > _maxSteps)
              Padding(
                padding: const EdgeInsets.only(left: 46, bottom: 12),
                child: Text(
                  'And ${plan.steps.length - _maxSteps} more in your PDF.',
                  style: reportNote,
                ),
              ),
            _Stop(
              icon: Icons.forum_outlined,
              title: 'At your visit, ask',
              t: t,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final q in plan.questions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(q, style: reportBody),
                    ),
                  TextButton.icon(
                    onPressed: () => _copy(context),
                    style: TextButton.styleFrom(
                      foregroundColor: ScanColors.clearInk,
                      minimumSize: const Size(44, 40),
                      padding: EdgeInsets.zero,
                      textStyle: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy my result for the dentist'),
                  ),
                ],
              ),
            ),
            _Stop(
              icon: Icons.favorite_border_rounded,
              title: 'Every day',
              t: t,
              last: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final tip in plan.dailyCare)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(tip, style: reportBody),
                    ),
                ],
              ),
            ),
            for (final r in braces) ...[
              const SizedBox(height: 8),
              Text(r.detail, style: reportNote),
            ],
            const SizedBox(height: 10),
            Divider(height: 1, thickness: 1, color: ReportColors.rule),
            const SizedBox(height: 10),
            Text(
              'See a dentist sooner for pain, a broken tooth, or bleeding that '
              'won\'t stop. $urgentCareWarning',
              style: reportNote,
            ),
          ],
        ),
      ),
    );
  }
}

/// One step on the path: an icon on a white disc, with a line down to the next.
class _Stop extends StatelessWidget {
  const _Stop({
    required this.icon,
    required this.title,
    required this.child,
    required this.t,
    this.subtitle,
    this.last = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;
  final double t;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                ScanIconDisc(icon),
                if (!last)
                  Expanded(
                    child: Opacity(
                      opacity: t,
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        color: AppColors.g2.withValues(alpha: 0.22),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 6, bottom: last ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: reportCardTitle),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: ScanColors.clearInk,
                      ),
                    ),
                  const SizedBox(height: 3),
                  child,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Where to go from here: keeping the results, nearby clinics, or asking Rabi
/// about them.
class ReportActions extends StatelessWidget {
  const ReportActions({
    super.key,
    this.onDownload,
    this.downloading = false,
    this.onAskRabi,
    this.onClinics,
  });

  /// Null while the page has nothing to put in a report.
  final VoidCallback? onDownload;
  final bool downloading;
  final VoidCallback? onAskRabi;
  final VoidCallback? onClinics;

  @override
  Widget build(BuildContext context) {
    Widget row(Widget lead, String label, VoidCallback onTap) => GlassCard(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              lead,
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.g2),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onDownload != null)
          DentraPillButton(
            label: 'Download My Results',
            loading: downloading,
            loadingLabel: 'Preparing your PDF',
            icon: Icons.download_rounded,
            onPressed: downloading ? null : onDownload,
          ),
        if (onDownload != null && (onClinics != null || onAskRabi != null))
          const SizedBox(height: 10),
        if (onClinics != null)
          row(
            const ScanIconDisc(Icons.location_on_outlined),
            'Find clinics nearby',
            onClinics!,
          ),
        if (onAskRabi != null && onClinics != null) const SizedBox(height: 10),
        if (onAskRabi != null)
          row(
            // Rabi's bunny mark, as in the chat.
            SizedBox.square(
              dimension: 34,
              child: Image.asset(
                'assets/images/rabi_avatar.png',
                fit: BoxFit.contain,
                excludeFromSemantics: true,
                errorBuilder: (_, __, ___) =>
                    const ScanIconDisc(Icons.chat_bubble_outline_rounded),
              ),
            ),
            'Ask Rabi about my results',
            onAskRabi!,
          ),
      ],
    );
  }
}
