import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../shared/widgets/app_backdrop.dart';
import '../../../shared/widgets/dentra_glass_ui.dart' show dentraMotion;
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/gloss_pill_button.dart';
import 'dentra_logo.dart';

/// Deep teal from the logo's wordmark, for teal words on glass (links). It
/// keeps 4.5:1 contrast where the brand teal would not.
const Color kAuthInk = Color(0xFF1D7F8E);

/// Widest the auth content grows on tablets and foldables.
const double _maxContentWidth = 460;

/// Shared layout for the auth screens, in the main app's style: the light
/// mint backdrop, the logo at the top, a centred title, the fields on one
/// frosted glass card, and a pinned action area that stays above the
/// keyboard. When the form runs under the action area, the area frosts
/// over so the two never blur together.
///
/// A screen can lay a [background] behind it all, which the glass card
/// frosts where they overlap, and put its title on the card.
class AuthScaffold extends StatefulWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.form,
    required this.primaryAction,
    this.background,
    this.titleOnCard = false,
    this.notice,
    this.footer,
    this.expandHero = true,
  });

  final String title;
  final String subtitle;

  /// The fields. Placed on the glass card, wrapped in an [AutofillGroup] and
  /// given the entrance animation.
  final Widget form;

  /// Pinned below the form, always visible (also above the keyboard).
  final Widget primaryAction;

  /// Fills the screen behind everything, e.g. `AuthAbstractBackdrop`. It
  /// holds still while the keyboard opens.
  final Widget? background;

  /// Puts the title and subtitle at the top of the glass card instead of
  /// above it, where a busy [background] can't run behind them.
  final bool titleOnCard;

  /// Short note shown just above [primaryAction], e.g. a consent line.
  /// Steps aside while the keyboard is open.
  final Widget? notice;

  /// Shown under [primaryAction]; steps aside while the keyboard is open.
  final Widget? footer;

  /// Whether the heading gets the generous spacing of a short form. Turn
  /// off for long forms: the heading then stays compact and the fields get
  /// the space.
  final bool expandHero;

  @override
  State<AuthScaffold> createState() => _AuthScaffoldState();
}

