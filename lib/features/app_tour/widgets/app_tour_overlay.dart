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
import '../../../shared/widgets/guide_bubble.dart';
import '../../../shared/widgets/guide_kit.dart';
import '../../../shared/widgets/mascot_stage.dart';
import '../data/app_tour_steps.dart';
import '../data/app_tour_targets.dart';
import '../providers/app_tour_provider.dart';
import 'tour_visuals.dart';

/// First-run tour of DENTRA. Sits above the app shell, starts on its own
/// for accounts that haven't seen it, and can be replayed from Profile.
///
/// The app stays visible under frosted glass while a clear lens glides
/// from feature to feature (scrolling Home and switching tabs as it
/// goes). Rabi hops along beside it and says what each one is for in his
/// speech bubble. Next, Back, a swipe on the bubble or a tap on the lit-up
/// target move along; Skip or system back end it at any point.
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

  /// Loops forever: the lens's ripple and the feature glyphs.
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  late final AnimationController _confetti = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );

  /// The bubble's scroll (only moves on short screens or with large text).
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

  /// Scrolls Home so [spot] sits near the top, leaving Rabi and his bubble
  /// room below it. The lens follows along while the page moves.
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

                // Rabi and his bubble go on whichever side of the target
                // has room, with Rabi between the two.
                const rabi = _TourGuide.rabiSize;
                const gap = 8.0;
                final roomBelow =
                    size.height - hole.bottom - safe.bottom - 16 - rabi - gap;
                final roomAbove = hole.top - safe.top - 6 - rabi - gap;
                final below = target != null && roomBelow > roomAbove;
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
                  alignment = Alignment.topCenter;
                } else {
                  padding = EdgeInsets.fromLTRB(20, safe.top + 6, 20,
                      math.max(safe.bottom + 16, size.height - hole.top + gap));
                  alignment = Alignment.bottomCenter;
                }

                // Where Rabi stands along that edge, as 0 (left) → 1
                // (right) of the room he has, and which way he faces.
                final width = math.min(_TourGuide.maxWidth, size.width - 40);
                final left = (size.width - width) / 2;
                var along = 0.5;
                var faceRight = false;
                if (target != null) {
                  final double x;
                  if (target.width > size.width * 0.55) {
                    // A wide card: under one end of it, a different end
                    // each time, pointing back at its middle.
                    faceRight = _step.isOdd;
                    x = faceRight ? left : left + width - rabi;
                  } else {
                    // A button: just beside it, on the roomier side.
                    faceRight = target.center.dx > size.width / 2;
                    x = faceRight ? hole.left - 6 - rabi : hole.right + 6;
                  }
                  along = width <= rabi
                      ? 0.5
                      : ((x - left) / (width - rabi)).clamp(0.0, 1.0);
                }

                return MascotStage(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          // Tapping the lit-up target moves on, as if it
                          // were the real thing.
                          onTapUp: (details) {
                            if (target != null &&
                                hole.outerRect
                                    .contains(details.localPosition)) {
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
                                origin: Offset(
                                    size.width / 2, size.height / 2 - 90),
                              ),
                            ),
                          ),
                        ),
                      Positioned.fill(
                        child: AnimatedPadding(
                          duration: dentraMotion(context, 460),
                          curve: Curves.easeOutCubic,
                          padding: padding,
                          child: AnimatedAlign(
                            duration: dentraMotion(context, 460),
                            curve: Curves.easeOutCubic,
                            alignment: alignment,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: _TourGuide.maxWidth,
                              ),
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
                                  chapterLabel: step.chapter == null
                                      ? null
                                      : _chapterLabel(),
                                  spotCount: _spotCount,
                                  isLast: _isLast,
                                  canGoBack: _step > 1 && step.spot != null,
                                  motion: _motion,
                                  still: still,
                                  rabiFirst: target == null || below,
                                  rabiAlong: along,
                                  rabiFacesRight: faceRight,
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
                  ),
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

// ── Rabi and his bubble ─────────────────────────────────────────────

/// Rabi beside his speech bubble. He stands on the side nearest the
/// lit-up feature and the bubble's tail follows him; the words slide in
/// each step while the bubble resizes around them.
class _TourGuide extends StatelessWidget {
  const _TourGuide({
    required this.step,
    required this.visit,
    required this.chapterLabel,
    required this.spotCount,
    required this.isLast,
    required this.canGoBack,
    required this.motion,
    required this.still,
    required this.rabiFirst,
    required this.rabiAlong,
    required this.rabiFacesRight,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
    required this.scrollController,
  });

  final AppTourStep step;

  /// Changes on every move, so each step's Rabi and words are new.
  final int visit;
  final String? chapterLabel;
  final int spotCount;
  final bool isLast;
  final bool canGoBack;
  final Animation<double> motion;
  final bool still;

  /// Rabi is above the bubble (the feature is above them both), else
  /// under it.
  final bool rabiFirst;

  /// 0 → 1: how far along from the left Rabi stands.
  final double rabiAlong;
  final bool rabiFacesRight;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onSkip;
  final ScrollController scrollController;

  static const double maxWidth = 400;

  /// Rabi's size beside a feature, and when he has the page to himself.
  static const double rabiSize = 84;
  static const double _heroSize = 124;

  @override
  Widget build(BuildContext context) {
    final duration = dentraMotion(context, 340);
    final hasSpot = step.spot != null;
    final size = hasSpot ? rabiSize : _heroSize;

    // Each step has its own spot, so Rabi hops from the last one. The old
    // spot stays until he has left it.
    final rabi = AnimatedContainer(
      key: const ValueKey('rabi'),
      duration: duration,
      curve: Curves.easeOutCubic,
      height: size,
      child: AnimatedSwitcher(
        duration: dentraMotion(context, 420),
        layoutBuilder: (current, previous) => Stack(
          fit: StackFit.expand,
          children: [...previous, if (current != null) current],
        ),
        transitionBuilder: (child, _) => child,
        child: AnimatedAlign(
          key: ValueKey(visit),
          duration: duration,
          curve: Curves.easeOutCubic,
          alignment: Alignment(rabiAlong * 2 - 1, 0),
          child: MascotSpot(
            size: size,
            mood: step.mood,
            // His arm lifts toward a feature above, dips to one below.
            aim: rabiFirst ? MascotAim.up : MascotAim.down,
            mirrored: rabiFacesRight,
          ),
        ),
      ),
    );

    final bubble = Flexible(
      key: const ValueKey('bubble'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The tail sits under (or over) the middle of Rabi.
          final room = constraints.maxWidth - size;
          final rabiCentre = room * rabiAlong + size / 2;
          const corner = 33.0;
          final tailAt = constraints.maxWidth <= 2 * corner
              ? 0.5
              : ((rabiCentre - corner) / (constraints.maxWidth - 2 * corner))
                  .clamp(0.0, 1.0);
          return GuideBubble(
            tail: rabiFirst ? BubbleTail.top : BubbleTail.bottom,
            tailAt: tailAt,
            padding: EdgeInsets.zero,
            child: AnimatedSize(
              duration: duration,
              curve: Curves.easeOutCubic,
              alignment:
                  rabiFirst ? Alignment.topCenter : Alignment.bottomCenter,
              // Scrolls on short screens or with very large text, so the
              // buttons always stay reachable.
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(18, 16, 14, 12),
                child: AnimatedSwitcher(
                  duration: duration,
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.topCenter,
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
                    child: hasSpot
                        ? _spotStep()
                        : isLast
                            ? _finale()
                            : _welcome(),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rabiFirst ? [rabi, bubble] : [bubble, rabi],
    );
  }

  /// Welcome: Rabi says hi and offers the tour.
  Widget _welcome() {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Caption('Quick tour · $spotCount stops'),
          const SizedBox(height: 4),
          _Title(step.title, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          _Body(step.body, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          GuidePrimaryButton(
            label: step.action,
            onPressed: onNext,
            height: 46,
            minWidth: 180,
          ),
          GuideQuietButton(
            label: 'Maybe later',
            semanticLabel: 'Maybe later, end the tour',
            onPressed: onSkip,
            height: 44,
          ),
        ],
      ),
    );
  }

  /// Send-off: one line and one button.
  Widget _finale() {
    return Padding(
      padding: const EdgeInsets.only(right: 4, bottom: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Title(step.title, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          _Body(step.body, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          GuidePrimaryButton(
            label: step.action,
            onPressed: onNext,
            height: 46,
            minWidth: 180,
          ),
        ],
      ),
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
                  size: 44,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Caption(chapterLabel!),
                  const SizedBox(height: 1),
                  _Title(step.title),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: _Body(step.body),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // Lined up with the words above, not with its own padding.
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
  const _Title(this.text, {this.textAlign});

  final String text;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(text, textAlign: textAlign, style: guideTitleStyle()),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(this.text, {this.textAlign});

  final String text;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(text, textAlign: textAlign, style: guideBodyStyle());
  }
}
