import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../shared/widgets/dentra_glass_ui.dart';

/// Copy for when the settings page can't be opened (e.g. on web).
const deviceSettingsUnavailable =
    "Couldn't open settings. Open your device settings and find Dentra.";

/// Opens this app's page in the system settings, where camera, photo and
/// location access are managed. Returns false when that isn't possible.
///
/// With [notify] it explains the failure in a snackbar. Pass false from
/// inside a sheet, where a snackbar would be hidden, and show it inline.
Future<bool> openDeviceSettings(
  BuildContext context, {
  bool notify = true,
}) async {
  var opened = false;
  try {
    opened = await Geolocator.openAppSettings();
  } catch (_) {
    opened = false;
  }
  if (!opened && notify && context.mounted) {
    showDentraSnack(
      context,
      deviceSettingsUnavailable,
      tone: DentraFeedbackTone.error,
    );
  }
  return opened;
}
