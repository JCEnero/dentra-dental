import 'package:flutter/material.dart';
import '../../data/scan_regions.dart';
import 'dental_arch_painter.dart';

/// The region's visual: its rendered asset when one is configured, else the
/// built-in arch illustration. Always 10:7.
class RegionVisual extends StatelessWidget {
  const RegionVisual({
    super.key,
    required this.region,
    this.compact = false,
  });

  final ScanRegion region;

  /// Thumbnail mode: no side labels, which would be unreadably small.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final illustration = FittedBox(
      fit: BoxFit.contain,
      child: SizedBox.fromSize(
        size: kArchCanvas,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: DentalArchPainter(
              region: region,
              showSideLabels: !compact,
            ),
          ),
        ),
      ),
    );
    final asset = region.renderAsset;

    return Semantics(
      image: true,
      label: '${region.label}: ${region.description.toLowerCase()}, '
          'highlighted on a dental arch illustration',
      child: ExcludeSemantics(
        child: AspectRatio(
          aspectRatio: kArchCanvas.aspectRatio,
          child: asset == null
              ? illustration
              : Image.asset(
                  asset,
                  fit: BoxFit.contain,
                  cacheWidth: compact ? 240 : null,
                  // Fall back to the illustration if the file is missing.
                  errorBuilder: (_, __, ___) => illustration,
                ),
        ),
      ),
    );
  }
}
