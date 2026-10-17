import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/gradient_divider.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/services/mock_data.dart';
import '../../../shared/widgets/section_label.dart';
import '../../ai_assistant/ai_chat_controller.dart';
import '../../treatment/screens/treatment_screen.dart';
import '../../notifications/widgets/notification_bell.dart';
import '../../profile/providers/profile_provider.dart';
import '../../screening/providers/screening_sessions_provider.dart';
import '../../../core/utils/dentra_dates.dart';

class HomeScreen extends ConsumerWidget {
  final ValueChanged<int> onNavigate;

  const HomeScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).valueOrNull;
    final firstName = profile?.firstName ?? '';
    final last = ref.watch(screeningSessionsProvider).valueOrNull?.firstOrNull;
    final tip = MockData.dailyTips.first;

    return SafeArea(
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
                        // One quiet line, so it doesn't compete with
                        // the device card's headline below.
                        Text.rich(
                          TextSpan(
                            text: 'Good morning, ',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: AppColors.secondaryText,
                            ),
                            children: [
                              TextSpan(
                                text: firstName.isEmpty ? 'there' : firstName,
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.navy,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  NotificationBell(onOpenProfile: () => onNavigate(4)),
                  const SizedBox(width: 10),
                  AvatarWidget(
                    size: 44,
                    initials: profile?.initials ?? '',
                    imageBytes: profile?.avatarBytes,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── DEVICE HERO CARD ──────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
              child: _DeviceHeroCard(onScan: () => onNavigate(1)),
            ),

            const SizedBox(height: 28),

            // ── SERVICES ─────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
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

                ],
              ),
            ),

            const SizedBox(height: 14),

            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
              child: Row(
                children: [
                  _ServiceButton(
                    glyph: _ServiceGlyph.tooth,
                    label: 'My Teeth',
                    onTap: () => onNavigate(2),
                  ),
                  const SizedBox(width: 12),
                  _ServiceButton(
                    glyph: _ServiceGlyph.capsule,
                    label: 'Treatment',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TreatmentScreen(
                            onNavigateToTab: onNavigate,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  _ServiceButton(
                    glyph: _ServiceGlyph.trend,
                    label: 'Reports',
                    onTap: () => onNavigate(2),
                  ),
                  const SizedBox(width: 12),
                  _ServiceButton(
                    glyph: _ServiceGlyph.scan,
                    label: 'Rabi AI',
                    onTap: () => AiChatScope.read(context).open(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── DENTAL HEALTH SCORE ───────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
              child: _DentalHealthScoreCard(),
            ),

            const SizedBox(height: 28),
            const GradientDivider(),

            // ── DAILY TIP ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenH,
                  AppSpacing.sectionGap, AppSpacing.screenH, 0),
              child: _DailyTipCard(
                headline: tip['headline']!,
                body: tip['body']!,
              ),
            ),

            const SizedBox(height: AppSpacing.sectionGap),
            const GradientDivider(),

            // ── YOUR SCREENING ────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenH,
                  AppSpacing.sectionGap, AppSpacing.screenH, 0),
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
                    last == null
                        ? 'No screenings yet'
                        : DentraDates.long(last.completedAt),
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    last == null
                        ? 'Start a scan to see it here.'
                        : '${last.capturedRegions.length} images captured · '
                            '${last.capturedRegions.length} of '
                            '${last.totalRegions} regions',
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

            // ── DENTRA AI ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenH,
                  AppSpacing.sectionGap, AppSpacing.screenH, 0),
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
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
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
  late final VideoPlayerController _controller;

  /// False while Home is a hidden tab or covered by another page.
  bool _onScreen = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/videos/BUNNY.webm')
      ..setLooping(true)
      ..setVolume(0)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {});
          _syncPlayback();
        }
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // IndexedStack marks inactive tabs invisible, and routes under an
    // opaque page have tickers disabled. Either way nobody sees the video,
    // so stop decoding it until it is back on screen.
    _onScreen = Visibility.of(context) && TickerMode.valuesOf(context).enabled;
    _syncPlayback();
  }

  void _syncPlayback() {
    if (!_controller.value.isInitialized) return;
    if (_onScreen) {
      _controller.play();
    } else {
      _controller.pause();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static const _radius = BorderRadius.all(Radius.circular(24));

  @override
  Widget build(BuildContext context) {
    // Frosted pane: the teal is saved for the one action that matters,
    // so the card reads calm and the CTA stands out.
    return GlassCard(
      borderRadius: _radius,
      borderWidth: 1.5,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Soft mint stage the mascot stands on, just above the CTA.
          Positioned(
            right: -56,
            bottom: 40,
            width: 190,
            height: 190,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.lightLavender.withValues(alpha: 0.75),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Text keeps clear of the mascot on the right.
                Padding(
                  padding: const EdgeInsets.only(right: 80),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DENTRA DEVICE',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                          color: AppColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Scan your smile',
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                          letterSpacing: -0.4,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Connected · Battery 86% · Signal Strong',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          height: 1.35,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Status pills
                const Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatusPill(
                      icon: Icons.battery_5_bar_rounded,
                      label: '86%',
                      semanticLabel: 'Battery 86%',
                    ),
                    _StatusPill(
                      icon: Icons.wifi_rounded,
                      label: 'Strong',
                      semanticLabel: 'Signal strong',
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // CTA
                PrimaryButton(
                  label: 'Start Dental Scan',
                  onTap: widget.onScan,
                ),
              ],
            ),
          ),

          // Connected indicator, top-right corner.
          const Positioned(
            top: 20,
            right: 20,
            child: _LiveDot(),
          ),

          // Tooth Bunny video — overlaid right side
          Positioned(
            right: 7,
            // Feet float just above the top edge of the CTA.
            bottom: 61,
            width: 100,
            height: 100,
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: _controller.value.isInitialized
                    ? FittedBox(
                        fit: BoxFit.contain,
                        alignment: Alignment.bottomRight,
                        child: SizedBox(
                          width: _controller.value.size.width,
                          height: _controller.value.size.height,
                          child: VideoPlayer(_controller),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Green "connected" indicator with a soft halo.
class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.successGreen,
        border: Border.all(
          color: AppColors.successGreen.withValues(alpha: 0.25),
          width: 3,
          strokeAlign: BorderSide.strokeAlignOutside,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String label;

  /// Full phrase for screen readers, since the visible label is terse.
  final String semanticLabel;

  const _StatusPill({
    required this.icon,
    required this.label,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.lightLavender,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: AppColors.g2),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 10,
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

// ── Service button ────────────────────────────────────────────────

enum _ServiceGlyph { tooth, capsule, scan, trend }

class _ServiceButton extends StatelessWidget {
  final _ServiceGlyph glyph;
  final String label;
  final VoidCallback onTap;

  const _ServiceButton({
    required this.glyph,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: GlassCard(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 16, 6, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomPaint(
                  size: const Size.square(26),
                  painter: _ServiceGlyphPainter(glyph),
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Thin-line dental glyphs drawn on a 24×24 grid so all four share
/// the same stroke weight and visual size.
class _ServiceGlyphPainter extends CustomPainter {
  final _ServiceGlyph glyph;
  const _ServiceGlyphPainter(this.glyph);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);

    final stroke = Paint()
      ..color = AppColors.g2
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = AppColors.g2;
    final tint = Paint()..color = AppColors.g1.withValues(alpha: 0.28);

    switch (glyph) {
      case _ServiceGlyph.tooth:
        final tooth = Path()
          ..moveTo(12, 6.5)
          ..cubicTo(10.5, 5, 8.5, 4.5, 6.8, 5)
          ..cubicTo(4.6, 5.7, 3.8, 8, 4.3, 10.5)
          ..cubicTo(4.8, 13, 5.8, 14.5, 6.3, 17)
          ..cubicTo(6.7, 19, 7.2, 20.5, 8.3, 20.5)
          ..cubicTo(9.6, 20.5, 9.8, 18.6, 10.2, 17)
          ..cubicTo(10.5, 15.6, 11, 14.8, 12, 14.8)
          ..cubicTo(13, 14.8, 13.5, 15.6, 13.8, 17)
          ..cubicTo(14.2, 18.6, 14.4, 20.5, 15.7, 20.5)
          ..cubicTo(16.8, 20.5, 17.3, 19, 17.7, 17)
          ..cubicTo(18.2, 14.5, 19.2, 13, 19.7, 10.5)
          ..cubicTo(20.2, 8, 19.4, 5.7, 17.2, 5)
          ..cubicTo(15.5, 4.5, 13.5, 5, 12, 6.5)
          ..close();
        canvas.drawPath(tooth, tint);
        canvas.drawPath(tooth, stroke);

      case _ServiceGlyph.capsule:
        canvas.save();
        canvas.translate(12, 12);
        canvas.rotate(math.pi / 4);
        final body =
            RRect.fromLTRBR(-3.8, -8.5, 3.8, 8.5, const Radius.circular(3.8));
        // Tint the lower half so it reads as a two-tone capsule.
        canvas.save();
        canvas.clipRect(const Rect.fromLTRB(-4, 0, 4, 9));
        canvas.drawRRect(body, tint);
        canvas.restore();
        canvas.drawRRect(body, stroke);
        canvas.drawLine(const Offset(-3.8, 0), const Offset(3.8, 0), stroke);
        canvas.restore();

      case _ServiceGlyph.scan:
        // Viewfinder corners
        const a = 4.0, b = 20.0, l = 4.5;
        final corners = Path()
          ..moveTo(a, a + l)
          ..lineTo(a, a + 1.5)
          ..quadraticBezierTo(a, a, a + 1.5, a)
          ..lineTo(a + l, a)
          ..moveTo(b - l, a)
          ..lineTo(b - 1.5, a)
          ..quadraticBezierTo(b, a, b, a + 1.5)
          ..lineTo(b, a + l)
          ..moveTo(b, b - l)
          ..lineTo(b, b - 1.5)
          ..quadraticBezierTo(b, b, b - 1.5, b)
          ..lineTo(b - l, b)
          ..moveTo(a + l, b)
          ..lineTo(a + 1.5, b)
          ..quadraticBezierTo(a, b, a, b - 1.5)
          ..lineTo(a, b - l);
        canvas.drawPath(corners, stroke);
        // AI spark in the middle
        final spark = Path()
          ..moveTo(12, 7.8)
          ..quadraticBezierTo(12.7, 11.3, 16.2, 12)
          ..quadraticBezierTo(12.7, 12.7, 12, 16.2)
          ..quadraticBezierTo(11.3, 12.7, 7.8, 12)
          ..quadraticBezierTo(11.3, 11.3, 12, 7.8)
          ..close();
        canvas.drawPath(spark, fill);

      case _ServiceGlyph.trend:
        final area = Path()
          ..moveTo(4.5, 16)
          ..lineTo(9.5, 11)
          ..lineTo(13, 14)
          ..lineTo(19.5, 7.5)
          ..lineTo(19.5, 20)
          ..lineTo(4.5, 20)
          ..close();
        canvas.drawPath(area, tint);
        final line = Path()
          ..moveTo(4.5, 16)
          ..lineTo(9.5, 11)
          ..lineTo(13, 14)
          ..lineTo(19.5, 7.5);
        canvas.drawPath(line, stroke);
        canvas.drawLine(const Offset(4, 20), const Offset(20, 20), stroke);
        canvas.drawCircle(const Offset(19.5, 7.5), 1.9, fill);
    }
  }

  @override
  bool shouldRepaint(_ServiceGlyphPainter old) => old.glyph != glyph;
}

// ── Dental Health Score card ──────────────────────────────────────

class _DentalHealthScoreCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const double score = 0.85;
    const int percent = 85;

    return GlassCard(
      borderRadius: BorderRadius.circular(20),
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
              const Icon(Icons.more_horiz_rounded,
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
                  painter: const _CircularScorePainter(score: score),
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
                        const Icon(
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

// ── Daily tip card ────────────────────────────────────────────────

class _DailyTipCard extends StatelessWidget {
  final String headline;
  final String body;
  const _DailyTipCard({required this.headline, required this.body});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      tint: AppColors.lightLavender,
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded,
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
          AiChatScope.read(context).open();
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
                              .withValues(alpha: 0.35),
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
                      'Ask Rabi',
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
            const Icon(Icons.arrow_forward_rounded,
                size: 14, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
