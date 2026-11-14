import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/theme.dart';
import '../core/constants/app_colors.dart';
import '../features/home/screens/home_screen.dart';
import '../features/scan/screens/scan_screen.dart';
import '../features/history/screens/history_screen.dart';
import '../features/clinics/screens/clinics_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../shared/widgets/app_backdrop.dart';
import '../shared/widgets/app_bottom_nav.dart';
import '../features/ai_assistant/ai_chat_controller.dart';
import '../features/ai_assistant/ai_assistant.dart';
import '../features/app_tour/data/app_tour_targets.dart';
import '../features/app_tour/widgets/app_tour_overlay.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/dental_profile/widgets/dental_onboarding_gate.dart';
import '../features/onboarding/screens/onboarding_screen.dart';
import '../features/onboarding/services/onboarding_storage.dart';
import '../features/splash/screens/session_loader.dart';

class DentraApp extends ConsumerStatefulWidget {
  const DentraApp({super.key, this.onboardingCompleted = false});

  /// Loaded from `OnboardingStorage` in `main()` before the first frame.
  final bool onboardingCompleted;

  @override
  ConsumerState<DentraApp> createState() => _DentraAppState();
}

class _DentraAppState extends ConsumerState<DentraApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  /// Debug only: every hot reload replays the launch loader, once the
  /// welcome introduction is done. It lands back on home when signed in,
  /// sign-in otherwise.
  @override
  void reassemble() {
    super.reassemble();
    if (!kDebugMode) return;
    OnboardingStorage.isCompleted().then((completed) {
      final navigator = _navigatorKey.currentState;
      if (!completed || navigator == null || !mounted) return;
      navigator.pushAndRemoveUntil(
        PageRouteBuilder<void>(
          transitionDuration: Duration.zero,
          pageBuilder: (_, __, ___) => const SessionLoader(restore: true),
        ),
        (_) => false,
      );
    });
  }

  /// ── Auth gate: onboarding on first launch. Returning users get the
  /// launch loader, which restores their session and loads their data
  /// before home, or shows sign-in when there is no session. '/home'
  /// (every sign-in) goes through the same loader ──
  Widget get _start => widget.onboardingCompleted
      ? const SessionLoader(restore: true)
      : const OnboardingScreen();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dentra',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      navigatorKey: _navigatorKey,
      // Always launch at [_start], alone. On web a refresh would otherwise
      // rebuild the stack from the URL (e.g. `#/home`), stacking a screen
      // over the splash and giving it a back button. Read lazily, like
      // MaterialApp's own `home`, so it follows widget updates.
      onGenerateInitialRoutes: (_) => [
        MaterialPageRoute<void>(builder: (_) => _start),
      ],
      // '/home' is how every sign-in enters the app: the loader fades in
      // over the sign-in screen and lets the user in once their data is
      // loaded.
      onGenerateRoute: (settings) => settings.name == '/home'
          ? PageRouteBuilder<void>(
              settings: settings,
              pageBuilder: (_, __, ___) => const SessionLoader(),
              transitionsBuilder: (_, anim, __, child) => FadeTransition(
                opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
                child: child,
              ),
              transitionDuration: const Duration(milliseconds: 320),
            )
          : null,
    );
  }
}

/// Shows the app only while a session is live; sign-in otherwise. Every
/// way into the app goes through here, so no route, stale flag or hot
/// reload can open it signed out. Swaps to sign-in as soon as the
/// session ends. Signed-in users who haven't completed their dental
/// profile get the onboarding questionnaire first.
class SignedInGate extends ConsumerWidget {
  const SignedInGate({super.key, this.app = const AppShell()});

  /// What signed-in users see. Tests swap in a stand-in, since the real
  /// shell needs device plugins.
  final Widget app;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(authServiceProvider).isAuthenticated;
    return signedIn ? DentalOnboardingGate(app: app) : const LoginScreen();
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;
  final AiChatController _aiChat = AiChatController();
  final AppTourTargets _tour = AppTourTargets(AppBottomNav.itemCount);

  @override
  void dispose() {
    _aiChat.dispose();
    super.dispose();
  }

  void _navigate(int index) {
    setState(() => _tab = index);
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      HomeScreen(onNavigate: _navigate, tourTargets: _tour),
      ScanScreen(onNavigate: _navigate),
      HistoryScreen(onNavigate: _navigate),
      const ClinicsScreen(),
      ProfileScreen(onNavigate: _navigate),
    ];

    return AiChatScope(
      controller: _aiChat,
      child: Scaffold(
        backgroundColor: AppColors.lightLavender,
        body: AppBackdrop(
          child: Stack(
            children: [
              // ── Main app UI ─────────────────────────────────
              Column(
                children: [
                  Expanded(
                    child: IndexedStack(
                      index: _tab,
                      sizing: StackFit.expand,
                      children: screens,
                    ),
                  ),
                  AppBottomNav(
                    activeIndex: _tab,
                    onTap: _navigate,
                    itemKeys: _tour.tabs,
                  ),
                ],
              ),

              // ── AI chat overlay (floats above everything) ───
              const AiChatOverlay(),

              // ── First-run app tour (above everything) ───────
              Positioned.fill(
                child: AppTour(targets: _tour, onSelectTab: _navigate),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
