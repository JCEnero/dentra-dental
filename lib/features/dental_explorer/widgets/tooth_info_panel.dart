import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_glass.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/tooth_catalog.dart';
import '../data/tooth_content.dart';
import '../state/tooth_type_colors.dart';

enum _InfoTab {
  overview('Overview'),
  anatomy('Anatomy'),
  care('Care'),
  history('History');

  const _InfoTab(this.label);
  final String label;
}

/// Details for the selected tooth, docked under the 3D view so the model
/// stays visible. Content is split into short tabs; closing the panel
/// keeps the current camera view.
class ToothInfoPanel extends StatefulWidget {
  const ToothInfoPanel({
    super.key,
    required this.tooth,
    required this.previous,
    required this.next,
    required this.onClose,
    required this.onPrevious,
    required this.onNext,
    required this.onFocus,
    this.historyBuilder,
  });

  final ToothInfo tooth;

  /// Content for the History tab; the tab is hidden when null.
  final Widget Function(ToothInfo tooth)? historyBuilder;

  /// Neighbours in chart order, shown on the footer buttons.
  final ToothInfo previous;
  final ToothInfo next;
  final VoidCallback onClose;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onFocus;

  @override
  State<ToothInfoPanel> createState() => _ToothInfoPanelState();
}

class _ToothInfoPanelState extends State<ToothInfoPanel> {
  // Kept while stepping between teeth, so the same topic can be compared.
  _InfoTab _tab = _InfoTab.overview;

  static const _radius = BorderRadius.all(Radius.circular(24));

  @override
  Widget build(BuildContext context) {
    final tooth = widget.tooth;
    return ClipRRect(
      borderRadius: _radius,
      child: GlassBlur(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: _radius,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.white.withValues(alpha: 0.94),
                AppColors.lightLavender.withValues(alpha: 0.92),
              ],
            ),
            border: Border.all(color: AppGlass.border, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                tooth: tooth,
                onFocus: widget.onFocus,
                onClose: widget.onClose,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: _TabBar(
                  tabs: [
                    for (final t in _InfoTab.values)
                      if (t != _InfoTab.history || widget.historyBuilder != null) t,
                  ],
                  value: _tab,
                  onChanged: (t) => setState(() => _tab = t),
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: dentraMotion(context, 180),
                  child: ListView(
                    key: ValueKey('${tooth.fdi}-$_tab'),
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                    children: switch (_tab) {
                      _InfoTab.overview => _overview(tooth),
                      _InfoTab.anatomy => _anatomy(tooth),
                      _InfoTab.care => _care(tooth),
                      _InfoTab.history => [widget.historyBuilder!(tooth)],
                    },
                  ),
                ),
              ),
              Divider(height: 1, thickness: 1, color: AppGlass.divider),
              _Footer(
                previous: widget.previous,
                next: widget.next,
                onPrevious: widget.onPrevious,
                onNext: widget.onNext,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _overview(ToothInfo tooth) {
    final position = ToothContent.forTooth(tooth);
    return [
      _Paragraph(ToothContent.forType(tooth.type).function),
      const SizedBox(height: 14),
      _FactRow(
          'Position', '${tooth.arch.label}, ${tooth.side.label.toLowerCase()}'),
      _FactRow(
          'Number', 'Quadrant ${tooth.quadrant} · position ${tooth.position}'),
      _FactRow('Erupts', position.eruption),
      _FactRow('Roots', position.roots, last: true),
    ];
  }

  List<Widget> _anatomy(ToothInfo tooth) {
    final position = ToothContent.forTooth(tooth);
    return [
      _Bullets(position.anatomy),
      const SizedBox(height: 10),
      _FactCallout(position.fact),
    ];
  }

  List<Widget> _care(ToothInfo tooth) {
    final type = ToothContent.forType(tooth.type);
    return [
      const _Label('Common concerns'),
      _Bullets(type.concerns),
      const SizedBox(height: 12),
      const _Label('Care tips'),
      _Bullets(type.hygiene),
      const SizedBox(height: 6),
      Text(
        'General education only, not a diagnosis.',
        style: GoogleFonts.outfit(
          fontSize: 11.5,
          color: AppColors.secondaryText,
        ),
      ),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.tooth,
    required this.onFocus,
    required this.onClose,
  });

  final ToothInfo tooth;
  final VoidCallback onFocus;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final iconStyle = IconButton.styleFrom(
      backgroundColor: AppColors.white.withValues(alpha: 0.7),
      foregroundColor: AppColors.navy,
      fixedSize: const Size(44, 44),
      minimumSize: const Size(44, 44),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppColors.cardGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              '${tooth.fdi}',
              semanticsLabel: 'Tooth ${tooth.fdi}',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    tooth.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                      letterSpacing: -0.2,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: ToothTypeColors.of(tooth.type),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        tooth.type.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onFocus,
            tooltip: 'Focus on this tooth',
            style: iconStyle,
            icon: const Icon(Icons.center_focus_strong_rounded, size: 19),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: onClose,
            tooltip: 'Close',
            style: iconStyle,
            icon: const Icon(Icons.close_rounded, size: 19),
          ),
        ],
      ),
    );
  }
}

