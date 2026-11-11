import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/camera_providers.dart';
import 'screens/camera_setup_screen.dart';
import 'screens/hotspot_setup_screen.dart';
import 'screens/live_capture_screen.dart';

export 'screens/camera_setup_screen.dart' show SetupOutcome;

// Ways into the Dentra Cam screens, for the Scan tab, Profile and the live
// camera itself.

/// Opens the setup guide over everything: over Bluetooth in the phone apps,
/// through the camera's hotspot on the website. Resolves to what the user
/// chose at the end, or null when they closed it before the camera was
/// saved.
Future<SetupOutcome?> openCameraSetup(BuildContext context) {
  final cloud = ProviderScope.containerOf(context, listen: false)
          .read(camLinkProvider) ==
      CamLink.cloud;
  return Navigator.of(context, rootNavigator: true).push(
    cloud ? HotspotSetupScreen.route() : CameraSetupScreen.route(),
  );
}

/// Opens the live camera for the scan in progress, starting at [startAt].
/// Its photos join the scan as the photo check passes them. Resolves to true
/// when the user chose Save & analyze.
Future<bool> openLiveCapture(
  BuildContext context,
  WidgetRef ref, {
  String? startAt,
}) async {
  final camera = await ref.read(savedCameraProvider.future);
  if (camera == null || !context.mounted) return false;
  final store = ref.read(cameraStoreProvider);
  final settings = await store.loadSettings();
  final tipsHidden = await store.tipsHidden();
  if (!context.mounted) return false;
  final save = await Navigator.of(context, rootNavigator: true).push(
    LiveCaptureScreen.route(
      camera: camera,
      settings: settings,
      showTips: !tipsHidden,
      startAt: startAt,
    ),
  );
  return save ?? false;
}
