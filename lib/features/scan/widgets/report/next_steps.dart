import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../screening/data/models/screening_session.dart';
import '../scan_theme.dart';
import 'report_style.dart';

/// What to do, most pressing first, in one card. Urgency is spelled out in
/// words.
class NextSteps extends StatelessWidget {
  const NextSteps({super.key, required this.recommendations});

  final List<ScreeningRecommendation> recommendations;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      width: double.infinity,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, r) in recommendations.indexed) ...[
            if (i > 0) ...[
              const SizedBox(height: 12),
              Divider(height: 1, thickness: 1, color: ReportColors.rule),
              const SizedBox(height: 12),
            ],
            Text(r.title, style: reportCardTitle),
            if (r.code != 'braces_seen') ...[
              const SizedBox(height: 1),
              Text(
                switch (r.urgency) {
                  'prompt' => 'See a dentist promptly',
                  'soon' => 'Book a visit soon',
                  _ => 'At your next check-up',
                },
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: ScanColors.clearInk,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(r.detail, style: reportBody),
          ],
        ],
      ),
    );
  }
}

/// Where to go from here: nearby clinics, or asking Rabi about the results.
class ReportActions extends StatelessWidget {
  const ReportActions({super.key, this.onAskRabi, this.onClinics});

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
        if (onAskRabi != null && onClinics != null) const SizedBox(height: 10),
        if (onClinics != null)
          row(
            const ScanIconDisc(Icons.location_on_outlined),
            'Find clinics nearby',
            onClinics!,
          ),
      ],
    );
  }
}
