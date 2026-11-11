import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/camera_store.dart';
import '../data/saved_camera.dart';
import '../services/camera_setup_link.dart';
import '../services/dentra_cam_client.dart';

/// Whether this build can use the Dentra Cam: the Android and iOS apps.
///
/// The web app is served over HTTPS, and browsers block plain-HTTP pictures
/// from the camera on such a page, so it keeps the phone-camera scan. Reads
/// the real OS rather than `defaultTargetPlatform`, which widget tests set
/// to Android.
final dentraCamAvailableProvider = Provider<bool>(
  (ref) => !kIsWeb && (Platform.isAndroid || Platform.isIOS),
);

final cameraStoreProvider = Provider<CameraStore>((ref) => const CameraStore());

final cameraSetupLinkProvider = Provider<CameraSetupLink>(
  (ref) => UniversalBleSetupLink(isAndroid: !kIsWeb && Platform.isAndroid),
);

/// Makes a client for the camera at an address. Tests swap in fakes.
final camClientFactoryProvider = Provider<DentraCamClient Function(String)>(
  (ref) => DentraCamClient.new,
);

/// The camera this phone was set up with, or null.
class SavedCameraNotifier extends AsyncNotifier<SavedCamera?> {
  @override
  Future<SavedCamera?> build() => ref.read(cameraStoreProvider).loadCamera();

  Future<void> save(SavedCamera camera) async {
    // Let the first load finish, so its answer can't land after this one.
    try {
      await future;
    } catch (_) {
      // Nothing was loaded; this replaces it either way.
    }
    state = AsyncData(camera);
    await ref.read(cameraStoreProvider).saveCamera(camera);
  }
}

final savedCameraProvider =
    AsyncNotifierProvider<SavedCameraNotifier, SavedCamera?>(
  SavedCameraNotifier.new,
);

/// Asks the Scan tab to start a scan, e.g. after "Start capturing" in a
/// setup guide opened from Profile. The Scan tab listens for changes.
class ScanStartRequests extends Notifier<int> {
  @override
  int build() => 0;

  void request() => state++;
}

final scanStartRequestProvider =
    NotifierProvider<ScanStartRequests, int>(ScanStartRequests.new);

/// How this scan's photos are taken, chosen at Start.
enum CaptureChoice { dentraCam, ownCamera }

/// Null until chosen, or when the choice sheet was closed: then a set-up
/// Dentra Cam is used if there is one.
class CaptureChoiceNotifier extends Notifier<CaptureChoice?> {
  @override
  CaptureChoice? build() => null;

  void choose(CaptureChoice? choice) => state = choice;
}

final captureChoiceProvider =
    NotifierProvider<CaptureChoiceNotifier, CaptureChoice?>(
  CaptureChoiceNotifier.new,
);
