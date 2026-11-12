import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../../shared/widgets/dentra_mascot.dart';
import '../camera_strings.dart';
import 'camera_bits.dart';

/// "How to capture", shown before the first photo. With [offerHide] it has
/// a "Don't show again" box; resolves to true when that was ticked.
Future<bool> showCaptureTips(
  BuildContext context, {
  bool offerHide = true,
}) async {
  final hide = await showGlassSheet<bool>(
    context: context,
    title: CamText.tipsTitle,
    subtitle: CamText.tipsSubtitle,
    builder: (_) => _Tips(offerHide: offerHide),
  );
  return hide ?? false;
}

class _Tips extends StatefulWidget {
  const _Tips({required this.offerHide});

  final bool offerHide;

  @override
  State<_Tips> createState() => _TipsState();
}

class _TipsState extends State<_Tips> {
  static const _icons = [
    Icons.back_hand_outlined,
    Icons.light_mode_outlined,
    Icons.slow_motion_video_rounded,
    Icons.water_drop_outlined,
  ];

  bool _hide = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RabiTip(CamText.tipsRabi, mood: MascotMood.point, size: 88),
        const SizedBox(height: 18),
        for (var i = 0; i < CamText.tips.length; i++) ...[
          CamInfoRow(
            icon: _icons[i % _icons.length],
            title: CamText.tips[i].$1,
            body: CamText.tips[i].$2,
          ),
          const SizedBox(height: 16),
        ],
        if (widget.offerHide)
          MergeSemantics(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _hide = !_hide),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Checkbox(
                      value: _hide,
                      onChanged: (v) => setState(() => _hide = v ?? false),
                      activeColor: AppColors.primary,
                      side: BorderSide(
                        color: AppColors.g2.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        CamText.tipsDontShow,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        DentraPillButton(
          label: CamText.tipsGotIt,
          onPressed: () => Navigator.of(context).pop(_hide),
        ),
      ],
    );
  }
}
