import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../dental_explorer/data/tooth_catalog.dart';
import 'record_format.dart';

/// Opens the tooth chart, starting from [initial]. Null when closed without
/// choosing; empty when the user chose no specific tooth.
Future<List<String>?> pickTeeth(BuildContext context, List<String> initial) =>
    showGlassSheet<List<String>>(
      context: context,
      title: 'Teeth involved',
      subtitle: 'Only choose teeth you know about. Numbers follow the FDI '
          'chart used in Dental Explorer.',
      builder: (_) => _ToothPicker(initial: initial),
    );

/// Optional "which teeth?" field. Empty means no specific tooth; the app
/// never picks one for the user.
class ToothNumberField extends StatelessWidget {
  const ToothNumberField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  /// FDI numbers, e.g. ['26', '36'].
  final List<String> value;
  final ValueChanged<List<String>> onChanged;

  Future<void> _pick(BuildContext context) async {
    final picked = await pickTeeth(context, value);
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final label = value.isEmpty ? 'No specific tooth' : teethLabel(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Teeth (optional)',
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.navy,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 7),
        Semantics(
          button: true,
          label: 'Teeth, $label. Opens tooth chart.',
          excludeSemantics: true,
          child: Material(
            color: AppColors.lightLavender,
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.mdAll,
              side: BorderSide(color: AppColors.border),
            ),
            child: InkWell(
              onTap: () => _pick(context),
              customBorder:
                  const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 50),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        label,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight:
                              value.isEmpty ? FontWeight.w400 : FontWeight.w500,
                          color: value.isEmpty
                              ? AppColors.secondaryText.withValues(alpha: 0.75)
                              : AppColors.navy,
                        ),
                      ),
                    ),
                    if (value.isNotEmpty)
                      IconButton(
                        onPressed: () => onChanged(const []),
                        tooltip: 'Clear teeth',
                        icon: const Icon(Icons.close_rounded,
                            size: 18, color: AppColors.secondaryText),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.only(right: 14),
                        child: Icon(Icons.grid_view_rounded,
                            size: 16, color: AppColors.secondaryText),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ToothPicker extends StatefulWidget {
  const _ToothPicker({required this.initial});

  final List<String> initial;

  @override
  State<_ToothPicker> createState() => _ToothPickerState();
}

class _ToothPickerState extends State<_ToothPicker> {
  late final Set<int> _selected = {
    for (final t in widget.initial)
      if (int.tryParse(t) case final n?) n,
  };

  void _toggle(int fdi) => setState(
      () => _selected.contains(fdi) ? _selected.remove(fdi) : _selected.add(fdi));

  Widget _row(List<ToothInfo> teeth, String arch) {
    return Row(
      children: [
        _Side('R', semantics: "$arch, patient's right"),
        for (var i = 0; i < teeth.length; i++) ...[
          if (i == 8)
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
          _Chip(
            tooth: teeth[i],
            selected: _selected.contains(teeth[i].fdi),
            onTap: () => _toggle(teeth[i].fdi),
          ),
        ],
        _Side('L', semantics: "$arch, patient's left"),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _selected.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            children: [
              _row(ToothCatalog.upperChartRow, 'Upper'),
              const SizedBox(height: 6),
              _row(ToothCatalog.lowerChartRow, 'Lower'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Semantics(
          liveRegion: true,
          child: Text(
            sorted.isEmpty
                ? 'No tooth selected'
                : sorted.map((n) => ToothCatalog.byFdi(n)!.name).join(' · '),
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              color: AppColors.secondaryText,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: 22),
        DentraButtonRow(
          secondary: DentraPillButton(
            label: 'No specific tooth',
            variant: DentraButtonVariant.outline,
            onPressed: () => Navigator.of(context).pop(const <String>[]),
          ),
          primary: DentraPillButton(
            label: sorted.isEmpty ? 'Done' : 'Use ${sorted.length}',
            onPressed: () =>
                Navigator.of(context).pop([for (final n in sorted) '$n']),
          ),
        ),
      ],
    );
  }
}

class _Side extends StatelessWidget {
  const _Side(this.text, {required this.semantics});

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

class _Chip extends StatelessWidget {
  const _Chip({
    required this.tooth,
    required this.selected,
    required this.onTap,
  });

  final ToothInfo tooth;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Tooth ${tooth.fdi}, ${tooth.name}',
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: dentraMotion(context, 160),
            width: 38,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: selected ? AppColors.cardGradient : null,
              color: selected ? null : AppColors.white.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? AppColors.white.withValues(alpha: 0.6)
                    : AppColors.g2.withValues(alpha: 0.16),
              ),
            ),
            child: Text(
              '${tooth.fdi}',
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.white : AppColors.navy,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
