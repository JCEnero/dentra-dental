import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
// The onboarding is the visual source of truth for the auth screens: same
// backdrop, header geometry and content width, so the hand-off from the
// final slide reads as one continuous surface.
import '../../onboarding/data/onboarding_content.dart';
import '../../onboarding/widgets/onboarding_backdrop.dart';
import '../../onboarding/widgets/onboarding_palette.dart';
import '../../onboarding/widgets/onboarding_slide_view.dart'
    show kOnboardingHeaderExtent, kOnboardingMaxContentWidth;
import 'dentra_logo.dart';

/// Shared layout for the auth screens: the onboarding's teal backdrop at the
/// top, a white crest (the onboarding's solid ribbon) rising into the form
/// surface, and a pinned action area that stays above the keyboard.
class AuthScaffold extends StatefulWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.form,
    required this.primaryAction,
    this.notice,
    this.footer,
    this.expandHero = true,
  });

  final String title;
  final String subtitle;

  /// The fields. Wrapped in an [AutofillGroup] and given the entrance
  /// animation.
  final Widget form;

  /// Pinned below the form, always visible (also above the keyboard).
  final Widget primaryAction;

  /// Short note shown just above [primaryAction], e.g. a consent line.
  /// Steps aside while the keyboard is open.
  final Widget? notice;

  /// Shown under [primaryAction]; steps aside while the keyboard is open.
  final Widget? footer;

  /// Whether the hero grows with taller screens. Turn off for long forms:
  /// the hero then stays compact and the fields get the space.
  final bool expandHero;

  @override
  State<AuthScaffold> createState() => _AuthScaffoldState();
}

