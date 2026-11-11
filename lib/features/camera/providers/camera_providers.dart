import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/api_config.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/camera_store.dart';
import '../data/saved_camera.dart';
import '../services/camera_setup_link.dart';
import '../services/cloud_cam_api.dart';
import '../services/cloud_cam_client.dart';
import '../services/dentra_cam_client.dart';

/// How this build reaches the Dentra Cam.
enum CamLink {
  /// On the home Wi-Fi, set up over Bluetooth: the Android and iOS apps.
  local,

  /// Through the DENTRA API, set up with the camera's own hotspot: the
  /// website. A web page is HTTPS, so browsers block the camera's
  /// plain-HTTP pictures, and iPhone browsers have no Bluetooth.
  cloud,
}

/// Null where the camera can't be used: the website without a backend,
/// and desktop builds. Reads the real OS rather than
/// `defaultTargetPlatform`, which widget tests set to Android.
final camLinkProvider = Provider<CamLink?>((ref) {
  if (kIsWeb) {
    return ref.watch(apiClientProvider) == null ? null : CamLink.cloud;
  }
  return Platform.isAndroid || Platform.isIOS ? CamLink.local : null;
});

/// Whether this build can use the Dentra Cam at all.
final dentraCamAvailableProvider = Provider<bool>(
  (ref) => ref.watch(camLinkProvider) != null,
);

/// The API's Dentra Cam endpoints; null without a backend.
final cloudCamApiProvider = Provider<CloudCamApi?>((ref) {
  final api = ref.watch(apiClientProvider);
  return api == null ? null : CloudCamApi(api);
});

final cameraStoreProvider = Provider<CameraStore>((ref) => const CameraStore());

final cameraSetupLinkProvider = Provider<CameraSetupLink>(
  (ref) => UniversalBleSetupLink(isAndroid: !kIsWeb && Platform.isAndroid),
);

/// Makes a client for the camera at an address. Tests swap in fakes.
final camClientFactoryProvider = Provider<DentraCamClient Function(String)>(
  (ref) => DentraCamClient.new,
);

/// Makes a client for a camera linked to the account, through the API.
final cloudCamClientFactoryProvider = Provider<CamClient Function(String)>((ref) {
  final baseUrl = ApiConfig.baseUrl;
  return (deviceId) => CloudCamClient(
        deviceId: deviceId,
        socketUri: cloudCamSocketUri(baseUrl ?? ''),
        // Read when the link opens, so it's always the current session.
        accessToken: () => ref.read(authServiceProvider).validAccessToken(),
      );
});

/// A client for [SavedCamera], whichever way it's reached.
final cameraClientProvider = Provider<CamClient Function(SavedCamera)>((ref) {
  final local = ref.watch(camClientFactoryProvider);
  final cloud = ref.watch(cloudCamClientFactoryProvider);
  return (camera) => camera.cloudId != null
      ? cloud(camera.cloudId!)
      : local(camera.host!);
});

/// The camera this phone was set up with, or on the website the one linked
/// to the signed-in account. Null when there's none.
class SavedCameraNotifier extends AsyncNotifier<SavedCamera?> {
  @override
  Future<SavedCamera?> build() async {
    if (ref.watch(camLinkProvider) != CamLink.cloud) {
      return ref.read(cameraStoreProvider).loadCamera();
    }
    // Another account signing in on this page has other cameras.
    ref.watch(authServiceProvider.select((a) => a.currentUserId));
    final api = ref.watch(cloudCamApiProvider);
    if (api == null) return null;
    final cameras = await api.cameras();
    return cameras.isEmpty ? null : cameras.first.toSaved();
  }

  Future<void> save(SavedCamera camera) async {
    // Let the first load finish, so its answer can't land after this one.
    try {
      await future;
    } catch (_) {
      // Nothing was loaded; this replaces it either way.
    }
    state = AsyncData(camera);
    // The website's cameras live on the account, not in the browser.
    if (camera.host != null) {
      await ref.read(cameraStoreProvider).saveCamera(camera);
    }
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
