import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../../shared/widgets/dentra_note_card.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/tooth_catalog.dart';
import '../data/tooth_content.dart';
import '../state/tooth_type_colors.dart';

/// Legend and how-to: tooth types, FDI numbering, controls and facts.
Future<void> showExplorerGuide(BuildContext context) {
  return showGlassSheet<void>(
    context: context,
    title: 'Guide to your teeth',
    subtitle: 'Tooth types, how the numbers work, and how to explore.',
    builder: (_) => const _GuideBody(),
  );
}

class _GuideBody extends StatelessWidget {
  const _GuideBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Heading('Tooth types'),
        for (final type in ToothType.values) _TypeRow(type: type),
        const SizedBox(height: 20),
        const _Heading('Reading tooth numbers'),
        Text(
          'Each tooth has a two-digit FDI number. The first digit is the '
          'quarter of the mouth (quadrant). The second counts out from the '
          'middle, 1 to 8.',
          style: _body,
        ),
        const SizedBox(height: 12),
        const _QuadrantGrid(),
        const SizedBox(height: 10),
        Text(
          'Example: 36 is quadrant 3 (lower left), position 6, the lower '
          'left first molar. Left and right are always the patient\'s own.',
          style: _body,
        ),
        const SizedBox(height: 20),
        const _Heading('Controls'),
        const _ControlRow(Icons.swipe_rounded, 'Drag', 'Rotate the model'),
        const _ControlRow(
            Icons.pinch_rounded, 'Pinch or scroll', 'Zoom in and out'),
        const _ControlRow(
            Icons.open_with_rounded, 'Two-finger drag', 'Move the model'),
        const _ControlRow(Icons.touch_app_rounded, 'Tap a tooth',
            'See its name, job and care tips'),
        const _ControlRow(Icons.layers_outlined, 'Gums button',
            'Show or hide the see-through gums'),
        const SizedBox(height: 20),
        const _Heading('Did you know?'),
        for (final fact in ToothContent.facts.take(3))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: DentraNoteCard(
              icon: Icons.lightbulb_outline_rounded,
              message: fact,
            ),
          ),
      ],
    );
  }
}

final _body = GoogleFonts.outfit(
  fontSize: 13.5,
  color: AppColors.navy.withValues(alpha: 0.85),
  height: 1.55,
);

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
      ),
    );
  }
}

class _TypeRow extends StatelessWidget {
  const _TypeRow({required this.type});
  final ToothType type;

  @override
  Widget build(BuildContext context) {
    final count = ToothCatalog.countOf(type);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(top: 3, right: 12),
            decoration: BoxDecoration(
              color: ToothTypeColors.of(type),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${type.plural} · $count teeth',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                Text(
                  ToothContent.forType(type).summary,
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    color: AppColors.secondaryText,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The four quadrants as seen when facing the patient.
class _QuadrantGrid extends StatelessWidget {
  const _QuadrantGrid();

  @override
  Widget build(BuildContext context) {
    Widget cell(int q, String name, String range) => Expanded(
          child: GlassCard(
            borderRadius: BorderRadius.circular(14),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            child: Column(
              children: [
                Text(
                  '$q',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.g2,
                  ),
                ),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
                Text(
                  range,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        );

    return Semantics(
      label: 'Quadrants facing the patient: 1 upper right, 2 upper left, '
          '4 lower right, 3 lower left.',
      excludeSemantics: true,
      child: Column(
        children: [
          Row(children: [
            cell(1, 'Upper right', '11 – 18'),
            const SizedBox(width: 8),
            cell(2, 'Upper left', '21 – 28'),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            cell(4, 'Lower right', '41 – 48'),
            const SizedBox(width: 8),
            cell(3, 'Lower left', '31 – 38'),
          ]),
        ],
      ),
    );
  }
}

class _ControlRow extends StatelessWidget {
  const _ControlRow(this.icon, this.gesture, this.result);

  final IconData icon;
  final String gesture;
  final String result;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.lightLavender,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: AppColors.g2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: '$gesture  ',
                  style: GoogleFonts.outfit(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                TextSpan(text: result, style: _body),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
