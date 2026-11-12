import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../../shared/widgets/dentra_mascot.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/app_tour_steps.dart';
import '../data/app_tour_targets.dart';
import '../providers/app_tour_provider.dart';
import 'tour_visuals.dart';

/// First-run tour of DENTRA. Sits above the app shell, starts on its own
/// for accounts that haven't seen it, and can be replayed from Profile.
///
/// The app stays visible under frosted glass while a clear lens glides
/// from feature to feature (scrolling Home and switching tabs as it
/// goes). Next, Back, a swipe on the card or a tap on the lit-up target
/// move along; Skip or system back end it at any point.
class AppTour extends ConsumerStatefulWidget {
  const AppTour({
    super.key,
    required this.targets,
    required this.onSelectTab,
  });

  final AppTourTargets targets;
  final ValueChanged<int> onSelectTab;

  @override
  ConsumerState<AppTour> createState() => _AppTourState();
}

class _AppTourState extends ConsumerState<AppTour> {
  Timer? _startTimer;

  @override
  void initState() {
    super.initState();
    // Let Home settle in before the tour frosts it over.
    _startTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) ref.read(appTourProvider.notifier).startIfNew();
    });
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showing = ref.watch(appTourProvider);
    return AnimatedSwitcher(
      duration: dentraMotion(context, 320),
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        children: [...previous, if (current != null) current],
      ),
      child: showing
          ? _TourLayer(
              key: const ValueKey('tour'),
              targets: widget.targets,
              onSelectTab: widget.onSelectTab,
              onDone: () => ref.read(appTourProvider.notifier).finish(),
            )
          : const SizedBox.shrink(),
    );
  }
}

class _TourLayer extends StatefulWidget {
  const _TourLayer({
    super.key,
    required this.targets,
    required this.onSelectTab,
    required this.onDone,
  });

  final AppTourTargets targets;
  final ValueChanged<int> onSelectTab;
  final VoidCallback onDone;

  @override
  State<_TourLayer> createState() => _TourLayerState();
}

