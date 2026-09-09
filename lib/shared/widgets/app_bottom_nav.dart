import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

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
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: List.generate(_items.length, (i) {
              final isActive = i == activeIndex;
              final item = _items[i];

              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(
                        vertical: 6, horizontal: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Icon container
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          width: isActive ? 52 : 40,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.lightLavender
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Icon(
                              isActive ? item.activeIcon : item.inactiveIcon,
                              size: 22,
                              color: isActive
                                  ? AppColors.g2
                                  : AppColors.secondaryText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
