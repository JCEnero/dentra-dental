import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_glass.dart';
import '../../../shared/widgets/app_backdrop.dart';
import '../widgets/dentra_logo.dart';

/// Bridge between a successful sign-in and home: the D mark sits in a
/// breathing glass tile while a teal arc orbits it, status lines step
/// through what's happening, then everything lifts away and '/home'
/// fades in.
///
/// Pushed with [route], which clears the stack so "back" can't return
/// to the sign-in form.
class SignInLoadingScreen extends StatefulWidget {
  const SignInLoadingScreen({super.key, this.name});

  /// First name for the greeting; falls back to a plain "Welcome back".
  final String? name;

  /// Fades in over the sign-in screen.
  static Route<void> route({String? name}) => PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => SignInLoadingScreen(name: name),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 320),
      );

  @override
  State<SignInLoadingScreen> createState() => _SignInLoadingScreenState();
}

class _SignInLoadingScreenState extends State<SignInLoadingScreen>
    with TickerProviderStateMixin {
  static const double _tileSize = 112;
  static const _steps = [
    'Signing you in',
    'Loading your dashboard',
    'Almost there',
  ];

  /// Total time on screen before leaving, excluding the exit.
  static const _hold = Duration(milliseconds: 1800);

  /// Drives the progress bar and the status steps, once.
  late final AnimationController _progress =
      AnimationController(vsync: this, duration: _hold);

  /// Endless orbit of the arc and the tile's breathing.
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  /// Content entrance (rise + fade in).
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  /// Content lifting away before home takes over.
  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );

  bool _started = false;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _progress.addListener(_syncStep);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    precacheImage(const AssetImage(DentraLogo.markAsset), context);

    if (MediaQuery.of(context).disableAnimations) {
      // Reduced motion: static layout, short hold, no orbit.
      _enter.value = 1;
      _progress.duration = const Duration(milliseconds: 900);
    } else {
      _spin.repeat();
      _enter.forward();
    }
    _progress.forward().whenComplete(_leave);
  }

  void _syncStep() {
    final step = (_progress.value * _steps.length)
        .floor()
        .clamp(0, _steps.length - 1);
    if (step != _step) setState(() => _step = step);
  }

  Future<void> _leave() async {
    if (!mounted) return;
    if (!MediaQuery.of(context).disableAnimations) await _exit.forward();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
  }

  @override
  void dispose() {
    _progress.dispose();
    _spin.dispose();
    _enter.dispose();
    _exit.dispose();
    super.dispose();
  }

  String get _greeting {
    final first = widget.name?.trim().split(RegExp(r'\s+')).first;
    return first == null || first.isEmpty
        ? 'Welcome back'
        : 'Welcome back, $first';
  }

  @override
  Widget build(BuildContext context) {
    final enter = CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic);
    final exit = CurvedAnimation(parent: _exit, curve: Curves.easeInCubic);

    return PopScope(
      // Nothing to go back to mid-sign-in.
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.lightLavender,
        body: AppBackdrop(
          child: SafeArea(
            child: AnimatedBuilder(
              animation: Listenable.merge([_enter, _exit]),
              builder: (context, child) {
                final rise = (1 - enter.value) * 18 - exit.value * 12;
                return Opacity(
                  opacity: enter.value * (1 - exit.value),
                  child: Transform.translate(
                    offset: Offset(0, rise),
                    child: Transform.scale(
                      scale: 1 + exit.value * 0.04,
                      child: child,
                    ),
                  ),
                );
              },
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTile(),
                      const SizedBox(height: 36),
                      Text(
                        _greeting,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildStatus(),
                      const SizedBox(height: 28),
                      _buildProgressBar(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Glass tile with the orbiting arc ────────────────────────

  Widget _buildTile() {
    final radius = BorderRadius.circular(32);
    const orbit = _tileSize + 40;

    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: orbit,
        child: AnimatedBuilder(
          animation: _spin,
          builder: (context, tile) {
            // Gentle breathing, two cycles per orbit.
            final breath = math.sin(_spin.value * math.pi * 2 * 2);
            return Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size.square(orbit),
                  painter: _OrbitPainter(_spin.value),
                ),
                Transform.scale(scale: 1 + breath * 0.02, child: tile),
              ],
            );
          },
          child: Container(
            width: _tileSize,
            height: _tileSize,
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: AppColors.g2.withValues(alpha: 0.16),
                  blurRadius: 36,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: DecoratedBox(
                  decoration: AppGlass.surface(
                    borderRadius: radius,
                    borderWidth: 1.4,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(26),
                    child: Image.asset(
                      DentraLogo.markAsset,
                      fit: BoxFit.contain,
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

  // ── Status line + progress ──────────────────────────────────

  Widget _buildStatus() {
    final text = '${_steps[_step]}…';
    return Semantics(
      liveRegion: true,
      label: text,
      child: ExcludeSemantics(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.35),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: Text(
            text,
            key: ValueKey(_step),
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 15,
              color: AppColors.secondaryText,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return ExcludeSemantics(
      child: SizedBox(
        width: 160,
        height: 4,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: AppColors.g2.withValues(alpha: 0.14)),
              AnimatedBuilder(
                animation: _progress,
                builder: (context, _) => FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: Curves.easeInOutCubic.transform(_progress.value),
                  child: const DecoratedBox(
                    decoration:
                        BoxDecoration(gradient: AppColors.primaryGradient),
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

/// A faint full ring with a bright teal arc sweeping around it.
class _OrbitPainter extends CustomPainter {
  const _OrbitPainter(this.t);

  /// Orbit position, 0 → 1.
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 3;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.g2.withValues(alpha: 0.12),
    );

    // Arc length eases between short and long as it travels.
    final sweep = math.pi * (0.45 + 0.35 * math.sin(t * math.pi * 2).abs());
    final start = t * math.pi * 2 - math.pi / 2;

    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: sweep,
          colors: [AppColors.g1.withValues(alpha: 0), AppColors.g2],
          transform: GradientRotation(start),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => old.t != t;
}
