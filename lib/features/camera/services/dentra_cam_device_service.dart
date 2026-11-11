import 'package:flutter/foundation.dart';

import '../../scan/data/models/captured_image.dart';
import '../../scan/services/dentra_device_service.dart';
import '../data/camera_config.dart';
import '../data/saved_camera.dart';
import 'dentra_cam_client.dart';

/// The Dentra Cam behind the scan's device card and device captures.
///
/// "Connected" means the saved camera answered just now, on the network or
/// through the API. The live camera screen keeps its own, continuous watch
/// on the stream.
class DentraCamDeviceService implements DentraDeviceService {
  DentraCamDeviceService({
    required Future<SavedCamera?> Function() camera,
    required CamClient Function(SavedCamera camera) client,
  })  : _camera = camera,
        _client = client;

  final Future<SavedCamera?> Function() _camera;
  final CamClient Function(SavedCamera camera) _client;

  @override
  bool get isSupported => true;

  @override
  Stream<DeviceLinkEvent> get events => const Stream.empty();

  @override
  Future<void> connect() => _withCamera((client) => client.status());

  @override
  Future<void> disconnect() async {}

  @override
  Future<CapturedImage> capture({ValueChanged<double>? onProgress}) =>
      _withCamera((client) async {
        final bytes = await client.capture(
          size: CameraConfig.captureSize,
          light: CameraConfig.captureWithLight,
        );
        onProgress?.call(1);
        return dentraCamImage(bytes);
      });

  Future<T> _withCamera<T>(Future<T> Function(CamClient) run) async {
    final camera = await _camera();
    if (camera == null) throw const DeviceException(DeviceFailure.notFound);
    final client = _client(camera);
    try {
      return await run(client);
    } on DentraCamException catch (e) {
      throw DeviceException(switch (e.failure) {
        CamFailure.timeout => DeviceFailure.timeout,
        CamFailure.unreachable => DeviceFailure.notFound,
        CamFailure.badResponse => DeviceFailure.transferInterrupted,
      });
    } finally {
      client.close();
    }
  }
}

/// A photo from the Dentra Cam, with how it was taken.
CapturedImage dentraCamImage(Uint8List bytes) => CapturedImage(
      bytes: bytes,
      source: CaptureSource.device,
      capturedAt: DateTime.now(),
      deviceMeta: {
        'camera': 'Dentra Cam',
        'res': CameraConfig.captureSize.label,
        'light': CameraConfig.captureWithLight,
      },
    );
