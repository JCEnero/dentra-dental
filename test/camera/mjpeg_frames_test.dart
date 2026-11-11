import 'dart:convert';
import 'dart:typed_data';

import 'package:dentra_mobile/features/camera/services/mjpeg_frames.dart';
import 'package:flutter_test/flutter_test.dart';

const _boundary = '123456789000000000000987654321';

/// A fake JPEG: start marker, [body] bytes (no markers inside), end marker.
Uint8List jpeg(int body, {int fill = 0x11}) => Uint8List.fromList([
      0xFF, 0xD8, //
      ...List.filled(body, fill),
      0xFF, 0xD9,
    ]);

/// One multipart part as the camera's stream handler writes it.
List<int> part(Uint8List frame, {bool withLength = true}) => [
      ...latin1.encode('\r\n--$_boundary\r\n'),
      ...latin1.encode('Content-Type: image/jpeg\r\n'),
      if (withLength) ...latin1.encode('Content-Length: ${frame.length}\r\n'),
      ...latin1.encode('\r\n'),
      ...frame,
    ];

void main() {
  test('reads whole frames by their Content-Length', () {
    final a = jpeg(300), b = jpeg(500, fill: 0x22);
    final frames = MjpegFrameSplitter().add([...part(a), ...part(b)]);
    expect(frames, [a, b]);
  });

  test('frames split across many small chunks come out whole', () {
    final a = jpeg(1000), b = jpeg(10, fill: 0x33);
    final bytes = [...part(a), ...part(b)];
    final splitter = MjpegFrameSplitter();
    final frames = <Uint8List>[];
    for (var i = 0; i < bytes.length; i += 7) {
      frames.addAll(splitter.add(bytes.sublist(i, (i + 7).clamp(0, bytes.length))));
    }
    expect(frames, [a, b]);
  });

  test('without a Content-Length, a frame ends at the JPEG end marker', () {
    final a = jpeg(64), b = jpeg(80, fill: 0x44);
    final bytes = [...part(a, withLength: false), ...part(b, withLength: false)];
    final splitter = MjpegFrameSplitter();
    final frames = <Uint8List>[];
    // One byte at a time, so markers split across chunks too.
    for (final byte in bytes) {
      frames.addAll(splitter.add([byte]));
    }
    expect(frames, [a, b]);
  });

  test('waits for the rest of a frame before handing it over', () {
    final a = jpeg(400);
    final bytes = part(a);
    final splitter = MjpegFrameSplitter();
    expect(splitter.add(bytes.sublist(0, bytes.length - 1)), isEmpty);
    expect(splitter.add(bytes.sublist(bytes.length - 1)), [a]);
  });

  test('junk before the first frame is skipped', () {
    final a = jpeg(50);
    final frames = MjpegFrameSplitter().add([
      ...latin1.encode('HTTP noise that is not a frame\r\n'),
      ...part(a),
    ]);
    expect(frames, [a]);
  });

  test('a frame bigger than the limit is dropped, and the stream recovers', () {
    final splitter = MjpegFrameSplitter(maxFrameBytes: 1000);
    // No length and no end marker: runs past the limit.
    expect(splitter.add([0xFF, 0xD8, ...List.filled(1500, 0x11)]), isEmpty);
    final a = jpeg(100);
    expect(splitter.add(part(a)), [a]);
  });

  test('looksLikeJpeg wants the start marker and some data', () {
    expect(looksLikeJpeg(jpeg(200)), isTrue);
    expect(looksLikeJpeg(jpeg(10)), isFalse);
    expect(looksLikeJpeg(Uint8List.fromList(List.filled(200, 0))), isFalse);
  });
}
