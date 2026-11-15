import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import 'dentra_glass_ui.dart';

/// Opens [image] full size over a dimmed page, pinch-to-zoom enabled.
/// [caption] names what is shown (e.g. the record source and date).
/// [overlay] is drawn over the image at exactly its size, and zooms with it.
Future<void> showDentraImageViewer(
  BuildContext context, {
  required ImageProvider image,
  String? caption,
  Widget? overlay,
}) {
  return showGlassDialog<void>(
    context: context,
    builder: (dialogContext) => GestureDetector(
      onTap: () => Navigator.of(dialogContext).pop(),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  maxScale: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: [
                        Image(
                          image: image,
                          fit: BoxFit.contain,
                          loadingBuilder: (_, child, progress) =>
                              progress == null
                                  ? child
                                  : const SizedBox.square(
                                      dimension: 64,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          color: AppColors.white,
                                          strokeWidth: 2.4,
                                        ),
                                      ),
                                    ),
                          errorBuilder: (_, __, ___) =>
                              const DentraImageError(),
                        ),
                        if (overlay != null) Positioned.fill(child: overlay),
                      ],
                    ),
                  ),
                ),
              ),
              if (caption != null)
                Positioned(
                  left: 16,
                  right: 72,
                  top: 14,
                  child: Text(
                    caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.white,
                      shadows: [
                        Shadow(
                          color: AppColors.navy.withValues(alpha: 0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  tooltip: 'Close',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.white.withValues(alpha: 0.85),
                    foregroundColor: AppColors.navy,
                  ),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Shown where a stored image could not be loaded (expired link, offline).
class DentraImageError extends StatelessWidget {
  const DentraImageError({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: "Image couldn't be loaded",
      child: Container(
        color: AppColors.lightLavender,
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image_outlined,
            color: AppColors.secondaryText),
      ),
    );
  }
}

/// Soft placeholder while an image loads.
class DentraImagePlaceholder extends StatelessWidget {
  const DentraImagePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: AppColors.g2.withValues(alpha: 0.08));
  }
}

/// Fills its box with [image] (cover), decoded only as large as needed,
/// with loading and error states.
class DentraCoverImage extends StatelessWidget {
  const DentraCoverImage({
    super.key,
    required this.image,
    this.fit = BoxFit.cover,
  });

  final ImageProvider image;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final side = math.max(
        c.maxWidth.isFinite ? c.maxWidth : 0,
        c.maxHeight.isFinite ? c.maxHeight : 0,
      );
      final pixels = (side * MediaQuery.devicePixelRatioOf(context)).ceil();
      return Image(
        image: pixels > 0 ? CoverResizeImage(image, pixels) : image,
        fit: fit,
        width: c.maxWidth.isFinite ? c.maxWidth : null,
        height: c.maxHeight.isFinite ? c.maxHeight : null,
        frameBuilder: (_, child, frame, sync) =>
            sync || frame != null ? child : const DentraImagePlaceholder(),
        errorBuilder: (_, __, ___) => const DentraImageError(),
      );
    });
  }
}

/// Decodes [image] just large enough to cover a [pixels]-wide square,
/// keeping its aspect ratio, so a grid tile doesn't hold a full camera
/// frame in memory. Never upscales.
///
/// Unlike `cacheWidth`, this works out the target from the photo's own
/// aspect ratio, so landscape photos stay sharp under [BoxFit.cover].
class CoverResizeImage extends ImageProvider<CoverResizeKey> {
  const CoverResizeImage(this.image, this.pixels);

  final ImageProvider image;
  final int pixels;

  @override
  Future<CoverResizeKey> obtainKey(ImageConfiguration configuration) => image
      .obtainKey(configuration)
      .then((inner) => CoverResizeKey(inner, pixels));

  @override
  ImageStreamCompleter loadImage(
    CoverResizeKey key,
    ImageDecoderCallback decode,
  ) {
    return image.loadImage(
      key.inner,
      (buffer, {getTargetSize}) => decode(
        buffer,
        getTargetSize: (width, height) {
          final scale = math.max(pixels / width, pixels / height);
          if (scale >= 1) {
            return ui.TargetImageSize(width: width, height: height);
          }
          return ui.TargetImageSize(
            width: (width * scale).ceil(),
            height: (height * scale).ceil(),
          );
        },
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CoverResizeImage &&
      other.image == image &&
      other.pixels == pixels;

  @override
  int get hashCode => Object.hash(image, pixels);
}

@immutable
class CoverResizeKey {
  const CoverResizeKey(this.inner, this.pixels);

  final Object inner;
  final int pixels;

  @override
  bool operator ==(Object other) =>
      other is CoverResizeKey && other.inner == inner && other.pixels == pixels;

  @override
  int get hashCode => Object.hash(inner, pixels);
}
