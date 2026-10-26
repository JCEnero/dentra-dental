
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../utils/device_settings.dart';
import 'profile_settings.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';

/// What the user decided in [chooseAvatar].
sealed class AvatarChoice {
  const AvatarChoice();
}

class AvatarPicked extends AvatarChoice {
  const AvatarPicked(this.bytes);
  final Uint8List bytes;
}

class AvatarRemoved extends AvatarChoice {
  const AvatarRemoved();
}

enum _AvatarAction { camera, gallery, remove }

/// Walks the user through changing their profile photo: choose a source,
/// pick an image, then confirm it in a preview. Resolves to null if they
/// cancel at any step.
Future<AvatarChoice?> chooseAvatar(
  BuildContext context, {
  required bool hasPhoto,
  ImagePicker? picker,
}) async {
  final action = await showGlassSheet<_AvatarAction>(
    context: context,
    title: 'Profile photo',
    subtitle: 'Choose a clear photo of your face. It is only shown to you '
        'and the clinics you connect with.',
    builder: (sheetContext) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProfileSheetCard(
          children: [
            // Web browsers handle camera capture inconsistently; the
            // library picker covers both there.
            if (!kIsWeb)
              ProfileSettingsTile(
                icon: Icons.photo_camera_outlined,
                title: 'Take a photo',
                onTap: () =>
                    Navigator.of(sheetContext).pop(_AvatarAction.camera),
              ),
            ProfileSettingsTile(
              icon: Icons.photo_library_outlined,
              title: kIsWeb ? 'Upload a photo' : 'Choose from library',
              onTap: () =>
                  Navigator.of(sheetContext).pop(_AvatarAction.gallery),
            ),
            if (hasPhoto)
              ProfileSettingsTile(
                icon: Icons.delete_outline_rounded,
                title: 'Remove photo',
                destructive: true,
                onTap: () =>
                    Navigator.of(sheetContext).pop(_AvatarAction.remove),
              ),
          ],
        ),
      ],
    ),
  );
  if (action == null || !context.mounted) return null;

  if (action == _AvatarAction.remove) {
    final confirmed = await showGlassConfirmDialog(
      context: context,
      icon: Icons.no_photography_outlined,
      title: 'Remove photo?',
      message: 'Your initials will be shown instead.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    return confirmed ? const AvatarRemoved() : null;
  }

  final source = action == _AvatarAction.camera
      ? ImageSource.camera
      : ImageSource.gallery;
  Uint8List bytes;
  try {
    final picked = await (picker ?? ImagePicker()).pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 512,
      maxHeight: 512,
      preferredCameraDevice: CameraDevice.front,
    );
    if (picked == null) return null; // User backed out of the picker.
    bytes = await picked.readAsBytes();
  } on PlatformException catch (e) {
    if (!context.mounted) return null;
    final denied = e.code.contains('access_denied');
    final what = source == ImageSource.camera ? 'camera' : 'photos';
    showDentraSnack(
      context,
      denied
          ? 'DENTRA needs access to your $what. Allow it in Settings.'
          : "Couldn't open your $what. Please try again.",
      tone: DentraFeedbackTone.error,
      retryLabel: 'Settings',
      onRetry: denied ? () => openDeviceSettings(context) : null,
    );
    return null;
  } catch (_) {
    if (context.mounted) {
      showDentraSnack(
        context,
        "Couldn't load that image. Try a different photo.",
        tone: DentraFeedbackTone.error,
      );
    }
    return null;
  }

  if (!context.mounted) return null;
  final confirmed = await showGlassDialog<bool>(
    context: context,
    builder: (dialogContext) => GlassDialogFrame(
      icon: Icons.account_circle_outlined,
      title: 'Use this photo?',
      message: 'This is how your photo will appear on your profile.',
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
            ),
            child: AvatarWidget(size: 132, imageBytes: bytes),
          ),
        ),
        const SizedBox(height: 24),
        DentraButtonRow(
          secondary: DentraPillButton(
            label: 'Cancel',
            variant: DentraButtonVariant.outline,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          primary: DentraPillButton(
            label: 'Use photo',
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ),
      ],
    ),
  );
  return confirmed == true ? AvatarPicked(bytes) : null;
}
