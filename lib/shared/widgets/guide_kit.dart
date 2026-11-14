import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import 'dentra_glass_ui.dart' show dentraMotion;

// The pieces Rabi's guides share (the Dentra Cam setup and the app tour):
// what he says, the step rail, and compact buttons that never cut a label.

TextStyle guideTitleStyle({bool large = false}) => GoogleFonts.outfit(
      fontSize: large ? 24 : 20,
      fontWeight: FontWeight.w700,
      color: AppColors.navy,
      letterSpacing: large ? -0.5 : -0.3,
      height: large ? 1.18 : 1.22,
    );

// Navy, not grey: it has to read on see-through glass.
TextStyle guideBodyStyle() => GoogleFonts.outfit(
      fontSize: 14.5,
      color: AppColors.navy.withValues(alpha: 0.74),
      height: 1.42,
    );

/// The teal the key words of an instruction are picked out in, dark enough
/// to read on white glass.
const Color guideAccent = Color(0xFF17807D);

/// A step's instruction: a short title and, at most, one line under it.
/// [highlight], a part of the title, is picked out in teal. The title types
/// itself in as Rabi says it, then the line under it fades in; swapping the
/// words slides the new ones in.
class GuideWords extends StatelessWidget {
  const GuideWords({
    super.key,
    required this.title,
    this.body,
    this.highlight,
    this.center = false,
    this.live = false,
    this.large = false,
  });

  final String title;
  final String? body;
  final String? highlight;
  final bool center;

  /// Read out by screen readers whenever it changes (a status).
  final bool live;

  /// A page heading rather than words in a bubble.
  final bool large;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: dentraMotion(context, 260),
      curve: Curves.easeOutCubic,
      alignment: center ? Alignment.topCenter : Alignment.topLeft,
      child: AnimatedSwitcher(
        duration: dentraMotion(context, 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (current, previous) => Stack(
          alignment: center ? Alignment.topCenter : Alignment.topLeft,
          children: [
            for (final old in previous)
              Positioned(top: 0, left: 0, right: 0, child: old),
            if (current != null) current,
          ],
        ),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.12), end: Offset.zero)
                .animate(animation),
            child: child,
          ),
        ),
        child: Semantics(
          key: ValueKey('$title\n$body'),
          liveRegion: live,
          container: true,
          child: _Typed(
            title: title,
            body: body,
            highlight: highlight,
            center: center,
            large: large,
          ),
        ),
      ),
    );
  }
}

/// Types [title] in a letter at a time, then fades [body] in. The whole
/// text is laid out from the start (the rest just isn't shown yet), so the
/// bubble never changes size as it types, and screen readers get it all.
class _Typed extends StatefulWidget {
  const _Typed({
    required this.title,
    required this.body,
    required this.highlight,
    required this.center,
    required this.large,
  });

  final String title;
  final String? body;
  final String? highlight;
  final bool center;
  final bool large;

  @override
  State<_Typed> createState() => _TypedState();
}

class _TypedState extends State<_Typed> with SingleTickerProviderStateMixin {
  late final AnimationController _type = AnimationController(
    vsync: this,
    // Brisk: about 55 letters a second, never more than a second.
    duration: Duration(
      milliseconds: (widget.title.length * 18).clamp(240, 900),
    ),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _type.value = 1;
    } else if (_type.value == 0 && !_type.isAnimating) {
      // A beat for the bubble to pop open first.
      Future<void>.delayed(const Duration(milliseconds: 160), () {
        if (mounted) _type.forward();
      });
    }
  }

  @override
  void dispose() {
    _type.dispose();
    super.dispose();
  }

  /// The title as spans, the highlight in teal, with everything past
  /// [shown] letters see-through.
  TextSpan _title(int shown) {
    final base = guideTitleStyle(large: widget.large);
    final parts = <(String, bool)>[];
    final h = widget.highlight;
    final at = h == null || h.isEmpty ? -1 : widget.title.indexOf(h);
    if (at < 0) {
      parts.add((widget.title, false));
    } else {
      parts
        ..add((widget.title.substring(0, at), false))
        ..add((h!, true))
        ..add((widget.title.substring(at + h.length), false));
    }
    final spans = <TextSpan>[];
    var left = shown;
    for (final (text, lit) in parts) {
      if (text.isEmpty) continue;
      final style = lit ? base.copyWith(color: guideAccent) : base;
      final seen = left.clamp(0, text.length);
      if (seen > 0) spans.add(TextSpan(text: text.substring(0, seen), style: style));
      if (seen < text.length) {
        spans.add(TextSpan(
          text: text.substring(seen),
          style: style.copyWith(color: Colors.transparent),
        ));
      }
      left -= text.length;
    }
    return TextSpan(children: spans);
  }

  @override
  Widget build(BuildContext context) {
    final align = widget.center ? TextAlign.center : TextAlign.start;
    final body = widget.body;
    return AnimatedBuilder(
      animation: _type,
      builder: (context, _) {
        final shown = (widget.title.length * _type.value).ceil();
        final after =
            Curves.easeOut.transform(((_type.value - 0.6) / 0.4).clamp(0.0, 1.0));
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: widget.center
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text.rich(_title(shown), textAlign: align),
            ),
            if (body != null) ...[
              SizedBox(height: widget.large ? 6 : 4),
              Opacity(
                opacity: after,
                child: Transform.translate(
                  offset: Offset(0, 6 * (1 - after)),
                  child: Text(body, textAlign: align, style: guideBodyStyle()),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ── Step rail ────────────────────────────────────────────────────────

/// Where the guide is: a row of linked steps. Done steps are ticked in
/// teal, the current one is a white disc with its icon, the rest are
/// small dots. Moving on slides the disc along and fills the line.
class GuideStepRail extends StatelessWidget {
  const GuideStepRail({
    super.key,
    required this.step,
    required this.icons,
    required this.label,
  });

  /// Zero-based.
  final int step;

  /// One per step, in order.
  final List<IconData> icons;

  /// The current step's name, for screen readers.
  final String label;

  static const double height = 36;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Step ${step + 1} of ${icons.length}, $label',
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: step.toDouble()),
          duration: dentraMotion(context, 560),
          curve: Curves.easeInOutCubic,
          builder: (context, at, _) => CustomPaint(
            size: const Size(double.infinity, height),
            painter: _RailPainter(at, icons),
          ),
        ),
      ),
    );
  }
}

