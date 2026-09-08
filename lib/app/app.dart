import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../features/home/screens/home_screen.dart';
import '../features/scan/screens/scan_screen.dart';
import '../features/history/screens/history_screen.dart';
import '../features/clinics/screens/clinics_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../shared/widgets/app_bottom_nav.dart';

class DentraApp extends StatelessWidget {
  const DentraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DENTRA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const AppShell(),
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

  void _navigate(int index) {
    setState(() => _tab = index);
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      HomeScreen(onNavigate: _navigate),
      const ScanScreen(),
      const HistoryScreen(),
      const ClinicsScreen(),
      const ProfileScreen(),
    ];

    // Use LayoutBuilder so we always get tight constraints,
    // then Column(Expanded + nav) fills the full viewport on web too.
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFF),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            children: [
              // Screen body fills all remaining space
              Expanded(
                child: IndexedStack(
                  index: _tab,
                  sizing: StackFit.expand,
                  children: screens,
                ),
              ),
              // Bottom nav always pinned at bottom
              AppBottomNav(
                activeIndex: _tab,
                onTap: _navigate,
              ),
            ],
          );
        },
      ),
    );
  }
}
