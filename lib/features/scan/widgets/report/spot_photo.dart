import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/dentra_image_viewer.dart';
import '../../data/scan_report.dart';
import '../scan_motion.dart';
import 'report_style.dart';

/// One mark to draw on a photo.
class SpotMarker {
  const SpotMarker(this.box, this.strength, {this.selected = false});

  /// Each side 0-1 of the photo.
  final Rect box;
  final SignStrength strength;
  final bool selected;
}

/// The marks of [spots] that have a place in [photoId].
List<SpotMarker> markersIn(
  List<ReportSpot> spots,
  String photoId, {
  ReportSpot? selected,
}) =>
    [
      for (final s in spots)
        if (s.photoId == photoId)
          if (s.box case final box?)
            SpotMarker(box, s.strength, selected: identical(s, selected)),
    ];

/// Rings around the marked teeth. White with a dark edge, so they stay visible
/// on any photo, and the selected one sets off the rest with a light veil.
class SpotMarkerPainter extends CustomPainter {
  const SpotMarkerPainter(this.markers);

  final List<SpotMarker> markers;

  RRect _ring(Rect box, Size size) {
    final rect = Rect.fromLTWH(
      box.left * size.width,
      box.top * size.height,
      box.width * size.width,
      box.height * size.height,
    );
    return RRect.fromRectAndRadius(
      rect,
      Radius.circular(rect.shortestSide * 0.18),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final m in markers.where((m) => m.selected)) {
      canvas.drawPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRect(Offset.zero & size),
          Path()..addRRect(_ring(m.box, size)),
        ),
        Paint()..color = AppColors.white.withValues(alpha: 0.3),
      );
    }
    for (final m in markers) {
      final ring = _ring(m.box, size);
      canvas.drawRRect(
        ring,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = m.selected ? 5 : 3.5
          ..color = ReportColors.strong.withValues(alpha: 0.7),
      );
      canvas.drawRRect(
        ring,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = m.selected ? 3 : 2
          ..color = AppColors.white,
      );
    }
  }

  @override
  bool shouldRepaint(SpotMarkerPainter old) {
    if (old.markers.length != markers.length) return true;
    for (var i = 0; i < markers.length; i++) {
      if (old.markers[i].box != markers[i].box ||
          old.markers[i].selected != markers[i].selected) {
        return true;
      }
    }
    return false;
  }
}

/// The part of a photo to show in a box of size [stage], each side 0-1: all the
/// box can hold of it, or close enough for [focus] to take about half of it.
/// Always inside the photo, and always the shape of the box.
Rect spotViewport(Size stage, Size natural, Rect? focus) {
  final stageRatio = stage.width / stage.height;
  final photoRatio = natural.width / natural.height;
  final fullW = stageRatio >= photoRatio ? 1.0 : stageRatio / photoRatio;
  final fullH = stageRatio >= photoRatio ? photoRatio / stageRatio : 1.0;
  if (focus == null) {
    return Rect.fromCenter(
      center: const Offset(0.5, 0.5),
      width: fullW,
      height: fullH,
    );
  }
  final share = math
      .max(focus.width * 2.1 / fullW, focus.height * 2.1 / fullH)
      .clamp(0.25, 1.0);
  final w = fullW * share, h = fullH * share;
  return Rect.fromCenter(
    center: Offset(
      focus.center.dx.clamp(w / 2, 1 - w / 2),
      focus.center.dy.clamp(h / 2, 1 - h / 2),
    ),
    width: w,
    height: h,
  );
}

/// A photo cropped to fill its box, with its markers, gliding in close to
/// [focus] when there is one. Markers stay on their teeth at any zoom because
/// both are laid out from the photo's own size.
class SpotPhoto extends StatefulWidget {
  const SpotPhoto({
    super.key,
    required this.image,
    this.markers = const [],
    this.focus,
    this.fallback,
    this.decodeWidth,
  });

  final ImageProvider image;
  final List<SpotMarker> markers;

  /// Decodes no wider than this. A full scan is up to 18 large photos, so
  /// anything that won't be zoomed into shouldn't hold all their pixels.
  final int? decodeWidth;

  /// The part of the photo to go in close to, each side 0-1.
  final Rect? focus;

  /// Shown in place of a photo that can't be loaded.
  final Widget? fallback;

  @override
  State<SpotPhoto> createState() => _SpotPhotoState();
}

class _SpotPhotoState extends State<SpotPhoto> {
  ImageProvider get _source => switch (widget.decodeWidth) {
        final width? => ResizeImage(
            widget.image,
            width: width,
            allowUpscaling: false,
          ),
        null => widget.image,
      };

  ImageStream? _stream;
  ImageStreamListener? _listener;
  Size? _natural;
  bool _failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(SpotPhoto old) {
    super.didUpdateWidget(old);
    if (old.image != widget.image || old.decodeWidth != widget.decodeWidth) {
      _resolve();
    }
  }

  void _resolve() {
    final stream = _source.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _stop();
    _natural = null;
    _failed = false;
    _listener = ImageStreamListener(
      (info, _) {
        if (!mounted) return;
        setState(() {
          _natural = Size(
            info.image.width.toDouble(),
            info.image.height.toDouble(),
          );
        });
        info.dispose();
      },
      onError: (_, __) {
        if (mounted) setState(() => _failed = true);
      },
    );
    _stream = stream..addListener(_listener!);
  }

  void _stop() {
    if (_listener != null) _stream?.removeListener(_listener!);
    _listener = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final natural = _natural;
    if (_failed) {
      return widget.fallback ?? const DentraImageError();
    }
    if (natural == null) return const DentraImagePlaceholder();

    return LayoutBuilder(builder: (context, c) {
      final stage = c.biggest;
      if (stage.isEmpty) return const SizedBox.shrink();
      return TweenAnimationBuilder<Rect?>(
        tween: RectTween(end: spotViewport(stage, natural, widget.focus)),
        duration: ScanMotion.of(context, ScanMotion.slow),
        curve: ScanMotion.curve,
        builder: (context, view, _) {
          final v = view ?? Rect.zero;
          // The whole photo at this zoom, slid so the viewport fills the box.
          final width = stage.width / v.width;
          final height = stage.height / v.height;
          return ClipRect(
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  left: -v.left * width,
                  top: -v.top * height,
                  width: width,
                  height: height,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image(
                        image: _source,
                        fit: BoxFit.fill,
                        gaplessPlayback: true,
                        excludeFromSemantics: true,
                      ),
                      if (widget.markers.isNotEmpty)
                        CustomPaint(
                          painter: SpotMarkerPainter(widget.markers),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    });
  }
}

/// Opens a photo full size with its markers, zoomable.
void openSpotPhoto(
  BuildContext context, {
  required ImageProvider image,
  required String caption,
  List<SpotMarker> markers = const [],
}) {
  unawaited(showDentraImageViewer(
    context,
    image: image,
    caption: caption,
    overlay: markers.isEmpty
        ? null
        : IgnorePointer(
            child: CustomPaint(painter: SpotMarkerPainter(markers)),
          ),
  ));
}

/// A plain tile for a photo that isn't there.
class MissingPhoto extends StatelessWidget {
  const MissingPhoto({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.navy.withValues(alpha: 0.04),
      child: const Center(
        child: Icon(
          Icons.hide_image_outlined,
          size: 20,
          color: ReportColors.hollowEdge,
        ),
      ),
    );
  }
}