class _RailPainter extends CustomPainter {
  const _RailPainter(this.at, this.icons);

  /// The current step, part-way between two while it moves.
  final double at;
  final List<IconData> icons;

  static const double _dot = 4.5;
  static const double _done = 8;
  static const double _disc = 15;

  @override
  void paint(Canvas canvas, Size size) {
    final n = icons.length;
    final y = size.height / 2;
    // Steps sit close enough to read as one line, however wide the bar.
    final gap = n < 2
        ? 0.0
        : math.min(46.0, (size.width - 2 * (_disc + 2)) / (n - 1));
    const left = _disc + 2;
    double x(double i) => left + gap * i;

    final line = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(x(0), y),
      Offset(x(n - 1.0), y),
      line..color = AppColors.g2.withValues(alpha: 0.15),
    );
    if (at > 0) {
      canvas.drawLine(
        Offset(x(0), y),
        Offset(x(at), y),
        line
          ..shader = AppColors.primaryGradient.createShader(
            Rect.fromLTRB(x(0), 0, x(n - 1.0), size.height),
          ),
      );
    }

    for (var i = 0; i < n; i++) {
      final c = Offset(x(i.toDouble()), y);
      // 1 on this step, 0 a step or more away; and how far it is behind.
      final here = (1 - (at - i).abs()).clamp(0.0, 1.0);
      final passed = (at - i).clamp(0.0, 1.0);
      final base = _dot + (_done - _dot) * passed;
      final r = base + (_disc - base) * Curves.easeOut.transform(here);

      if (here > 0) {
        canvas.drawCircle(
          c,
          r + 1,
          Paint()
            ..color = AppColors.g1.withValues(alpha: 0.5 * here)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
        );
      }
      canvas.drawCircle(c, r, Paint()..color = AppColors.white);
      final ticked = passed * (1 - here);
      if (ticked > 0) {
        canvas.drawCircle(
          c,
          r,
          Paint()
            ..shader = AppColors.cardGradient
                .createShader(Rect.fromCircle(center: c, radius: r))
            ..color = Color.fromRGBO(255, 255, 255, ticked),
        );
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - r * 0.42, c.dy + r * 0.02)
            ..lineTo(c.dx - r * 0.1, c.dy + r * 0.34)
            ..lineTo(c.dx + r * 0.46, c.dy - r * 0.3),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = AppColors.white.withValues(alpha: ticked),
        );
      }
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = AppColors.g2.withValues(alpha: 0.26 * (1 - ticked)),
      );

      if (here > 0.05) {
        final icon = icons[i];
        final glyph = TextPainter(
          textDirection: TextDirection.ltr,
          text: TextSpan(
            text: String.fromCharCode(icon.codePoint),
            style: TextStyle(
              fontSize: 16 * (0.6 + 0.4 * here),
              fontFamily: icon.fontFamily,
              package: icon.fontPackage,
              color: AppColors.primary.withValues(alpha: here),
            ),
          ),
        )..layout();
        glyph.paint(canvas, c - Offset(glyph.width / 2, glyph.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(_RailPainter old) => old.at != at || old.icons != icons;
}

// ── Buttons ──────────────────────────────────────────────────────────

/// The guide's main action: a teal pill as wide as its label needs. A
/// label too long for the space shrinks to fit; it is never cut short.
class GuidePrimaryButton extends StatelessWidget {
  const GuidePrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.iconAfter = false,
    this.height = 52,
    this.minWidth = 136,
  });

  final String label;

  /// Null disables it.
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Puts [icon] after the label (an arrow onward) instead of before it.
  final bool iconAfter;
  final double height;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: AnimatedOpacity(
        duration: dentraMotion(context, 180),
        opacity: enabled ? 1 : 0.45,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height / 2),
            gradient: const LinearGradient(
              colors: [AppColors.cardSolid, AppColors.g2],
            ),
            boxShadow: [
              if (enabled)
                BoxShadow(
                  color: AppColors.g2.withValues(alpha: 0.26),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: minWidth),
                child: SizedBox(
                  height: height,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icon != null && !iconAfter) ...[
                            Icon(icon, size: 18, color: AppColors.white),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            label,
                            maxLines: 1,
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.1,
                              color: AppColors.white,
                            ),
                          ),
                          if (icon != null && iconAfter) ...[
                            const SizedBox(width: 8),
                            Icon(icon, size: 18, color: AppColors.white),
                          ],
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
    );
  }
}

