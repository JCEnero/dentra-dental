import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_backdrop.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../../shared/widgets/dentra_mascot.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/guide_kit.dart';
import '../../../shared/widgets/mascot_stage.dart';
import '../../scan/widgets/scan_theme.dart';
import '../camera_strings.dart';
import '../state/live_camera_controller.dart';
import 'camera_bits.dart';
import 'setup_device_stage.dart';
import 'live_view.dart';

// The frame and scene pieces both setup guides share: over Bluetooth in the
// phone apps, and through the camera's hotspot on the website.

/// A setup guide's page: the step rail and close button on top, the current
/// [scene] in the middle and its [actions] at the bottom. Rabi belongs to
/// the whole page: as the scene changes he vanishes in a puff where he
/// stood and pops up on the next scene in the same moment.
class SetupFrame extends StatelessWidget {
  const SetupFrame({
    super.key,
    required this.step,
    required this.icons,
    required this.label,
    required this.onClose,
    required this.sceneKey,
    required this.direction,
    required this.scene,
    required this.actions,
    this.onRefresh,
  });

  /// Zero-based.
  final int step;

  /// One icon per step, for the rail.
  final List<IconData> icons;

  /// The step's name, read out with the rail.
  final String label;
  final VoidCallback onClose;

  /// Changes whenever the scene should slide to a new one.
  final Key sceneKey;

  /// 1 heading forward, -1 back: which way scenes slide.
  final int direction;
  final Widget scene;
  final Widget actions;

  /// Pulling down on the scene runs this, where it is set.
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    Widget body = _SceneArea(
      sceneKey: sceneKey,
      direction: direction,
      child: scene,
    );
    if (onRefresh != null) {
      body = RefreshIndicator(
        color: AppColors.primary,
        onRefresh: onRefresh!,
        child: body,
      );
    }
    return Scaffold(
      backgroundColor: AppColors.lightLavender,
      body: AppBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(
                    step: step,
                    icons: icons,
                    label: label,
                    onClose: onClose,
                  ),
                  Expanded(
                    child: MascotStage(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: body),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
                            child: actions,
                          ),
                        ],
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

/// The step rail, a short count and the close button.
class _Header extends StatelessWidget {
  const _Header({
    required this.step,
    required this.icons,
    required this.label,
    required this.onClose,
  });

  final int step;
  final List<IconData> icons;
  final String label;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: GuideStepRail(step: step, icons: icons, label: label),
          ),
          const SizedBox(width: 10),
          ExcludeSemantics(
            child: Text(
              '${step + 1} of ${icons.length}',
              style: figureText(
                size: 12.5,
                weight: FontWeight.w600,
                color: AppColors.secondaryText,
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: onClose,
            tooltip: CamText.closeSetup,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.white.withValues(alpha: 0.62),
              foregroundColor: AppColors.navy,
              fixedSize: const Size(44, 44),
              side: BorderSide(color: AppColors.g2.withValues(alpha: 0.18)),
            ),
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

/// The scrolling area between the header and the buttons. A scene is at
/// least as tall as the area, so it can centre itself or sit at the bottom;
/// a new [sceneKey] slides it in from the side the guide is heading to.
class _SceneArea extends StatelessWidget {
  const _SceneArea({
    required this.sceneKey,
    required this.direction,
    required this.child,
  });

  final Key sceneKey;
  final int direction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final motion = camMotion(context);
    const padding = EdgeInsets.fromLTRB(20, 10, 20, 10);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: math.max(0, constraints.maxHeight - padding.vertical),
          ),
          child: AnimatedSwitcher(
            duration: motion,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (current, previous) => Stack(
              fit: StackFit.passthrough,
              alignment: Alignment.topCenter,
              children: [
                for (final old in previous)
                  Positioned(top: 0, left: 0, right: 0, child: old),
                if (current != null) current,
              ],
            ),
            transitionBuilder: (child, animation) {
              // In from the side we're heading to; out toward the other.
              final incoming = child.key == sceneKey;
              final dx = 0.1 * direction * (incoming ? 1 : -1);
              final shift = Tween(begin: Offset(dx, 0), end: Offset.zero)
                  .animate(animation);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: shift,
                  // Rabi pops up only on the scene coming in, where it
                  // will come to rest.
                  child: MascotScene(
                    current: incoming,
                    shift: shift,
                    child: child,
                  ),
                ),
              );
            },
            child: KeyedSubtree(key: sceneKey, child: child),
          ),
        ),
      ),
    );
  }
}

