import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_glass.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/tooth_catalog.dart';
import '../state/explorer_camera.dart';
import '../state/tooth_type_colors.dart';

/// Round frosted button floating over the 3D view. With [active] it
/// becomes a toggle and shows the brand teal when on.
class ViewerIconButton extends StatelessWidget {
  const ViewerIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  /// Null for a plain button; true/false for a toggle.
  final bool? active;

  static const double size = 44;

  @override
  Widget build(BuildContext context) {
    final on = active ?? false;
    return Semantics(
      button: true,
      toggled: active,
      label: tooltip,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        child: ClipOval(
          child: GlassBlur(
            child: AnimatedContainer(
              duration: dentraMotion(context, 180),
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: on ? AppColors.cardGradient : null,
                color: on ? null : AppColors.white.withValues(alpha: 0.72),
                border: Border.all(
                  color: on
                      ? AppColors.white.withValues(alpha: 0.6)
                      : AppGlass.border,
                ),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: onPressed,
                  customBorder: const CircleBorder(),
                  child: Icon(
                    icon,
                    size: 20,
                    color: on ? AppColors.white : AppColors.navy,
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

/// Vertical stack of buttons sharing one glass pill.
class ViewerButtonColumn extends StatelessWidget {
  const ViewerButtonColumn({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          children[i],
        ],
      ],
    );
  }
}

/// Horizontal row of preset view directions.
class CameraViewBar extends StatelessWidget {
  const CameraViewBar({super.key, required this.onView});

  final ValueChanged<CameraView> onView;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: CameraView.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final view = CameraView.values[i];
          return _ViewChip(
            label: view.label,
            onTap: () => onView(view),
          );
        },
      ),
    );
  }
}

class _ViewChip extends StatelessWidget {
  const _ViewChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label view',
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: GlassBlur(
          child: Material(
            color: AppColors.white.withValues(alpha: 0.72),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: AppGlass.border),
            ),
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 13),
                child: Center(
                  child: Text(
                    label,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
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

/// Small key for "colour by type" mode.
class TypeLegendStrip extends StatelessWidget {
  const TypeLegendStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppGlass.border),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          for (final type in ToothType.values)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: ToothTypeColors.of(type),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  type.plural,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// One-line coaching hint at the top of the viewer.
class ViewerHint extends StatelessWidget {
  const ViewerHint({super.key, required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppGlass.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.g2),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
