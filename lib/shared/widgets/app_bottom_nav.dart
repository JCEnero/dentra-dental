import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import 'glass_card.dart';

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
  });

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
      activeIcon: Icons.local_hospital_rounded,
      inactiveIcon: Icons.local_hospital_outlined,
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
        reduceMotion ? Duration.zero : const Duration(milliseconds: 200);

    return GlassBar(
      child: SafeArea(
        top: false,
        // Labels may grow with system font size, but only so far: a tab bar
        // that overflows is worse than one that scales slightly less.
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
            child: Row(
              children: List.generate(_items.length, (i) {
                final isActive = i == activeIndex;
                final item = _items[i];
                final color =
                    isActive ? AppColors.navy : AppColors.secondaryText;

                return Expanded(
                  child: Semantics(
                    button: true,
                    selected: isActive,
                    label: item.label,
                    excludeSemantics: true,
                    child: InkResponse(
                      onTap: () => onTap(i),
                      highlightShape: BoxShape.rectangle,
                      containedInkWell: true,
                      borderRadius: BorderRadius.circular(16),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 56),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedContainer(
                              duration: duration,
                              curve: Curves.easeOut,
                              width: 56,
                              height: 30,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? AppColors.lightLavender
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Icon(
                                isActive ? item.activeIcon : item.inactiveIcon,
                                size: 22,
                                color: isActive ? AppColors.g2 : color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
