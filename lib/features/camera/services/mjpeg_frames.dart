import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

/// Cuts an MJPEG (multipart/x-mixed-replace) byte stream into JPEG frames.
///
/// Each part's Content-Length is used when it has one; otherwise a frame runs
/// from a JPEG start marker (FF D8) to the next end marker (FF D9).
/// Boundaries and part headers are skipped either way, so the boundary string
/// doesn't matter.
class MjpegFrameSplitter {
  MjpegFrameSplitter({this.maxFrameBytes = 4 * 1024 * 1024});

  /// A frame larger than this means the stream is broken; it's dropped.
  final int maxFrameBytes;

  /// Part headers are short, so this much text before a frame is junk.
  static const int _maxHeaderBytes = 8 * 1024;

  static final RegExp _contentLength =
      RegExp(r'content-length:\s*(\d+)', caseSensitive: false);

  Uint8List _buf = Uint8List(64 * 1024);
  int _len = 0;

  /// Start of the frame being read, or -1 while looking for one.
  int _start = -1;

  /// The Content-Length of the frame being read, when its part had one.
  int? _expected;

  /// Where the next marker search resumes.
  int _scan = 0;

  /// Adds bytes from the stream and returns the frames they completed.
  List<Uint8List> add(List<int> chunk) {
    _append(chunk);
    final frames = <Uint8List>[];
    while (true) {
      if (_start < 0) {
        final soi = _find(0xD8, _scan);
        if (soi < 0) {
          if (_len > _maxHeaderBytes) {
            // Keep the last byte: it may be the first half of a marker.
            _drop(_len - 1);
            _scan = 0;
          } else {
            _scan = math.max(0, _len - 1);
          }
          break;
        }
        _expected = _lengthBefore(soi);
        _start = soi;
        _scan = soi + 2;
      }

      final int end;
      final expected = _expected;
      if (expected != null) {
        if (_len - _start < expected) break;
        end = _start + expected;
      } else {
        final eoi = _find(0xD9, _scan);
        if (eoi < 0) {
          if (_len - _start > maxFrameBytes) {
            _reset();
          } else {
            _scan = math.max(_start + 2, _len - 1);
          }
          break;
        }
        end = eoi + 2;
      }

      frames.add(Uint8List.fromList(Uint8List.sublistView(_buf, _start, end)));
      _drop(end);
      _start = -1;
      _expected = null;
      _scan = 0;
    }
    return frames;
  }

  /// Index of 0xFF followed by [marker], from [from] on, or -1.
  int _find(int marker, int from) {
    for (var i = from; i < _len - 1; i++) {
      if (_buf[i] == 0xFF && _buf[i + 1] == marker) return i;
    }
    return -1;
  }

  /// The Content-Length in the part headers just before [soi], if any.
  int? _lengthBefore(int soi) {
    final header = latin1.decode(
      Uint8List.sublistView(_buf, math.max(0, soi - 512), soi),
    );
    final match = _contentLength.allMatches(header).lastOrNull;
    final length = match == null ? null : int.tryParse(match.group(1)!);
    return length != null && length > 2 && length <= maxFrameBytes
        ? length
        : null;
  }

  void _append(List<int> chunk) {
    final needed = _len + chunk.length;
    if (needed > _buf.length) {
      var size = _buf.length * 2;
      while (size < needed) {
        size *= 2;
      }
      _buf = Uint8List(size)..setRange(0, _len, _buf);
    }
    _buf.setRange(_len, needed, chunk);
    _len = needed;
  }

  /// Forgets the first [count] bytes.
  void _drop(int count) {
    _buf.setRange(0, _len - count, _buf, count);
    _len -= count;
  }

  void _reset() {
    _len = 0;
    _start = -1;
    _expected = null;
    _scan = 0;
  }
}

/// Whether [bytes] look like a JPEG: the start marker and some data.
bool looksLikeJpeg(List<int> bytes) =>
    bytes.length > 100 && bytes[0] == 0xFF && bytes[1] == 0xD8;
