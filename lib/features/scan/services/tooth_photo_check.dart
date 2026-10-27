import 'dart:typed_data';
import 'dart:ui' as ui;

/// On-device check that a photo plausibly shows teeth before it's used in
/// a scan. A color heuristic, not a trained model: it looks for
/// tooth-white areas sitting next to gum, lip or tongue pink. That's
/// enough to turn away landscapes, walls, documents and most selfies.
///
/// Fails open: a photo that can't be decoded passes, so a codec quirk on
/// one platform never blocks a real scan.
class ToothPhotoCheck {
  const ToothPhotoCheck._();

  /// Width the photo is shrunk to before checking. Small enough to be
  /// instant, large enough to see a row of teeth.
  static const int _sampleWidth = 96;

  /// How far (in sample pixels) a tooth pixel may be from soft tissue.
  static const int _neighborhood = 3;

  /// Share of all sample pixels, in percent.
  static const double _minToothPct = 4;
  static const double _maxToothPct = 80;
  static const double _minTissuePct = 3;
  static const double _minToothNearTissuePct = 2.5;

  static Future<bool> looksLikeTeeth(Uint8List bytes) async {
    final ByteData? rgba;
    final int width, height;
    try {
      final codec =
          await ui.instantiateImageCodec(bytes, targetWidth: _sampleWidth);
      final frame = await codec.getNextFrame();
      codec.dispose();
      final image = frame.image;
      width = image.width;
      height = image.height;
      rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
    } catch (_) {
      return true;
    }
    if (rgba == null || width == 0 || height == 0) return true;
    return evaluate(rgba.buffer.asUint8List(), width, height);
  }

  /// The decision on raw RGBA pixels. Public for tests.
  static bool evaluate(Uint8List rgba, int width, int height) {
    final total = width * height;
    final tooth = Uint8List(total);
    final tissue = Uint8List(total);
    var toothCount = 0, tissueCount = 0;

    for (var i = 0; i < total; i++) {
      final r = rgba[i * 4] / 255;
      final g = rgba[i * 4 + 1] / 255;
      final b = rgba[i * 4 + 2] / 255;
      final (h, s, v) = _hsv(r, g, b);
      if (_isTooth(h, s, v)) {
        tooth[i] = 1;
        toothCount++;
      } else if (_isTissue(h, s, v)) {
        tissue[i] = 1;
        tissueCount++;
      }
    }

    final toothPct = toothCount * 100 / total;
    final tissuePct = tissueCount * 100 / total;
    if (toothPct < _minToothPct || toothPct > _maxToothPct) return false;
    if (tissuePct < _minTissuePct) return false;

    // Teeth sit in the mouth: count tooth pixels with tissue close by.
    var nearTissue = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (tooth[y * width + x] == 0) continue;
        if (_hasNeighbor(tissue, width, height, x, y)) nearTissue++;
      }
    }
    return nearTissue * 100 / total >= _minToothNearTissuePct;
  }

  /// Bright and low in color: white to ivory or pale yellow.
  static bool _isTooth(double h, double s, double v) =>
      v >= 0.5 && (s <= 0.12 || (s <= 0.38 && h >= 18 && h <= 65));

  /// Gum, lip and tongue: saturated pinks and reds. Skin sits at more
  /// orange hues, so it's mostly left out.
  static bool _isTissue(double h, double s, double v) =>
      v >= 0.22 && s >= 0.28 && (h >= 330 || h <= 14);

  static bool _hasNeighbor(
      Uint8List mask, int width, int height, int x, int y) {
    for (var dy = -_neighborhood; dy <= _neighborhood; dy++) {
      final ny = y + dy;
      if (ny < 0 || ny >= height) continue;
      for (var dx = -_neighborhood; dx <= _neighborhood; dx++) {
        final nx = x + dx;
        if (nx < 0 || nx >= width) continue;
        if (mask[ny * width + nx] == 1) return true;
      }
    }
    return false;
  }

  /// Hue in degrees, saturation and value from 0 to 1.
  static (double, double, double) _hsv(double r, double g, double b) {
    final max = r > g ? (r > b ? r : b) : (g > b ? g : b);
    final min = r < g ? (r < b ? r : b) : (g < b ? g : b);
    final d = max - min;
    final s = max == 0 ? 0.0 : d / max;
    double h;
    if (d == 0) {
      h = 0;
    } else if (max == r) {
      h = 60 * (((g - b) / d) % 6);
    } else if (max == g) {
      h = 60 * ((b - r) / d + 2);
    } else {
      h = 60 * ((r - g) / d + 4);
    }
    if (h < 0) h += 360;
    return (h, s, max);
  }
}