class _TourLayerState extends State<_TourLayer>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  int _step = 0;

  /// The current step's target, in this layer's coordinates.
  Rect? _target;

  /// Set once the tour moved away from the tab the user was on.
  bool _movedTabs = false;

  /// Set when leaving, so taps during the fade-out do nothing.
  bool _closing = false;

  /// Loops forever: ripple, arrow bob, feature glyphs, the mascot's sway.
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  late final AnimationController _confetti = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );

  /// The card's scroll (only moves on short screens or with large text).
  final ScrollController _cardScroll = ScrollController();

  AppTourStep get _current => appTourSteps[_step];
  bool get _isLast => _step == appTourSteps.length - 1;
  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  static final int _spotCount =
      appTourSteps.where((s) => s.spot != null).length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _measureAfterFrame();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotion) {
      _motion
        ..stop()
        ..value = 0;
    } else if (!_motion.isAnimating) {
      _motion.repeat();
    }
  }

  @override
  void didChangeMetrics() => _measureAfterFrame();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motion.dispose();
    _confetti.dispose();
    _cardScroll.dispose();
    super.dispose();
  }

  // ── Target ────────────────────────────────────────────────────

  Rect? _measure() {
    final spot = _current.spot;
    if (spot == null) return null;
    return _rectOf(widget.targets.keyFor(spot));
  }

  Rect? _rectOf(GlobalKey key) {
    final target = key.currentContext?.findRenderObject();
    final layer = context.findRenderObject();
    if (target is! RenderBox || layer is! RenderBox) return null;
    if (!target.hasSize || !layer.hasSize) return null;
    return target.localToGlobal(Offset.zero, ancestor: layer) & target.size;
  }

  /// Measures after layout, for the first frame, size changes and scrolls.
  void _measureAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final rect = _measure();
      if (rect != _target) setState(() => _target = rect);
    });
  }

  /// Scrolls Home so [spot] sits near the top, leaving the card room
  /// below it. The lens follows along while the page moves.
  Future<void> _bringIntoView(TourSpot spot, int step) async {
    final ctx = widget.targets.keyFor(spot).currentContext;
    final position = ctx == null ? null : Scrollable.maybeOf(ctx)?.position;
    if (ctx == null || position == null) return;
    void follow() {
      if (mounted && _step == step) setState(() => _target = _measure());
    }

    position.addListener(follow);
    try {
      await Scrollable.ensureVisible(
        ctx,
        alignment: 0.1,
        duration: dentraMotion(context, 420),
        curve: Curves.easeOutCubic,
      );
    } finally {
      position.removeListener(follow);
    }
    follow();
  }

  // ── Navigation ────────────────────────────────────────────────

  void _goTo(int step) {
    final spot = appTourSteps[step].spot;
    if (spot != null) {
      widget.onSelectTab(spot.tab);
      _movedTabs = true;
    } else if (_movedTabs) {
      // The send-off sits over Home, where the user lands.
      widget.onSelectTab(0);
    }
    HapticFeedback.selectionClick();
    // Each step's card starts at its top.
    if (_cardScroll.hasClients) _cardScroll.jumpTo(0);
    setState(() {
      _step = step;
      _target = _measure();
    });
    if (_isLast && !_reduceMotion) {
      HapticFeedback.lightImpact();
      _confetti.forward(from: 0);
    }
    if (spot != null && spot.dockIndex == null) _bringIntoView(spot, step);
  }

  void _next() => _isLast ? _finish() : _goTo(_step + 1);

  void _back() {
    if (_step > 1) _goTo(_step - 1);
  }

  void _finish() {
    if (_closing) return;
    setState(() => _closing = true);
    if (_movedTabs) widget.onSelectTab(0);
    widget.onDone();
  }

  // ── Build ─────────────────────────────────────────────────────

  /// The clear lens over [r]: round for small square targets (dock, bell),
  /// a soft rounded rectangle for cards.
  static RRect _lens(Rect r) {
    final rect = r.inflate(6);
    final round =
        (rect.width - rect.height).abs() < 6 && rect.shortestSide <= 72;
    return RRect.fromRectAndRadius(
      rect,
      Radius.circular(round ? rect.shortestSide / 2 : 22),
    );
  }

  /// "HOME · 2 OF 5" for the current step's chapter.
  String _chapterLabel() {
    final chapter = _current.chapter;
    final inChapter = [
      for (var i = 0; i < appTourSteps.length; i++)
        if (appTourSteps[i].chapter == chapter) i,
    ];
    return '$chapter · ${inChapter.indexOf(_step) + 1} of ${inChapter.length}';
  }

  @override
  Widget build(BuildContext context) {
    final step = _current;
    final target = _target;
    final safe = MediaQuery.paddingOf(context);
    final still = _reduceMotion;
    final spotsSoFar =
        appTourSteps.take(_step + 1).where((s) => s.spot != null).length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: IgnorePointer(
        ignoring: _closing,
        // Hides the app beneath from screen readers while the tour is up.
        child: BlockSemantics(
          child: Semantics(
            scopesRoute: true,
            namesRoute: true,
            explicitChildNodes: true,
            label: 'App tour',
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                final hole = target == null
                    ? RRect.fromRectAndRadius(
                        Rect.fromCenter(
                            center: size.center(Offset.zero),
                            width: 0,
                            height: 0),
                        Radius.zero,
                      )
                    : _lens(target);

                // The card goes on whichever side of the target has room.
                // Rabi stands on the card's top edge, so the card keeps
                // that much clear of the target and the status bar.
                const perch = _TourCard.guideSize;
                final roomBelow =
                    size.height - hole.bottom - (perch + 14) - safe.bottom - 16;
                final roomAbove = hole.top - 52 - safe.top - (perch + 6);
                final below = target != null && roomBelow > roomAbove;
                final EdgeInsets cardPadding;
                final Alignment cardAlignment;
                if (target == null) {
                  cardPadding = EdgeInsets.fromLTRB(
                      20, safe.top + 16, 20, safe.bottom + 16);
                  cardAlignment = Alignment.center;
                } else if (below) {
                  // Clamped: mid-scroll, the target can sit off screen.
                  cardPadding = EdgeInsets.fromLTRB(
                      20,
                      math.max(safe.top + perch + 6, hole.bottom + perch + 14),
                      20,
                      safe.bottom + 16);
                  cardAlignment = Alignment.topCenter;
                } else {
                  cardPadding = EdgeInsets.fromLTRB(20, safe.top + perch + 6, 20,
                      math.max(safe.bottom + 16, size.height - hole.top + 52));
                  cardAlignment = Alignment.bottomCenter;
                }

                // Rabi stands on the side away from the target and points
                // across at it.
                final mascotLeft =
                    target != null && target.center.dx > size.width / 2;

                return Stack(
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        // Tapping the lit-up target moves on, as if it
                        // were the real thing.
                        onTapUp: (details) {
                          if (target != null &&
                              hole.outerRect.contains(details.localPosition)) {
                            _next();
                          }
                        },
                        child: TweenAnimationBuilder<RRect>(
                          tween: _RRectTween(end: hole),
                          duration: dentraMotion(context, 520),
                          curve: Curves.easeInOutCubic,
                          builder: (context, lens, _) => Stack(
                            fit: StackFit.expand,
                            children: [
                              _FrostedScrim(lens: lens),
                              CustomPaint(
                                painter: SpotlightPainter(
                                  hole: lens,
                                  motion: _motion,
                                  arrowBelow: below,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_isLast && !still)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: ConfettiPainter(
                              progress: _confetti,
                              origin:
                                  Offset(size.width / 2, size.height / 2 - 90),
                            ),
                          ),
                        ),
                      ),
                    Positioned.fill(
                      child: AnimatedPadding(
                        duration: dentraMotion(context, 460),
                        curve: Curves.easeOutCubic,
                        padding: cardPadding,
                        child: AnimatedAlign(
                          duration: dentraMotion(context, 460),
                          curve: Curves.easeOutCubic,
                          alignment: cardAlignment,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 400),
                            child: GestureDetector(
                              // Swipe the card like a story.
                              onHorizontalDragEnd: (d) {
                                final v = d.primaryVelocity ?? 0;
                                if (v < -250) _next();
                                if (v > 250) _back();
                              },
                              child: _TourCard(
                                step: step,
                                stepIndex: _step,
                                chapterLabel: step.chapter == null
                                    ? null
                                    : _chapterLabel(),
                                progress: spotsSoFar / _spotCount,
                                spotCount: _spotCount,
                                isLast: _isLast,
                                canGoBack: _step > 1 && step.spot != null,
                                motion: _motion,
                                still: still,
                                mascotLeft: mascotLeft,
                                targetAbove: below,
                                onNext: _next,
                                onBack: _back,
                                onSkip: _finish,
                                scrollController: _cardScroll,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _RRectTween extends Tween<RRect> {
  _RRectTween({super.end});

  @override
  RRect lerp(double t) => RRect.lerp(begin, end, t)!;
}

/// Frosted glass over the whole app except the [lens]: a light blur with
/// a navy-to-teal tint. The web build skips the blur (see `GlassBlur`)
/// and tints a little more instead.
class _FrostedScrim extends StatelessWidget {
  const _FrostedScrim({required this.lens});

  final RRect lens;

  static final ImageFilter _blur = ImageFilter.blur(sigmaX: 7, sigmaY: 7);

  static BoxDecoration _tint(double alpha) => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.navy.withValues(alpha: alpha),
            AppColors.g2.withValues(alpha: alpha * 0.9),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _OutsideLens(lens),
      child: kIsWeb
          ? DecoratedBox(decoration: _tint(0.42))
          : BackdropFilter(
              filter: _blur,
              child: DecoratedBox(decoration: _tint(0.24)),
            ),
    );
  }
}

class _OutsideLens extends CustomClipper<Path> {
  _OutsideLens(this.lens);

  final RRect lens;

  @override
  Path getClip(Size size) => Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(Offset.zero & size)
    ..addRRect(lens);

  @override
  bool shouldReclip(_OutsideLens old) => old.lens != lens;
}

// ── Card ────────────────────────────────────────────────────────────

/// The glass card that does the talking, with the mascot perched on top.
/// Contents slide in each step while the card resizes around them; a
/// thin bar along the top fills as the tour goes on.
class _TourCard extends StatelessWidget {
  const _TourCard({
    required this.step,
    required this.stepIndex,
    required this.chapterLabel,
    required this.progress,
    required this.spotCount,
    required this.isLast,
    required this.canGoBack,
    required this.motion,
    required this.still,
    required this.mascotLeft,
    required this.targetAbove,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
    required this.scrollController,
  });

  final AppTourStep step;
  final int stepIndex;
  final String? chapterLabel;
  final double progress;
  final int spotCount;
  final bool isLast;
  final bool canGoBack;
  final Animation<double> motion;
  final bool still;
  final bool mascotLeft;

  /// The lit-up target is above the card (else below it).
  final bool targetAbove;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onSkip;
  final ScrollController scrollController;

  /// Rabi's size while he stands on the card.
  static const double guideSize = 64;

  static const double _r = 26;
  static const _radius = BorderRadius.all(Radius.circular(_r));

  /// More see-through than the app's sheets: the frosted page shows
  /// through. Nearly opaque on web, which has no blur behind it.
  static final BoxDecoration _fill = BoxDecoration(
    borderRadius: _radius,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        AppColors.white.withValues(alpha: kIsWeb ? 0.94 : 0.62),
        AppColors.lightLavender.withValues(alpha: kIsWeb ? 0.88 : 0.40),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final duration = dentraMotion(context, 340);
    final hasSpot = step.spot != null;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: _radius,
          child: GlassBlur(
            strong: true,
            child: CustomPaint(
              foregroundPainter: const _GlassRimPainter(_r),
              child: DecoratedBox(
                decoration: _fill,
                child: Stack(
                  children: [
                    AnimatedSize(
                      duration: duration,
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.bottomCenter,
                      // Scrolls on short screens or with very large text,
                      // so the buttons always stay reachable.
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
                        child: AnimatedSwitcher(
                          duration: duration,
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.08, 0),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          ),
                          child: Semantics(
                            key: ValueKey(stepIndex),
                            // Announces each new step to screen readers.
                            liveRegion: true,
                            container: true,
                            child: hasSpot
                                ? _spotStep()
                                : isLast
                                    ? _finale()
                                    : _welcome(),
                          ),
                        ),
                      ),
                    ),
                    if (hasSpot)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: _ProgressLine(progress),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Rabi walks along the top edge and points at each feature. On
        // his own stop he just waves.
        if (hasSpot)
          Positioned(
            top: -guideSize * 0.93,
            left: 14,
            right: 14,
            height: guideSize,
            child: IgnorePointer(
              child: AnimatedAlign(
                duration: dentraMotion(context, 520),
                curve: Curves.easeInOutBack,
                alignment:
                    mascotLeft ? Alignment.centerLeft : Alignment.centerRight,
                child: _Hop(
                  key: ValueKey(stepIndex),
                  child: Transform.rotate(
                    // His arm lifts toward a target above, dips to one
                    // below.
                    angle: step.spot == TourSpot.rabi
                        ? 0
                        : (mascotLeft ? -1 : 1) * (targetAbove ? 0.2 : -0.14),
                    alignment: const Alignment(0, 0.9),
                    child: DentraMascot(
                      mood: step.spot == TourSpot.rabi
                          ? MascotMood.wave
                          : MascotMood.point,
                      size: guideSize,
                      mirrored: mascotLeft,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Welcome: the mascot says hi and offers the tour.
  Widget _welcome() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _PopIn(child: DentraMascot(size: 108)),
        const SizedBox(height: 8),
        _Caption('Quick tour · $spotCount stops'),
        const SizedBox(height: 4),
        _Title(step.title, textAlign: TextAlign.center),
        const SizedBox(height: 6),
        _Body(step.body, textAlign: TextAlign.center),
        const SizedBox(height: 18),
        _PillButton(label: step.action, onPressed: onNext),
        const SizedBox(height: 2),
        _SkipButton(label: 'Maybe later', onPressed: onSkip),
      ],
    );
  }

  /// Send-off: a happy mascot, one line and one button.
  Widget _finale() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _PopIn(
          child: DentraMascot(mood: MascotMood.cheer, size: 104),
        ),
        const SizedBox(height: 10),
        _Title(step.title, textAlign: TextAlign.center),
        const SizedBox(height: 4),
        _Body(step.body, textAlign: TextAlign.center),
        const SizedBox(height: 18),
        _PillButton(label: step.action, onPressed: onNext),
      ],
    );
  }

  /// A feature: its live glyph, chapter, what it's for, and controls.
  Widget _spotStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ExcludeSemantics(
              child: _PopIn(
                child: _GlyphTile(
                  spot: step.spot!,
                  motion: motion,
                  still: still,
                  size: 46,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Caption(chapterLabel!),
                  const SizedBox(height: 2),
                  _Title(step.title),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _Body(step.body),
        const SizedBox(height: 14),
        Row(
          children: [
            _SkipButton(label: 'Skip', onPressed: onSkip),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (canGoBack) ...[
                    _BackButton(onPressed: onBack),
                    const SizedBox(width: 8),
                  ],
                  // Narrows with very large text rather than overflowing.
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 100),
                      child: _PillButton(label: step.action, onPressed: onNext),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Glass edge: a bright rim that fades round the card, with a soft
/// sheen in the top-left corner.
class _GlassRimPainter extends CustomPainter {
  const _GlassRimPainter(this.radius);

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.9, -1.1),
          radius: 0.9,
          colors: [
            AppColors.white.withValues(alpha: 0.38),
            AppColors.white.withValues(alpha: 0),
          ],
        ).createShader(bounds),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds.deflate(0.6), Radius.circular(radius)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.white.withValues(alpha: 0.95),
            AppColors.white.withValues(alpha: 0.25),
            AppColors.g1.withValues(alpha: 0.6),
          ],
        ).createShader(bounds),
    );
  }

  @override
  bool shouldRepaint(_GlassRimPainter old) => old.radius != radius;
}

/// Thin teal bar across the top of the card, filling with the tour.
class _ProgressLine extends StatelessWidget {
  const _ProgressLine(this.value);

  final double value;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: dentraMotion(context, 520),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: v,
          child: Container(
            height: 3,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius:
                  const BorderRadius.horizontal(right: Radius.circular(3)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.g1.withValues(alpha: 0.6),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// White tile with a breath of light teal, holding a feature's
/// animated glyph.
class _GlyphTile extends StatelessWidget {
  const _GlyphTile({
    required this.spot,
    required this.motion,
    required this.still,
    required this.size,
  });

  final TourSpot spot;
  final Animation<double> motion;
  final bool still;
  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.32);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: radius,
        // White, warming to pale mint in the far corner.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.white,
            AppColors.lightLavender,
            AppColors.mintGreen.withValues(alpha: 0.55),
          ],
          stops: const [0, 0.6, 1],
        ),
        border: Border.all(color: AppColors.g1.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: AppColors.g2.withValues(alpha: 0.16),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: CustomPaint(
          painter:
              FeatureGlyphPainter(spot: spot, motion: motion, still: still),
        ),
      ),
    );
  }
}

/// Springs its child in from small, once per step.
class _PopIn extends StatelessWidget {
  const _PopIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: dentraMotion(context, 700),
      curve: Curves.elasticOut,
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.4 + 0.6 * v, child: child),
      ),
      child: child,
    );
  }
}

/// A little jump, once per step.
class _Hop extends StatelessWidget {
  const _Hop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: dentraMotion(context, 520),
      builder: (context, v, child) => Transform.translate(
        offset: Offset(0, -12 * math.sin(v * math.pi)),
        child: child,
      ),
      child: child,
    );
  }
}

/// Small plain caption above a title: the chapter and step.
class _Caption extends StatelessWidget {
  const _Caption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: AppColors.navy.withValues(alpha: 0.6),
      ),
    );
  }
}

