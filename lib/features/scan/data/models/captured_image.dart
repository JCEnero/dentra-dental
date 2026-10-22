import 'dart:typed_data';

enum CaptureSource { device, phoneCamera, photoLibrary }

/// An image actually received from a capture source. Never synthesized.
class CapturedImage {
  const CapturedImage({
    required this.bytes,
    required this.source,
    required this.capturedAt,
    this.nirBytes,
    this.deviceMeta,
  });

  final Uint8List bytes;
  final CaptureSource source;
  final DateTime capturedAt;

  /// The DENTRA device's paired ~850 nm NIR frame, taken right after the
  /// photo with the same framing. Null for phone captures.
  final Uint8List? nirBytes;

  /// Flat readings the device reported (exposure, LED current, firmware),
  /// sent with the capture so analysis can account for them.
  final Map<String, Object>? deviceMeta;
}