/// Where Rabi stands beside what he says.
enum RabiPlace {
  /// Centred above his words: hello, looking, done.
  above,

  /// To the left of his words, facing them.
  left,

  /// To the right of his words, facing them. With [RabiSays.perched] he
  /// stands on whatever comes next (a list he is pointing down at).
  right,

  /// Under his words, at the right: beside the button he points down at.
  below,
}

/// Rabi and the step's instruction, laid out as one piece: the words are
/// the page's heading, with Rabi beside, above or below them.
class RabiSays extends StatelessWidget {
  const RabiSays({
    super.key,
    required this.title,
    this.body,
    this.highlight,
    this.place = RabiPlace.left,
    this.mood = MascotMood.point,
    this.aim = MascotAim.side,
    this.busy = false,
    this.perched = false,
    this.live = false,
    this.size,
  });

  final String title;
  final String? body;

  /// A part of [title] picked out in teal.
  final String? highlight;
  final RabiPlace place;
  final MascotMood mood;
  final MascotAim aim;

  /// Rings ripple behind him while something is under way.
  final bool busy;

  /// Stands him on the top edge of the next thing in the column.
  final bool perched;

  /// The words are a status: read out when they change.
  final bool live;
  final double? size;

  @override
  Widget build(BuildContext context) {
    GuideWords words({bool center = false}) => GuideWords(
          title: title,
          body: body,
          highlight: highlight,
          center: center,
          live: live,
          large: true,
        );

    switch (place) {
      case RabiPlace.above:
        return Column(
          children: [
            MascotSpot(mood: mood, aim: aim, busy: busy, size: size ?? 136),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: words(center: true),
            ),
          ],
        );
      case RabiPlace.below:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            words(),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: MascotSpot(
                  mood: mood,
                  aim: aim,
                  busy: busy,
                  size: size ?? 112,
                ),
              ),
            ),
          ],
        );
      case RabiPlace.left || RabiPlace.right:
        final onLeft = place == RabiPlace.left;
        // Narrow screens and large text leave his words the room.
        return LayoutBuilder(builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(1);
          final room = constraints.maxWidth * (scale > 1.15 ? 0.24 : 0.3);
          final rabi = MascotSpot(
            mood: mood,
            aim: aim,
            busy: busy,
            size: math.min(size ?? 96, room),
            // His arm is on his words' side.
            mirrored: onLeft,
          );
          final text = Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: onLeft ? 10 : 2,
                right: onLeft ? 2 : 10,
                bottom: perched ? 18 : 0,
              ),
              child: words(),
            ),
          );
          return Row(
            crossAxisAlignment:
                perched ? CrossAxisAlignment.end : CrossAxisAlignment.center,
            children: onLeft ? [rabi, text] : [text, rabi],
          );
        });
    }
  }
}

/// A scene's column: its pieces spaced evenly, top-aligned by default or
/// centred in the space there is.
class SetupScene extends StatelessWidget {
  const SetupScene({
    super.key,
    required this.children,
    this.centered = false,
    this.atBottom = false,
  });

  final List<Widget> children;

  /// Sits in the middle of the page (a scene with little on it).
  final bool centered;

  /// Sits at the bottom, by the buttons.
  final bool atBottom;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: atBottom
          ? MainAxisAlignment.end
          : centered
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

/// The first scene: Rabi stands on the stage, pointing down at the
/// Dentra Cam on its charger, and says what to have ready.
class SetupWelcomeScene extends StatelessWidget {
  const SetupWelcomeScene(
      {super.key, required this.items, required this.icons});

  final List<String> items;
  final List<IconData> icons;

