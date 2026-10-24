// lib/features/treatment/screens/treatment_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../data/models/treatment_model.dart';

class TreatmentDetailScreen extends StatelessWidget {
  final TreatmentModel treatment;

  const TreatmentDetailScreen({super.key, required this.treatment});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── HERO SLIVER APP BAR ──────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: _HeroBanner(treatment: treatment),
            ),
            title: _CollapsedTitle(name: treatment.name),
            leading: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 15,
                    color: AppColors.navy,
                  ),
                ),
              ),
            ),
          ),

          // ── BODY ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH, 24, AppSpacing.screenH, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + category badge row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          treatment.name,
                          style: GoogleFonts.outfit(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.lightLavender,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          treatment.category.label,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.g2,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Info pills row
                  Row(
                    children: [
                      _InfoPill(
                        icon: Icons.schedule_rounded,
                        label: treatment.duration,
                      ),
                      if (treatment.requiresFollowUp) ...[
                        const SizedBox(width: 8),
                        _InfoPill(
                          icon: Icons.event_repeat_rounded,
                          label: 'Follow-up required',
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Description
                  Text(
                    'About this treatment',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    treatment.longDescription,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: AppColors.secondaryText,
                      height: 1.65,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Divider
                  Container(
                    height: 1,
                    color: AppColors.border,
                  ),

                  const SizedBox(height: 28),

                  // Procedure steps
                  Text(
                    'What to expect',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Step-by-step breakdown of the procedure',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppColors.secondaryText,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Steps timeline
                  ...treatment.steps.asMap().entries.map((entry) {
                    final isLast =
                        entry.key == treatment.steps.length - 1;
                    return _StepTile(
                      step: entry.value,
                      stepNumber: entry.key + 1,
                      isLast: isLast,
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero banner – teal gradient with large icon
// ─────────────────────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  final TreatmentModel treatment;

  const _HeroBanner({required this.treatment});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: AppColors.cardGradient,
      ),
      child: SafeArea(
        bottom: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(22),
                ),
                clipBehavior: Clip.antiAlias,
                child: treatment.iconPath != null
                    ? Padding(
                        padding: const EdgeInsets.all(10),
                        child: Image.asset(
                          treatment.iconPath!,
                          fit: BoxFit.contain,
                        ),
                      )
                    : Icon(
                        treatment.icon,
                        size: 40,
                        color: Colors.white,
                      ),
              ),
              const SizedBox(height: 12),
              Text(
                treatment.name,
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Collapsed title shown when hero is scrolled away
// ─────────────────────────────────────────────────────────────────────────────

class _CollapsedTitle extends StatelessWidget {
  final String name;

  const _CollapsedTitle({required this.name});

  @override
  Widget build(BuildContext context) {
    return Text(
      name,
      style: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.navy,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small info pill (duration, follow-up)
// ─────────────────────────────────────────────────────────────────────────────

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.lightLavender,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.g2),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.g2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single step tile with timeline connector
// ─────────────────────────────────────────────────────────────────────────────

class _StepTile extends StatelessWidget {
  final TreatmentStep step;
  final int stepNumber;
  final bool isLast;

  const _StepTile({
    required this.step,
    required this.stepNumber,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline column: circle + vertical line
          SizedBox(
            width: 36,
            child: Column(
              children: [
                // Numbered circle
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$stepNumber',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                // Connector line (hidden on last item)
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.g2.withValues(alpha: 0.4),
                            AppColors.g2.withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Step content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    step.description,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppColors.secondaryText,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
