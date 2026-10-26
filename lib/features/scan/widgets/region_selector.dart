import 'package:flutter/material.dart';
import '../../../shared/widgets/glass_card.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_glass.dart';
import '../../../core/constants/app_spacing.dart';
import '../data/scan_regions.dart';
import 'scan_motion.dart';
import 'visuals/region_visual.dart';

/// Horizontally scrolling region cards, each with its own arch visual.
class RegionSelector extends StatefulWidget {
  const RegionSelector({
    super.key,
    required this.selectedId,
    required this.capturedIds,
    required this.enabled,
    required this.onSelect,
  });

  final String selectedId;
  final Set<String> capturedIds;

  /// False while a capture or review is in progress.
  final bool enabled;
  final ValueChanged<String> onSelect;

  @override
  State<RegionSelector> createState() => _RegionSelectorState();
}

class _RegionSelectorState extends State<RegionSelector> {
  static const double _cardWidth = 116;
  static const double _gap = 10;
  final ScrollController _scroll = ScrollController();

  @override
  void didUpdateWidget(RegionSelector old) {
    super.didUpdateWidget(old);
    if (old.selectedId != widget.selectedId) {
      // Keep the selected card on screen, e.g. after auto-advancing. Only
      // this list scrolls; the page stays where the user is looking.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scroll.hasClients) return;
        final index = scanRegions.indexWhere((r) => r.id == widget.selectedId);
        final position = _scroll.position;
        final cardCenter =
            AppSpacing.screenH + index * (_cardWidth + _gap) + _cardWidth / 2;
        final target = (cardCenter - position.viewportDimension / 2)
            .clamp(position.minScrollExtent, position.maxScrollExtent);
        final duration = ScanMotion.of(context, ScanMotion.slow);
        if (duration == Duration.zero) {
          _scroll.jumpTo(target);
        } else {
          _scroll.animateTo(target,
              duration: duration, curve: ScanMotion.curve);
        }
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Cards have a fixed height in a horizontal list, so cap text growth
    // and size the list to the scaled text.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Builder(builder: (context) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        const visualHeight = (_cardWidth - 16) / 1.43;
        // Card content (the thumbnail flexes), plus room below for the
        // selected card's shadow.
        final height = 8 + visualHeight + 4 + 8 + 36 * textScale + 10 + 18;
        return SizedBox(
          height: height,
          child: ListView.separated(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH, 2, AppSpacing.screenH, 16),
            physics: const BouncingScrollPhysics(),
            itemCount: scanRegions.length,
            separatorBuilder: (_, __) => const SizedBox(width: _gap),
            itemBuilder: (context, i) {
              final region = scanRegions[i];
              return _RegionCard(
                key: ValueKey(region.id),
                region: region,
                index: i,
                width: _cardWidth,
                selected: region.id == widget.selectedId,
                captured: widget.capturedIds.contains(region.id),
                enabled: widget.enabled,
                onTap: () => widget.onSelect(region.id),
              );
            },
          ),
        );
      }),
    );
  }
}

class _RegionCard extends StatelessWidget {
  const _RegionCard({
    super.key,
    required this.region,
    required this.index,
    required this.width,
    required this.selected,
    required this.captured,
    required this.enabled,
    required this.onTap,
  });

  final ScanRegion region;
  final int index;
  final double width;
  final bool selected;
  final bool captured;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final duration = ScanMotion.of(context, ScanMotion.medium);
    final status = captured ? 'Captured' : 'Not captured';

    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: '${region.label}, region ${index + 1} of ${scanRegions.length}, '
          '$status',
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: GlassBlur(
          child: AnimatedContainer(
            duration: duration,
            curve: ScanMotion.curve,
            width: width,
            decoration: AppGlass.surface(
              borderRadius: BorderRadius.circular(18),
              borderColor: selected ? AppColors.g2 : null,
              borderWidth: selected ? 1.6 : 1,
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: enabled && !selected ? onTap : null,
                borderRadius: BorderRadius.circular(17),
                splashColor: AppColors.lightLavender,
                highlightColor: AppColors.lightLavender.withValues(alpha: 0.5),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Takes whatever height the text leaves, so larger text
                      // shrinks the thumbnail instead of overflowing the card.
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: const RadialGradient(
                                  radius: 0.9,
                                  colors: [
                                    AppColors.white,
                                    AppColors.lightLavender,
                                  ],
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: Center(
                                  child: RegionVisual(
                                      region: region, compact: true),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: _CheckBadge(visible: captured),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        region.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        captured
                            ? 'Captured'
                            : selected
                                ? 'Selected'
                                : 'To capture',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: captured || selected
                              ? AppColors.primary
                              : AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Scales in once when a region is completed.
class _CheckBadge extends StatelessWidget {
  const _CheckBadge({required this.visible});
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: visible ? 1 : 0.4,
      duration: ScanMotion.of(context, ScanMotion.medium),
      curve: ScanMotion.curve,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: ScanMotion.of(context, ScanMotion.fast),
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.primaryGradient,
            border: Border.all(color: AppColors.white, width: 1.5),
          ),
          child:
              const Icon(Icons.check_rounded, size: 12, color: AppColors.white),
        ),
      ),
    );
  }
}
