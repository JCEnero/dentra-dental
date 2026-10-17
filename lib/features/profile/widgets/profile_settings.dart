import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_glass.dart';
import '../../../shared/widgets/glass_card.dart';

/// A titled glass card holding a list of settings rows, separated by
/// hairlines.
class ProfileSettingsGroup extends StatelessWidget {
  const ProfileSettingsGroup({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Semantics(
            header: true,
            child: Text(
              title.toUpperCase(),
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: AppColors.secondaryText,
              ),
            ),
          ),
        ),
        GlassCard(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    // Lines up with the text, past the icon tile.
                    indent: 70,
                    color: AppGlass.divider,
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Rounded icon tile at the start of a settings row.
class ProfileIconTile extends StatelessWidget {
  const ProfileIconTile({
    super.key,
    required this.icon,
    this.color = AppColors.primary,
  });

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}

/// Tappable settings row: icon, title, optional subtitle and a trailing
/// chevron (or a custom [trailing] widget).
class ProfileSettingsTile extends StatelessWidget {
  const ProfileSettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.destructive = false,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool destructive;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final accent = destructive ? AppColors.danger : AppColors.primary;
    final titleColor = destructive ? AppColors.danger : AppColors.navy;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.lightLavender.withValues(alpha: 0.7),
        highlightColor: AppColors.lightLavender.withValues(alpha: 0.45),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: [
                ProfileIconTile(icon: icon, color: accent),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: titleColor,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: AppColors.secondaryText,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (trailing != null)
                  trailing!
                else if (showChevron && onTap != null)
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: destructive
                        ? AppColors.danger
                        : AppColors.secondaryText.withValues(alpha: 0.8),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Settings row with a switch. While [busy] the switch is replaced by a
/// spinner and taps are ignored, so a pending save cannot be doubled.
class ProfileSwitchTile extends StatelessWidget {
  const ProfileSwitchTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.busy = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null && !busy;

    return MergeSemantics(
      child: ProfileSettingsTile(
        icon: icon,
        title: title,
        subtitle: subtitle,
        showChevron: false,
        onTap: enabled ? () => onChanged!(!value) : null,
        trailing: SizedBox(
          width: 56,
          height: 40,
          child: Center(
            child: busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : Switch(
                    value: value,
                    onChanged: enabled ? onChanged : null,
                    activeThumbColor: AppColors.white,
                    activeTrackColor: AppColors.g2,
                    inactiveThumbColor: AppColors.white,
                    inactiveTrackColor:
                        AppColors.secondaryText.withValues(alpha: 0.25),
                    trackOutlineColor:
                        WidgetStateProperty.all(Colors.transparent),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Groups rows inside a glass sheet in one white card with hairline dividers.
class ProfileSheetCard extends StatelessWidget {
  const ProfileSheetCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.g2.withValues(alpha: 0.12)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  indent: 70,
                  color: AppColors.g2.withValues(alpha: 0.12),
                ),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}
