import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/scan_report.dart';
import '../scan_motion.dart';
import '../scan_theme.dart';

// Shared look for the results page. Every state is a shade of one teal ramp,
// light to dark as a result gets more pressing, and always comes with words.

/// Fills for what can be said about an area. Only the three flagged states
/// carry data colour, all teal; a clear area stays calm and an unread one
/// hollow. Dark navy is for text, never for a result.
abstract class ReportColors {
  static const Color clear = AppColors.lavender;
  static const Color faint = AppColors.cardSolid;
  static const Color possible = Color(0xFF2A9493);
  static const Color strong = Color(0xFF1F6F71);
  static const Color hollow = AppColors.white;

  /// The outline of an unread area: it has no fill to show it by.
  static const Color hollowEdge = ScanColors.muted;

  /// Hairlines, one step off the glass.
  static Color get rule => AppColors.navy.withValues(alpha: 0.09);

  static Color of(AreaState state) => switch (state) {
        AreaState.strong => strong,
        AreaState.possible => possible,
        AreaState.faint => faint,
        AreaState.clear => clear,
        _ => hollow,
      };

  static Color ofSign(SignStrength strength) => of(AreaState.of(strength));
}

/// What a state means, in the words the legend and the screen reader use.
String areaStateLabel(AreaState state) => switch (state) {
      AreaState.strong => SignStrength.strong.label,
      AreaState.possible => SignStrength.possible.label,
      AreaState.faint => SignStrength.faint.label,
      AreaState.clear => 'Nothing flagged',
      AreaState.retake => 'Needs a retake',
      AreaState.notRead => 'Not read yet',
      AreaState.notTaken => 'No photo',
    };

final TextStyle reportHeadline = GoogleFonts.outfit(
  fontSize: 21,
  height: 1.2,
  fontWeight: FontWeight.w800,
  letterSpacing: -0.2,
  color: AppColors.navy,
);

final TextStyle reportCardTitle = GoogleFonts.outfit(
  fontSize: 14,
  fontWeight: FontWeight.w700,
  color: AppColors.navy,
);

final TextStyle reportBody = GoogleFonts.outfit(
  fontSize: 13,
  height: 1.45,
  color: AppColors.secondaryText,
);

final TextStyle reportNote = GoogleFonts.outfit(
  fontSize: 11.5,
  height: 1.4,
  color: AppColors.secondaryText,
);

/// A small teal label over a part of a card, e.g. "What we found".
final TextStyle reportLabel = GoogleFonts.outfit(
  fontSize: 11.5,
  height: 1.3,
  fontWeight: FontWeight.w700,
  color: ScanColors.clearInk,
);

/// A row that opens to show more: its title and a chevron, closed until tapped,
/// so the detail is there for anyone who wants it without crowding the page.
class ReportFold extends StatefulWidget {
  const ReportFold({
    super.key,
    required this.title,
    required this.child,
    this.count,
    this.subtitle,
  });

  final String title;

  /// The short answer, under the title, so the row says something closed too.
  final String? subtitle;

  /// How many things are inside, shown beside the title.
  final int? count;
  final Widget child;

  @override
  State<ReportFold> createState() => _ReportFoldState();
}

class _ReportFoldState extends State<ReportFold> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final motion = ScanMotion.of(context, ScanMotion.fast);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: _open,
          label: [
            widget.title,
            if (widget.count != null) '${widget.count}',
            if (widget.subtitle != null) widget.subtitle!,
          ].join(', '),
          excludeSemantics: true,
          child: InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.title, style: reportCardTitle),
                          if (widget.subtitle case final subtitle?) ...[
                            const SizedBox(height: 1),
                            Text(subtitle, style: reportNote),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (widget.count case final n?) ...[
                    Text('$n', style: reportNote),
                    const SizedBox(width: 6),
                  ],
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: motion,
                    child: const Icon(
                      Icons.expand_more_rounded,
                      size: 22,
                      color: AppColors.g2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: motion,
          curve: ScanMotion.curve,
          alignment: Alignment.topCenter,
          child: _open
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: widget.child,
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// A section's heading and, under it, one line on what it shows.
class ReportHeading extends StatelessWidget {
  const ReportHeading(this.title, {super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ScanSectionTitle(title),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle!, style: reportBody),
        ],
      ],
    );
  }
}

class ReportSwatch extends StatelessWidget {
  const ReportSwatch(this.state, {super.key, this.size = 11});

  final AreaState state;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: ReportColors.of(state),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: state.read ? null : Border.all(color: ReportColors.hollowEdge),
      ),
    );
  }
}
