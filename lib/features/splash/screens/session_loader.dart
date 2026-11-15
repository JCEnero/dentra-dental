import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/app.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_backdrop.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/services/auth_service.dart';
import '../../auth/widgets/dentra_logo.dart';
import '../../dental_profile/providers/dental_profile_providers.dart';
import '../../home/providers/daily_tip_provider.dart';
import '../../home/screens/home_screen.dart' show ServiceIcons;
import '../../notifications/providers/notifications_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../../screening/providers/screening_sessions_provider.dart';
import '../widgets/loading_mark.dart';

/// The app's one loading phase: on launch or a web refresh, and after
/// every sign-in.
///
/// It lets a user in only once the server has confirmed their session
/// and everything Home shows first has loaded: their profile (name and
/// photo), dental onboarding status, scan history and notifications.
/// Nothing ends it on a timer. If the server can't be reached or the data
/// can't load, it says so and offers to try again or sign out; if the
/// session ends while loading, sign-in comes next instead.
///
/// The D mark sits in a glass tile while a teal line traces its outline,
/// one step per thing that has really loaded. When the line closes, the
/// wordmark turns into a greeting with the user's name, then the app
/// settles in beneath.
///
/// The next screen is built inside this same route, so it becomes the
/// root: nothing sits beneath it to go "back" to.
class SessionLoader extends ConsumerStatefulWidget {
  const SessionLoader({
    super.key,
    this.restore = false,
    this.app = const AppShell(),
  });

  /// Launch: restore the stored session first, behind the brand intro.
  /// Sign-in leaves it false, since the session has just started.
  final bool restore;

  /// What signed-in users see once everything has loaded. Tests swap in
  /// a stand-in, since the real shell needs device plugins.
  final Widget app;

  @override
  ConsumerState<SessionLoader> createState() => _SessionLoaderState();
}

/// Why loading stopped short of the app.
enum _Stuck {
  /// A stored session exists but the server couldn't confirm it.
  unreachable,

  /// Signed in, but some of the user's data didn't load.
  data,
}

/// One thing the loader waits for, and the line shown while it does.
class _Step {
  _Step(this.label);

  final String label;
  bool done = false;
}