class _AuthScaffoldState extends State<AuthScaffold>
    with SingleTickerProviderStateMixin {
  // Entrance for the form only; the header stays put for continuity.
  late final AnimationController _entranceCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _fade =
      CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.04),
    end: Offset.zero,
  ).animate(_fade);
  bool _entranceStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entranceStarted) return;
    _entranceStarted = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _entranceCtrl.value = 1;
    } else {
      _entranceCtrl.forward();
    }
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboardOpen = media.viewInsets.bottom > 0;
    // Based on the full window, so opening the keyboard never reflows the
    // hero.
    final compact = media.size.height < 700 || !widget.expandHero;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Light status bar over teal; dark navigation bar icons over white.
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: Stack(
          children: [
            // Same tone as the final onboarding slide.
            const Positioned.fill(
              child: OnboardingBackdrop(visual: OnboardingVisual.monitoring),
            ),
            Column(
              children: [
                // Keeps the status bar over teal even when the form scrolls.
                SizedBox(height: media.padding.top),
                Expanded(
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: () => FocusScope.of(context).unfocus(),
                        behavior: HitTestBehavior.opaque,
                        child: CustomScrollView(
                          physics: const ClampingScrollPhysics(),
                          slivers: [
                            SliverToBoxAdapter(
                              child: _AuthHero(
                                // Any auth screen pushed on top of another
                                // gets a way back; the root login doesn't.
                                // Reactive (unlike Navigator.canPop), so a
                                // screen that faded in over the splash
                                // drops the button once the splash is gone.
                                onBack: (ModalRoute.of(context)
                                            ?.impliesAppBarDismissal ??
                                        false)
                                    ? () => Navigator.maybePop(context)
                                    : null,
                                title: widget.title,
                                subtitle: widget.subtitle,
                                compact: compact,
                                headingGap: _headingGap(compact, media),
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: ColoredBox(
                                color: AppColors.white,
                                child: _ContentWidth(child: _buildForm()),
                              ),
                            ),
                            // Paints any leftover space white. It has no
                            // intrinsic size of its own, so animated error
                            // messages in the form never cause overflow.
                            // Reaches 1px up under the form to hide
                            // sub-pixel seams.
                            const SliverFillRemaining(
                              hasScrollBody: false,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned(
                                    top: -1,
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    child: ColoredBox(color: AppColors.white),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Softens the edge where scrolled content meets the
                      // pinned action area (short screens, keyboard open).
                      const Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: AppSpacing.lg,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0x00FFFFFF), AppColors.white],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _ActionArea(
                  keyboardOpen: keyboardOpen,
                  primaryAction: widget.primaryAction,
                  notice: widget.notice,
                  footer: widget.footer,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Taller screens give the heading more air instead of leaving an empty
  /// gap above the pinned button.
  double _headingGap(bool compact, MediaQueryData media) {
    if (compact) return AppSpacing.md;
    return ((media.size.height - 700) * 0.4).clamp(AppSpacing.xl, 104.0);
  }

  Widget _buildForm() {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xs,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: AutofillGroup(child: widget.form),
        ),
      ),
    );
  }
}

// ── Layout helpers ────────────────────────────────────────────────────────────

/// Centres content at the onboarding's maximum width (tablets, foldables).
class _ContentWidth extends StatelessWidget {
  const _ContentWidth({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: kOnboardingMaxContentWidth,
        ),
        child: child,
      ),
    );
  }
}

// ── Hero ──────────────────────────────────────────────────────────────────────

/// Logo, heading and subtitle on the teal backdrop, ending in a white crest
/// that becomes the form surface below.
/// Frosted round back button that sits on the teal hero.
class _HeroBackButton extends StatelessWidget {
  const _HeroBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: 'Back',
      style: IconButton.styleFrom(
        backgroundColor: AppColors.white.withValues(alpha: 0.18),
        foregroundColor: AppColors.white,
        fixedSize: const Size(44, 44),
        minimumSize: const Size(44, 44),
        side: BorderSide(color: AppColors.white.withValues(alpha: 0.35)),
      ),
      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
    );
  }
}

class _AuthHero extends StatelessWidget {
  const _AuthHero({
    required this.title,
    required this.subtitle,
    required this.compact,
    required this.headingGap,
    this.onBack,
  });

  /// Shows a back button beside the logo when set.
  final VoidCallback? onBack;
  final String title;
  final String subtitle;
  final bool compact;
  final double headingGap;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final scale = compact ? 0.85 : 1.0;
    final crestDepth = (width * 0.16).clamp(44.0, 84.0) * scale;
    final headingSize = (width * 0.105).clamp(32.0, 46.0) * scale;

    return CustomPaint(
      painter: _HeroFormsPainter(crestDepth: crestDepth),
      child: _ContentWidth(
        child: Padding(
          // Leaves room for the veil, contour and crest beneath the text.
          padding: EdgeInsets.only(bottom: crestDepth * 1.75),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Same height and inset as the onboarding header, so the logo
              // does not move during the hand-off.
              SizedBox(
                height: kOnboardingHeaderExtent,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: Row(
                    children: [
                      if (onBack != null) ...[
                        _HeroBackButton(onPressed: onBack!),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      Semantics(
                        label: 'DENTRA',
                        excludeSemantics: true,
                        child: const DentraLogo(onDark: true, size: 0.72),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: headingGap),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        // Display type is already large; cap extra scaling
                        // so the composition holds.
                        textScaler: MediaQuery.textScalerOf(context).clamp(
                          maxScaleFactor: 1.3,
                        ),
                        style: GoogleFonts.outfit(
                          fontSize: headingSize,
                          fontWeight: FontWeight.w800,
                          color: AppColors.white,
                          letterSpacing: -headingSize * 0.03,
                          height: 1.05,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm + 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                        color: AppColors.white.withValues(alpha: 0.85),
                      ),
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

/// The onboarding's flowing forms, adapted: a translucent side disc, a
/// veil and a hairline contour, then an opaque white crest that fills to
/// the bottom edge and continues as the form surface.
class _HeroFormsPainter extends CustomPainter {
  const _HeroFormsPainter({required this.crestDepth});

  final double crestDepth;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final c = crestDepth;

    // The hero paints above the form in the scroll view, so nothing may
    // spill past its bounds, except the crest's 1px overlap that hides
    // sub-pixel seams with the form.
    canvas.clipRect(Rect.fromLTRB(0, 0, w, h + 1));

    // Side form entering from the right edge, behind the heading. Kept
    // inside the hero so the scroll viewport never clips its rim.
    final discRadius = (w * 0.34).clamp(0.0, 190.0);
    final discCenter = Offset(w * 0.98, discRadius + 4);
    final discRect = Rect.fromCircle(center: discCenter, radius: discRadius);
    canvas.drawCircle(
      discCenter,
      discRadius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: [
            AppColors.white.withValues(alpha: 0.16),
            AppColors.white.withValues(alpha: 0.04),
          ],
        ).createShader(discRect),
    );
    canvas.drawCircle(
      discCenter,
      discRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.white.withValues(alpha: 0.18),
    );

    // Veil: tints the teal toward white just above the crest.
    final veilEdge =
        _edge(w, h - 0.85 * c, h - 1.55 * c, h - 0.55 * c, h - 1.35 * c);
    canvas.drawPath(
      _fillBelow(veilEdge, w, h),
      Paint()..color = AppColors.white.withValues(alpha: 0.09),
    );
    canvas.drawPath(
      veilEdge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.white.withValues(alpha: 0.22),
    );

    // Hairline contour crossing the veil for rhythm.
    canvas.drawPath(
      _edge(w, h - 1.25 * c, h - 0.95 * c, h - 1.70 * c, h - 1.05 * c),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.white.withValues(alpha: 0.35),
    );

    // Solid white crest with a soft teal shadow on its leading edge.
    final crestEdge =
        _edge(w, h - 0.30 * c, h - 1.10 * c, h - 0.10 * c, h - 0.80 * c);
    // The shadow shape runs well past the bottom and is clipped there, so
    // its blurred lower edge never bleeds onto the form below.
    canvas
      ..save()
      ..clipRect(Rect.fromLTRB(-2, 0, w + 2, h));
    canvas.drawPath(
      _fillBelow(crestEdge, w, h + c).shift(Offset(0, -c * 0.06)),
      Paint()
        ..color = OnboardingPalette.shadow.withValues(alpha: 0.25)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, c * 0.12),
    );
    canvas.restore();
    canvas.drawPath(
        _fillBelow(crestEdge, w, h), Paint()..color = AppColors.white);
  }

  /// A full-width cubic edge: y at the left, two control points, y at the
  /// right. Extends 2px past each side so no seam shows.
  Path _edge(double w, double y0, double y1, double y2, double y3) => Path()
    ..moveTo(-2, y0)
    ..cubicTo(w * 0.34, y1, w * 0.66, y2, w + 2, y3);

  Path _fillBelow(Path edge, double w, double h) => Path.from(edge)
    ..lineTo(w + 2, h + 1)
    ..lineTo(-2, h + 1)
    ..close();

  @override
  bool shouldRepaint(_HeroFormsPainter old) => old.crestDepth != crestDepth;
}

// ── Action area ───────────────────────────────────────────────────────────────

class _ActionArea extends StatelessWidget {
  const _ActionArea({
    required this.keyboardOpen,
    required this.primaryAction,
    required this.notice,
    required this.footer,
  });

  final bool keyboardOpen;
  final Widget primaryAction;
  final Widget? notice;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final hasBottomInset = MediaQuery.paddingOf(context).bottom > 0;

    return ColoredBox(
      color: AppColors.white,
      child: SafeArea(
        top: false,
        child: _ContentWidth(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              keyboardOpen || hasBottomInset ? AppSpacing.sm : AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (notice != null && !keyboardOpen) ...[
                  notice!,
                  const SizedBox(height: AppSpacing.sm + 4),
                ],
                primaryAction,
                if (footer != null && !keyboardOpen) ...[
                  const SizedBox(height: AppSpacing.xs),
                  footer!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Question? Action" line under the primary button, e.g.
/// "Don't have an account? Sign up".
class AuthFooterLink extends StatelessWidget {
  const AuthFooterLink({
    super.key,
    required this.prompt,
    required this.action,
    required this.onTap,
  });

  final String prompt;
  final String action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Wrap rather than Row so large accessibility text never overflows.
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          prompt,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.secondaryText,
          ),
        ),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 44),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            foregroundColor: AppColors.primary,
            shape: const StadiumBorder(),
          ),
          child: Text(
            action,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// Full-width teal pill: the on-white counterpart of the onboarding's white
/// "Get Started" pill. Shows a spinner and ignores taps while [loading].
class AuthPillButton extends StatelessWidget {
  const AuthPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loadingLabel,
    this.loading = false,
    this.semanticLabel,
  });

  final String label;
  final String? loadingLabel;
  final String? semanticLabel;
  final bool loading;
  final VoidCallback? onPressed;

  static const double _height = 56;

  @override
  Widget build(BuildContext context) {
    final textStyle = GoogleFonts.outfit(
      fontSize: 16,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.2,
      color: AppColors.white,
    );
    final busyLabel = loadingLabel ?? label;

    final Widget content = loading
        ? Row(
            key: const ValueKey('loading'),
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(busyLabel, maxLines: 1, style: textStyle),
              ),
            ],
          )
        : Text(
            label,
            key: const ValueKey('label'),
            maxLines: 1,
            style: textStyle,
          );

    return Semantics(
      button: true,
      enabled: !loading && onPressed != null,
      label: loading ? busyLabel : (semanticLabel ?? label),
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          // Turquoise → base: the deeper end of the brand gradient keeps
          // white text as legible as the palette allows.
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [OnboardingPalette.turquoise, OnboardingPalette.base],
          ),
          borderRadius: BorderRadius.circular(_height / 2),
          boxShadow: [
            BoxShadow(
              color: OnboardingPalette.shadow.withValues(alpha: 0.28),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: loading ? null : onPressed,
            child: SizedBox(
              height: _height,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: AnimatedSwitcher(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 200),
                    child: content,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Feedback ──────────────────────────────────────────────────────────────────

/// Form-level error (e.g. from the auth service), announced to screen
/// readers when it appears.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 4,
        ),
        decoration: BoxDecoration(
          color: AppColors.coral.withValues(alpha: 0.08),
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: AppColors.coral.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                Icons.error_outline_rounded,
                size: 18,
                color: AppColors.coral,
              ),
            ),
            const SizedBox(width: AppSpacing.sm + 2),
            Expanded(
              // Navy text keeps the message readable; coral carries the tone.
              child: Text(
                message,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.navy,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fades a form-level [AuthErrorBanner] in and out.
class AuthErrorSlot extends StatelessWidget {
  const AuthErrorSlot({super.key, required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      child: message != null
          ? AuthErrorBanner(message: message!)
          : const SizedBox(width: double.infinity),
    );
  }
}
