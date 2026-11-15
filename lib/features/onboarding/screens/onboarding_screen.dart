import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../shared/widgets/app_backdrop.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/screens/registration_screen.dart';
import '../../auth/widgets/dentra_logo.dart';
import '../data/onboarding_content.dart';
import '../services/onboarding_storage.dart';
import '../widgets/onboarding_controls.dart';
import '../widgets/onboarding_slide_view.dart';
import '../widgets/welcome_stage.dart';

enum OnboardingMode {
  /// Shown on first launch. Finishing persists completion and hands off to
  /// the auth flow.
  firstRun,

  /// Opened again from inside the app. Finishing simply closes it.
  replay,
}

enum _AuthDestination { login, registration }

/// The welcome slides: an introduction to DENTRA built around its camera.
///
/// Slide copy comes from `onboardingSlides`; the picture is one shared
/// `WelcomeStage` that follows the swipe. This widget owns only navigation,
/// completion, and hand-off to the auth screens.
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
        icon: Icons.close_rounded,
        onTap: _close,
      );
    } else if (_isLast) {
      headerAction = _HeaderAction(
        label: 'Log In',
        semanticLabel: 'Log in',
        emphasis: true,
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
      // Dark status and navigation bar icons over the light glass page.
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: kWelcomeNavigationBar,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: PopScope(
        // System back steps through slides before leaving onboarding.
        canPop: _index == 0 && !_isBusy,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _back();
        },
        child: Scaffold(
          backgroundColor: AppColors.lightLavender,
          body: AppBackdrop(
            child: Stack(
              children: [
                // The whole screen, so its light fades out on its own.
                Positioned.fill(
                  child: WelcomeStage(
                    pageController: _pageController,
                    top: geometry.stageTop,
                    bottom: geometry.stageBottom,
                    semanticLabel: _slides[_index].visualDescription,
                    labelStyle: GoogleFonts.outfit(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                    ),
                  ),
                ),
                // Swipes anywhere on the screen move the slides.
                PageView.builder(
                  controller: _pageController,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) => OnboardingSlideView(
                    content: _slides[i],
                    index: i,
                    pageController: _pageController,
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
                    child: _Header(),
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
                  bottom: geometry.controlsBottom,
                  child: SafeArea(
                    top: false,
                    bottom: false,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: kOnboardingMaxContentWidth,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                          ),
                          child: OnboardingControls(
                            pageController: _pageController,
                            slideCount: _slides.length,
                            currentIndex: _index,
                            finalLabel: _isReplay ? 'Done' : 'Get Started',
                            onNext: _next,
                            onBack: _back,
                            isBusy: _isBusy,
                            isPrimaryLoading: _pendingDestination ==
                                _AuthDestination.registration,
                          ),
                        ),
                      ),
                    ),
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

/// The page backdrop's lowest tone, for the system navigation bar.
const Color kWelcomeNavigationBar = Color(0xFFEBF8F6);

class _HeaderAction {
  const _HeaderAction({
    required this.label,
    required this.semanticLabel,
    required this.onTap,
    this.emphasis = false,
    this.icon,
  });

  final String label;
  final String semanticLabel;
  final VoidCallback onTap;

  /// Shown on its own, with no pill behind it, in place of [label].
  final IconData? icon;

  /// Log In on the last slide: teal words and a firmer rim.
  final bool emphasis;
}

/// The full-colour logo at the top left.
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
        padding: EdgeInsets.only(
          left: AppSpacing.lg - 4,
          right: width < 360 ? 96 : 120,
        ),
        child: const Align(
          alignment: Alignment.centerLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: DentraLogo(size: 1.22),
          ),
        ),
      ),
    );
  }
}

/// Skip / Log In / Close: a small frosted glass pill in the top-right
/// corner, clearly a button but quieter than the main one.
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
    final inset = compact ? 12.0 : (width >= 600 ? 24.0 : 18.0);

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: SizedBox(
        height: kOnboardingHeaderExtent,
        child: Padding(
          padding: EdgeInsets.only(right: inset),
          child: Center(
            child: AnimatedSwitcher(
              duration: duration,
              child: action.icon != null
                  ? _bareIcon(action)
                  : Semantics(
                      key: ValueKey(action.label),
                      label: action.semanticLabel,
                      button: true,
                      excludeSemantics: true,
                      child: Material(
                        color: AppColors.white.withValues(alpha: 0.62),
                        shape: StadiumBorder(
                          side: BorderSide(
                            color: AppColors.g2.withValues(
                              alpha: action.emphasis ? 0.4 : 0.16,
                            ),
                            width: action.emphasis ? 1.3 : 1,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: enabled ? action.onTap : null,
                          splashColor: AppColors.g1.withValues(alpha: 0.14),
                          highlightColor: AppColors.g1.withValues(alpha: 0.06),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 64),
                            child: SizedBox(
                              height: 44,
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: compact ? 14 : 18,
                                ),
                                child: Center(
                                  widthFactor: 1,
                                  child: Text(
                                    action.label,
                                    style: GoogleFonts.outfit(
                                      fontSize: compact ? 13.5 : 14,
                                      fontWeight: action.emphasis
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      color: action.emphasis
                                          ? kOnboardingInk
                                          : AppColors.navy
                                              .withValues(alpha: 0.7),
                                    ),
                                  ),
                                ),
                              ),
                            ),
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

  /// Just the glyph, in navy: no pill, no rim. Still a full 48px target.
  Widget _bareIcon(_HeaderAction action) {
    return Semantics(
      key: ValueKey(action.label),
      label: action.semanticLabel,
      button: true,
      excludeSemantics: true,
      child: IconButton(
        onPressed: enabled ? action.onTap : null,
        tooltip: action.label,
        iconSize: 28,
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: AppColors.navy.withValues(alpha: 0.78),
          highlightColor: AppColors.g1.withValues(alpha: 0.12),
        ),
        icon: Icon(action.icon),
      ),
    );
  }
}