  @override
  Widget build(BuildContext context) {
    return SetupScene(
      children: [
        const RabiSays(
          place: RabiPlace.right,
          perched: true,
          mood: MascotMood.point,
          aim: MascotAim.down,
          size: 104,
          title: CamText.welcomeTitle,
          highlight: CamText.welcomeHighlight,
          body: CamText.welcomeBody,
        ),
        const SetupDeviceStage(scene: DeviceScene.charging),
        const SizedBox(height: 14),
        SetupReadyList(items: items, icons: icons),
      ],
    );
  }
}

/// What to have ready, as one glass card of rows.
class SetupReadyList extends StatelessWidget {
  const SetupReadyList({super.key, required this.items, required this.icons});

  final List<String> items;
  final List<IconData> icons;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(22);
    // Clearer than a stock GlassCard: a thin white sheen with a bright
    // rim, so the backdrop reads through it as glass.
    return ClipRRect(
      borderRadius: radius,
      child: GlassBlur(
        child: DecoratedBox(
          decoration: setupClearGlass(radius),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: _rows(),
          ),
        ),
      ),
    );
  }

  Widget _rows() {
    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0)
            Divider(
              height: 1,
              thickness: 1,
              indent: 50,
              color: AppColors.g2.withValues(alpha: 0.12),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: CamInfoRow(icon: icons[i % icons.length], title: items[i]),
          ),
        ],
      ],
    );
  }
}

/// "Turn on the camera": the Dentra Cam turned to show its power switch,
/// which lights up and slides on, with Rabi pointing at it from the stage.
class SetupPowerScene extends StatelessWidget {
  const SetupPowerScene({super.key, required this.body, required this.reset});

  final String body;

  /// What to do with a camera that was set up before.
  final String reset;

  @override
  Widget build(BuildContext context) {
    return SetupScene(
      children: [
        RabiSays(
          place: RabiPlace.left,
          perched: true,
          mood: MascotMood.point,
          aim: MascotAim.down,
          size: 104,
          title: CamText.powerTitle,
          highlight: CamText.powerHighlight,
          body: body,
        ),
        const SetupDeviceStage(scene: DeviceScene.power),
        const SizedBox(height: 16),
        SetupHint(reset, icon: Icons.restart_alt_rounded),
      ],
    );
  }
}

/// The last scene: Rabi cheers over the camera's live picture.
class SetupDoneScene extends StatelessWidget {
  const SetupDoneScene({super.key, required this.body, required this.preview});

  final String body;
  final LiveCameraController? preview;

  @override
  Widget build(BuildContext context) {
    return SetupScene(
      children: [
        RabiSays(
          place: RabiPlace.above,
          mood: MascotMood.cheer,
          title: CamText.successTitle,
          body: body,
          size: 124,
        ),
        const SizedBox(height: 14),
        SetupPreview(preview: preview),
      ],
    );
  }
}

/// A soft teal panel for something that went wrong, or to know.
class SetupNotice extends StatelessWidget {
  const SetupNotice({super.key, this.title, required this.body});

  final String? title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
        decoration: BoxDecoration(
          color: AppColors.g2.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.g2.withValues(alpha: 0.24)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) ...[
                    Text(
                      title!,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 3),
                  ],
                  Text(
                    body,
                    style: GoogleFonts.outfit(
                      fontSize: 13.5,
                      color: AppColors.navy,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small line under a scene: a hint, in an icon's company.
class SetupHint extends StatelessWidget {
  const SetupHint(this.text,
      {super.key, this.icon = Icons.info_outline_rounded});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1.5),
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: AppColors.secondaryText,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

/// Things to do in order: an icon on a white disc for each, joined by a
/// teal line, with one line beside it and an optional smaller note. The
/// steps rise in one after another.
class SetupTimeline extends StatelessWidget {
  const SetupTimeline({super.key, required this.steps});

  /// Icon, what to do, and a line for when it doesn't go to plan.
  final List<(IconData, String, String?)> steps;

  @override
  Widget build(BuildContext context) {
    final motion = dentraMotion(context, 260 + 90 * steps.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < steps.length; i++)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: motion,
            curve: Interval(
              (i * 0.16).clamp(0.0, 0.7),
              (0.45 + i * 0.16).clamp(0.3, 1.0),
              curve: Curves.easeOutCubic,
            ),
            builder: (context, v, child) => Opacity(
              opacity: v,
              child: Transform.translate(
                offset: Offset(0, 10 * (1 - v)),
                child: child,
              ),
            ),
            child: _TimelineStep(
              number: i + 1,
              icon: steps[i].$1,
              text: steps[i].$2,
              note: steps[i].$3,
              last: i == steps.length - 1,
            ),
          ),
      ],
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.number,
    required this.icon,
    required this.text,
    required this.note,
    required this.last,
  });

