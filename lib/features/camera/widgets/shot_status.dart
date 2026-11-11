import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../scan/widgets/scan_theme.dart';
import '../camera_strings.dart';
import '../state/guided_capture_controller.dart';

/// How an area's photo check reads: icon, words and a colour from the teal
/// ramp (deeper means it needs you more). Null for an area not done yet.
({IconData icon, String label, Color color})? shotStatus(
  AreaShot? shot, {
  bool skipped = false,
}) {
  if (shot == null) {
    return skipped
        ? (
            icon: Icons.skip_next_rounded,
            label: CamText.checkSkipped,
            color: ScanColors.muted,
          )
        : null;
  }
  return switch (shot.check) {
    ShotCheck.checking => (
        icon: Icons.hourglass_top_rounded,
        label: CamText.checking,
        color: AppColors.primary,
      ),
    ShotCheck.passed => (
        icon: Icons.check_circle_rounded,
        label: CamText.checkPassed,
        color: ScanColors.clearInk,
      ),
    ShotCheck.rejected => (
        icon: Icons.replay_circle_filled_rounded,
        label: CamText.checkRejected,
        color: AppColors.navy,
      ),
    ShotCheck.error => (
        icon: Icons.sync_problem_rounded,
        label: CamText.checkError,
        color: AppColors.secondaryText,
      ),
  };
}

/// The status as a small badge on a white disc; a spinner while checking.
class ShotBadge extends StatelessWidget {
  const ShotBadge({super.key, required this.shot, this.size = 20});

  final AreaShot shot;
  final double size;

  @override
  Widget build(BuildContext context) {
    final status = shotStatus(shot)!;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.12),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.12),
            blurRadius: 4,
          ),
        ],
      ),
      child: shot.check == ShotCheck.checking
          ? const CircularProgressIndicator(
              strokeWidth: 1.8,
              color: AppColors.primary,
            )
          : FittedBox(child: Icon(status.icon, color: status.color)),
    );
  }
}
