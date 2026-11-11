import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../scan/widgets/scan_theme.dart';
import '../camera_strings.dart';
import '../providers/camera_providers.dart';

/// Asks at Start whether this scan uses the Dentra Cam or the user's own
/// camera. Null when closed without choosing.
///
/// [camAvailable] is false on the website, where the Dentra Cam can't
/// connect: it's still listed, so people know it exists, but can't be
/// chosen. [cameraName] is the set-up camera, if any. [canUseCamera] is
/// false where there's no camera to open, so photos are chosen instead.
Future<CaptureChoice?> showCaptureChoice(
  BuildContext context, {
  required bool camAvailable,
  String? cameraName,
  bool canUseCamera = true,
}) {
  return showGlassSheet<CaptureChoice>(
    context: context,
    title: CamText.choiceTitle,
    subtitle: CamText.choiceSubtitle,
    builder: (sheet) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChoiceRow(
          icon: Icons.videocam_outlined,
          title: CamText.choiceCam,
          body: camAvailable
              ? CamText.choiceCamBody(cameraName)
              : CamText.choiceCamAppOnly,
          onTap: camAvailable
              ? () => Navigator.of(sheet).pop(CaptureChoice.dentraCam)
              : null,
        ),
        const SizedBox(height: 10),
        _ChoiceRow(
          icon: canUseCamera
              ? Icons.photo_camera_outlined
              : Icons.photo_library_outlined,
          title: CamText.choiceOwn,
          body: canUseCamera ? CamText.choiceOwnBody : CamText.choiceOwnPhotos,
          onTap: () => Navigator.of(sheet).pop(CaptureChoice.ownCamera),
        ),
        const SizedBox(height: 8),
      ],
    ),
  );
}

/// One option as a glass row. Without [onTap] it's shown but can't be
/// chosen, and says why in [body].
class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.icon,
    required this.title,
    required this.body,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: '$title. $body',
      excludeSemantics: true,
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : 0.6,
        child: GlassCard(
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          onTap: onTap,
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              ScanIconDisc(icon, size: 42, iconSize: 21),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        color: AppColors.secondaryText,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (enabled)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.secondaryText,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
