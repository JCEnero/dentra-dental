import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'glass_card.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_glass.dart';

// ── Nav item model ─────────────────────────────────────────────

class _NavItem {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;

  const _NavItem({
    required this.activeIcon,
    required this.inactiveIcon,
    required this.label,
  });
}

// ── Bottom navigation ──────────────────────────────────────────

class AppBottomNav extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({
    super.key,
    required this.activeIndex,
    required this.onTap,
    this.itemKeys,
  });

  /// Optional keys for the buttons, in order, so overlays such as the app
  /// tour can find them on screen.
  final List<GlobalKey>? itemKeys;

  static int get itemCount => _items.length;

  static const List<_NavItem> _items = [
    _NavItem(
      activeIcon: Icons.home_rounded,
      inactiveIcon: Icons.home_outlined,
      label: 'Home',
    ),
    _NavItem(
      activeIcon: Icons.document_scanner_rounded,
      inactiveIcon: Icons.document_scanner_outlined,
      label: 'Scan',
    ),
    _NavItem(
      activeIcon: Icons.history_rounded,
      inactiveIcon: Icons.history_rounded,
      label: 'History',
    ),
    _NavItem(
      activeIcon: Icons.location_on_rounded,
      inactiveIcon: Icons.location_on_outlined,
      label: 'Clinics',
    ),
    _NavItem(
      activeIcon: Icons.person_rounded,
      inactiveIcon: Icons.person_outline_rounded,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 220);
    const pillRadius = BorderRadius.all(Radius.circular(36));

    // Floating Dock-style pill: frosted glass with round buttons, set in
    // from the screen edges so the backdrop flows around it.
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ClipRRect(
              borderRadius: pillRadius,
              child: GlassBlur(
                child: DecoratedBox(
                  decoration: AppGlass.surface(
                    borderRadius: pillRadius,
                    borderWidth: 1.2,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(_items.length, (i) {
                        return _DockButton(
                          key: itemKeys?[i],
                          item: _items[i],
                          active: i == activeIndex,
                          reduceMotion: reduceMotion,
                          duration: duration,
                          onTap: () => onTap(i),
                        );
                      }),
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

/// One round Dock button: a glossy teal disc when active, a plain glass
/// icon otherwise, with a small indicator dot like the macOS Dock.
class _DockButton extends StatelessWidget {
  const _DockButton({
    super.key,
    required this.item,
    required this.active,
    required this.reduceMotion,
    required this.duration,
    required this.onTap,
  });

  final _NavItem item;
  final bool active;
  final bool reduceMotion;
  final Duration duration;
  final VoidCallback onTap;

  static const double size = 52;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: item.label,
      excludeSemantics: true,
      child: Tooltip(
        message: item.label,
        child: InkResponse(
          onTap: onTap,
          radius: size / 2,
          customBorder: const CircleBorder(),
          splashColor: AppColors.lightLavender.withValues(alpha: 0.7),
          highlightColor: Colors.transparent,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Glass bubble: inflates when chosen, deflates when left.
                AnimatedScale(
                  duration: reduceMotion
                      ? Duration.zero
                      : Duration(milliseconds: active ? 520 : 260),
                  curve: active ? Curves.elasticOut : Curves.easeInBack,
                  scale: active ? 1 : 0,
                  child: const _GlassBubble(),
                ),
                AnimatedScale(
                  duration: duration,
                  curve: Curves.easeOutBack,
                  scale: active ? 1.08 : 0.9,
                  child: Icon(
                    active ? item.activeIcon : item.inactiveIcon,
                    size: 22,
                    color: active ? AppColors.white : AppColors.secondaryText,
                  ),
                ),
                // Dock indicator dot under the active app.
                Positioned(
                  bottom: 0,
                  child: AnimatedOpacity(
                    duration: duration,
                    opacity: active ? 1 : 0,
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.g2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Frosted glass disc with a light teal tint and a glossy top highlight.
class _GlassBubble extends StatelessWidget {
  const _GlassBubble();

  static const double _disc = 44;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: _disc,
          height: _disc,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.g1.withValues(alpha: 0.55),
                AppColors.g2.withValues(alpha: 0.8),
              ],
            ),
            border: Border.all(
              color: AppColors.white.withValues(alpha: 0.7),
              width: 1.2,
            ),
          ),
          // Soft shine across the top, like light on a bubble.
          child: Align(
            alignment: const Alignment(-0.35, -0.6),
            child: Container(
              width: 18,
              height: 9,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.white.withValues(alpha: 0.55),
                    AppColors.white.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