class _AuthScaffoldState extends State<AuthScaffold>
    with SingleTickerProviderStateMixin {
  // Entrance for everything under the logo; the logo stays put for
  // continuity with the screen before.
  late final AnimationController _entranceCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );
  late final Animation<double> _headingIn = CurvedAnimation(
    parent: _entranceCtrl,
    curve: const Interval(0, 0.7, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _cardIn = CurvedAnimation(
    parent: _entranceCtrl,
    curve: const Interval(0.18, 1, curve: Curves.easeOutCubic),
  );
  bool _entranceStarted = false;

  final _scroll = ScrollController();

  /// True while the form runs on under the action area.
  final _docked = ValueNotifier<bool>(false);

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
    _scroll.dispose();
    _docked.dispose();
    super.dispose();
  }

  bool _onScroll(Notification n) {
    final metrics = switch (n) {
      ScrollNotification(:final metrics) => metrics,
      ScrollMetricsNotification(:final metrics) => metrics,
      _ => null,
    };
    if (metrics != null && metrics.axis == Axis.vertical) {
      _docked.value = metrics.extentAfter > 1;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboardOpen = media.viewInsets.bottom > 0;
    // Based on the full window, so opening the keyboard never reflows the
    // heading.
    final compact = media.size.height < 700 || !widget.expandHero;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Dark status and navigation bar icons over the light glass page.
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: const Color(0xFFEBF8F6),
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      // The backdrop sits outside the Scaffold, so it holds still while
      // the keyboard resizes the page.
      child: ColoredBox(
        color: AppColors.lightLavender,
        child: AppBackdrop(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (widget.background case final background?)
                Positioned.fill(child: background),
              Scaffold(
                backgroundColor: Colors.transparent,
                body: Column(
                  children: [
                    // Keeps the status bar clear even when the form scrolls.
                    SizedBox(height: media.padding.top),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => FocusScope.of(context).unfocus(),
                        behavior: HitTestBehavior.opaque,
                        child: NotificationListener<Notification>(
                          onNotification: _onScroll,
                          child: LayoutBuilder(
                            builder: (context, viewport) =>
                                SingleChildScrollView(
                              controller: _scroll,
                              physics: const ClampingScrollPhysics(),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: viewport.maxHeight,
                                ),
                                child: _ContentWidth(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.lg - 4,
                                    ),
                                    // Logo at the top; the rest centred in the
                                    // space left, a little above the middle.
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        _AuthHeader(
                                          // Any auth screen pushed on top of
                                          // another gets a way back; the root
                                          // login doesn't. Reactive (unlike
                                          // Navigator.canPop), so a screen that
                                          // faded in over the splash drops the
                                          // button once the splash is gone.
                                          onBack: (ModalRoute.of(context)
                                                      ?.impliesAppBarDismissal ??
                                                  false)
                                              ? () =>
                                                  Navigator.maybePop(context)
                                              : null,
                                        ),
                                        _buildBody(compact),
                                        SizedBox(
                                          height: compact
                                              ? AppSpacing.md
                                              : AppSpacing.xl + 8,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    ValueListenableBuilder<bool>(
                      valueListenable: _docked,
                      builder: (context, docked, _) => _ActionArea(
                        docked: docked,
                        keyboardOpen: keyboardOpen,
                        primaryAction: widget.primaryAction,
                        notice: widget.notice,
                        footer: widget.footer,
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

  Widget _buildBody(bool compact) {
    final screen = MediaQuery.sizeOf(context);
    final titleSize =
        (screen.width * 0.082).clamp(27.0, 33.0) * (compact ? 0.92 : 1);
    final onCard = widget.titleOnCard;

    Widget rise(Animation<double> a, double from, Widget child) =>
        FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween<Offset>(begin: Offset(0, from), end: Offset.zero)
                .animate(a),
            child: child,
          ),
        );

    return Column(
      children: [
        SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
        if (!onCard) ...[
          rise(_headingIn, 0.12, _heading(titleSize)),
          SizedBox(height: compact ? AppSpacing.md + 4 : AppSpacing.lg + 4),
        ],
        rise(
          _cardIn,
          0.06,
          GlassCard(
            borderRadius: BorderRadius.all(Radius.circular(onCard ? 30 : 28)),
            borderWidth: onCard ? 1.4 : 1.2,
            padding: onCard
                ? const EdgeInsets.fromLTRB(20, 26, 20, 12)
                : const EdgeInsets.fromLTRB(18, 20, 18, 12),
            child: onCard
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _heading(titleSize * 0.84),
                      const SizedBox(height: AppSpacing.lg - 2),
                      AutofillGroup(child: widget.form),
                    ],
                  )
                : AutofillGroup(child: widget.form),
          ),
        ),
      ],
    );
  }

  /// The title and subtitle, centred.
  Widget _heading(double titleSize) {
    return Column(
      children: [
        Semantics(
          header: true,
          child: Text(
            widget.title,
            textAlign: TextAlign.center,
            // Display type is already large; cap extra scaling so the
            // composition holds.
            textScaler: MediaQuery.textScalerOf(context).clamp(
              maxScaleFactor: 1.3,
            ),
            style: GoogleFonts.outfit(
              fontSize: titleSize,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
              letterSpacing: -titleSize * 0.025,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Text(
            widget.subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              height: 1.45,
              color: AppColors.secondaryText,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Layout helpers ────────────────────────────────────────────────────────────

/// Centres content at the auth screens' maximum width.
class _ContentWidth extends StatelessWidget {
  const _ContentWidth({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxContentWidth),
        child: child,
      ),
    );
  }
}

/// The full-colour logo, centred, with a round glass Back button at the
/// left when there is somewhere to go back to.
class _AuthHeader extends StatelessWidget {
  const _AuthHeader({this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Semantics(
            label: 'DENTRA',
            excludeSemantics: true,
            child: const DentraLogo(size: 1.05),
          ),
          if (onBack != null)
            Align(
              alignment: Alignment.centerLeft,
              child: _BackButton(onPressed: onBack!),
            ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: 'Back',
      style: IconButton.styleFrom(
        backgroundColor: AppColors.white.withValues(alpha: 0.62),
        foregroundColor: AppColors.navy,
        highlightColor: AppColors.g1.withValues(alpha: 0.12),
        fixedSize: const Size(44, 44),
        minimumSize: const Size(44, 44),
        side: BorderSide(color: AppColors.g2.withValues(alpha: 0.18)),
      ),
      icon: const Icon(Icons.arrow_back_rounded, size: 20),
    );
  }
}

// ── Action area ───────────────────────────────────────────────────────────────

class _ActionArea extends StatelessWidget {
  const _ActionArea({
    required this.docked,
    required this.keyboardOpen,
    required this.primaryAction,
    required this.notice,
    required this.footer,
  });

  /// The form runs on underneath, so the area frosts over.
  final bool docked;
  final bool keyboardOpen;
  final Widget primaryAction;
  final Widget? notice;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final hasBottomInset = MediaQuery.paddingOf(context).bottom > 0;

    return ClipRect(
      child: GlassBlur(
        child: AnimatedContainer(
          duration: dentraMotion(context, 220),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: docked ? 0.72 : 0),
            border: Border(
              top: BorderSide(
                color: AppColors.g2.withValues(alpha: docked ? 0.12 : 0),
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: _ContentWidth(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg - 4,
                  AppSpacing.sm + 4,
                  AppSpacing.lg - 4,
                  keyboardOpen || hasBottomInset
                      ? AppSpacing.sm
                      : AppSpacing.md,
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
                      const SizedBox(height: AppSpacing.xs + 2),
                      footer!,
                    ],
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

/// "Question? Action" line under the primary button, e.g.
/// "Don't have an account? Sign up". Quiet grey words with the action in
/// teal.
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
            foregroundColor: kAuthInk,
            overlayColor: AppColors.g1,
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

/// The auth screens' main button: the app's glossy teal pill with an arrow
/// on a white disc. Shows a spinner and ignores taps while [loading].
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

  @override
  Widget build(BuildContext context) {
    return GlossPillButton(
      label: label,
      semanticLabel: semanticLabel,
      loading: loading,
      loadingLabel: loadingLabel,
      onPressed: onPressed,
      height: 56,
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
        margin:
            const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md - 2,
          vertical: AppSpacing.sm + 4,
        ),
        decoration: BoxDecoration(
          color: AppColors.coral.withValues(alpha: 0.08),
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          border: Border.all(color: AppColors.coral.withValues(alpha: 0.28)),
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
    final banner = message != null
        ? AuthErrorBanner(message: message!)
        : const SizedBox(width: double.infinity);
    // Under reduced motion it simply appears: AnimatedSize can't run with no
    // duration.
    if (MediaQuery.disableAnimationsOf(context)) return banner;
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      child: banner,
    );
  }
}
