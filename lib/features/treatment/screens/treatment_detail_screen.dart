// lib/features/treatment/screens/treatment_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_glass.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../shared/widgets/app_backdrop.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../../shared/widgets/dentra_note_card.dart';
import '../../../shared/widgets/dentra_page_header.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/models/treatment_model.dart';

/// Detail page shared by every treatment.
///
/// Light glass header tinted with the treatment's own accent, a facts
/// strip, the description and a numbered procedure timeline. The top bar
/// starts clear and frosts over, showing the name, once the title
/// scrolls away.
class TreatmentDetailScreen extends StatefulWidget {
  final TreatmentModel treatment;
  final VoidCallback? onFindClinic;

  const TreatmentDetailScreen({
    super.key,
    required this.treatment,
    this.onFindClinic,
  });

  @override
  State<TreatmentDetailScreen> createState() => _TreatmentDetailScreenState();
}

class _TreatmentDetailScreenState extends State<TreatmentDetailScreen> {
  static const double _barHeight = 60;

  final ScrollController _scroll = ScrollController();

  // 0 at rest, 1 once the header title is under the bar.
  final ValueNotifier<double> _collapse = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      // The title sits ~140px down; fade the bar in over the last 60px.
      final t = ((_scroll.offset - 80) / 60).clamp(0.0, 1.0);
      if (t != _collapse.value) _collapse.value = t;
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _collapse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final treatment = widget.treatment;
    final media = MediaQuery.of(context);
    final hasCta = widget.onFindClinic != null;

    return Scaffold(
      backgroundColor: AppColors.lightLavender,
      body: AppBackdrop(
        child: Stack(
          children: [
            CustomScrollView(
              controller: _scroll,
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.screenH,
                      media.padding.top + _barHeight + 8,
                      AppSpacing.screenH,
                      0,
                    ),
                    child: _Header(treatment: treatment),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.screenH,
                    24,
                    AppSpacing.screenH,
                    (hasCta ? 112 : 32) + media.padding.bottom,
                  ),
                  sliver: SliverList.list(
                    children: [
                      _FactsStrip(treatment: treatment),
                      const SizedBox(height: 32),
                      const _SectionTitle('About this treatment'),
                      const SizedBox(height: 10),
                      Text(
                        treatment.longDescription,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          color: AppColors.navy.withValues(alpha: 0.78),
                          height: 1.65,
                        ),
                      ),
                      const SizedBox(height: 32),
                      _SectionTitle(
                        'What to expect',
                        trailing: '${treatment.steps.length} steps',
                      ),
                      const SizedBox(height: 12),
                      _StepsCard(steps: treatment.steps),
                      const SizedBox(height: 24),
                      const DentraNoteCard(
                        message:
                            'This is general information, not medical advice. '
                            "Your dentist will recommend what's right for you.",
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Top bar, drawn over the content.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _TopBar(
                height: _barHeight,
                collapse: _collapse,
                title: treatment.name,
                onBack: () => Navigator.of(context).maybePop(),
              ),
            ),

            if (hasCta)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: GlassBar(
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenH, 14, AppSpacing.screenH, 14),
                      child: DentraPillButton(
                        label: 'Find a clinic near me',
                        icon: Icons.location_on_outlined,
                        onPressed: widget.onFindClinic,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top bar: clear at rest, frosted with the title once scrolled
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.height,
    required this.collapse,
    required this.title,
    required this.onBack,
  });

  final double height;
  final ValueNotifier<double> collapse;
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return ValueListenableBuilder<double>(
      valueListenable: collapse,
      builder: (context, t, _) {
        final bar = SizedBox(
          height: top + height,
          child: Padding(
            padding: EdgeInsets.fromLTRB(AppSpacing.screenH - 4, top, 16, 0),
            child: Row(
              children: [
                DentraBackButton(onPressed: onBack),
                const SizedBox(width: 12),
                Expanded(
                  child: Opacity(
                    opacity: t,
                    child: ExcludeSemantics(
                      // The header title already announces the page.
                      excluding: t < 1,
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        if (t == 0) return bar;
        return ClipRect(
          child: GlassBlur(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppGlass.barFill.withValues(alpha: AppGlass.barFill.a * t),
                border: Border(
                  bottom: BorderSide(
                    color: AppGlass.divider.withValues(
                      alpha: AppGlass.divider.a * t,
                    ),
                  ),
                ),
              ),
              child: bar,
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header: accent icon, category, title, summary
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.treatment});

  final TreatmentModel treatment;

  @override
  Widget build(BuildContext context) {
    final accent = treatment.iconColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Icon on a frosted tile tinted with the treatment's color.
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: GlassBlur(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.white.withValues(alpha: 0.85),
                        treatment.iconBackground.withValues(alpha: 0.9),
                      ],
                    ),
                    border: Border.all(color: AppGlass.border),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.18),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(treatment.icon, size: 28, color: accent),
                ),
              ),
            ),
            const Spacer(),
            _CategoryTag(category: treatment.category, accent: accent),
          ],
        ),
        const SizedBox(height: 20),
        Semantics(
          header: true,
          child: Text(
            treatment.name,
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
              letterSpacing: -0.6,
              height: 1.15,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          treatment.shortDescription,
          style: GoogleFonts.outfit(
            fontSize: 15,
            color: AppColors.secondaryText,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _CategoryTag extends StatelessWidget {
  const _CategoryTag({required this.category, required this.accent});

  final TreatmentCategory category;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppGlass.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            category.label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Facts strip: one glass card, segments split by hairlines
// ─────────────────────────────────────────────────────────────────────────────

class _FactsStrip extends StatelessWidget {
  const _FactsStrip({required this.treatment});

  final TreatmentModel treatment;

  @override
  Widget build(BuildContext context) {
    final facts = [
      (Icons.schedule_rounded, 'Duration', treatment.duration),
      (
        Icons.event_repeat_rounded,
        'Follow-up',
        treatment.requiresFollowUp ? 'Needed' : 'Not needed',
      ),
      (
        Icons.format_list_numbered_rounded,
        'Procedure',
        '${treatment.steps.length} steps',
      ),
    ];

    return GlassCard(
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < facts.length; i++) ...[
              if (i > 0)
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: AppColors.g2.withValues(alpha: 0.14),
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
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 15, color: AppColors.g2),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sections
// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.secondaryText,
            ),
          ),
      ],
    );
  }
}

/// Procedure steps as a numbered timeline inside one glass card.
class _StepsCard extends StatelessWidget {
  const _StepsCard({required this.steps});

  final List<TreatmentStep> steps;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.fromLTRB(16, 20, 18, 20),
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            _StepTile(
              step: steps[i],
              number: i + 1,
              total: steps.length,
              isLast: i == steps.length - 1,
            ),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.step,
    required this.number,
    required this.total,
    required this.isLast,
  });

  final TreatmentStep step;
  final int number;
  final int total;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step $number of $total. ${step.title}. ${step.description}',
      excludeSemantics: true,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 30,
              child: Column(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.white,
                      border: Border.all(
                        color: AppColors.g2.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      '$number',
                      textScaler: TextScaler.noScaling,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.g2,
                      ),
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 1.5,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        color: AppColors.g2.withValues(alpha: 0.18),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 4, bottom: isLast ? 0 : 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      step.description,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: AppColors.secondaryText,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
