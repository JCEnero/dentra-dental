import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/gradient_divider.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/services/mock_data.dart';
import '../../../shared/widgets/section_label.dart';
import '../../ai_assistant/ai_chat_controller.dart';
import '../../treatment/screens/treatment_screen.dart';

class HomeScreen extends StatelessWidget {
  final ValueChanged<int> onNavigate;

  const HomeScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final last = MockData.screenings.first;
    final tip  = MockData.dailyTips.first;

    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.white),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── HEADER ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH, 36, AppSpacing.screenH, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Good Morning,',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: AppColors.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                'Rommel',
                                style: GoogleFonts.outfit(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.navy,
                                  letterSpacing: -0.5,
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppColors.lightLavender,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.waving_hand_rounded,
                                  size: 16,
                                  color: AppColors.g2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Bell icon
                    GestureDetector(
                      onTap: () {},
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.lightLavender,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.notifications_none_rounded,
                          size: 20,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const AvatarWidget(size: 40),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── DEVICE HERO CARD ──────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenH),
                child: _DeviceHeroCard(onScan: () => onNavigate(1)),
              ),

              const SizedBox(height: 28),

              // ── SERVICES ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenH),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Services',
                      style: GoogleFonts.outfit(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {},
                      child: Text(
                        'See All',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenH),
                child: Row(
                  children: [
                    _ServiceButton(
                      icon: Icons.sentiment_satisfied_alt_rounded,
                      label: 'My Teeth',
                      onTap: () => onNavigate(2),
                    ),
                    const SizedBox(width: 12),
                    _ServiceButton(
                      icon: Icons.healing_rounded,
                      label: 'Treatment',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const TreatmentScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    _ServiceButton(
                      icon: Icons.auto_awesome_rounded,
                      label: 'AI Analysis',
                      onTap: () {},
                    ),
                    const SizedBox(width: 12),
                    _ServiceButton(
                      icon: Icons.assignment_outlined,
                      label: 'Reports',
                      onTap: () => onNavigate(2),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── DENTAL HEALTH SCORE ───────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenH),
                child: _DentalHealthScoreCard(),
              ),

              const SizedBox(height: 28),
              const GradientDivider(),

              // ── YOUR SCREENING ────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH, AppSpacing.sectionGap,
                    AppSpacing.screenH, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('Your screening',
                        color: AppColors.secondaryText),
                    const SizedBox(height: 16),
                    Text(
                      'Last screening',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'September 7',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${last.teeth} teeth detected · ${last.images} images captured',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: AppColors.secondaryText,
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
                    const SectionLabel('Screening overview',
                        color: AppColors.secondaryText),
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
                    const SectionLabel('Your monitoring',
                        color: AppColors.secondaryText),
                    const SizedBox(height: 16),
                    Text(
                      '3 screenings this month',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your screening history is available to help you\nreview visual observations over time.',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: AppColors.secondaryText,
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
                                  color: AppColors.g1,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'DENTRA AI',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                  color: AppColors.secondaryText,
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
                              color: AppColors.navy,
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
                    AppSpacing.screenH, 24, AppSpacing.screenH, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PROFESSIONAL CARE',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Screening information is not a diagnosis. If you have concerns about your oral health, consider speaking with a licensed dentist.',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppColors.secondaryText,
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

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Device hero card ──────────────────────────────────────────────

class _DeviceHeroCard extends StatefulWidget {
  final VoidCallback onScan;
  const _DeviceHeroCard({required this.onScan});

  @override
  State<_DeviceHeroCard> createState() => _DeviceHeroCardState();
}

class _DeviceHeroCardState extends State<_DeviceHeroCard> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/videos/BUNNY.webm')
      ..setLooping(true)
      ..setVolume(0)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {});
          _controller.play();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.g2.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.30),
            blurRadius: 0,
            spreadRadius: -1,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Label row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        'DENTRA DEVICE',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                          color: Colors.white.withValues(alpha: 0.65),
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
                        'Scan your smile',
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
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Status pills
                  Row(
                    children: const [
                      _StatusPill(
                          icon: Icons.battery_5_bar_rounded, label: '86%'),
                      SizedBox(width: 8),
                      _StatusPill(icon: Icons.wifi_rounded, label: 'Strong'),
                      SizedBox(width: 8),
                      _StatusPill(
                          icon: Icons.bluetooth_rounded, label: 'BLE'),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // CTA
                  PrimaryButton(
                    label: 'Start Dental Scan',
                    variant: ButtonVariant.white,
                    onTap: widget.onScan,
                  ),
                ],
              ),
            ),

            // Tooth Bunny video — overlaid right side
            Positioned(
              right: -4,
              bottom: 60,
              width: 100,
              height: 100,
              child: _controller.value.isInitialized
                  ? SizedBox(
                      width: 100,
                      height: 100,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        alignment: Alignment.bottomRight,
                        child: SizedBox(
                          width: _controller.value.size.width,
                          height: _controller.value.size.height,
                          child: VideoPlayer(_controller),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
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
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.75)),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.90),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Service button ────────────────────────────────────────────────

class _ServiceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ServiceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: AppColors.g2.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.lightLavender,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: AppColors.g2),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Dental Health Score card ──────────────────────────────────────

class _DentalHealthScoreCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const double score = 0.85;
    const int percent = 85;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.g2.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Dental Health Score',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              Icon(Icons.more_horiz_rounded,
                  size: 20, color: AppColors.secondaryText),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Circular progress
              SizedBox(
                width: 80,
                height: 80,
                child: CustomPaint(
                  painter: _CircularScorePainter(score: score),
                  child: Center(
                    child: Text(
                      '$percent%',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              // Right side text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Great!',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.thumb_up_rounded,
                          size: 18,
                          color: AppColors.g2,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "You're doing an amazing job caring for your teeth.",
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CircularScorePainter extends CustomPainter {
  final double score; // 0.0 to 1.0

  const _CircularScorePainter({required this.score});

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 7.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - strokeWidth / 2;

    // Background track
    final trackPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc — teal gradient effect via single color
    final progressPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF5DE8D8), Color(0xFF2CA6A4)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * score;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // start at top
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_CircularScorePainter old) => old.score != score;
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
              color: AppColors.navy,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: AppColors.secondaryText,
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
      color: AppColors.border,
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
      {'label': 'Sep 7', 'active': true},
    ];

    return Row(
      children: List.generate(points.length, (i) {
        final isActive = points[i]['active'] as bool;
        final label = points[i]['label'] as String;
        return Expanded(
          flex: i < points.length - 1 ? 1 : 0,
          child: Row(
            children: [
              Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive ? AppColors.g2 : AppColors.border,
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: AppColors.g2.withValues(alpha: 0.3),
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
                      fontWeight:
                          isActive ? FontWeight.w700 : FontWeight.w400,
                      color: isActive
                          ? AppColors.navy
                          : AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
              if (i < points.length - 1)
                Expanded(
                  child: Container(
                    height: 1,
                    margin: const EdgeInsets.only(
                        bottom: 16, left: 4, right: 4),
                    color: AppColors.border,
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
        color: AppColors.lightLavender,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 13, color: AppColors.secondaryText),
              const SizedBox(width: 6),
              Text(
                'DAILY TIP',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppColors.secondaryText,
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
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: AppColors.secondaryText,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Ask AI button ─────────────────────────────────────────────────

class _AskAiButton extends StatefulWidget {
  @override
  State<_AskAiButton> createState() => _AskAiButtonState();
}

class _AskAiButtonState extends State<_AskAiButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {
          AiChatScope.of(context).open();
        },
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: _hovered ? 0.78 : 1.0,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 150),
            scale: _hovered ? 1.04 : 1.0,
            child: Container(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: _hovered
                    ? [
                        BoxShadow(
                          color: AppColors.primaryGradient.colors.first
                              .withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
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
            ),
          ),
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
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 5),
            Icon(Icons.arrow_forward_rounded,
                size: 14, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
