import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../data/models/captured_image.dart';

enum CameraFailure { permissionDenied, unavailable, failed }

class CameraException implements Exception {
  const CameraException(this.failure);
  final CameraFailure failure;

  @override
  String toString() => 'CameraException($failure)';
}

/// Captures with the phone's own camera (or photo library) via
/// `image_picker`, which opens the system camera UI. There is no in-app
/// live preview.
class PhoneCameraService {
  PhoneCameraService([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Whether this platform can open a camera (false on most desktops).
  bool get supportsCamera {
    try {
      return _picker.supportsImageSource(ImageSource.camera);
    } catch (_) {
      return false;
    }
  }

  /// Returns null when the user cancels. Throws [CameraException].
  Future<CapturedImage?> capture(CaptureSource source) async {
    assert(source != CaptureSource.device);
    final XFile? file;
    try {
      file = await _picker.pickImage(
        source: source == CaptureSource.phoneCamera
            ? ImageSource.camera
            : ImageSource.gallery,
        // Plenty for screening, and keeps five images light in memory.
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
        preferredCameraDevice: CameraDevice.rear,
      );
    } on PlatformException catch (e) {
      throw CameraException(switch (e.code) {
        'camera_access_denied' ||
        'photo_access_denied' =>
          CameraFailure.permissionDenied,
        'no_available_camera' => CameraFailure.unavailable,
        _ => CameraFailure.failed,
      });
    } on StateError {
      // Thrown when no camera delegate exists on this platform.
      throw const CameraException(CameraFailure.unavailable);
    } catch (_) {
      throw const CameraException(CameraFailure.failed);
    }
    if (file == null) return null;

    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) throw const CameraException(CameraFailure.failed);
      return CapturedImage(
        bytes: bytes,
        source: source,
        capturedAt: DateTime.now(),
      );
    } on CameraException {
      rethrow;
    } catch (_) {
      throw const CameraException(CameraFailure.failed);
    }
  }
}

final phoneCameraServiceProvider =
    Provider<PhoneCameraService>((ref) => PhoneCameraService());
