import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Paints the camera's live picture from a stream of JPEG frames.
///
/// Only the newest frame is decoded: frames that arrive while one decodes
/// replace each other, so a slow phone shows fewer pictures instead of
/// falling behind. Shows nothing until the first frame.
class LiveView extends StatefulWidget {
  const LiveView({super.key, required this.frames, this.fit = BoxFit.contain});

  final ValueListenable<Uint8List?> frames;
  final BoxFit fit;

  @override
  State<LiveView> createState() => _LiveViewState();
}

class _LiveViewState extends State<LiveView> {
  ui.Image? _image;
  Uint8List? _next;
  bool _decoding = false;

  @override
  void initState() {
    super.initState();
    widget.frames.addListener(_onFrame);
    _onFrame();
  }

  @override
  void didUpdateWidget(LiveView old) {
    super.didUpdateWidget(old);
    if (old.frames != widget.frames) {
      old.frames.removeListener(_onFrame);
      widget.frames.addListener(_onFrame);
      _onFrame();
    }
  }

  void _onFrame() {
    final bytes = widget.frames.value;
    if (bytes == null) return;
    _next = bytes;
    if (!_decoding) unawaited(_decode());
  }

  Future<void> _decode() async {
    _decoding = true;
    while (_next != null && mounted) {
      final bytes = _next!;
      _next = null;
      ui.Image? image;
      try {
        final codec = await ui.instantiateImageCodec(bytes);
        try {
          image = (await codec.getNextFrame()).image;
        } finally {
          codec.dispose();
        }
      } catch (_) {
        // A damaged frame: skip it, the next one is moments away.
      }
      if (image == null) continue;
      if (!mounted) {
        image.dispose();
        break;
      }
      final old = _image;
      setState(() => _image = image);
      old?.dispose();
    }
    _decoding = false;
  }

  @override
  void dispose() {
    widget.frames.removeListener(_onFrame);
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) return const SizedBox.expand();
    return RawImage(
      image: image,
      fit: widget.fit,
      width: double.infinity,
      height: double.infinity,
      filterQuality: FilterQuality.medium,
    );
  }
}
