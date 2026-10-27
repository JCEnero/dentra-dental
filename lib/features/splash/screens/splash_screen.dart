import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_glass.dart';
import '../../../shared/widgets/app_backdrop.dart';
import '../../auth/widgets/dentra_logo.dart';

/// Launch animation for returning users: a frosted glass tile settles in
/// over drifting teal light, the D mark rises into it, a sheen sweeps
/// across, then the wordmark tightens into place, then fades away to
/// reveal [next].
///
/// [next] is built inside this same route rather than pushed as a new
/// one, so it becomes the root screen: nothing sits beneath it to go
/// "back" to.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.next});

  /// The screen shown once the animation ends (login or home).
  final WidgetBuilder next;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  /// Brand teal from the logo's wordmark.
  static const Color _wordmarkColor = Color(0xFF1D7F8E);
  static const double _tileSize = 132;

  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  /// Slow, endless drift of the light behind the glass.
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  )..repeat();

  // ── Choreography (fractions of the intro) ───────────────────
  late final Animation<double> _tile =
      _curve(0.0, 0.36, Curves.easeOutCubic);
  late final Animation<double> _mark = _curve(0.16, 0.48, Curves.easeOutBack);
  late final Animation<double> _ring = _curve(0.30, 0.78, Curves.easeOut);
  late final Animation<double> _sheen = _curve(0.40, 0.70, Curves.easeInOut);
  late final Animation<double> _word = _curve(0.46, 0.78, Curves.easeOutCubic);
  late final Animation<double> _tagline =
      _curve(0.60, 0.88, Curves.easeOutCubic);

  /// Fades the splash out over [SplashScreen.next] once the intro ends.
  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  bool _started = false;
  bool _left = false;

  Animation<double> _curve(double begin, double end, Curve curve) =>
      CurvedAnimation(
        parent: _intro,
        curve: Interval(begin, end, curve: curve),
      );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    final reduceMotion = MediaQuery.of(context).disableAnimations;
    // Decode the logo first so it never pops in mid-animation, but never
    // hold launch on it for more than a moment.
    Future.any<void>([
      precacheImage(const AssetImage(DentraLogo.markAsset), context),
      Future<void>.delayed(const Duration(milliseconds: 300)),
    ]).whenComplete(() {
      if (!mounted) return;
      if (reduceMotion) {
        _ambient.stop();
        _intro.value = 1;
        Future.delayed(const Duration(milliseconds: 900), _leave);
      } else {
        _intro.forward().whenComplete(_leave);
      }
    });
  }

  void _leave() {
    if (!mounted || _left) return;
    setState(() => _left = true);
    _exit.forward().whenComplete(() {
      if (mounted) _ambient.stop();
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _ambient.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_left) return _buildSplash();

    final out = CurvedAnimation(parent: _exit, curve: Curves.easeOutCubic);
    return Stack(
      fit: StackFit.expand,
      children: [
        // The next screen settles in from a hair larger as the splash lifts.
        ScaleTransition(
          scale: Tween<double>(begin: 1.03, end: 1).animate(out),
          child: widget.next(context),
        ),
        AnimatedBuilder(
          animation: _exit,
          builder: (context, splash) => _exit.isCompleted
              ? const SizedBox.shrink()
              : IgnorePointer(
                  child: Opacity(opacity: 1 - out.value, child: splash),
                ),
          child: _buildSplash(),
        ),
      ],
    );
  }

  Widget _buildSplash() {
    return Scaffold(
      backgroundColor: AppColors.lightLavender,
      body: Semantics(
        label: 'DENTRA is starting',
        child: AppBackdrop(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Moving light gives the glass something to blur.
              RepaintBoundary(
                child: CustomPaint(painter: _DriftingLightPainter(_ambient)),
              ),
              Center(
                child: AnimatedBuilder(
                  animation: _intro,
                  builder: (context, _) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTile(),
                      const SizedBox(height: 28),
                      _buildWordmark(),
                      const SizedBox(height: 10),
                      _buildTagline(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Glass tile with the D mark ──────────────────────────────

  Widget _buildTile() {
    final t = _tile.value;
    final radius = BorderRadius.circular(38);

    return SizedBox.square(
      dimension: _tileSize,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // One soft ring that ripples outward as the mark lands.
          if (_ring.value > 0 && _ring.value < 1)
            Transform.scale(
              scale: 1 + _ring.value * 0.55,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: AppColors.white
                        .withValues(alpha: (1 - _ring.value) * 0.9),
                    width: 1.4,
                  ),
                ),
              ),
            ),
          Opacity(
            opacity: t,
            child: Transform.scale(
              scale: 0.86 + 0.14 * t,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.g2.withValues(alpha: 0.16 * t),
                      blurRadius: 40,
                      offset: const Offset(0, 18),
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
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _buildMark(),
                          _buildSheen(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMark() {
    final m = _mark.value;
    return Opacity(
      opacity: m.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, (1 - m) * 14),
        child: Transform.scale(
          scale: 0.88 + 0.12 * m,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Image.asset(DentraLogo.markAsset, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  /// A diagonal band of light that crosses the tile once.
  Widget _buildSheen() {
    final s = _sheen.value;
    if (s == 0 || s == 1) return const SizedBox.shrink();
    return IgnorePointer(
      child: FractionalTranslation(
        translation: Offset(-1.2 + s * 2.4, 0),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.white.withValues(alpha: 0),
                AppColors.white.withValues(alpha: 0.55),
                AppColors.white.withValues(alpha: 0),
              ],
              stops: const [0.35, 0.5, 0.65],
            ),
          ),
        ),
      ),
    );
  }

  // ── Text ────────────────────────────────────────────────────

  Widget _buildWordmark() {
    final w = _word.value;
    return Opacity(
      opacity: w,
      child: Transform.translate(
        offset: Offset(0, (1 - w) * 8),
        child: Text(
          'DENTRA',
          style: GoogleFonts.outfit(
            fontSize: 26,
            fontWeight: FontWeight.w500,
            color: _wordmarkColor,
            // Letters drift together as the word settles.
            letterSpacing: 7 + (1 - w) * 8,
            height: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildTagline() {
    final g = _tagline.value;
    return Opacity(
      opacity: g,
      child: Text(
        'A better way to manage your dental practice.',
        style: GoogleFonts.outfit(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppColors.secondaryText,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Two soft teal orbs circling slowly around the center of the screen.
class _DriftingLightPainter extends CustomPainter {
  _DriftingLightPainter(this.progress) : super(repaint: progress);

  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final a = progress.value * 2 * math.pi;
    final r = math.min(size.width, size.height) * 0.16;

    _orb(canvas, c + Offset(math.cos(a) * r, math.sin(a) * r * 0.8 - 30),
        radius: 120, color: AppColors.g1, opacity: 0.55);
    _orb(
        canvas,
        c +
            Offset(math.cos(a + math.pi) * r * 1.1,
                math.sin(a + math.pi) * r * 0.7 + 20),
        radius: 100,
        color: AppColors.g2,
        opacity: 0.40);
  }

  void _orb(
    Canvas canvas,
    Offset center, {
    required double radius,
    required Color color,
    required double opacity,
  }) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_DriftingLightPainter old) => old.progress != progress;
}
