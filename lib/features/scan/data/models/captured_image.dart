import 'dart:typed_data';

enum CaptureSource { device, phoneCamera, photoLibrary }

/// An image actually received from a capture source. Never synthesized.
class CapturedImage {
  const CapturedImage({
    required this.bytes,
    required this.source,
    required this.capturedAt,
  });

  final Uint8List bytes;
  final CaptureSource source;
  final DateTime capturedAt;
}
