import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_glass.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/models/user_profile.dart';
import '../../../core/utils/dentra_dates.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';

/// Identity card at the top of the profile: photo, name, email, an edit
/// button and a short screening summary.
class ProfileHeaderCard extends StatelessWidget {
  const ProfileHeaderCard({
    super.key,
    required this.profile,
    required this.onAvatarTap,
    required this.onEdit,
    required this.onViewHistory,
    required this.screeningCount,
    this.lastScreening,
    this.avatarBusy = false,
  });

  final UserProfile profile;
  final VoidCallback onAvatarTap;
  final VoidCallback onEdit;
  final VoidCallback onViewHistory;
  final int? screeningCount;
  final DateTime? lastScreening;
  final bool avatarBusy;

  @override
  Widget build(BuildContext context) {
    final hasName = profile.fullName.trim().isNotEmpty;

    return GlassCard(
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Column(
        children: [
          _EditableAvatar(
            profile: profile,
            busy: avatarBusy,
            onTap: onAvatarTap,
          ),
          const SizedBox(height: 14),
          Text(
            hasName ? profile.fullName : 'Add your name',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: hasName ? AppColors.navy : AppColors.secondaryText,
            ),
          ),
          if (profile.email.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              profile.email,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: AppColors.secondaryText,
              ),
            ),
          ],
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 160),
            child: IntrinsicWidth(
              child: DentraPillButton(
                label: 'Edit profile',
                icon: Icons.edit_outlined,
                variant: DentraButtonVariant.outline,
                onPressed: onEdit,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Divider(height: 1, thickness: 1, color: AppGlass.divider),
          _ScreeningSummary(
            count: screeningCount,
            last: lastScreening,
            onTap: onViewHistory,
          ),
        ],
      ),
    );
  }
}

class _EditableAvatar extends StatelessWidget {
  const _EditableAvatar({
    required this.profile,
    required this.busy,
    required this.onTap,
  });

  final UserProfile profile;
  final bool busy;
  final VoidCallback onTap;

  static const double _size = 96;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: profile.avatarBytes == null
          ? 'Add profile photo'
          : 'Change profile photo',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: busy ? null : onTap,
        child: SizedBox(
          width: _size + 8,
          height: _size + 8,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Gradient ring with a white gap, so the photo reads as a
              // separate layer on the glass.
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.cardGradient,
                ),
                child: Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.white,
                  ),
                  child: AnimatedSwitcher(
                    duration: dentraMotion(context, 260),
                    child: AvatarWidget(
                      key: ValueKey(profile.avatarBytes?.length ?? profile.initials),
                      size: _size - 2,
                      initials: profile.initials,
                      imageBytes: profile.avatarBytes,
                    ),
                  ),
                ),
              ),
              if (busy)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.white.withValues(alpha: 0.6),
                    ),
                    child: const Center(
                      child: SizedBox.square(
                        dimension: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: 0,
                bottom: 2,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.cardSolid, AppColors.g2],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.g2.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.photo_camera_rounded,
                    size: 16,
                    color: AppColors.white,
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

class _ScreeningSummary extends StatelessWidget {
  const _ScreeningSummary({
    required this.count,
    required this.last,
    required this.onTap,
  });

  /// Null while history is still loading.
  final int? count;
  final DateTime? last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Screening history. '
          '${count ?? 'Loading'} screenings. '
          '${last != null ? 'Last on ${DentraDates.medium(last!)}' : ''}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          child: Row(
            children: [
              Expanded(
                child: _Stat(
                  value: count?.toString() ?? '–',
                  label: count == 1 ? 'Screening' : 'Screenings',
                ),
              ),
              Container(width: 1, height: 32, color: AppGlass.divider),
              Expanded(
                child: _Stat(
                  value: last != null ? DentraDates.medium(last!) : 'None yet',
                  label: 'Last screening',
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: AppColors.secondaryText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: AppColors.secondaryText,
          ),
        ),
      ],
    );
  }
}
