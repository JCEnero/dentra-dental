import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/scan_report.dart';
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

/// A small swatch and its meaning.
class ReportLegendItem extends StatelessWidget {
  const ReportLegendItem(this.state, {super.key});

  final AreaState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ReportSwatch(state),
        const SizedBox(width: 5),
        Flexible(child: Text(areaStateLabel(state), style: reportNote)),
      ],
    );
  }
}

/// The states shown, darkest first, and one key for all that aren't read.
class ReportLegend extends StatelessWidget {
  const ReportLegend(this.states, {super.key, this.alignment = WrapAlignment.start});

  final Set<AreaState> states;
  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: alignment,
      spacing: 12,
      runSpacing: 4,
      children: [
        for (final s in const [
          AreaState.strong,
          AreaState.possible,
          AreaState.faint,
          AreaState.clear,
        ])
          if (states.contains(s)) ReportLegendItem(s),
        if (states.any((s) => !s.read)) const ReportLegendItem(AreaState.notRead),
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
        border: state.read
            ? null
            : Border.all(color: ReportColors.hollowEdge),
      ),
    );
  }
}
