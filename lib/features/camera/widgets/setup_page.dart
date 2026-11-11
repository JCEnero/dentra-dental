import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../dental_profile/widgets/question_block.dart'
    show QuestionnaireProgress;
import '../camera_strings.dart';
import 'camera_bits.dart';

// The frame both setup guides share: over Bluetooth in the phone apps, and
// through the camera's hotspot on the website.

/// The guide's title, its progress, and a close button.
class SetupTopBar extends StatelessWidget {
  const SetupTopBar({
    super.key,
    required this.step,
    required this.total,
    required this.label,
    required this.onClose,
  });

  final int step;
  final int total;

  /// The step's name, read out with the progress line.
  final String label;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  CamText.setupTitle,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 8),
                QuestionnaireProgress(step: step, total: total, label: label),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onClose,
            tooltip: CamText.closeSetup,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.white.withValues(alpha: 0.7),
              foregroundColor: AppColors.navy,
              fixedSize: const Size(44, 44),
            ),
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

/// The scrolling area under the top bar. A new [contentKey] slides the
/// content in from the side the guide is heading to ([direction] 1 or -1).
class SetupBody extends StatelessWidget {
  const SetupBody({
    super.key,
    required this.contentKey,
    required this.direction,
    required this.child,
  });

  final Key contentKey;
  final int direction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final motion = camMotion(context);
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: AnimatedSize(
        duration: motion,
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: motion,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [
              for (final old in previous)
                Positioned(top: 0, left: 0, right: 0, child: old),
              if (current != null) current,
            ],
          ),
          transitionBuilder: (child, animation) {
            // In from the side we're heading to; out toward the other.
            final incoming = child.key == contentKey;
            final dx = 0.12 * direction * (incoming ? 1 : -1);
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(begin: Offset(dx, 0), end: Offset.zero)
                    .animate(animation),
                child: child,
              ),
            );
          },
          child: KeyedSubtree(key: contentKey, child: child),
        ),
      ),
    );
  }
}

/// One step's layout: picture, title, text, its own content, then Rabi.
class SetupPage extends StatelessWidget {
  const SetupPage({
    super.key,
    this.art,
    required this.title,
    this.body,
    required this.rabi,
    this.children = const [],
  });

  final Widget? art;
  final String title;
  final String? body;
  final String rabi;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (art != null) ...[art!, const SizedBox(height: 8)],
        Semantics(
          header: true,
          child: Text(title, style: camTitleStyle()),
        ),
        if (body != null) ...[
          const SizedBox(height: 6),
          Text(body!, style: camBodyStyle()),
        ],
        for (final child in children) ...[
          const SizedBox(height: 14),
          child,
        ],
        const SizedBox(height: 22),
        RabiTip(rabi),
      ],
    );
  }
}

/// A soft teal panel for something to know or do.
class SetupNotice extends StatelessWidget {
  const SetupNotice({super.key, this.title, required this.body});

  final String? title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
        decoration: BoxDecoration(
          color: AppColors.g2.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.g2.withValues(alpha: 0.26)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) ...[
                    Text(
                      title!,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 3),
                  ],
                  Text(
                    body,
                    style: GoogleFonts.outfit(
                      fontSize: 13.5,
                      color: AppColors.navy,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
