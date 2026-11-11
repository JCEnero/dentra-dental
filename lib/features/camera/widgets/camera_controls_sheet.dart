import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../../shared/widgets/glass_card.dart';
import '../camera_strings.dart';
import '../data/camera_protocol.dart';
import '../state/live_camera_controller.dart';
import 'camera_bits.dart';

/// Light, orientation and live-view quality. The live picture stays on
/// behind the sheet, so every change shows at once.
Future<void> showCameraControls(
  BuildContext context,
  LiveCameraController live,
) =>
    showGlassSheet<void>(
      context: context,
      title: CamText.controls,
      builder: (_) => _Controls(live: live),
    );

class _Controls extends StatefulWidget {
  const _Controls({required this.live});

  final LiveCameraController live;

  @override
  State<_Controls> createState() => _ControlsState();
}

class _ControlsState extends State<_Controls> {
  /// The slider's position while it's being dragged.
  double? _dragLevel;
  String? _error;

  void _send(Future<bool> change) {
    setState(() => _error = null);
    unawaited(change.then((ok) {
      if (!ok && mounted) setState(() => _error = CamText.settingFailed);
    }));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.live,
      builder: (context, _) {
        final live = widget.live;
        final s = live.settings;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (live.lightAvailable) ...[
              _Row(
                icon: s.lightOn
                    ? Icons.light_mode_rounded
                    : Icons.light_mode_outlined,
                title: CamText.light,
                trailing: Switch(
                  value: s.lightOn,
                  activeTrackColor: AppColors.primary,
                  onChanged: (on) => _send(live.setLight(on: on)),
                ),
              ),
              const SizedBox(height: 4),
              Semantics(
                label: CamText.brightness,
                child: Row(
                  children: [
                    const SizedBox(width: 50),
                    Text(
                      CamText.brightness,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: (_dragLevel ?? s.lightLevel.toDouble())
                            .clamp(0, 100),
                        min: 0,
                        max: 100,
                        divisions: 20,
                        label: '${(_dragLevel ?? s.lightLevel).round()}%',
                        activeColor: AppColors.primary,
                        inactiveColor: AppColors.g2.withValues(alpha: 0.16),
                        onChanged: s.lightOn
                            ? (v) => setState(() => _dragLevel = v)
                            : null,
                        // Sent once, when the finger lifts, so the camera isn't
                        // flooded while dragging.
                        onChangeEnd: (v) {
                          _dragLevel = null;
                          _send(live.setLight(level: v.round()));
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            Row(
              children: [
                Expanded(
                  child: _ActionTile(
                    icon: Icons.screen_rotation_alt_rounded,
                    label: CamText.rotate,
                    hint: CamText.rotateHint,
                    onTap: () => _send(live.rotate()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionTile(
                    icon: Icons.flip_rounded,
                    label: CamText.mirror,
                    hint: CamText.mirrorHint,
                    onTap: () => _send(live.mirror()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              CamText.liveView,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final (size, label) in const [
                  (CamFrameSize.vga, CamText.liveSmooth),
                  (CamFrameSize.svga, CamText.liveSharp),
                ]) ...[
                  if (size != CamFrameSize.vga) const SizedBox(width: 10),
                  Expanded(
                    child: _SizeTile(
                      label: label,
                      detail: size.label,
                      selected: s.liveSize == size,
                      onTap: () => _send(live.setLiveSize(size)),
                    ),
                  ),
                ],
              ],
            ),
            DentraInlineNotice(message: _error),
          ],
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.title, required this.trailing});

  final IconData icon;
  final String title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Row(
        children: [
          Expanded(child: CamInfoRow(icon: icon, title: title)),
          trailing,
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label. $hint',
      onTap: onTap,
      excludeSemantics: true,
      child: GlassCard(
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            Text(
              hint,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: AppColors.secondaryText,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SizeTile extends StatelessWidget {
  const _SizeTile({
    required this.label,
    required this.detail,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $detail',
      onTap: onTap,
      excludeSemantics: true,
      child: GlassCard(
        borderRadius: BorderRadius.circular(14),
        borderColor: selected ? AppColors.primary : null,
        borderWidth: selected ? 1.6 : 1,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  Text(
                    detail,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: AppColors.primary,
              ),
          ],
        ),
      ),
    );
  }
}
