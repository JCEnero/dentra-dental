import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../auth/widgets/dentra_logo.dart';
import '../data/profile_content.dart';
import '../widgets/profile_settings.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';

Future<void> showPrivacyPolicySheet(BuildContext context) {
  return showGlassSheet<void>(
    context: context,
    title: 'Privacy policy',
    subtitle: 'Last updated ${ProfileContent.policyUpdated}',
    builder: (_) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ProfileContent.policyIntro,
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: AppColors.secondaryText,
            height: 1.6,
          ),
        ),
        for (final (i, (heading, body))
            in ProfileContent.policySections.indexed) ...[
          const SizedBox(height: 18),
          Semantics(
            header: true,
            child: Text(
              '${i + 1}. $heading',
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: AppColors.secondaryText,
              height: 1.6,
            ),
          ),
        ],
      ],
    ),
  );
}

Future<void> showAboutSheet(BuildContext context) {
  return showGlassSheet<void>(
    context: context,
    title: 'About DENTRA',
    builder: (_) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: DentraLogo(size: 1.4)),
        const SizedBox(height: 8),
        Text(
          'Smart dental screening at home',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: AppColors.secondaryText,
          ),
        ),
        const SizedBox(height: 22),
        const ProfileSheetCard(
          children: [
            _InfoRow(label: 'Version', value: ProfileContent.appVersion),
            _InfoRow(label: 'Developer', value: 'DENTRA Health, Inc.'),
            _InfoRow(label: 'Website', value: ProfileContent.website),
            _InfoRow(label: 'Support', value: ProfileContent.supportEmail),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'DENTRA provides preliminary observations only and is not a '
          'substitute for professional dental care.',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: AppColors.secondaryText,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '© 2026 DENTRA Health, Inc. All rights reserved.',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: AppColors.secondaryText,
          ),
        ),
      ],
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SelectableText(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
