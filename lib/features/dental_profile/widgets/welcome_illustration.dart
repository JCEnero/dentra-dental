import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../onboarding/widgets/visuals/tooth_glyph.dart';

/// A tooth in soft mint rings with a small check badge: the welcome
/// slide's only decoration. Same line art as the intro tour.
class WelcomeIllustration extends StatelessWidget {
  const WelcomeIllustration({super.key, this.size = 148});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: const CustomPaint(painter: _WelcomePainter()),
      ),
    );
  }
}

class _WelcomePainter extends CustomPainter {
  const _WelcomePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2;

    // Faint outer ring and a filled inner disc.
    canvas.drawCircle(
      center,
      r - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = AppColors.g2.withValues(alpha: 0.12),
    );
    canvas.drawCircle(
      center,
      r * 0.78,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.white,
            AppColors.mintGreen.withValues(alpha: 0.55),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: r * 0.78)),
    );

    // The tooth.
    final tooth = ToothGlyph.rectAt(center.translate(0, 2), r * 0.82);
    canvas.drawPath(
        ToothGlyph.outline(tooth), Paint()..color = AppColors.white);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = AppColors.g2;
    canvas.drawPath(ToothGlyph.outline(tooth), line);
    canvas.drawPath(
      ToothGlyph.cervicalLine(tooth),
      line
        ..strokeWidth = 1.8
        ..color = AppColors.g2.withValues(alpha: 0.45),
    );

    // Check badge, lower right.
    final badge = center.translate(r * 0.52, r * 0.50);
    final badgeR = r * 0.2;
    canvas.drawCircle(badge, badgeR + 3, Paint()..color = AppColors.white);
    canvas.drawCircle(
      badge,
      badgeR,
      Paint()
        ..shader = AppColors.cardGradient
            .createShader(Rect.fromCircle(center: badge, radius: badgeR)),
    );
    paintCheckMark(canvas, badge, badgeR, AppColors.white, strokeWidth: 2.4);
  }

  @override
  bool shouldRepaint(_WelcomePainter oldDelegate) => false;
}
