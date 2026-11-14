import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/dentra_dates.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../../shared/widgets/dentra_image_viewer.dart';
import '../state/comparison_state.dart';

enum _Mode {
  sideBySide('Side by side'),
  slider('Slider');

  const _Mode(this.label);
  final String label;
}

/// Earlier and later images at matching dimensions, side by side or as a
/// draggable before/after slider. Each side can pick among its images;
/// two screenings are matched region by region where they share one.
class ImageComparison extends StatefulWidget {
  const ImageComparison(
      {super.key, required this.earlier, required this.later});

  final ComparableItem earlier;
  final ComparableItem later;

  @override
  State<ImageComparison> createState() => _ImageComparisonState();
}

class _ImageComparisonState extends State<ImageComparison> {
  _Mode _mode = _Mode.sideBySide;
  int _earlierIndex = 0;
  int _laterIndex = 0;
  double _split = 0.5;

  /// Regions both screenings captured, when comparing two screenings.
  List<String> get _sharedRegions {
    final a = widget.earlier.images
        .map((i) => i.regionId)
        .whereType<String>()
        .toSet();
    return [
      for (final i in widget.later.images)
        if (i.regionId != null && a.contains(i.regionId)) i.regionId!,
    ];
  }

  @override
  void initState() {
    super.initState();
    _matchRegion(_sharedRegions.firstOrNull);
  }

  @override
  void didUpdateWidget(ImageComparison old) {
    super.didUpdateWidget(old);
    if (old.earlier.key != widget.earlier.key ||
        old.later.key != widget.later.key) {
      _earlierIndex = 0;
      _laterIndex = 0;
      _matchRegion(_sharedRegions.firstOrNull);
    }
    _earlierIndex = _earlierIndex.clamp(0, widget.earlier.images.length - 1);
    _laterIndex = _laterIndex.clamp(0, widget.later.images.length - 1);
  }

  void _matchRegion(String? region) {
    if (region == null) return;
    _earlierIndex =
        widget.earlier.images.indexWhere((i) => i.regionId == region);
    _laterIndex = widget.later.images.indexWhere((i) => i.regionId == region);
  }

  String _caption(
          ComparisonSlot slot, ComparableItem item, ComparableImage image) =>
      '${slot.label} · ${item.source.label} · ${DentraDates.medium(item.at)} · '
      '${image.label}';

  @override
  Widget build(BuildContext context) {
    final earlier = widget.earlier.images[_earlierIndex];
    final later = widget.later.images[_laterIndex];
    final shared = _sharedRegions;
    final linked = shared.isNotEmpty && earlier.regionId == later.regionId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in _Mode.values)
              DentraChoiceChip(
                label: m.label,
                selected: _mode == m,
                onSelected: () => setState(() => _mode = m),
              ),
          ],
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: dentraMotion(context, 200),
          child: _mode == _Mode.sideBySide
              ? Row(
                  key: const ValueKey('side'),
                  children: [
                    Expanded(
                      child: _Tile(
                        image: earlier.image,
                        badge: ComparisonSlot.earlier.label,
                        caption: _caption(
                            ComparisonSlot.earlier, widget.earlier, earlier),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Tile(
                        image: later.image,
                        badge: ComparisonSlot.later.label,
                        caption:
                            _caption(ComparisonSlot.later, widget.later, later),
                      ),
                    ),
                  ],
                )
              : _Slider(
                  key: const ValueKey('slider'),
                  earlier: earlier.image,
                  later: later.image,
                  split: _split,
                  onChanged: (v) => setState(() => _split = v),
                ),
        ),
        const SizedBox(height: 12),
        if (linked && shared.length > 1)
          _Picker(
            label: 'Region',
            options: [
              for (final r in shared)
                widget.earlier.images.firstWhere((i) => i.regionId == r).label
            ],
            selected: shared.indexOf(earlier.regionId!),
            onSelected: (i) => setState(() => _matchRegion(shared[i])),
          )
        else if (!linked) ...[
          if (widget.earlier.images.length > 1)
            _Picker(
              label: 'Earlier image',
              options: [for (final i in widget.earlier.images) i.label],
              selected: _earlierIndex,
              onSelected: (i) => setState(() => _earlierIndex = i),
            ),
          if (widget.later.images.length > 1)
            _Picker(
              label: 'Later image',
              options: [for (final i in widget.later.images) i.label],
              selected: _laterIndex,
              onSelected: (i) => setState(() => _laterIndex = i),
            ),
        ],
        Text(
          linked
              ? 'Both show the ${earlier.label.toLowerCase()} region. Tap an image to enlarge it.'
              : 'Tap an image to enlarge it.',
          style:
              GoogleFonts.outfit(fontSize: 12, color: AppColors.secondaryText),
        ),
      ],
    );
  }
}

