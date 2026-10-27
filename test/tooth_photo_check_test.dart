import 'dart:typed_data';

import 'package:dentra_mobile/features/scan/services/tooth_photo_check.dart';
import 'package:flutter_test/flutter_test.dart';

const _w = 96, _h = 72;

/// A [_w]×[_h] RGBA image painted by [color] per pixel.
Uint8List _image((int, int, int) Function(int x, int y) color) {
  final px = Uint8List(_w * _h * 4);
  for (var y = 0; y < _h; y++) {
    for (var x = 0; x < _w; x++) {
      final (r, g, b) = color(x, y);
      final i = (y * _w + x) * 4;
      px
        ..[i] = r
        ..[i + 1] = g
        ..[i + 2] = b
        ..[i + 3] = 255;
    }
  }
  return px;
}

const _gum = (196, 72, 92);
const _tooth = (238, 230, 206);

void main() {
  test('accepts a row of teeth framed by gums', () {
    final mouth = _image((x, y) {
      final inRow = y > 24 && y < 48;
      final onTooth = x % 12 > 1; // thin gaps between teeth
      return inRow && onTooth ? _tooth : _gum;
    });
    expect(ToothPhotoCheck.evaluate(mouth, _w, _h), isTrue);
  });

  test('rejects a landscape', () {
    final landscape =
        _image((x, y) => y < _h / 2 ? (120, 170, 230) : (60, 140, 50));
    expect(ToothPhotoCheck.evaluate(landscape, _w, _h), isFalse);
  });

  test('rejects a blank white sheet', () {
    final sheet = _image((_, __) => (245, 245, 242));
    expect(ToothPhotoCheck.evaluate(sheet, _w, _h), isFalse);
  });

  test('rejects a plain pink image (gums or lips only, no teeth)', () {
    final pink = _image((_, __) => _gum);
    expect(ToothPhotoCheck.evaluate(pink, _w, _h), isFalse);
  });

  test('rejects plain gray, dark to light', () {
    for (final v in [80, 128, 190]) {
      final gray = _image((_, __) => (v, v, v));
      expect(ToothPhotoCheck.evaluate(gray, _w, _h), isFalse, reason: 'gray $v');
    }
  });

  test('rejects a face whose mouth is too small to check', () {
    // A selfie from arm's length: mostly skin, a few pixels of teeth.
    final face = _image((x, y) {
      final dx = (x - 48).abs(), dy = (y - 50).abs();
      if (dx < 10 && dy < 3) return _tooth;
      if (dx < 14 && dy < 6) return _gum;
      return (224, 172, 140); // skin
    });
    expect(ToothPhotoCheck.evaluate(face, _w, _h), isFalse);
  });

  // Known limit of a color heuristic: anything bright beside something
  // pink passes. Kept as a test so a tuning change that alters it is seen.
  test('accepts a white and pink split (known false positive)', () {
    final split = _image((x, _) => x < _w / 2 ? (245, 245, 242) : _gum);
    expect(ToothPhotoCheck.evaluate(split, _w, _h), isTrue);
  });

  test('rejects white on a non-mouth background', () {
    // White text on a blue sign: tooth-white, but no gum or lip tissue.
    final sign = _image(
        (x, y) => (y ~/ 6).isEven && x % 8 < 5 ? _tooth : (30, 70, 160));
    expect(ToothPhotoCheck.evaluate(sign, _w, _h), isFalse);
  });
}
