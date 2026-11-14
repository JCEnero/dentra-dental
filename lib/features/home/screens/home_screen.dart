import 'package:flutter/services.dart' show ByteData;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vector_graphics/vector_graphics.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/gradient_divider.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../ai_assistant/ai_chat_controller.dart';
import '../../app_tour/data/app_tour_targets.dart';
import '../../comparison/screens/comparison_screen.dart';
import '../../history/screens/tooth_history_explorer.dart';
import '../../treatment/screens/treatment_screen.dart';
import '../../notifications/data/notification_events.dart';
import '../../notifications/providers/notifications_provider.dart';
import '../../notifications/widgets/notification_bell.dart';
import '../../profile/providers/profile_provider.dart';
import '../../profile/screens/edit_profile_screen.dart';
import '../data/daily_tip_repository.dart';
import '../providers/daily_tip_provider.dart';
import '../widgets/latest_scan_card.dart';
import '../widgets/screening_activity_card.dart';

class HomeScreen extends ConsumerWidget {
  final ValueChanged<int> onNavigate;

  /// Keys the app tour uses to point at the bell and services.
  final AppTourTargets? tourTargets;

  const HomeScreen({super.key, required this.onNavigate, this.tourTargets});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).valueOrNull;
    final firstName = profile?.firstName ?? '';
    final tip =
        ref.watch(dailyTipProvider(ref.watch(currentDayProvider))).valueOrNull;

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
                  NotificationBell(
                    key: tourTargets?.notifications,
                    onOpenProfile: () => onNavigate(4),
                  ),
                  const SizedBox(width: 10),
                  // Opens Edit Profile; the Profile tab until it has loaded.
                  Semantics(
                    button: true,
                    label: 'Edit profile',
                    excludeSemantics: true,
                    child: Tooltip(
                      message: 'Edit profile',
                      child: Material(
                        type: MaterialType.transparency,
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () async {
                            if (profile == null) return onNavigate(4);
                            final saved =
                                await Navigator.of(context, rootNavigator: true)
                                    .push(EditProfileScreen.route(profile));
                            if (saved != true || !context.mounted) return;
                            ref
                                .read(notificationsProvider.notifier)
                                .record(NotificationEvents.profileUpdated());
                            showDentraSnack(context, 'Profile updated.');
                          },
                          child: AvatarWidget(
                            size: 44,
                            initials: profile?.initials ?? '',
                            imageBytes: profile?.avatarBytes,
                          ),
                        ),
                      ),
                    ),
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
                    key: tourTargets?.teeth,
                    icon: ServiceIcons.teeth,
                    label: 'Teeth',
                    semanticLabel: 'Dental Explorer',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ToothHistoryExplorer(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  _ServiceButton(
                    key: tourTargets?.treatment,
                    icon: ServiceIcons.treatment,
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
                  const SizedBox(width: 8),
                  _ServiceButton(
                    key: tourTargets?.comparison,
                    icon: ServiceIcons.comparison,
                    label: 'Comparison',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (routeContext) => ComparisonScreen(
                            onStartScreening: () {
                              Navigator.of(routeContext).pop();
                              onNavigate(1);
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  _ServiceButton(
                    key: tourTargets?.rabi,
                    icon: ServiceIcons.rabi,
                    label: 'Rabi AI',
                    onTap: () => AiChatScope.read(context).open(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── DAILY TIP ─────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
              child: _DailyTipCard(tip: tip),
            ),

            const SizedBox(height: 28),
            const GradientDivider(),

            // ── SCREENING HISTORY GRAPH ───────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenH,
                  AppSpacing.sectionGap, AppSpacing.screenH, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const LatestScanCard(),
                  const ScreeningActivityCard(),
                  const SizedBox(height: 2),
                  // Full history and reports live on the History tab.
                  _LinkButton(
                    label: 'View Full History',
                    onTap: () => onNavigate(2),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.sectionGap),
            const GradientDivider(),

            // ── RABI AI ───────────────────────────────────────
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
                              'RABI AI',
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

class _DeviceHeroCard extends StatelessWidget {
  final VoidCallback onScan;
  const _DeviceHeroCard({required this.onScan});

  /// The waving mascot: an animated WebP with transparency (12 fps, 5 s
  /// loop). `Image` stops advancing frames while TickerMode is off (a
  /// hidden tab or a covered page) and when animations are disabled.
  static const _mascot = 'assets/images/bunny_wave.webp';

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
                        'Connected · Battery 87% · Signal Strong',
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
                      label: '87%',
                      semanticLabel: 'Battery 87%',
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
                  onTap: onScan,
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
                child: Image.asset(
                  _mascot,
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomRight,
                  gaplessPlayback: true,
                ),
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

/// The four Services icons, drawn on the glass with no backing disc.
/// Public so the loading phase can decode them before Home appears.
abstract class ServiceIcons {
  static const teeth = 'assets/images/icons/teeth.svg';
  static const treatment = 'assets/images/icons/treatment.svg';
  static const comparison = 'assets/images/icons/comparison.svg';
  static const rabi = 'assets/images/icons/rabi-ai.svg';

  static const all = [teeth, treatment, comparison, rabi];

  /// Loads every icon into memory, so the row is complete on Home's first
  /// frame instead of popping in a moment later.
  static Future<void> precache() => Future.wait([
        for (final asset in all) _IconLoader(asset).loadBytes(null),
      ]);
}

/// Loads an icon compiled at build time (the vector_graphics_compiler
/// transformer in pubspec.yaml) and keeps its bytes, so the SVG is never
/// parsed on the device and each icon is read from the bundle once.
class _IconLoader extends AssetBytesLoader {
  const _IconLoader(super.assetName);

  static final _bytes = <String, Future<ByteData>>{};

  @override
  Future<ByteData> loadBytes(BuildContext? context) =>
      _bytes.putIfAbsent(assetName, () => super.loadBytes(context));
}

class _ServiceButton extends StatelessWidget {
  /// Icon asset from [ServiceIcons].
  final String icon;
  final String label;

  /// Fuller name for screen readers when the visible label is short.
  final String? semanticLabel;
  final VoidCallback onTap;

  const _ServiceButton({
    super.key,
    required this.icon,
    required this.label,
    this.semanticLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        label: semanticLabel ?? label,
        excludeSemantics: true,
        child: GlassCard(
          onTap: onTap,
          child: CustomPaint(
            painter: const _ServiceTilePainter(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 15, 6, 17),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  VectorGraphic(
                    loader: _IconLoader(icon),
                    width: 30,
                    height: 30,
                    excludeFromSemantics: true,
                  ),
                  const SizedBox(height: 9),
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
      ),
    );
  }
}

/// The quiet teal inside each Services tile: a soft wash that deepens
/// toward the lower right corner, and the glass rim catching teal light
/// along the same edge. No shapes, so the tile still reads as plain white
/// glass and the icon keeps no backing of its own.
class _ServiceTilePainter extends CustomPainter {
  const _ServiceTilePainter();

  /// Matches the GlassCard's corner radius.
  static const _radius = Radius.circular(16);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.g1.withValues(alpha: 0),
            AppColors.g1.withValues(alpha: 0.20),
          ],
          stops: const [0.35, 1],
        ).createShader(rect),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(0.5), _radius),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.white.withValues(alpha: 0),
            AppColors.g1.withValues(alpha: 0.55),
          ],
          stops: const [0.4, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_ServiceTilePainter old) => false;
}

// ── Daily tip card ────────────────────────────────────────────────

class _DailyTipCard extends StatelessWidget {
  /// Null while today's tip loads.
  final DailyTip? tip;
  const _DailyTipCard({required this.tip});

  @override
  Widget build(BuildContext context) {
    final t = tip;
    Widget bar(double width, double height) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: AppColors.g2.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
        );

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
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: t == null
                ? ExcludeSemantics(
                    key: const ValueKey('loading'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        bar(180, 14),
                        const SizedBox(height: 12),
                        bar(double.infinity, 10),
                        const SizedBox(height: 8),
                        bar(200, 10),
                      ],
                    ),
                  )
                : Column(
                    key: ValueKey(t.date),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.headline,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t.body,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: AppColors.secondaryText,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        t.aiGenerated
                            ? 'Smart general tip · not personal advice'
                            : 'General tip · not personal advice',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: AppColors.secondaryText.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
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
