import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// How one photo measured on the phone, right after it was taken. The photo
/// check where there's no server one (`LocalPhotoCheckService`); otherwise the
/// server's check decides.
class PhotoQuality {
  const PhotoQuality({
    required this.light,
    required this.focus,
    this.tooSmall = false,
  });

  final PhotoLight light;
  final PhotoFocus focus;

  /// Smaller than the analysis can read, whatever its light and focus.
  final bool tooSmall;

  /// Same thresholds as ml/inference's quality.py, so what this says here is
  /// close to what the analysis would say. Checked at about the same size.
  /// Change them together.
  static const int checkSide = 512;
  static const double minMean = 35;
  static const double maxMean = 225;
  static const double maxClipped = 0.25;
  static const double minSharpness = 6;
  static const int minSide = 240;

  /// Decodes [bytes] small and measures them, or returns null when the photo
  /// can't be read here.
  static Future<PhotoQuality?> measure(Uint8List bytes) async {
    try {
      // Never scaled up: that would blur a small photo into looking soft.
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: checkSide,
        allowUpscaling: false,
      );
      final image = (await codec.getNextFrame()).image;
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final width = image.width, height = image.height;
      image.dispose();
      codec.dispose();
      if (data == null) return null;
      final quality = fromRgba(data.buffer.asUint8List(), width, height);
      return PhotoQuality(
        light: quality.light,
        focus: quality.focus,
        tooSmall: await _isTooSmall(bytes, width, height),
      );
    } catch (_) {
      return null;
    }
  }

  /// Whether a photo's real shorter side is under [minSide]. A photo no wider
  /// than [checkSide] was decoded as it is, so [width] and [height] are real. A
  /// wider one was scaled down, so only a thin one needs its real size looked up.
  static Future<bool> _isTooSmall(
      Uint8List bytes, int width, int height) async {
    if (math.min(width, height) >= minSide) return false;
    if (width < checkSide) return true;
    final codec = await ui.instantiateImageCodec(bytes);
    final image = (await codec.getNextFrame()).image;
    final side = math.min(image.width, image.height);
    image.dispose();
    codec.dispose();
    return side < minSide;
  }

  /// Measures raw RGBA pixels: BT.601 brightness, the share of near-white
  /// pixels, and the variance of a 4-neighbour Laplacian for focus.
  static PhotoQuality fromRgba(Uint8List rgba, int width, int height) {
    final gray = Float32List(width * height);
    var sum = 0.0;
    var clipped = 0;
    for (var i = 0; i < gray.length; i++) {
      final v = 0.299 * rgba[i * 4] +
          0.587 * rgba[i * 4 + 1] +
          0.114 * rgba[i * 4 + 2];
      gray[i] = v;
      sum += v;
      if (v >= 250) clipped++;
    }
    final mean = sum / gray.length;
    final light = mean < minMean
        ? PhotoLight.dark
        : mean > maxMean || clipped / gray.length > maxClipped
            ? PhotoLight.glare
            : PhotoLight.good;

    var n = 0;
    var lapSum = 0.0, lapSquares = 0.0;
    for (var y = 1; y < height - 1; y++) {
      for (var x = 1; x < width - 1; x++) {
        final i = y * width + x;
        final lap = gray[i - width] +
            gray[i + width] +
            gray[i - 1] +
            gray[i + 1] -
            4 * gray[i];
        lapSum += lap;
        lapSquares += lap * lap;
        n++;
      }
    }
    final avg = n == 0 ? 0.0 : lapSum / n;
    final variance = n == 0 ? 0.0 : lapSquares / n - avg * avg;
    return PhotoQuality(
      light: light,
      focus: variance < minSharpness ? PhotoFocus.soft : PhotoFocus.sharp,
    );
  }
}

enum PhotoLight { good, dark, glare }

enum PhotoFocus { sharp, soft }
