import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/tooth_catalog.dart';
import '../state/explorer_controller.dart';
import '../state/tooth_type_colors.dart';

/// Two-row dental chart (FDI numbers) for picking a tooth by number.
/// Laid out as when facing the patient: their right is on the left.
class ToothChart extends StatefulWidget {
  const ToothChart({
    super.key,
    required this.controller,
    required this.onSelect,
    required this.onOpenGuide,
    this.markedTeeth = const {},
  });

  final ExplorerController controller;

  /// Teeth with history items, marked with a small dot.
  final Set<int> markedTeeth;
  final ValueChanged<ToothInfo> onSelect;
  final VoidCallback onOpenGuide;

  @override
  State<ToothChart> createState() => _ToothChartState();
}

class _ToothChartState extends State<ToothChart> {
  final _scroll = ScrollController();
  final _keys = {for (final t in ToothCatalog.all) t.index: GlobalKey()};

  @override
  void initState() {
    super.initState();
    // Start centred on the midline, where the front teeth are.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final selected = widget.controller.selected;
      if (selected != null) {
        _reveal(selected, animate: false);
      } else {
        _scroll.jumpTo(_scroll.position.maxScrollExtent / 2);
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _reveal(ToothInfo tooth, {bool animate = true}) {
    final ctx = _keys[tooth.index]!.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.5,
      duration: animate ? dentraMotion(context, 260) : Duration.zero,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        return GlassCard(
          borderRadius: BorderRadius.circular(22),
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 6, 0),
                child: Row(
                  children: [
                    Flexible(
                      child: Semantics(
                        header: true,
                        child: Text(
                          'Tooth chart',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.markedTeeth.isEmpty
                            ? 'Tap to explore'
                            : 'Dot: has history',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: widget.onOpenGuide,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        minimumSize: const Size(44, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        textStyle: GoogleFonts.outfit(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      icon: const Icon(Icons.help_outline_rounded, size: 16),
                      label: const Text('Numbering'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    _row(ToothCatalog.upperChartRow, c, 'Upper'),
                    const SizedBox(height: 6),
                    _row(ToothCatalog.lowerChartRow, c, 'Lower'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _row(List<ToothInfo> teeth, ExplorerController c, String archName) {
    return Row(
      children: [
        _SideLabel('R', semantics: "$archName, patient's right"),
        for (var i = 0; i < teeth.length; i++) ...[
          if (i == 8)
            // Midline between the two quadrants.
            Container(
              width: 2,
              height: 30,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: AppColors.g2.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(1),
              ),
            )
          else if (i > 0)
            const SizedBox(width: 4),
          _ToothChip(
            key: _keys[teeth[i].index],
            tooth: teeth[i],
            selected: c.selected == teeth[i],
            visible: c.isVisible(teeth[i]),
            inRegion: c.region.includes(teeth[i]),
            hasHistory: widget.markedTeeth.contains(teeth[i].fdi),
            onTap: () {
              widget.onSelect(teeth[i]);
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => _reveal(teeth[i]));
            },
          ),
        ],
        _SideLabel('L', semantics: "$archName, patient's left"),
      ],
    );
  }
}

class _SideLabel extends StatelessWidget {
  const _SideLabel(this.text, {required this.semantics});

  final String text;
  final String semantics;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semantics,
      excludeSemantics: true,
      child: SizedBox(
        width: 22,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.secondaryText,
          ),
        ),
      ),
    );
  }
}

class _ToothChip extends StatelessWidget {
  const _ToothChip({
    super.key,
    required this.tooth,
    required this.selected,
    required this.visible,
    required this.inRegion,
    required this.onTap,
    this.hasHistory = false,
  });

  final ToothInfo tooth;
  final bool selected;
  final bool visible;
  final bool inRegion;
  final bool hasHistory;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final typeColor = ToothTypeColors.of(tooth.type);
    return Semantics(
      button: true,
      selected: selected,
      label: 'Tooth ${tooth.fdi}, ${tooth.name}'
          '${hasHistory ? ', has history items' : ''}',
      excludeSemantics: true,
      child: AnimatedOpacity(
        duration: dentraMotion(context, 200),
        opacity: selected ? 1 : (!visible ? 0.4 : (inRegion ? 1 : 0.6)),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: dentraMotion(context, 200),
              width: 38,
              height: 44,
              decoration: BoxDecoration(
                gradient: selected ? AppColors.cardGradient : null,
                color: selected ? null : AppColors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? AppColors.white.withValues(alpha: 0.6)
                      : AppColors.g2.withValues(alpha: 0.16),
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppColors.g2.withValues(alpha: 0.28),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                children: [
                  if (hasHistory)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: selected ? AppColors.white : AppColors.g2,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  Center(
                      child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${tooth.fdi}',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: selected ? AppColors.white : AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 3),
                      // Type key: matches the legend colours.
                      Container(
                        width: 14,
                        height: 3,
                        decoration: BoxDecoration(
                          color: selected ? AppColors.white : typeColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