/// A round glass button for going back a step.
class GuideBackButton extends StatelessWidget {
  const GuideBackButton({
    super.key,
    required this.onPressed,
    this.label = 'Back',
    this.size = 52,
  });

  final VoidCallback onPressed;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: Material(
          color: AppColors.white.withValues(alpha: 0.62),
          shape: CircleBorder(
            side: BorderSide(color: AppColors.g2.withValues(alpha: 0.22)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox.square(
              dimension: size,
              child: const Icon(
                Icons.arrow_back_rounded,
                size: 20,
                color: AppColors.navy,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A plain-text action beside the main one: "Not now", "Done", "Skip".
class GuideQuietButton extends StatelessWidget {
  const GuideQuietButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.semanticLabel,
    this.height = 52,
  });

  final String label;
  final VoidCallback onPressed;
  final String? semanticLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            height: height,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy.withValues(alpha: 0.72),
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

/// Three dots that rise in turn: something is under way.
class GuideDots extends StatefulWidget {
  const GuideDots({super.key});

  @override
  State<GuideDots> createState() => _GuideDotsState();
}

class _GuideDotsState extends State<GuideDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _beat = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _beat
        ..stop()
        ..value = 0.25;
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
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: const Size(30, 18),
        painter: _DotsPainter(_beat),
      ),
    );
  }
}

class _DotsPainter extends CustomPainter {
  _DotsPainter(this.beat) : super(repaint: beat);

  final Animation<double> beat;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 3; i++) {
      // Each dot rises a little after the one before it.
      final phase = (beat.value - i * 0.16) % 1;
      final up = phase < 0.5 ? math.sin(phase * 2 * math.pi) : 0.0;
      canvas.drawCircle(
        Offset(4 + i * 11.0, size.height / 2 - 4 * up),
        3.2,
        Paint()..color = AppColors.g2.withValues(alpha: 0.45 + 0.55 * up),
      );
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => old.beat != beat;
}

/// Something is under way and there is nothing to press: [GuideDots]
/// beside a word or two ("Searching…"). The words shrink to fit rather
/// than being cut.
class GuideStatus extends StatelessWidget {
  const GuideStatus(this.label, {super.key, this.semanticLabel});

  final String label;

  /// A fuller wording for screen readers.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: SizedBox(
        height: 52,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const GuideDots(),
              const SizedBox(width: 10),
              AnimatedSwitcher(
                duration: dentraMotion(context, 220),
                child: Text(
                  label,
                  key: ValueKey(label),
                  maxLines: 1,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
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

/// The guide's bottom row: a way back on the left, the next thing on the
/// right. When both will not fit side by side (a narrow screen, very large
/// text) the main action goes on top.
class GuideActions extends StatelessWidget {
  const GuideActions({super.key, this.leading, this.trailing});

  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final lead = leading;
    final trail = trailing == null
        ? null
        : AnimatedSwitcher(
            duration: dentraMotion(context, 240),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.centerRight,
              children: [...previous, if (current != null) current],
            ),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween(begin: 0.92, end: 1.0).animate(animation),
                alignment: Alignment.centerRight,
                child: child,
              ),
            ),
            child: trailing,
          );
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.5;
    if (stacked && lead != null && trail != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          trail,
          const SizedBox(height: 6),
          Align(alignment: Alignment.centerLeft, child: lead),
        ],
      );
    }
    // The way back keeps to its own size (under half the row); the main
    // action has the rest.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          mainAxisAlignment: lead == null
              ? MainAxisAlignment.end
              : MainAxisAlignment.spaceBetween,
          children: [
            if (lead != null)
              ConstrainedBox(
                constraints:
                    BoxConstraints(maxWidth: constraints.maxWidth * 0.42),
                child: lead,
              ),
            if (lead != null && trail != null) const SizedBox(width: 12),
            if (trail != null) Flexible(child: trail),
          ],
        ),
      ),
    );
  }
}
