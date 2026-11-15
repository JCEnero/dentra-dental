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
import '../../../shared/widgets/glass_card.dart' show GlassBlur;
import '../../../shared/widgets/guide_bubble.dart';
import '../../../shared/widgets/guide_kit.dart';
import '../data/app_tour_steps.dart';
import '../data/app_tour_targets.dart';
import '../providers/app_tour_provider.dart';
import 'tour_visuals.dart';

/// First-run tour of DENTRA. Sits above the app shell, starts on its own
/// for accounts that haven't seen it, and can be replayed from Profile.
///
/// It opens full screen over the frosted app, everything centred among
/// soft teal glass: a short invitation, Start the tour and Maybe later.
/// Then
/// the app stays visible under frosted glass while a clear
/// lens glides from feature to feature (scrolling Home and switching tabs
/// as it goes). Rabi rides inside his speech bubble, whose tail points at
/// the lit-up feature, and says what each one is for. Next, Back, a swipe
/// on the bubble or a tap on the lit-up target move along; Skip or system
/// back end it at any point. It ends with Rabi celebrating on his own,
/// without a bubble.
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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int _step = 0;

  /// Counts every move, forward or back. Keys what slides in, so going
  /// back and forth quickly never brings in a key that is still on its way
  /// out.
  int _visit = 0;

  /// The current step's target, in this layer's coordinates.
  Rect? _target;

  /// Set once the tour moved away from the tab the user was on.
  bool _movedTabs = false;

  /// Set when leaving, so taps during the fade-out do nothing.
  bool _closing = false;

  /// Loops forever: the lens's ripple.
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  /// The bubble's scroll (only moves on short screens or with large text).
  final ScrollController _cardScroll = ScrollController();

  AppTourStep get _current => appTourSteps[_step];
  bool get _isIntro => _step == 0;
  bool get _isLast => _step == appTourSteps.length - 1;
  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

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

  /// Scrolls Home so [spot] sits near the top, leaving the bubble room
  /// below it. The lens and the bubble's tail follow while the page moves.
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
    // Each step's words start at their top.
    if (_cardScroll.hasClients) _cardScroll.jumpTo(0);
    setState(() {
      _step = step;
      _visit++;
      _target = _measure();
    });
    if (_isLast && !_reduceMotion) HapticFeedback.lightImpact();
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

                // The bubble goes on whichever side of the target has
                // room, its tail reaching across the gap.
                const gap = 8.0;
                final roomBelow =
                    size.height - hole.bottom - safe.bottom - 16 - gap;
                final roomAbove = hole.top - safe.top - 6 - gap;
                final below = target != null && roomBelow > roomAbove;

                // On a phone the bubble spans the screen; on a wider one it
                // slides along toward the target.
                final width = math.min(_TourGuide.maxWidth, size.width - 40);
                final slack = math.max(0.0, size.width - 40 - width);
                final bubbleLeft = target == null
                    ? 20 + slack / 2
                    : (target.center.dx - width / 2).clamp(20.0, 20.0 + slack);
                final alongX =
                    slack == 0 ? 0.0 : (bubbleLeft - 20) / slack * 2 - 1;

                final EdgeInsets padding;
                final Alignment alignment;
                if (target == null) {
                  padding = EdgeInsets.fromLTRB(
                      20, safe.top + 16, 20, safe.bottom + 16);
                  alignment = Alignment.center;
                } else if (below) {
                  // Clamped: mid-scroll, the target can sit off screen.
                  padding = EdgeInsets.fromLTRB(
                      20,
                      math.max(safe.top + 6, hole.bottom + gap),
                      20,
                      safe.bottom + 16);
                  alignment = Alignment(alongX, -1);
                } else {
                  padding = EdgeInsets.fromLTRB(20, safe.top + 6, 20,
                      math.max(safe.bottom + 16, size.height - hole.top + gap));
                  alignment = Alignment(alongX, 1);
                }

                final guide = KeyedSubtree(
                  key: const ValueKey('guide'),
                  child: AnimatedPadding(
                    duration: dentraMotion(context, 460),
                    curve: Curves.easeOutCubic,
                    padding: padding,
                    child: AnimatedAlign(
                      duration: dentraMotion(context, 460),
                      curve: Curves.easeOutCubic,
                      alignment: alignment,
                      child: SizedBox(
                        width: width,
                        child: GestureDetector(
                          // Swipe the bubble like a story.
                          onHorizontalDragEnd: (d) {
                            final v = d.primaryVelocity ?? 0;
                            if (v < -250) _next();
                            if (v > 250) _back();
                          },
                          child: _TourGuide(
                            step: step,
                            visit: _visit,
                            chapterLabel:
                                step.chapter == null ? '' : _chapterLabel(),
                            canGoBack: _step > 1 && step.spot != null,
                            tail: target == null
                                ? BubbleTail.none
                                : below
                                    ? BubbleTail.top
                                    : BubbleTail.bottom,
                            // The tail aims at the middle of the target.
                            tailTo: target == null
                                ? width / 2
                                : target.center.dx - bubbleLeft,
                            // Rabi turns to face the target.
                            rabiFacesRight: target != null &&
                                target.center.dx >
                                    bubbleLeft + _TourGuide.rabiCentre,
                            onNext: _next,
                            onBack: _back,
                            onSkip: _finish,
                            scrollController: _cardScroll,
                          ),
                        ),
                      ),
                    ),
                  ),
                );

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
                              _FrostedScrim(
                                lens: lens,
                                light: _isIntro || _isLast,
                                deep: _isIntro,
                              ),
                              CustomPaint(
                                painter: SpotlightPainter(
                                  hole: lens,
                                  motion: _motion,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: AnimatedSwitcher(
                        duration: dentraMotion(context, 380),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        layoutBuilder: (current, previous) => Stack(
                          fit: StackFit.expand,
                          children: [...previous, if (current != null) current],
                        ),
                        // The intro recedes a little as it fades, handing
                        // over to the lens.
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: child.key == const ValueKey('intro')
                              ? ScaleTransition(
                                  scale: Tween<double>(begin: 0.96, end: 1)
                                      .animate(animation),
                                  child: child,
                                )
                              : child,
                        ),
                        child: _isIntro
                            ? _Intro(
                                key: const ValueKey('intro'),
                                step: step,
                                onStart: _next,
                                onLater: _finish,
                              )
                            : _isLast
                                ? _Finale(
                                    key: const ValueKey('finale'),
                                    step: step,
                                    onDone: _next,
                                  )
                                : guide,
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
/// a navy-to-teal tint, which brightens to a white-to-mint veil when
/// [light] (the intro and the send-off, which stand on it without a
/// bubble). With [deep] (the intro) the app is blurred further under a
/// thinner veil, so the intro in front reads as a layer of its own.
/// The web build skips the blur (see `GlassBlur`) and tints a little more
/// instead.
class _FrostedScrim extends StatelessWidget {
  const _FrostedScrim({
    required this.lens,
    required this.light,
    this.deep = false,
  });

  final RRect lens;
  final bool light;
  final bool deep;

  static BoxDecoration _tint(double alpha, double light, double deep) {
    // The intro's veil is thinner, so more of the app shows through. The
    // web has no blur to soften the app, so its veil stays a little
    // thicker there.
    final top = kIsWeb ? 0.9 - 0.04 * deep : 0.8 - 0.28 * deep;
    final bottom = kIsWeb ? 0.94 - 0.04 * deep : 0.86 - 0.26 * deep;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(
            AppColors.navy.withValues(alpha: alpha),
            AppColors.white.withValues(alpha: top),
            light,
          )!,
          Color.lerp(
            AppColors.g2.withValues(alpha: alpha * 0.9),
            AppColors.lightLavender.withValues(alpha: bottom),
            light,
          )!,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final motion = dentraMotion(context, 520);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: light ? 1 : 0),
      duration: motion,
      curve: Curves.easeInOutCubic,
      builder: (context, v, _) => TweenAnimationBuilder<double>(
        tween: Tween(end: deep ? 1 : 0),
        duration: motion,
        curve: Curves.easeInOutCubic,
        builder: (context, d, _) {
          final sigma = 7 + 13 * d;
          return ClipPath(
            clipper: _OutsideLens(lens),
            child: kIsWeb
                ? DecoratedBox(decoration: _tint(0.42, v, d))
                : BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                    child: DecoratedBox(decoration: _tint(0.24, v, d)),
                  ),
          );
        },
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

// ── Rabi's bubble ───────────────────────────────────────────────────

/// Rabi's speech bubble with Rabi inside it. At each feature he sits
/// beside the words, turned toward it, while the tail points at it. He
/// stays put as the words slide in, changing pose from step to step.
class _TourGuide extends StatelessWidget {
  const _TourGuide({
    required this.step,
    required this.visit,
    required this.chapterLabel,
    required this.canGoBack,
    required this.tail,
    required this.tailTo,
    required this.rabiFacesRight,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
    required this.scrollController,
  });

  final AppTourStep step;

  /// Changes on every move, so each step's words are new.
  final int visit;
  final String chapterLabel;
  final bool canGoBack;

  /// Which edge the tail leaves from: top when the feature is above.
  final BubbleTail tail;

  /// Where along that edge the feature is, from the bubble's left.
  final double tailTo;
  final bool rabiFacesRight;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onSkip;
  final ScrollController scrollController;

  static const double maxWidth = 400;
  static const double _pad = 16;

  /// Rabi beside a feature's words.
  static const double _avatar = 76;

  /// The middle of Rabi beside a feature's words, from the bubble's left.
  static const double rabiCentre = _pad + _avatar / 2;

  @override
  Widget build(BuildContext context) {
    return GuideBubble(
      tail: tail,
      tailTo: tailTo,
      padding: EdgeInsets.zero,
      child: AnimatedSize(
        duration: dentraMotion(context, 340),
        curve: Curves.easeOutCubic,
        alignment: tail == BubbleTail.bottom
            ? Alignment.bottomCenter
            : Alignment.topCenter,
        // Scrolls on short screens or with very large text, so the buttons
        // always stay reachable.
        child: SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(_pad, _pad, _pad, 12),
          child: _spotStep(context),
        ),
      ),
    );
  }

  /// A feature: Rabi, the chapter, what it's for, and controls.
  Widget _spotStep(BuildContext context) {
    final duration = dentraMotion(context, 340);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BubbleRabi(
              size: _avatar,
              mood: step.mood,
              // His arm lifts toward a feature above, dips to one below.
              aim: tail == BubbleTail.top ? MascotAim.up : MascotAim.down,
              facesRight: rabiFacesRight,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedSwitcher(
                duration: duration,
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.topLeft,
                  children: [
                    for (final old in previous)
                      Positioned(top: 0, left: 0, right: 0, child: old),
                    if (current != null) current,
                  ],
                ),
                transitionBuilder: (child, animation) => FadeTransition(
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
                  key: ValueKey(visit),
                  // Announces each new step to screen readers.
                  liveRegion: true,
                  container: true,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Caption(chapterLabel),
                        const SizedBox(height: 1),
                        _Title(step.title),
                        const SizedBox(height: 4),
                        _Body(step.body),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // Lined up with the edge of the bubble's content.
            Transform.translate(
              offset: const Offset(-12, 0),
              child: GuideQuietButton(
                label: 'Skip',
                semanticLabel: 'Skip, end the tour',
                onPressed: onSkip,
                height: 44,
              ),
            ),
            // The main action keeps its size; it only narrows when Skip,
            // Back and Next truly cannot share the row.
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (canGoBack) ...[
                    GuideBackButton(
                      onPressed: onBack,
                      label: 'Previous step',
                      size: 44,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: GuidePrimaryButton(
                      label: step.action,
                      onPressed: onNext,
                      height: 44,
                      minWidth: 96,
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

/// Rabi as he sits in the bubble beside a feature's words. Turning to
/// face the other way, he narrows to nothing and opens out again, rather
/// than flipping in one frame.
class _BubbleRabi extends StatelessWidget {
  const _BubbleRabi({
    required this.size,
    required this.mood,
    required this.aim,
    required this.facesRight,
  });

  final double size;
  final MascotMood mood;
  final MascotAim aim;
  final bool facesRight;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      // He faces (and points) left as drawn; -1 mirrors him.
      tween: Tween(end: facesRight ? -1 : 1),
      duration: dentraMotion(context, 420),
      curve: Curves.easeInOutCubic,
      builder: (context, turn, rabi) => Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(
          turn.abs() < 0.06 ? 0.06 * turn.sign : turn,
          1,
          1,
        ),
        child: rabi,
      ),
      child: DentraMascot(
        mood: mood,
        aim: aim,
        size: size,
        stage: true,
        awake: true,
      ),
    );
  }
}

// ── Intro ───────────────────────────────────────────────────────────

/// The tour's opening, full screen over the frosted app with nothing boxed
/// in: soft teal glass in the corners, a short invitation in the middle,
/// then Start the tour and Maybe later. The words and buttons rise in one
/// after another.
class _Intro extends StatefulWidget {
  const _Intro({
    super.key,
    required this.step,
    required this.onStart,
    required this.onLater,
  });

  final AppTourStep step;
  final VoidCallback onStart;
  final VoidCallback onLater;

  @override
  State<_Intro> createState() => _IntroState();
}

class _IntroState extends State<_Intro> with SingleTickerProviderStateMixin {
  /// Runs once: the backdrop, then the words and buttons.
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _enter.value = 1;
      _started = true;
    } else if (!_started) {
      _started = true;
      _enter.forward();
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    final step = widget.step;
    return LayoutBuilder(
      builder: (context, box) {
        final padding =
            EdgeInsets.fromLTRB(28, safe.top + 24, 28, safe.bottom + 24);
        return Stack(
          fit: StackFit.expand,
          children: [
            TourIntroBackdrop(enter: _enter),
            // Scrolls only on short screens or with very large text.
            SingleChildScrollView(
              padding: padding,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: math.max(0.0, box.maxHeight - padding.vertical),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 290),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Semantics(
                          liveRegion: true,
                          container: true,
                          child: Column(
                            children: [
                              _Rise(
                                enter: _enter,
                                from: 0.12,
                                child: Semantics(
                                  header: true,
                                  child: Text(
                                    step.title,
                                    textAlign: TextAlign.center,
                                    style:
                                        guideTitleStyle(large: true).copyWith(
                                      fontSize: 25,
                                      letterSpacing: -0.5,
                                      height: 1.15,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              _Rise(
                                enter: _enter,
                                from: 0.2,
                                child: Text(
                                  step.body,
                                  textAlign: TextAlign.center,
                                  style: guideBodyStyle()
                                      .copyWith(fontSize: 14, height: 1.45),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 26),
                        _Rise(
                          enter: _enter,
                          from: 0.3,
                          child: _StartButton(
                            label: step.action,
                            onPressed: widget.onStart,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _Rise(
                          enter: _enter,
                          from: 0.38,
                          child: _LaterButton(onPressed: widget.onLater),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The intro's way in: a pill of frosted white glass with a bright rim,
/// the label and an arrow in deep teal. A press sinks it a little.
class _StartButton extends StatefulWidget {
  const _StartButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  State<_StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends State<_StartButton> {
  bool _down = false;

  static const _radius = BorderRadius.all(Radius.circular(25));

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: dentraMotion(context, 140),
        curve: Curves.easeOut,
        child: CustomPaint(
          // A soft teal lift under the glass.
          painter: const _GlassLiftPainter(),
          child: ClipRRect(
            borderRadius: _radius,
            child: GlassBlur(
              strong: true,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: _radius,
                  // Brighter at the top, as if lit from above.
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.white.withValues(alpha: 0.9),
                      AppColors.white.withValues(alpha: 0.66),
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.white,
                    width: 1.4,
                  ),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: widget.onPressed,
                    onHighlightChanged: (down) => setState(() => _down = down),
                    splashColor: AppColors.g1.withValues(alpha: 0.14),
                    highlightColor: AppColors.g1.withValues(alpha: 0.06),
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(minHeight: 50, minWidth: 196),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Shrinks to fit rather than cut a word.
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  widget.label,
                                  maxLines: 1,
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.1,
                                    color: guideAccent,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            AnimatedSlide(
                              offset: Offset(_down ? 0.15 : 0, 0),
                              duration: dentraMotion(context, 140),
                              child: const Icon(
                                Icons.arrow_forward_rounded,
                                size: 17,
                                color: guideAccent,
                              ),
                            ),
                          ],
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
}

/// A soft teal glow under the start button, fading out on every side
/// with no edge of its own.
class _GlassLiftPainter extends CustomPainter {
  const _GlassLiftPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(size.width * 0.12, size.height * 0.45,
        size.width * 0.76, size.height * 0.7);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2)),
      Paint()
        ..color = AppColors.g2.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
  }

  @override
  bool shouldRepaint(_GlassLiftPainter old) => false;
}

/// The intro's quiet way out: just the words, with a short teal stroke
/// under them that stretches across them while pressed.
class _LaterButton extends StatefulWidget {
  const _LaterButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_LaterButton> createState() => _LaterButtonState();
}

class _LaterButtonState extends State<_LaterButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final motion = dentraMotion(context, 180);
    return Semantics(
      button: true,
      label: 'Maybe later, end the tour',
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onPressed,
          onHighlightChanged: (down) => setState(() => _down = down),
          customBorder: const StadiumBorder(),
          splashColor: AppColors.g1.withValues(alpha: 0.1),
          highlightColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 120),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Maybe later',
                      maxLines: 1,
                      style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.navy.withValues(alpha: 0.66),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  AnimatedContainer(
                    duration: motion,
                    curve: Curves.easeOutCubic,
                    width: _down ? 52 : 16,
                    height: 2,
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(2)),
                      gradient: LinearGradient(
                        colors: [AppColors.g1, AppColors.g2],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Send-off ────────────────────────────────────────────────────────

/// The end of the tour: Rabi on his own, no bubble, cheering. He springs
/// up into a halo while rings and rays pop out behind him and confetti
/// fires in from both corners; then the words and the button rise in
/// beneath him.
class _Finale extends StatefulWidget {
  const _Finale({super.key, required this.step, required this.onDone});

  final AppTourStep step;
  final VoidCallback onDone;

  @override
  State<_Finale> createState() => _FinaleState();
}

class _FinaleState extends State<_Finale> with TickerProviderStateMixin {
  /// Runs once: Rabi's jump, the burst, then the words.
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );

  /// Repeats: the halo's breathing and the sparkles' twinkle.
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  late final AnimationController _confetti = AnimationController(
    vsync: this,
    duration: ConfettiPainter.duration,
  );

  Timer? _fire;
  bool _started = false;

  static const double _rabi = 176;
  static const Size _stage = Size(280, 236);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _fire?.cancel();
      _enter.value = 1;
      _loop.stop();
      _confetti.value = 0;
      _started = true;
    } else if (!_started) {
      _started = true;
      _enter.forward();
      _loop.repeat();
      // Fired as he lands.
      _fire = Timer(const Duration(milliseconds: 260), () {
        if (!mounted) return;
        HapticFeedback.mediumImpact();
        _confetti.forward();
      });
    }
  }

  @override
  void dispose() {
    _fire?.cancel();
    _enter.dispose();
    _loop.dispose();
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    final safe = MediaQuery.paddingOf(context);
    final step = widget.step;
    // Rabi's middle, inside the stage: he stands at its foot.
    final rabiTop = _stage.height - _rabi - 4;
    final heart = Offset(_stage.width / 2, rabiTop + _rabi * 0.56);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (!still)
          IgnorePointer(
            child: CustomPaint(painter: ConfettiPainter(progress: _confetti)),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(28, safe.top + 24, 28, safe.bottom + 24),
          child: Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox.fromSize(
                      size: _stage,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: CelebrationPainter(
                                enter: _enter,
                                loop: _loop,
                                center: heart,
                                radius: _stage.width * 0.42,
                                still: still,
                              ),
                            ),
                          ),
                          Positioned(
                            left: (_stage.width - _rabi) / 2,
                            top: rabiTop,
                            child: AnimatedBuilder(
                              animation: _enter,
                              builder: (context, rabi) {
                                // Springs up from below and lands.
                                final t = (_enter.value / 0.36).clamp(0.0, 1.0);
                                final jump = Curves.easeOutBack.transform(t);
                                return Opacity(
                                  opacity: Curves.easeOut
                                      .transform((t * 2.2).clamp(0.0, 1.0)),
                                  child: Transform.translate(
                                    offset: Offset(0, 80 * (1 - jump)),
                                    child: Transform.scale(
                                      scale: 0.5 + 0.5 * jump,
                                      alignment: Alignment.bottomCenter,
                                      child: rabi,
                                    ),
                                  ),
                                );
                              },
                              child: const DentraMascot(
                                mood: MascotMood.cheer,
                                size: _rabi,
                                awake: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Semantics(
                      liveRegion: true,
                      container: true,
                      child: Column(
                        children: [
                          _Rise(
                            enter: _enter,
                            from: 0.34,
                            child: Semantics(
                              header: true,
                              child: Text(
                                step.title,
                                textAlign: TextAlign.center,
                                style: guideTitleStyle(large: true)
                                    .copyWith(fontSize: 28),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          _Rise(
                            enter: _enter,
                            from: 0.44,
                            child: Text(
                              step.body,
                              textAlign: TextAlign.center,
                              style: guideBodyStyle().copyWith(fontSize: 15.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _Rise(
                      enter: _enter,
                      from: 0.54,
                      child: GuidePrimaryButton(
                        label: step.action,
                        onPressed: widget.onDone,
                        height: 50,
                        minWidth: 200,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Fades its child in while it rises a little, from [from] of [enter].
class _Rise extends StatelessWidget {
  const _Rise({required this.enter, required this.from, required this.child});

  final Animation<double> enter;
  final double from;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: enter,
      builder: (context, child) {
        final p = Curves.easeOutCubic
            .transform(((enter.value - from) / 0.3).clamp(0.0, 1.0));
        return Opacity(
          opacity: p,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - p)),
            child: child,
          ),
        );
      },
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

class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(text, style: guideTitleStyle()),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: guideBodyStyle());
  }
}
