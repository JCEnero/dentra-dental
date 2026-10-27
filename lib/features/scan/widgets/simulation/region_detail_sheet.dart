import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/dentra_glass_ui.dart';
import '../../../../shared/widgets/dentra_note_card.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../data/capture_regions.dart';
import '../../providers/scan_flow_provider.dart';
import '../../rendering/scan_scene.dart';
import '../scan_motion.dart';
import 'region_capture_card.dart';
import 'region_guide_view.dart';
import 'scan_sim_theme.dart';

Future<void> showRegionDetail(BuildContext context, CaptureRegion region) {
  return showGlassSheet<void>(
    context: context,
    title: region.label,
    subtitle: 'Region ${region.code} · ${region.technical}',
    builder: (_) => RegionDetailSheet(region: region),
  );
}

/// A region up close: the large guide or the user's photo with the
/// guide laid over it as an outline, and how to position the camera.
class RegionDetailSheet extends ConsumerStatefulWidget {
  const RegionDetailSheet({super.key, required this.region});

  final CaptureRegion region;

  @override
  ConsumerState<RegionDetailSheet> createState() => _RegionDetailSheetState();
}

class _RegionDetailSheetState extends ConsumerState<RegionDetailSheet> {
  bool _showPhoto = true;
  bool _outline = true;

  @override
  Widget build(BuildContext context) {
    final region = widget.region;
    final photo =
        ref.watch(scanFlowProvider.select((s) => s.photos[region.id]));
    final showingPhoto = photo != null && _showPhoto;
    final rejected = photo?.check == PhotoCheck.rejected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (photo != null) ...[
          _ViewToggle(
            showPhoto: _showPhoto,
            onChanged: (v) => setState(() => _showPhoto = v),
          ),
          const SizedBox(height: 12),
        ],
        AspectRatio(
          aspectRatio: 4 / 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AnimatedSwitcher(
              duration: ScanMotion.of(context, ScanMotion.medium),
              child: showingPhoto
                  ? Stack(
                      key: const ValueKey('photo'),
                      fit: StackFit.expand,
                      children: [
                        Image.memory(
                          photo.bytes,
                          fit: BoxFit.cover,
                          cacheWidth: 1080,
                          gaplessPlayback: true,
                          semanticLabel: '${region.label} photo',
                        ),
                        // Same camera and framing as the sample photos,
                        // so the outline lines up with them exactly.
                        AnimatedOpacity(
                          opacity: _outline ? 1 : 0,
                          duration: ScanMotion.of(context, ScanMotion.medium),
                          child: ExcludeSemantics(
                            child: RegionGuideView(
                              region: region,
                              look: SceneLook.overlay,
                              fill: 0.9,
                            ),
                          ),
                        ),
                        const IgnorePointer(
                          child: CustomPaint(painter: _FramePainter()),
                        ),
                        Positioned(
                          left: 10,
                          bottom: 10,
                          child: _OutlineSwitch(
                            on: _outline,
                            onChanged: (v) => setState(() => _outline = v),
                          ),
                        ),
                      ],
                    )
                  : Stack(
                      key: const ValueKey('guide'),
                      fit: StackFit.expand,
                      children: [
                        RegionGuideView(region: region),
                        const IgnorePointer(
                          child: CustomPaint(painter: _FramePainter()),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (rejected) ...[
          const DentraNoteCard(
            icon: Icons.error_outline_rounded,
            message: "We couldn't find teeth in this photo, so it won't be "
                'used in the scan. Retake it close up, with your lips pulled '
                'back and good light.',
          ),
          const SizedBox(height: 12),
        ],
        Text(
          region.instruction,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.4,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 18),
        Text('HOW TO POSITION', style: capsLabel()),
        const SizedBox(height: 10),
        for (var i = 0; i < region.tips.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.lightLavender,
                    border: Border.all(color: AppColors.lavender),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: figureText(size: 11.5, color: AppColors.g2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      region.tips[i],
                      style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        height: 1.45,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        GlowButton(
          label: photo == null
              ? 'Add Photo'
              : rejected
                  ? 'Retake Photo'
                  : 'Replace Photo',
          icon: photo == null
              ? Icons.add_a_photo_outlined
              : Icons.cached_rounded,
          intensity: 0.5,
          onTap: () => pickRegionPhoto(context, ref, region),
        ),
        if (photo != null) ...[
          const SizedBox(height: 10),
          PrimaryButton(
            label: 'Remove photo',
            variant: ButtonVariant.secondary,
            onTap: () {
              ref.read(scanFlowProvider.notifier).removePhoto(region.id);
              showDentraSnack(context, '${region.label} photo removed',
                  tone: DentraFeedbackTone.info);
            },
          ),
        ],
      ],
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.showPhoto, required this.onChanged});

  final bool showPhoto;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        DentraChoiceChip(
          label: 'Your photo',
          selected: showPhoto,
          onSelected: () => onChanged(true),
        ),
        DentraChoiceChip(
          label: 'Guide',
          selected: !showPhoto,
          onSelected: () => onChanged(false),
        ),
      ],
    );
  }
}

class _OutlineSwitch extends StatelessWidget {
  const _OutlineSwitch({required this.on, required this.onChanged});

  final bool on;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: on,
      button: true,
      label: 'Guide outline',
      excludeSemantics: true,
      child: Material(
        color: AppColors.navy.withValues(alpha: 0.6),
        shape: StadiumBorder(
          side: BorderSide(color: AppColors.white.withValues(alpha: 0.3)),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => onChanged(!on),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 36),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    on ? Icons.layers_rounded : Icons.layers_clear_rounded,
                    size: 16,
                    color: on ? AppColors.g1 : AppColors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    on ? 'Outline on' : 'Outline off',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
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

/// Camera framing: corner brackets and a small center cross.
class _FramePainter extends CustomPainter {
  const _FramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = AppColors.g1.withValues(alpha: 0.9);
    const inset = 12.0, arm = 22.0;
    final r = (Offset.zero & size).deflate(inset);
    for (final (corner, dx, dy) in [
      (r.topLeft, 1.0, 1.0),
      (r.topRight, -1.0, 1.0),
      (r.bottomLeft, 1.0, -1.0),
      (r.bottomRight, -1.0, -1.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(corner.dx, corner.dy + dy * arm)
          ..lineTo(corner.dx, corner.dy)
          ..lineTo(corner.dx + dx * arm, corner.dy),
        paint,
      );
    }
    final c = size.center(Offset.zero);
    final thin = Paint()
      ..strokeWidth = 1
      ..color = AppColors.g1.withValues(alpha: 0.6);
    canvas.drawLine(c.translate(-8, 0), c.translate(8, 0), thin);
    canvas.drawLine(c.translate(0, -8), c.translate(0, 8), thin);
  }

  @override
  bool shouldRepaint(_FramePainter old) => false;
}
