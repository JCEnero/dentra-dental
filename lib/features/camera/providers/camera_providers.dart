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
  /// Legacy cameras reached directly on home Wi-Fi.
  local,

  /// Account-owned cameras reached through the HTTPS relay on every build.
  cloud,
}

/// Account-linked setup uses the backend on every platform. Without it, native
/// builds can still use a previously saved local camera. Reads the OS rather than
/// `defaultTargetPlatform`, which widget tests set to Android.
final camLinkProvider = Provider<CamLink?>((ref) {
  // Provisioning links every platform to the same account-owned camera.
  if (ref.watch(apiClientProvider) != null) return CamLink.cloud;
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
final cloudCamClientFactoryProvider =
    Provider<CamClient Function(String)>((ref) {
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
  return (camera) =>
      camera.cloudId != null ? cloud(camera.cloudId!) : local(camera.host!);
});

/// All cameras owned by this account, including offline cameras that need
/// removing after a full flash erase. Reloads when the account changes.
final cloudCamerasProvider = FutureProvider<List<CloudCamera>>((ref) async {
  ref.watch(authServiceProvider.select((a) => a.currentUserId));
  final api = ref.watch(cloudCamApiProvider);
  if (api == null) return const [];
  return api.cameras();
});

/// The camera this phone was set up with, or on the website the one linked
/// to the signed-in account. Null when there's none.
class SavedCameraNotifier extends AsyncNotifier<SavedCamera?> {
  String? _selectedCloudId;

  @override
  Future<SavedCamera?> build() async {
    if (ref.watch(camLinkProvider) != CamLink.cloud) {
      return ref.read(cameraStoreProvider).loadCamera();
    }
    final cameras = await ref.watch(cloudCamerasProvider.future);
    final selected =
        cameras.where((camera) => camera.id == _selectedCloudId).firstOrNull ??
            cameras.firstOrNull;
    _selectedCloudId = selected?.id;
    if (selected == null && !kIsWeb) {
      return ref.read(cameraStoreProvider).loadCamera();
    }
    return selected?.toSaved();
  }

  Future<void> save(SavedCamera camera) async {
    // Let the first load finish, so its answer can't land after this one.
    try {
      await future;
    } catch (_) {
      // Nothing was loaded; this replaces it either way.
    }
    _selectedCloudId = camera.cloudId;
    state = AsyncData(camera);
    // The website's cameras live on the account, not in the browser.
    if (camera.host != null) {
      await ref.read(cameraStoreProvider).saveCamera(camera);
    } else {
      ref.invalidate(cloudCamerasProvider);
    }
  }

  Future<void> remove(SavedCamera camera) async {
    final id = camera.cloudId;
    if (id != null) {
      final api = ref.read(cloudCamApiProvider);
      if (api == null) throw StateError('Camera API unavailable');
      await api.removeCamera(id);
      // Also rebuilds this provider, selecting another owned camera, if any.
      ref.invalidate(cloudCamerasProvider);
    } else {
      await future;
      await ref.read(cameraStoreProvider).removeCamera();
      state = const AsyncData(null);
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
