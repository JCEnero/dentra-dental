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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Light status/navigation bar icons over the teal backdrop.
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: OnboardingPalette.base,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: PopScope(
        // System back steps through slides before leaving onboarding.
        canPop: _index == 0 && !_isBusy,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _back();
        },
        child: Scaffold(
          backgroundColor: OnboardingPalette.base,
          body: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => OnboardingSlideView(
                  content: _slides[i],
                  index: i,
                  pageController: _pageController,
                  isActive: i == _index,
                ),
              ),
              // Overlaid chrome. Empty areas let swipes reach the PageView.
              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: kOnboardingMaxContentWidth,
                    ),
                    child: Column(
                      children: [
                        _Header(action: headerAction, enabled: !_isBusy),
                        const Spacer(),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            0,
                            AppSpacing.lg,
                            MediaQuery.paddingOf(context).bottom > 0
                                ? AppSpacing.sm
                                : AppSpacing.lg,
                          ),
                          child: OnboardingControls(
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
                      ],
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

class _Header extends StatelessWidget {
  const _Header({required this.action, required this.enabled});

  final _HeaderAction action;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);

    return SizedBox(
      height: kOnboardingHeaderExtent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.md,
          0,
        ),
        child: Row(
          children: [
            Semantics(
              label: 'DENTRA',
              excludeSemantics: true,
              child: const DentraLogo(onDark: true, size: 0.72),
            ),
            const Spacer(),
            AnimatedSwitcher(
              duration: duration,
              child: Semantics(
                key: ValueKey(action.label),
                label: action.semanticLabel,
                button: true,
                excludeSemantics: true,
                child: TextButton(
                  onPressed: enabled ? action.onTap : null,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    foregroundColor: AppColors.white,
                    shape: action.outlined
                        ? StadiumBorder(
                            side: BorderSide(
                              color: AppColors.white.withValues(alpha: 0.7),
                              width: 1.2,
                            ),
                          )
                        : const StadiumBorder(),
                  ),
                  child: Text(
                    action.label,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight:
                          action.outlined ? FontWeight.w700 : FontWeight.w600,
                      color: AppColors.white.withValues(
                        alpha: action.outlined ? 1.0 : 0.85,
                      ),
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