/// Same box for both sides, so the images line up at the same size.
const _aspect = 3 / 4;

class _Tile extends StatelessWidget {
  const _Tile(
      {required this.image, required this.badge, required this.caption});

  final ImageProvider image;
  final String badge;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$caption. Opens full size.',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () =>
            showDentraImageViewer(context, image: image, caption: caption),
        child: AspectRatio(
          aspectRatio: _aspect,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                DentraCoverImage(image: image),
                Positioned(left: 8, top: 8, child: _Badge(badge)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Slider extends StatelessWidget {
  const _Slider({
    super.key,
    required this.earlier,
    required this.later,
    required this.split,
    required this.onChanged,
  });

  final ImageProvider earlier;
  final ImageProvider later;

  /// 0–1: how much of the width shows the earlier image.
  final double split;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        // Kept to a comfortable height on wide screens.
        constraints: const BoxConstraints(maxWidth: 360),
        child: AspectRatio(
          aspectRatio: _aspect,
          child: LayoutBuilder(builder: (context, c) {
            void drag(Offset local) =>
                onChanged((local.dx / c.maxWidth).clamp(0.0, 1.0));
            return Semantics(
              slider: true,
              label: 'Earlier and later image slider',
              value: '${(split * 100).round()}% earlier',
              increasedValue:
                  '${((split + 0.1).clamp(0, 1) * 100).round()}% earlier',
              decreasedValue:
                  '${((split - 0.1).clamp(0, 1) * 100).round()}% earlier',
              onIncrease: () => onChanged((split + 0.1).clamp(0.0, 1.0)),
              onDecrease: () => onChanged((split - 0.1).clamp(0.0, 1.0)),
              child: GestureDetector(
                onHorizontalDragUpdate: (d) => drag(d.localPosition),
                onTapDown: (d) => drag(d.localPosition),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DentraCoverImage(image: later),
                      ClipRect(
                        clipper: _LeftClipper(split),
                        child: DentraCoverImage(image: earlier),
                      ),
                      Positioned(
                        left: (c.maxWidth * split - 1).clamp(0, c.maxWidth - 2),
                        top: 0,
                        bottom: 0,
                        child: Container(width: 2, color: AppColors.white),
                      ),
                      Positioned(
                        left:
                            (c.maxWidth * split - 16).clamp(0, c.maxWidth - 32),
                        top: c.maxHeight / 2 - 16,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.navy.withValues(alpha: 0.2),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.compare_arrows_rounded,
                              size: 18, color: AppColors.g2),
                        ),
                      ),
                      Positioned(
                          left: 8,
                          top: 8,
                          child: _Badge(ComparisonSlot.earlier.label)),
                      Positioned(
                          right: 8,
                          top: 8,
                          child: _Badge(ComparisonSlot.later.label)),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _LeftClipper extends CustomClipper<Rect> {
  const _LeftClipper(this.fraction);

  final double fraction;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(_LeftClipper old) => old.fraction != fraction;
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.white,
        ),
      ),
    );
  }
}

class _Picker extends StatelessWidget {
  const _Picker({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final List<String> options;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < options.length; i++)
                DentraChoiceChip(
                  label: options[i],
                  selected: i == selected,
                  onSelected: () => onSelected(i),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