/// Text tabs over a hairline: the active tab is navy with a short teal
/// underline, the rest stay muted.
class _TabBar extends StatelessWidget {
  const _TabBar({required this.tabs, required this.value, required this.onChanged});

  final List<_InfoTab> tabs;
  final _InfoTab value;
  final ValueChanged<_InfoTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final motion = dentraMotion(context, 180);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppGlass.divider)),
      ),
      child: Row(
        children: [
          for (final tab in tabs)
            Expanded(
              child: Semantics(
                button: true,
                selected: tab == value,
                inMutuallyExclusiveGroup: true,
                label: tab.label,
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(tab),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AnimatedDefaultTextStyle(
                          duration: motion,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight:
                                tab == value ? FontWeight.w700 : FontWeight.w500,
                            color: tab == value
                                ? AppColors.navy
                                : AppColors.secondaryText,
                          ),
                          child: Text(
                            tab.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 8),
                        AnimatedContainer(
                          duration: motion,
                          curve: Curves.easeOut,
                          width: tab == value ? 18 : 0,
                          height: 2,
                          decoration: BoxDecoration(
                            color: AppColors.g2,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.previous,
    required this.next,
    required this.onPrevious,
    required this.onNext,
  });

  final ToothInfo previous;
  final ToothInfo next;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final style = TextButton.styleFrom(
      foregroundColor: AppColors.primary,
      minimumSize: const Size(44, 44),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      textStyle: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Semantics(
              label: 'Previous tooth, ${previous.fdi}',
              excludeSemantics: true,
              button: true,
              child: TextButton.icon(
                onPressed: onPrevious,
                style: style,
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                label: Text('Tooth ${previous.fdi}',
                    overflow: TextOverflow.ellipsis),
              ),
            ),
          ),
          Flexible(
            child: Semantics(
              label: 'Next tooth, ${next.fdi}',
              excludeSemantics: true,
              button: true,
              child: TextButton.icon(
                onPressed: onNext,
                style: style,
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                label:
                    Text('Tooth ${next.fdi}', overflow: TextOverflow.ellipsis),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Paragraph extends StatelessWidget {
  const _Paragraph(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        fontSize: 14,
        color: AppColors.navy.withValues(alpha: 0.85),
        height: 1.55,
      ),
    );
  }
}

/// Label on the left, value on the right, hairline between rows.
class _FactRow extends StatelessWidget {
  const _FactRow(this.label, this.value, {this.last = false});

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border:
            last ? null : Border(bottom: BorderSide(color: AppGlass.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppColors.secondaryText,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: GoogleFonts.outfit(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
      ),
    );
  }
}

class _Bullets extends StatelessWidget {
  const _Bullets(this.items);
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.only(top: 8, right: 10),
                  decoration: const BoxDecoration(
                    color: AppColors.g2,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(child: _Paragraph(item)),
              ],
            ),
          ),
      ],
    );
  }
}

class _FactCallout extends StatelessWidget {
  const _FactCallout(this.fact);
  final String fact;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      tint: AppColors.lightLavender,
      borderRadius: BorderRadius.circular(14),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline_rounded,
              size: 18, color: AppColors.g2),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              fact,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppColors.navy,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
