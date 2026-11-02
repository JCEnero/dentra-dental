import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// PLACEHOLDER: the project has no DENTRA device driver yet (no Wi-Fi protocol,
/// SDK or image-transfer code), so this reports the device as unsupported
/// instead of pretending to connect.
///
/// To integrate the hardware, implement [DentraDeviceService] and override
/// [dentraDeviceServiceProvider] with it.
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

final dentraDeviceServiceProvider = Provider<DentraDeviceService>(
  (ref) => const UnsupportedDentraDeviceService(),
);
