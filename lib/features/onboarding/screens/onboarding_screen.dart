import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/screens/registration_screen.dart';
import '../../auth/widgets/dentra_logo.dart';
import '../data/onboarding_content.dart';
import '../services/onboarding_storage.dart';
import '../widgets/onboarding_controls.dart';
import '../widgets/onboarding_palette.dart';
import '../widgets/onboarding_slide_view.dart';
import '../widgets/onboarding_stage.dart';

enum OnboardingMode {
  /// Shown on first launch. Finishing persists completion and hands off to
  /// the auth flow.
  firstRun,

  /// Opened again from inside the app. Finishing simply closes it.
  replay,
}

enum _AuthDestination { login, registration }

/// Three-slide introduction to DENTRA.
///
/// Slide copy and visuals come from `onboardingSlides`. This widget owns only
/// navigation, completion, and hand-off to the auth screens.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.mode = OnboardingMode.firstRun});

  final OnboardingMode mode;

  /// Route for replaying onboarding from inside the app.
  static Route<void> replayRoute() => MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => const OnboardingScreen(mode: OnboardingMode.replay),
      );

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final List<OnboardingSlideContent> _slides = onboardingSlides;

  int _index = 0;
  _AuthDestination? _pendingDestination;
  bool _isClosing = false;

  bool get _isReplay => widget.mode == OnboardingMode.replay;
  bool get _isLast => _index == _slides.length - 1;
  bool get _isBusy => _pendingDestination != null || _isClosing;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ── Slide navigation ─────────────────────────────────────────

  void _goTo(int index) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _pageController.jumpToPage(index);
    } else {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _next() {
    if (_isBusy) return;
    if (!_isLast) {
      _goTo(_index + 1);
    } else if (_isReplay) {
      _close();
    } else {
      _finish(_AuthDestination.registration);
    }
  }

  void _back() {
    if (_index > 0 && !_isBusy) _goTo(_index - 1);
  }

  // ── Exit paths ───────────────────────────────────────────────

  void _close() {
    if (_isBusy) return;
    setState(() => _isClosing = true);
    Navigator.of(context).pop();
  }

  /// Persists completion, then replaces onboarding with the chosen auth
  /// screen so Back does not return here.
  Future<void> _finish(_AuthDestination destination) async {
    if (_isBusy) return;
    setState(() => _pendingDestination = destination);

    await OnboardingStorage.markCompleted();
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => switch (destination) {
          _AuthDestination.login => const LoginScreen(),
          _AuthDestination.registration => const RegistrationScreen(),
        },
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 320),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final _HeaderAction headerAction;
    if (_isReplay) {
      headerAction = _HeaderAction(
        label: 'Close',
        semanticLabel: 'Close introduction',
        onTap: _close,
      );
    } else if (_isLast) {
      headerAction = _HeaderAction(
        label: 'Log In',
        semanticLabel: 'Log in',
        outlined: true,
        onTap: () => _finish(_AuthDestination.login),
      );
    } else {
      headerAction = _HeaderAction(
        label: 'Skip',
        semanticLabel: 'Skip introduction',
        onTap: () => _finish(_AuthDestination.login),
      );
    }

    final geometry = OnboardingGeometry.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Light status bar icons over the teal stage; dark navigation bar
      // icons over the white surface.
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: OnboardingPalette.surfaceTint,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: PopScope(
        // System back steps through slides before leaving onboarding.
        canPop: _index == 0 && !_isBusy,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _back();
        },
        child: Scaffold(
          backgroundColor: AppColors.white,
          body: Stack(
            children: [
              Positioned.fill(
                child: OnboardingStage(
                  pageController: _pageController,
                  geometry: geometry,
                ),
              ),
              PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => OnboardingSlideView(
                  content: _slides[i],
                  index: i,
                  pageController: _pageController,
                  isActive: i == _index,
                  geometry: geometry,
                ),
              ),
              // Overlaid chrome. Empty areas let swipes reach the PageView.
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: _Centered(child: _Header()),
                ),
              ),
              // The action sits in the screen's own top-right corner, not
              // the centred content column, at any width.
              Positioned(
                top: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  left: false,
                  child: _HeaderActionButton(
                    action: headerAction,
                    enabled: !_isBusy,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: geometry.controlsBottomPadding,
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: _Centered(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      child: OnboardingControls(
                        slideCount: _slides.length,
                        currentIndex: _index,
                        finalLabel: _isReplay ? 'Done' : 'Get Started',
                        onNext: _next,
                        onBack: _back,
                        isBusy: _isBusy,
                        buttonSize: kOnboardingButtonSize,
                        isPrimaryLoading: _pendingDestination ==
                            _AuthDestination.registration,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Centres chrome at the content column's maximum width.
class _Centered extends StatelessWidget {
  const _Centered({required this.child});

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

class _HeaderAction {
  const _HeaderAction({
    required this.label,
    required this.semanticLabel,
    required this.onTap,
    this.outlined = false,
  });

  final String label;
  final String semanticLabel;
  final VoidCallback onTap;
  final bool outlined;
}

/// The logo, aligned with the content column.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    // Fixed-height bar: the logo scales down rather than crowd the action
    // in the corner on narrow screens.
    final width = MediaQuery.sizeOf(context).width;
    return SizedBox(
      height: kOnboardingHeaderExtent,
      child: Padding(
        padding:
            EdgeInsets.only(left: AppSpacing.lg, right: width < 360 ? 96 : 120),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Semantics(
              label: 'DENTRA',
              excludeSemantics: true,
              child: const DentraLogo(onDark: true, size: 0.72),
            ),
          ),
        ),
      ),
    );
  }
}

/// Skip / Log In / Close, pinned to the top-right corner. The inset and
/// pill size follow the screen width.
class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({required this.action, required this.enabled});

  final _HeaderAction action;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 360;
    final inset = compact ? 10.0 : (width >= 600 ? 24.0 : 14.0);

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: SizedBox(
        height: kOnboardingHeaderExtent,
        child: Padding(
          padding: EdgeInsets.only(right: inset),
          child: Center(
            child: AnimatedSwitcher(
              duration: duration,
              child: Semantics(
                key: ValueKey(action.label),
                label: action.semanticLabel,
                button: true,
                excludeSemantics: true,
                child: TextButton(
                  onPressed: enabled ? action.onTap : null,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 40),
                    tapTargetSize: MaterialTapTargetSize.padded,
                    padding:
                        EdgeInsets.symmetric(horizontal: compact ? 14 : 18),
                    foregroundColor: AppColors.white,
                    // Outlined for Log In; a soft frosted pill otherwise.
                    backgroundColor: action.outlined
                        ? Colors.transparent
                        : AppColors.white.withValues(alpha: 0.16),
                    shape: StadiumBorder(
                      side: BorderSide(
                        color: AppColors.white.withValues(
                          alpha: action.outlined ? 0.75 : 0.32,
                        ),
                        width: action.outlined ? 1.2 : 1,
                      ),
                    ),
                  ),
                  child: Text(
                    action.label,
                    style: GoogleFonts.outfit(
                      fontSize: compact ? 13 : 14,
                      fontWeight:
                          action.outlined ? FontWeight.w700 : FontWeight.w600,
                      color: AppColors.white,
                    ),
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
