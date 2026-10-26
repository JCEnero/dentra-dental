import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_glass.dart';

/// Frosted-glass card: blurs whatever sits behind it, then lays a
/// translucent white fill and a bright rim on top.
///
/// Pass [onTap] for a tappable card; the ripple stays inside the glass.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.tint = AppColors.white,
    this.borderColor,
    this.borderWidth = 1,
    this.onTap,
    this.width,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius borderRadius;

  /// Fill color behind the transparency. White by default; a light brand
  /// tint (e.g. `AppColors.lightLavender`) gives a softly colored pane.
  final Color tint;

  /// Overrides the default bright rim, e.g. for a selected state.
  final Color? borderColor;
  final double borderWidth;
  final VoidCallback? onTap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    Widget content =
        padding != null ? Padding(padding: padding!, child: child) : child;

    if (onTap != null) {
      content = Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          splashColor: AppColors.lightLavender.withValues(alpha: 0.7),
          highlightColor: AppColors.lightLavender.withValues(alpha: 0.45),
          child: content,
        ),
      );
    }

    return SizedBox(
      width: width,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: GlassBlur(
          child: DecoratedBox(
            decoration: AppGlass.surface(
              borderRadius: borderRadius,
              tint: tint,
              borderColor: borderColor,
              borderWidth: borderWidth,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// Full-width frosted bar for docked chrome (bottom nav, action bars).
/// Draws a faint teal hairline on the edge facing the content.
class GlassBar extends StatelessWidget {
  const GlassBar({super.key, required this.child, this.edge = GlassBarEdge.top});

  final Widget child;
  final GlassBarEdge edge;

  @override
  Widget build(BuildContext context) {
    final side = BorderSide(color: AppGlass.divider);
    return ClipRect(
      child: GlassBlur(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppGlass.barFill,
            border: edge == GlassBarEdge.top
                ? Border(top: side)
                : Border(bottom: side),
          ),
          child: child,
        ),
      ),
    );
  }
}

enum GlassBarEdge { top, bottom }

/// Background blur behind glass surfaces.
///
/// Skipped on web: there, platform views such as the Google Map split the
/// scene into separate layers, and backdrop blurs read stale pixels across
/// them (ghosted, duplicated content). The page backdrop is already soft,
/// so the translucent fill alone looks nearly identical.
class GlassBlur extends StatelessWidget {
  const GlassBlur({super.key, required this.child, this.strong = false});

  final Widget child;

  /// The heavier blur used by surfaces that appear over content.
  final bool strong;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return child;
    return BackdropFilter.grouped(
      filter: strong ? AppGlass.floatBlur : AppGlass.blur,
      child: child,
    );
  }
}
