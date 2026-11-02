import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/scan_outcomes.dart';
import '../../data/scan_report.dart';
import '../scan_theme.dart';
import 'report_style.dart';

/// Which side of which teeth the scan really looked at: every area against
/// every surface. A clear result only means something for the squares that
/// were read, so the gaps are shown as plainly as the rest.
class CoverageGrid extends StatelessWidget {
  const CoverageGrid({super.key, required this.coverage});

  final Map<(ToothSurface, MouthArea), AreaState> coverage;

  static const double _gap = 4;
  static const double _labelWidth = 48;
  static const double _archGap = 10;

  // Columns as on the map: their left on the left.
  static const _upper = [
    MouthArea.upperLeft,
    MouthArea.upperFront,
    MouthArea.upperRight,
  ];
  static const _lower = [
    MouthArea.lowerLeft,
    MouthArea.lowerFront,
    MouthArea.lowerRight,
  ];

  /// The one gap worth explaining, if there is one.
  String? get _note {
    bool any(AreaState state) => coverage.values.contains(state);
    if (any(AreaState.retake)) {
      return 'Some surfaces need a retake before they can be read.';
    }
    if (any(AreaState.notRead)) {
      return 'Inner sides are saved for you and your dentist. '
          'This check can\'t read them yet.';
    }
    if (any(AreaState.notTaken)) return 'Some surfaces had no photo in this scan.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final note = _note;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _GridHeader(),
        const SizedBox(height: 4),
        for (final (i, surface) in ToothSurface.values.indexed) ...[
          if (i > 0) const SizedBox(height: _gap),
          _GridRow(surface: surface, coverage: coverage),
        ],
        const SizedBox(height: 12),
        ReportLegend(coverage.values.toSet()),
        if (note != null) ...[
          const SizedBox(height: 8),
          Text(note, style: reportBody),
        ],
      ],
    );
  }
}

class _GridHeader extends StatelessWidget {
  const _GridHeader();

  @override
  Widget build(BuildContext context) {
    Widget arch(String name) => Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name.toUpperCase(), style: capsLabel()),
              const SizedBox(height: 3),
              Row(
                children: [
                  for (final part in const ['L', 'Front', 'R'])
                    Expanded(
                      child: Text(
                        part,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        softWrap: false,
                        // Each square says all this to a screen reader; these
                        // only have to fit above a narrow column.
                        textScaler: TextScaler.noScaling,
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
    return ExcludeSemantics(
      child: Row(
        children: [
          const SizedBox(width: CoverageGrid._labelWidth),
          arch('Upper'),
          const SizedBox(width: CoverageGrid._archGap),
          arch('Lower'),
        ],
      ),
    );
  }
}

class _GridRow extends StatelessWidget {
  const _GridRow({required this.surface, required this.coverage});

  final ToothSurface surface;
  final Map<(ToothSurface, MouthArea), AreaState> coverage;

  @override
  Widget build(BuildContext context) {
    Widget cells(List<MouthArea> areas) => Expanded(
          flex: 3,
          child: Row(
            children: [
              for (final (i, area) in areas.indexed) ...[
                if (i > 0) const SizedBox(width: CoverageGrid._gap),
                Expanded(
                  child: _Cell(
                    surface: surface,
                    area: area,
                    state: coverage[(surface, area)]!,
                  ),
                ),
              ],
            ],
          ),
        );
    return Row(
      children: [
        SizedBox(
          width: CoverageGrid._labelWidth,
          child: ExcludeSemantics(
            child: Text(
              surface.label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
          ),
        ),
        cells(CoverageGrid._upper),
        const SizedBox(width: CoverageGrid._archGap),
        cells(CoverageGrid._lower),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.surface,
    required this.area,
    required this.state,
  });

  final ToothSurface surface;
  final MouthArea area;
  final AreaState state;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${area.label}, ${surface.label.toLowerCase()} surface: '
          '${areaStateLabel(state)}',
      excludeSemantics: true,
      child: Container(
        height: 26,
        decoration: BoxDecoration(
          color: ReportColors.of(state),
          borderRadius: BorderRadius.circular(7),
          border: state.read ? null : Border.all(color: ReportColors.hollowEdge),
        ),
      ),
    );
  }
}
