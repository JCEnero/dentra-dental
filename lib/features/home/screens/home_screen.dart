import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/services/mock_data.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/gradient_divider.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/section_label.dart';

class HomeScreen extends StatelessWidget {
  final ValueChanged<int> onNavigate;

  const HomeScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final last = MockData.screenings.first;
    final tip  = MockData.dailyTips.first;

    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.verticalGradient),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── HEADER ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH, 20, AppSpacing.screenH, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Good morning',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Rommel',
                            style: GoogleFonts.outfit(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppColors.white,
                              letterSpacing: -0.5,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Ready for your next screening?',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.45),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const AvatarWidget(size: 44),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── HERO DEVICE CARD ──────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
                child: _DeviceHeroCard(onScan: () => onNavigate(1)),
              ),

              const SizedBox(height: AppSpacing.sectionGap),
              const GradientDivider(),

              // ── YOUR SCREENING ────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH, AppSpacing.sectionGap,
                    AppSpacing.screenH, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('Your screening'),
                    const SizedBox(height: 16),
                    Text(
                      'Last screening',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'September 7',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${last.teeth} teeth detected · ${last.images} images captured',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _LinkButton(
                      label: 'View results',
                      onTap: () => onNavigate(2),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.sectionGap),
              const GradientDivider(),

              // ── SCREENING OVERVIEW ────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH, AppSpacing.sectionGap,
                    AppSpacing.screenH, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('Screening overview'),
                    const SizedBox(height: 20),
                    IntrinsicHeight(
                      child: Row(
                        children: [
                          const _StatColumn(value: '18', label: 'Teeth'),
                          _VerticalDivider(),
                          const _StatColumn(value: '4', label: 'Images'),
                          _VerticalDivider(),
                          const _StatColumn(value: '5', label: 'Regions'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.sectionGap),
              const GradientDivider(),

              // ── YOUR MONITORING ───────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH, AppSpacing.sectionGap,
                    AppSpacing.screenH, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('Your monitoring'),
                    const SizedBox(height: 16),
                    Text(
                      '3 screenings this month',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your screening history is available to help you\nreview visual observations over time.',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.45),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _MonitoringTimeline(),
                    const SizedBox(height: 4),
                    _LinkButton(
                      label: 'View history',
                      onTap: () => onNavigate(2),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.sectionGap),
              const GradientDivider(),

              // ── DAILY TIP ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH, AppSpacing.sectionGap,
                    AppSpacing.screenH, 0),
                child: _DailyTipCard(
                  headline: tip['headline']!,
                  body: tip['body']!,
                ),
              ),

              const SizedBox(height: AppSpacing.sectionGap),
              const GradientDivider(),

              // ── DENTRA AI ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH, AppSpacing.sectionGap,
                    AppSpacing.screenH, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFFC8BEFF),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'DENTRA AI',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                  color: Colors.white.withValues(alpha: 0.45),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Need help understanding your\nscreening results?',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.white,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _AskAiButton(),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.sectionGap),

              // ── PROFESSIONAL CARE ─────────────────────────────
              const Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenH),
                child: GradientDivider(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH, 24,
                    AppSpacing.screenH, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PROFESSIONAL CARE',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Screening information is not a diagnosis. If you have concerns about your oral health, consider speaking with a licensed dentist.',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.45),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _LinkButton(
                      label: 'Find a nearby clinic',
                      onTap: () => onNavigate(3),
                    ),
                  ],
                ),
              ),

              // Bottom padding above nav bar
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Device hero card ──────────────────────────────────────────────

class _DeviceHeroCard extends StatelessWidget {
  final VoidCallback onScan;
  const _DeviceHeroCard({required this.onScan});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDeep,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: 36,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
          // Inner top highlight
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.26),
            blurRadius: 0,
            spreadRadius: -1,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label + icon row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'DENTRA DEVICE',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Status
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.95),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Ready to scan',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 14),
                child: Text(
                  'Connected · Battery 86% · Signal Strong',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Status pills
              const Row(
                children: [
                  _StatusPill(icon: Icons.battery_5_bar_rounded, label: '86%'),
                  SizedBox(width: 8),
                  _StatusPill(icon: Icons.wifi_rounded, label: 'Strong'),
                  SizedBox(width: 8),
                  _StatusPill(icon: Icons.bluetooth_rounded, label: 'BLE'),
                ],
              ),

              const SizedBox(height: 14),

              // CTA
              PrimaryButton(
                label: 'Start Dental Scan',
                variant: ButtonVariant.white,
                onTap: onScan,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatusPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.5)),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stat column ───────────────────────────────────────────────────

class _StatColumn extends StatelessWidget {
  final String value;
  final String label;
  const _StatColumn({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: AppColors.white,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: Colors.white.withValues(alpha: 0.12),
    );
  }
}

// ── Monitoring timeline ───────────────────────────────────────────

class _MonitoringTimeline extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final points = [
      {'label': 'Aug 12', 'active': false},
      {'label': 'Aug 28', 'active': false},
      {'label': 'Sep 7',  'active': true},
    ];

    return Row(
      children: List.generate(points.length, (i) {
        final isActive = points[i]['active'] as bool;
        final label    = points[i]['label'] as String;
        return Expanded(
          flex: i < points.length - 1 ? 1 : 0,
          child: Row(
            children: [
              Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: isActive ? 10 : 10,
                    height: isActive ? 10 : 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? AppColors.white
                          : Colors.white.withValues(alpha: 0.5),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.2),
                                blurRadius: 0,
                                spreadRadius: 3,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                      color: isActive
                          ? AppColors.white
                          : Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
              if (i < points.length - 1)
                Expanded(
                  child: Container(
                    height: 1,
                    margin: const EdgeInsets.only(bottom: 16, left: 4, right: 4),
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

// ── Daily tip card ────────────────────────────────────────────────

class _DailyTipCard extends StatelessWidget {
  final String headline;
  final String body;
  const _DailyTipCard({required this.headline, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDeep,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.16),
            blurRadius: 0,
            spreadRadius: -1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 13, color: Colors.white.withValues(alpha: 0.55)),
              const SizedBox(width: 6),
              Text(
                'DAILY TIP',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            headline,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.5),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Ask AI button ─────────────────────────────────────────────────

class _AskAiButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(
          children: [
            Text(
              'Ask AI',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.white,
              ),
            ),
            const SizedBox(width: 5),
            const Icon(Icons.arrow_forward_rounded,
                size: 14, color: AppColors.white),
          ],
        ),
      ),
    );
  }
}

// ── Link button ───────────────────────────────────────────────────

class _LinkButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _LinkButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 5),
            Icon(Icons.arrow_forward_rounded,
                size: 14, color: Colors.white.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}