  final int number;
  final IconData icon;
  final String text;
  final String? note;
  final bool last;

  static const double _disc = 34;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$number. $text${note == null ? '' : '. $note'}',
      excludeSemantics: true,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: _disc,
              child: Column(
                children: [
                  Container(
                    width: _disc,
                    height: _disc,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.white,
                      border: Border.all(
                        color: AppColors.g2.withValues(alpha: 0.2),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.g2.withValues(alpha: 0.14),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(icon, size: 17, color: AppColors.primary),
                  ),
                  if (!last)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(1),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.g1.withValues(alpha: 0.7),
                              AppColors.g2.withValues(alpha: 0.25),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 6, bottom: last ? 0 : 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text,
                      style: GoogleFonts.outfit(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.navy,
                        height: 1.35,
                      ),
                    ),
                    if (note != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        note!,
                        style: GoogleFonts.outfit(
                          fontSize: 12.5,
                          color: AppColors.secondaryText,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The new camera's live picture, as soon as it can be had.
class SetupPreview extends StatelessWidget {
  const SetupPreview({super.key, required this.preview});

  final LiveCameraController? preview;

  @override
  Widget build(BuildContext context) {
    const waiting = Center(child: GuideStatus(CamText.connectingShort));
    final preview = this.preview;
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.white.withValues(alpha: 0.75)),
          ),
          child: preview == null
              ? waiting
              : ListenableBuilder(
                  listenable: preview,
                  builder: (context, _) => Stack(
                    fit: StackFit.expand,
                    children: [
                      LiveView(frames: preview.frame),
                      if (!preview.isLive) waiting,
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

/// A looping 0 → 1 beat for a scene's small animations. Holds still when
/// the device asks for reduced motion.
class _Loop extends StatefulWidget {
  const _Loop({required this.period, required this.builder});

  final Duration period;
  final Widget Function(BuildContext context, Animation<double> beat) builder;

  @override
  State<_Loop> createState() => _LoopState();
}

class _LoopState extends State<_Loop> with SingleTickerProviderStateMixin {
  late final AnimationController _beat = AnimationController(
    vsync: this,
    duration: widget.period,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _beat
        ..stop()
        ..value = 0;
    } else if (!_beat.isAnimating) {
      _beat.repeat();
    }
  }

  @override
  void dispose() {
    _beat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _beat);
}

/// How far the camera has got on its way to the Wi-Fi.
enum LinkPhase { sending, joining, restarting, finding, done }

/// Phone, camera and Wi-Fi in a row, with dots travelling along whichever
/// link is being made right now. Finished links stay drawn in teal.
class SetupLinkArt extends StatelessWidget {
  const SetupLinkArt({
    super.key,
    required this.phase,
    this.stuck = false,
    this.direct = false,
  });

  final LinkPhase phase;

  /// Something went wrong: the dots stop.
  final bool stuck;

  /// No handing over of Wi-Fi details: the phone looks for a camera that
  /// is on the network already.
  final bool direct;

  @override
  Widget build(BuildContext context) {
    // Which of the two links is drawn solid, and which is in motion.
    final sent = direct || phase.index > LinkPhase.sending.index;
    final joined = direct || phase.index > LinkPhase.joining.index;
    final done = phase == LinkPhase.done;
    return ExcludeSemantics(
      child: _Loop(
        period: const Duration(milliseconds: 1500),
        builder: (context, beat) => SizedBox(
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LinkNode(
                Icons.smartphone_rounded,
                lit: true,
                pulsing: !stuck && phase == LinkPhase.finding,
                beat: beat,
              ),
              _LinkLine(
                beat: beat,
                solid: sent && phase != LinkPhase.finding || done,
                flowing: !stuck &&
                    (phase == LinkPhase.sending || phase == LinkPhase.finding),
              ),
              _LinkNode(
                Icons.videocam_rounded,
                lit: sent,
                pulsing: !stuck && phase == LinkPhase.restarting,
                beat: beat,
              ),
              _LinkLine(
                beat: beat,
                solid: joined,
                flowing: !stuck && phase == LinkPhase.joining,
              ),
              _LinkNode(
                Icons.wifi_rounded,
                lit: joined,
                pulsing: false,
                beat: beat,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkNode extends StatelessWidget {
  const _LinkNode(
    this.icon, {
    required this.lit,
    required this.pulsing,
    required this.beat,
  });

  final IconData icon;
  final bool lit;
  final bool pulsing;
  final Animation<double> beat;

  @override
  Widget build(BuildContext context) {
    final motion = dentraMotion(context, 320);
    return CustomPaint(
      painter: pulsing ? _NodePulse(beat) : null,
      child: AnimatedContainer(
        duration: motion,
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.white.withValues(alpha: lit ? 1 : 0.55),
          border: Border.all(
            color: AppColors.g2.withValues(alpha: lit ? 0.3 : 0.14),
          ),
        ),
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(
            end: lit ? AppColors.primary : ScanColors.muted,
          ),
          duration: motion,
          builder: (context, color, _) => Icon(icon, size: 21, color: color),
        ),
      ),
    );
  }
}

class _NodePulse extends CustomPainter {
  _NodePulse(this.beat) : super(repaint: beat);

  final Animation<double> beat;

  @override
  void paint(Canvas canvas, Size size) {
    final t = beat.value;
    canvas.drawCircle(
      size.center(Offset.zero),
      size.shortestSide / 2 + 9 * t,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = AppColors.g1.withValues(alpha: 0.7 * (1 - t)),
    );
  }

  @override
  bool shouldRepaint(_NodePulse old) => old.beat != beat;
}

class _LinkLine extends StatelessWidget {
  const _LinkLine({
    required this.beat,
    required this.solid,
    required this.flowing,
  });

  final Animation<double> beat;
  final bool solid;
  final bool flowing;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: solid ? 1 : 0),
      duration: dentraMotion(context, 420),
      curve: Curves.easeOutCubic,
      builder: (context, filled, _) => CustomPaint(
        size: const Size(58, 46),
        painter: _LinePainter(beat, filled, flowing),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.beat, this.filled, this.flowing)
      : super(repaint: flowing ? beat : null);

  final Animation<double> beat;

  /// 0 → 1: how much of the line is drawn solid.
  final double filled;
  final bool flowing;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    const inset = 7.0;
    final from = Offset(inset, y);
    final to = Offset(size.width - inset, y);
    final line = Paint()
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;

    // Waiting: a row of faint dots.
    const dots = 5;
    for (var i = 0; i < dots; i++) {
      final p = Offset.lerp(from, to, i / (dots - 1))!;
      canvas.drawCircle(
        p,
        1.7,
        Paint()..color = AppColors.g2.withValues(alpha: 0.26 * (1 - filled)),
      );
    }
    if (filled > 0) {
      canvas.drawLine(
        from,
        Offset.lerp(from, to, filled)!,
        line..color = AppColors.g2.withValues(alpha: 0.85),
      );
    }
    if (flowing) {
      // Two brighter dots travelling along it, one after the other.
      for (final shift in const [0.0, 0.5]) {
        final t = (beat.value + shift) % 1;
        canvas.drawCircle(
          Offset.lerp(from, to, t)!,
          3.4,
          Paint()
            ..color =
                AppColors.g1.withValues(alpha: math.sin(t * math.pi).abs()),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.filled != filled || old.flowing != flowing || old.beat != beat;
}