class _SessionLoaderState extends ConsumerState<SessionLoader>
    with TickerProviderStateMixin {
  /// Brand teal from the logo's wordmark; dark enough for text.
  static const Color _brandTeal = Color(0xFF1D7F8E);

  /// Room under the title for the status line, or the retry panel when
  /// loading is stuck, so the mark never jumps.
  static const double _panelHeight = 176;

  // ── Motion ──────────────────────────────────────────────────

  /// Brand entrance. Longer on launch, quick after sign-in.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.restore ? 1500 : 700),
  );

  /// Slow, endless drift of the light behind the glass.
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  );

  /// The line closing: glow, ripple and the mark's nod.
  late final AnimationController _finish = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  /// The loader lifting away over the next screen.
  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  late final Animation<double> _tileIn = _part(0, 0.45, Curves.easeOutCubic);
  late final Animation<double> _markIn = _part(0.15, 0.6, Curves.easeOutBack);
  late final Animation<double> _sheen = _part(0.45, 0.85, Curves.easeInOut);
  late final Animation<double> _wordIn = _part(0.35, 0.85, Curves.easeOutCubic);
  late final Animation<double> _traceIn = _part(0.4, 0.8, Curves.easeOut);
  late final Animation<double> _statusIn = _part(0.6, 1, Curves.easeOut);

  Animation<double> _part(double begin, double end, Curve curve) =>
      CurvedAnimation(
        parent: _intro,
        curve: Interval(begin, end, curve: curve),
      );

  // ── Progress line ───────────────────────────────────────────

  /// Eases the line toward what has really loaded. While a step is in
  /// flight it creeps toward the next one but never reaches it, so it
  /// keeps moving without ever claiming more than is done.
  late final Ticker _ticker = createTicker(_tick);
  final ValueNotifier<double> _trace = ValueNotifier<double>(0);
  Duration _now = Duration.zero;
  Duration _lastTick = Duration.zero;
  Duration _stepAt = Duration.zero;

  /// Everything is settled: run the line to the end.
  bool _closing = false;
  Completer<void>? _closed;

  // ── Loading ─────────────────────────────────────────────────

  final List<_Step> _steps = [
    _Step('Checking your session'),
    _Step('Loading your profile'),
    _Step('Loading your dental profile'),
    _Step('Getting your scans ready'),
    _Step('Syncing your notifications'),
  ];

  late Future<void> _introDone;
  bool _started = false;
  bool _reduceMotion = false;

  /// Bumped on every attempt, so a stale one can't act after a retry.
  int _attempt = 0;
  _Stuck? _stuck;
  bool _slow = false;
  Timer? _slowTimer;

  /// Filled in by the profile and onboarding steps, for the greeting.
  String _firstName = '';
  bool _returning = true;

  /// The wordmark has turned into the greeting.
  bool _greet = false;

  /// The next screen is built beneath the loader.
  bool _revealed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    // Decode the logo first so it never pops in, but never hold on it.
    final logo = precacheImage(const AssetImage(DentraLogo.markAsset), context)
        .timeout(const Duration(milliseconds: 300), onTimeout: () {});
    if (_reduceMotion) {
      _intro.value = 1;
      _finish.duration = Duration.zero;
      _exit.duration = Duration.zero;
      _introDone = Future<void>.value();
    } else {
      _ambient.repeat();
      // On web, index.html has already shown the tile and mark in this
      // same spot while the app downloaded: carry on from there.
      if (kIsWeb && widget.restore) _intro.value = 0.6;
      _introDone = logo.then<void>((_) {
        if (mounted) return _intro.forward().orCancel;
      }).catchError((Object _) {});
    }
    _ticker.start();
    // After this frame: loading sets state as it goes.
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    _ticker.dispose();
    _trace.dispose();
    _intro.dispose();
    _ambient.dispose();
    _finish.dispose();
    _exit.dispose();
    super.dispose();
  }

  bool _isCurrent(int attempt) => mounted && attempt == _attempt;

  /// Confirms the session, then loads the user's data in parallel. Ends
  /// in [_close] (in, or on to sign-in) or [_stop] (stuck, with a retry).
  Future<void> _load() async {
    final attempt = ++_attempt;
    _slowTimer?.cancel();
    _slowTimer = Timer(const Duration(seconds: 7), () {
      if (_isCurrent(attempt) && _stuck == null && !_closing) {
        setState(() => _slow = true);
      }
    });
    final auth = ref.read(authServiceProvider);

    // 1. The session, confirmed by the server.
    if (!_steps[0].done) {
      if (!auth.isAuthenticated) {
        if (!widget.restore) return _close(signedIn: false);
        final result = await auth.restoreSession();
        if (!_isCurrent(attempt)) return;
        switch (result) {
          case SessionRestore.signedOut:
            return _close(signedIn: false);
          case SessionRestore.unreachable:
            return _stop(_Stuck.unreachable);
          case SessionRestore.restored:
            break;
        }
      }
      _markDone(0);
    }

    // 2. What Home shows first, all at once. The status line still
    // follows the order of [_steps].
    final loaded = await Future.wait([
      _step(1, () async {
        final profile = await ref.read(profileProvider.future);
        _firstName = profile.firstName;
        // Decode the photo now, so the avatar never pops in on Home.
        final photo = profile.avatarBytes;
        if (photo != null && mounted) {
          await precacheImage(MemoryImage(photo), context, onError: (_, __) {});
        }
      }),
      _step(2, () async {
        _returning = await ref.read(onboardingStatusProvider.future);
      }),
      _step(3, () => ref.read(screeningSessionsProvider.future)),
      _step(4, () => ref.read(notificationsProvider.future)),
    ]);
    if (!_isCurrent(attempt)) return;
    // The server ended the session meanwhile: sign in again, not the app.
    if (!auth.isAuthenticated) return _close(signedIn: false);
    if (loaded.contains(false)) return _stop(_Stuck.data);

    // Polish for Home's first frame: today's tip and the Services icons.
    // Neither is the user's own data, so they only get a short grace.
    final tip = ref.read(dailyTipProvider(ref.read(currentDayProvider)).future);
    await Future.wait<void>([
      tip.then((_) {}, onError: (Object _) {}),
      ServiceIcons.precache().catchError((Object _) {}),
    ]).timeout(
      const Duration(milliseconds: 2500),
      onTimeout: () => const [],
    );
    if (!_isCurrent(attempt)) return;
    _close(signedIn: true);
  }

  /// Runs one step unless it already finished in an earlier attempt.
  /// False when it failed.
  Future<bool> _step(int index, Future<void> Function() load) async {
    if (_steps[index].done) return true;
    try {
      await load();
    } catch (_) {
      return false;
    }
    if (mounted) _markDone(index);
    return true;
  }

  void _markDone(int index) {
    setState(() {
      _steps[index].done = true;
      _stepAt = _now;
    });
  }

  void _stop(_Stuck why) {
    _slowTimer?.cancel();
    setState(() {
      _stuck = why;
      _slow = false;
    });
  }

  void _retry() {
    if (_stuck == _Stuck.data) {
      // Errors are cached by the providers: clear the ones that failed.
      if (!_steps[1].done) ref.invalidate(profileProvider);
      if (!_steps[2].done) ref.invalidate(onboardingStatusProvider);
      if (!_steps[3].done) ref.invalidate(screeningSessionsProvider);
      if (!_steps[4].done) ref.invalidate(notificationsProvider);
    }
    setState(() {
      _stuck = null;
      _stepAt = _now;
    });
    _load();
  }

  Future<void> _signOut() async {
    _attempt++;
    await ref.read(authServiceProvider).signOut();
    if (mounted) _leave();
  }

  /// Closes the line, greets a signed-in user by name, then leaves. When
  /// [signedIn] is false the next screen is sign-in.
  Future<void> _close({required bool signedIn}) async {
    _slowTimer?.cancel();
    await _introDone;
    if (!mounted) return;

    final closed = _closed = Completer<void>();
    setState(() {
      _closing = true;
      _slow = false;
    });
    // Only visual, so never let a paused ticker hold the app back.
    await closed.future.timeout(
      const Duration(milliseconds: 900),
      onTimeout: () {},
    );
    if (!mounted) return;
    _trace.value = 1;

    if (!signedIn) {
      // Straight on to sign-in; the ripple plays out as the loader lifts.
      _finish.forward();
      return _leave();
    }
    setState(() => _greet = true);
    await _finish.forward().orCancel.catchError((Object _) {});
    if (!mounted) return;
    // Let the greeting land before the app takes over.
    await Future<void>.delayed(
        Duration(milliseconds: _reduceMotion ? 1200 : 450));
    if (mounted) _leave();
  }

  void _leave() {
    if (_revealed) return;
    setState(() => _revealed = true);
    _exit.forward().whenComplete(() {
      if (!mounted) return;
      _ambient.stop();
      _ticker.stop();
    });
  }

  void _tick(Duration now) {
    final dt = (now - _lastTick).inMicroseconds / 1e6;
    _lastTick = now;
    _now = now;

    final total = _steps.length;
    final done = _steps.where((s) => s.done).length / total;
    final current = _trace.value;

    double goal;
    if (_closing) {
      goal = 1;
    } else if (_stuck != null || _reduceMotion) {
      goal = done;
    } else {
      final waited = (now - _stepAt).inMicroseconds / 1e6;
      goal = done + (0.85 / total) * (1 - math.exp(-waited / 1.4));
    }
    // Never runs backwards.
    goal = math.max(goal, current);

    final next = _reduceMotion
        ? goal
        : current +
            (goal - current) * (1 - math.exp(-dt / (_closing ? 0.09 : 0.16)));
    if (_closing && next >= 0.997) {
      _trace.value = 1;
      _ticker.stop();
      _closed?.complete();
      _closed = null;
      return;
    }
    _trace.value = next;
  }

  // ── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final loader = _buildLoader();
    if (!_revealed) return loader;

    final out = CurvedAnimation(parent: _exit, curve: Curves.easeOutCubic);
    return Stack(
      fit: StackFit.expand,
      children: [
        // The next screen settles in from a hair larger as the loader
        // lifts. The gate shows sign-in when there is no session.
        ScaleTransition(
          scale: Tween<double>(begin: 1.03, end: 1).animate(out),
          child: SignedInGate(app: widget.app),
        ),
        AnimatedBuilder(
          animation: _exit,
          builder: (context, loader) => _exit.isCompleted
              ? const SizedBox.shrink()
              : IgnorePointer(
                  child: Opacity(opacity: 1 - out.value, child: loader),
                ),
          child: loader,
        ),
      ],
    );
  }

  Widget _buildLoader() {
    return PopScope(
      // Nothing to go back to mid-load; stuck, the system back may leave.
      canPop: _stuck != null,
      child: Scaffold(
        backgroundColor: AppColors.lightLavender,
        body: AppBackdrop(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Moving light gives the glass something to blur.
              RepaintBoundary(
                child: CustomPaint(painter: _DriftingLightPainter(_ambient)),
              ),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: AnimatedBuilder(
                      animation:
                          Listenable.merge([_intro, _finish, _exit, _trace]),
                      builder: (context, _) => Transform.translate(
                        offset: Offset(0, -_exit.value * 14),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            LoadingMark(
                              tileIn: _tileIn.value,
                              markIn: _markIn.value,
                              sheen: _sheen.value,
                              traceExtent: _trace.value,
                              traceOpacity:
                                  _traceIn.value * (_stuck == null ? 1 : 0.45),
                              complete: _finish.value,
                            ),
                            const SizedBox(height: 26),
                            SizedBox(
                              height: 36,
                              child: Center(child: _buildTitle()),
                            ),
                            const SizedBox(height: 8),
                            Opacity(
                              opacity: _statusIn.value,
                              child: SizedBox(
                                height: _panelHeight,
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  child: _buildStatus(),
                                ),
                              ),
                            ),
                          ],
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
    );
  }

  /// The wordmark, then the greeting once the user's data is in.
  Widget _buildTitle() {
    final Widget title;
    if (_greet) {
      final hello = _returning ? 'Welcome back' : 'Welcome';
      final name = _firstName;
      title = Text.rich(
        TextSpan(
          text: name.isEmpty
              ? (_returning ? hello : 'Welcome to Dentra')
              : '$hello, ',
          children: [
            if (name.isNotEmpty)
              TextSpan(
                text: name,
                style: const TextStyle(
                  color: _brandTeal,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
        key: const ValueKey('greeting'),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.outfit(
          fontSize: 24,
          fontWeight: FontWeight.w500,
          color: AppColors.navy,
          height: 1.2,
        ),
      );
    } else {
      final w = _wordIn.value;
      title = Opacity(
        key: const ValueKey('wordmark'),
        opacity: w.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - w) * 8),
          child: Text(
            'DENTRA',
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.w500,
              color: _brandTeal,
              // Letters drift together as the word settles.
              letterSpacing: 7 + (1 - w) * 8,
              height: 1,
            ),
          ),
        ),
      );
    }
    return AnimatedSwitcher(
      duration: dentraMotion(context, 420),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: _riseIn,
      child: title,
    );
  }

  /// What is happening now, a note when it takes a while, or the retry
  /// panel when loading is stuck.
  Widget _buildStatus() {
    final stuck = _stuck;
    if (stuck != null) {
      return AnimatedSwitcher(
        duration: dentraMotion(context, 280),
        child: _buildStuck(stuck),
      );
    }

    final String text;
    if (_greet) {
      text = _returning
          ? 'Your dashboard is ready'
          : "Let's set up your dental profile";
    } else {
      final pending = _steps.where((s) => !s.done);
      text = '${pending.isEmpty ? 'Almost there' : pending.first.label}…';
    }

    return Semantics(
      liveRegion: true,
      label: _slow ? '$text. This is taking longer than usual.' : text,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: dentraMotion(context, 280),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: _riseIn,
              child: Text(
                text,
                key: ValueKey(text),
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  color: AppColors.secondaryText,
                ),
              ),
            ),
            AnimatedOpacity(
              opacity: _slow ? 1 : 0,
              duration: dentraMotion(context, 400),
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'This is taking longer than usual.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: AppColors.secondaryText.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStuck(_Stuck stuck) {
    final unreachable = stuck == _Stuck.unreachable;
    return Column(
      key: ValueKey(stuck),
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          liveRegion: true,
          child: Text(
            unreachable
                ? "We couldn't reach Dentra"
                : "We couldn't load your account",
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Check your connection, then try again.',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: AppColors.secondaryText,
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: 220,
          child: DentraPillButton(label: 'Try again', onPressed: _retry),
        ),
        const SizedBox(height: 4),
        TextButton(
          // Unreachable: the stored session is kept for next time.
          onPressed: unreachable ? _leave : _signOut,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.secondaryText,
            minimumSize: const Size(44, 44),
          ),
          child: Text(
            unreachable ? 'Sign in again' : 'Sign out',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  static Widget _riseIn(Widget child, Animation<double> animation) =>
      FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.35),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      );
}

/// Two soft teal orbs circling slowly around the centre of the screen.
class _DriftingLightPainter extends CustomPainter {
  _DriftingLightPainter(this.progress) : super(repaint: progress);

  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final a = progress.value * 2 * math.pi;
    final r = math.min(size.width, size.height) * 0.16;

    _orb(canvas, c + Offset(math.cos(a) * r, math.sin(a) * r * 0.8 - 60),
        radius: 120, color: AppColors.g1, opacity: 0.55);
    _orb(
        canvas,
        c +
            Offset(math.cos(a + math.pi) * r * 1.1,
                math.sin(a + math.pi) * r * 0.7 - 10),
        radius: 100,
        color: AppColors.g2,
        opacity: 0.28);
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
