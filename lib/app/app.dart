import 'package:flutter/material.dart';
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
import '../features/auth/screens/login_screen.dart';
import '../features/onboarding/screens/onboarding_screen.dart';

class DentraApp extends StatelessWidget {
  const DentraApp({super.key, this.onboardingCompleted = false});

  /// Loaded from `OnboardingStorage` in `main()` before the first frame.
  final bool onboardingCompleted;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DENTRA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      // ── Auth gate: onboarding on first launch, then sign-in.
      //    '/home' lands on AppShell ──
      home:
          onboardingCompleted ? const LoginScreen() : const OnboardingScreen(),
      routes: {
        '/home': (_) => const AppShell(),
      },
    );
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
      HomeScreen(onNavigate: _navigate),
      const ScanScreen(),
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
                  ),
                ],
              ),

              // ── AI chat overlay (floats above everything) ───
              const AiChatOverlay(),
            ],
          ),
        ),
      ),
    );
  }
}