/// Compact teal pill for the card's main action. Fills the width it's
/// given.
class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  static const double _height = 44;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_height / 2),
          gradient: const LinearGradient(
            colors: [AppColors.cardSolid, AppColors.g2],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.g2.withValues(alpha: 0.22),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              height: _height,
              width: double.infinity,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
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

class _Title extends StatelessWidget {
  const _Title(this.text, {this.textAlign});

  final String text;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text,
        textAlign: textAlign,
        style: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.navy,
          height: 1.25,
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(this.text, {this.textAlign});

  final String text;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      // Navy, not grey: it has to read on see-through glass.
      style: GoogleFonts.outfit(
        fontSize: 13.5,
        color: AppColors.navy.withValues(alpha: 0.78),
        height: 1.45,
      ),
    );
  }
}

class _SkipButton extends StatelessWidget {
  const _SkipButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label, end the tour',
      excludeSemantics: true,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.navy.withValues(alpha: 0.7),
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Previous step',
      excludeSemantics: true,
      child: Material(
        color: AppColors.white.withValues(alpha: 0.5),
        shape: CircleBorder(
          side: BorderSide(color: AppColors.white.withValues(alpha: 0.9)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: const SizedBox.square(
            dimension: 44,
            child:
                Icon(Icons.arrow_back_rounded, size: 18, color: AppColors.navy),
          ),
        ),
      ),
    );
  }
}
