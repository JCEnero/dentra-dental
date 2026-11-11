import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../camera/providers/camera_providers.dart';
import '../../camera/services/dentra_cam_device_service.dart';
import '../data/models/captured_image.dart';

/// Link state reported by the device driver after `connect` succeeds.
enum DeviceLinkEvent { connected, reconnecting, disconnected }

enum DeviceFailure {
  /// Device support is not available in this build.
  unsupported,
  notFound,
  timeout,
  connectionLost,
  transferInterrupted,
  unknown,
}

class DeviceException implements Exception {
  const DeviceException(this.failure);
  final DeviceFailure failure;

  @override
  String toString() => 'DeviceException($failure)';
}

/// Contract for the DENTRA intraoral imaging device.
///
/// The scan UI only reflects what an implementation reports: it shows
/// "connected" after [connect] completes, and images only after [capture]
/// returns real bytes.
abstract class DentraDeviceService {
  /// False when this build has no driver for the device.
  bool get isSupported;

  /// Link changes after a successful [connect] (drops, auto-reconnects).
  Stream<DeviceLinkEvent> get events;

  /// Completes once the device is connected. Throws [DeviceException].
  Future<void> connect();

  Future<void> disconnect();

  /// Captures one image on the device and transfers it to the phone,
  /// reporting transfer progress from 0 to 1 when known.
  Future<CapturedImage> capture({ValueChanged<double>? onProgress});
}

/// For builds that can't reach the device (the web app), so the scan says so
/// instead of pretending to connect.
class UnsupportedDentraDeviceService implements DentraDeviceService {
  const UnsupportedDentraDeviceService();

  @override
  bool get isSupported => false;

  @override
  Stream<DeviceLinkEvent> get events => const Stream.empty();

  @override
  Future<void> connect() async =>
      throw const DeviceException(DeviceFailure.unsupported);

  @override
  Future<void> disconnect() async {}

  @override
  Future<CapturedImage> capture({ValueChanged<double>? onProgress}) async =>
      throw const DeviceException(DeviceFailure.unsupported);
}

/// The Dentra Cam over Wi-Fi in the phone apps (see
/// `camera/data/camera_protocol.dart`); unsupported elsewhere.
final dentraDeviceServiceProvider = Provider<DentraDeviceService>((ref) {
  if (!ref.watch(dentraCamAvailableProvider)) {
    return const UnsupportedDentraDeviceService();
  }
  return DentraCamDeviceService(
    camera: () => ref.read(savedCameraProvider.future),
    client: ref.watch(camClientFactoryProvider),
  );
});
