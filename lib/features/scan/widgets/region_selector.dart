import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_glass.dart';
import '../../../core/constants/app_spacing.dart';
import '../data/scan_regions.dart';
import 'guide/region_guide_view.dart';
import 'scan_motion.dart';
import 'scan_theme.dart';

/// All the views in one sliding row: each one's 3D guide until its photo is
/// taken, then the photo. Keeps the current view in sight.
class RegionSelector extends StatefulWidget {
  const RegionSelector({
    super.key,
    required this.selectedId,
    required this.photos,
    required this.enabled,
    required this.onSelect,
  });

  final String selectedId;

  /// Accepted photo bytes by region id.
  final Map<String, Uint8List> photos;
  final bool enabled;
  final ValueChanged<String> onSelect;

  @override
  State<RegionSelector> createState() => _RegionSelectorState();
}

class _RegionSelectorState extends State<RegionSelector> {
  static const double _tileWidth = 92;
  static const double _gap = 8;
  final ScrollController _scroll = ScrollController();

  @override
  void didUpdateWidget(RegionSelector old) {
    super.didUpdateWidget(old);
    if (old.selectedId == widget.selectedId) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final index = scanRegionIndex(widget.selectedId);
      final position = _scroll.position;
      final center =
          AppSpacing.screenH + index * (_tileWidth + _gap) + _tileWidth / 2;
      final target = (center - position.viewportDimension / 2)
          .clamp(position.minScrollExtent, position.maxScrollExtent);
      final duration = ScanMotion.of(context, ScanMotion.slow);
      if (duration == Duration.zero) {
        _scroll.jumpTo(target);
      } else {
        _scroll.animateTo(target, duration: duration, curve: ScanMotion.curve);
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Room for the label to grow with large text.
    final height = 82 + 24 * MediaQuery.textScalerOf(context).scale(1);
    return SizedBox(
      height: height,
      child: ListView.separated(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
        itemCount: scanRegions.length,
        separatorBuilder: (_, __) => const SizedBox(width: _gap),
        itemBuilder: (context, i) {
          final region = scanRegions[i];
          return SizedBox(
            width: _tileWidth,
            child: _ViewTile(
              key: ValueKey(region.id),
              region: region,
              index: i,
              photo: widget.photos[region.id],
              hasSecond: widget.photos.containsKey(secondPhotoId(region.id)),
              selected: region.id == baseRegionId(widget.selectedId),
              // Tapping the view leaves its second photo.
              canReselect: region.id != widget.selectedId,
              enabled: widget.enabled,
              onTap: () => widget.onSelect(region.id),
            ),
          );
        },
      ),
    );
  }
}

class _ViewTile extends StatelessWidget {
  const _ViewTile({
    super.key,
    required this.region,
    required this.index,
    required this.photo,
    required this.hasSecond,
    required this.selected,
    required this.canReselect,
    required this.enabled,
    required this.onTap,
  });

  final ScanRegion region;
  final int index;
  final Uint8List? photo;
  final bool hasSecond;
  final bool selected;
  final bool canReselect;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final duration = ScanMotion.of(context, ScanMotion.medium);
    final captured = photo != null;
    final radius = BorderRadius.circular(16);

    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: '${region.label}, view ${index + 1} of ${scanRegions.length}, '
          '${captured ? 'Captured' : 'Not captured'}',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: duration,
        curve: ScanMotion.curve,
        decoration: AppGlass.surface(
          borderRadius: radius,
          borderColor: selected ? AppColors.g2 : null,
          borderWidth: selected ? 1.6 : 1,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: enabled && (!selected || canReselect) ? onTap : null,
            borderRadius: radius,
            splashColor: AppColors.lightLavender,
            highlightColor: AppColors.lightLavender.withValues(alpha: 0.5),
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          AnimatedSwitcher(
                            duration: ScanMotion.of(context, ScanMotion.slow),
                            child: captured
                                ? _Thumb(key: const ValueKey('p'), bytes: photo!)
                                : RegionGuideView(
                                    key: const ValueKey('g'),
                                    region: region,
                                    fill: 0.8,
                                  ),
                          ),
                          Positioned(
                            top: 3,
                            right: 3,
                            child: _Badge(
                                captured: captured, hasSecond: hasSecond),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      region.short,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? AppColors.navy : AppColors.secondaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({super.key, required this.bytes});
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, c) => Image.memory(
        bytes,
        fit: BoxFit.cover,
        cacheWidth: c.maxWidth.isFinite ? (c.maxWidth * dpr).round() : null,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const ColoredBox(
          color: AppColors.lightLavender,
          child: Center(
            child: Icon(Icons.broken_image_outlined,
                size: 18, color: AppColors.secondaryText),
          ),
        ),
      ),
    );
  }
}

/// A check that pops and draws in once the view has its photo, with a "2"
/// beside it when it also has a second one.
class _Badge extends StatelessWidget {
  const _Badge({required this.captured, required this.hasSecond});

  final bool captured;
  final bool hasSecond;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: captured ? 1 : 0.4,
      duration: ScanMotion.of(context, ScanMotion.medium),
      curve: Curves.easeOutBack,
      child: AnimatedOpacity(
        opacity: captured ? 1 : 0,
        duration: ScanMotion.of(context, ScanMotion.fast),
        child: Container(
          height: 18,
          constraints: const BoxConstraints(minWidth: 18),
          padding: EdgeInsets.symmetric(horizontal: hasSecond ? 4 : 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            gradient: AppColors.cardGradient,
            border: Border.all(color: AppColors.white, width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DrawnCheck(visible: captured, size: 11, strokeWidth: 1.8),
              if (hasSecond) ...[
                const SizedBox(width: 2),
                Text(
                  '2',
                  textScaler: TextScaler.noScaling,
                  style: figureText(
                    size: 10,
                    weight: FontWeight.w800,
                    color: AppColors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
