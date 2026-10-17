import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_glass.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/models/app_notification.dart';
import '../providers/notifications_provider.dart';
import '../screens/notifications_screen.dart';

/// Frosted-glass bell for page headers. Shows the unread count, opens the
/// notification center, and gives a short swing when a new one arrives.
class NotificationBell extends ConsumerStatefulWidget {
  const NotificationBell({super.key, this.size = 44, this.onOpenProfile});

  final double size;

  /// Called when a notification asks to open account settings.
  final VoidCallback? onOpenProfile;

  @override
  ConsumerState<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<NotificationBell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _swing = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  // Ignores taps while the screen is opening or open.
  bool _opening = false;

  @override
  void dispose() {
    _swing.dispose();
    super.dispose();
  }

  void _ring() {
    if (!mounted || MediaQuery.disableAnimationsOf(context)) return;
    _swing.forward(from: 0);
  }

  Future<void> _open() async {
    if (_opening) return;
    _opening = true;
    final target = await Navigator.of(context, rootNavigator: true)
        .push(NotificationsScreen.route());
    _opening = false;
    if (!mounted) return;
    if (target == NotificationTarget.profile) widget.onOpenProfile?.call();
  }

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(unreadNotificationCountProvider);
    ref.listen<int>(unreadNotificationCountProvider, (prev, next) {
      if (prev != null && next > prev) _ring();
    });

    final size = widget.size;
    return Semantics(
      button: true,
      label: unread == 0 ? 'Notifications' : 'Notifications, $unread unread',
      excludeSemantics: true,
      onTap: _open,
      child: Tooltip(
        message: 'Notifications',
        child: SizedBox.square(
          dimension: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ClipOval(
                child: GlassBlur(
                  child: DecoratedBox(
                    decoration: AppGlass.surface(
                      borderRadius: BorderRadius.circular(size / 2),
                    ),
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        onTap: _open,
                        customBorder: const CircleBorder(),
                        splashColor:
                            AppColors.lightLavender.withValues(alpha: 0.7),
                        highlightColor:
                            AppColors.lightLavender.withValues(alpha: 0.45),
                        child: Center(
                          child: AnimatedBuilder(
                            animation: _swing,
                            builder: (_, child) => Transform.rotate(
                              // Damped swing pivoting from the bell's top.
                              angle: math.sin(_swing.value * math.pi * 4) *
                                  (1 - _swing.value) *
                                  0.35,
                              alignment: Alignment.topCenter,
                              child: child,
                            ),
                            child: AnimatedSwitcher(
                              duration: dentraMotion(context, 180),
                              child: Icon(
                                unread > 0
                                    ? Icons.notifications_rounded
                                    : Icons.notifications_none_rounded,
                                key: ValueKey(unread > 0),
                                size: size * 0.48,
                                color: AppColors.navy,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -2,
                right: -2,
                child: IgnorePointer(
                  child: AnimatedScale(
                    scale: unread > 0 ? 1 : 0,
                    duration: dentraMotion(context, 220),
                    curve: Curves.easeOutBack,
                    child: _Badge(count: unread),
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

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        // Danger red keeps white digits at 4.5:1 contrast.
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.danger.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        textScaler: TextScaler.noScaling,
        style: GoogleFonts.outfit(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.white,
          height: 1,
        ),
      ),
    );
  }
}
