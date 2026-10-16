import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';

/// DENTRA brand logo — tooth icon + wordmark.
/// [onDark] renders white text for use on gradient/dark backgrounds.
/// [size] scales the whole component (default 1.0).
class DentraLogo extends StatelessWidget {
  final bool onDark;
  final double size;

  const DentraLogo({
    super.key,
    this.onDark = false,
    this.size = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = 28.0 * size;
    final fontSize = 22.0 * size;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Tooth icon badge
        Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(
            gradient: onDark ? null : AppColors.primaryGradient,
            color: onDark ? Colors.white.withValues(alpha: 0.18) : null,
            borderRadius: BorderRadius.circular(7 * size),
          ),
          child: Center(
            child: CustomPaint(
              size: Size(iconSize * 0.58, iconSize * 0.64),
              painter: _ToothIconPainter(
                color: onDark ? Colors.white : Colors.white,
              ),
            ),
          ),
        ),
        SizedBox(width: 8 * size),
        // Wordmark
        Text(
          'DENTRA',
          style: GoogleFonts.outfit(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            color: onDark ? Colors.white : AppColors.navy,
            letterSpacing: 1.2,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

class _ToothIconPainter extends CustomPainter {
  final Color color;
  const _ToothIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // Simplified tooth silhouette using a smooth path
    final path = Path();
    // Crown — rounded trapezoid shape
    path.moveTo(w * 0.18, h * 0.0);
    path.cubicTo(w * 0.0, h * 0.0, w * 0.0, h * 0.22, w * 0.04, h * 0.30);
    path.cubicTo(w * 0.08, h * 0.38, w * 0.10, h * 0.48, w * 0.12, h * 0.60);
    // Right root
    path.cubicTo(w * 0.13, h * 0.72, w * 0.18, h * 1.0, w * 0.30, h * 1.0);
    path.cubicTo(w * 0.42, h * 1.0, w * 0.46, h * 0.80, w * 0.50, h * 0.68);
    // Center valley
    path.cubicTo(w * 0.54, h * 0.80, w * 0.58, h * 1.0, w * 0.70, h * 1.0);
    path.cubicTo(w * 0.82, h * 1.0, w * 0.87, h * 0.72, w * 0.88, h * 0.60);
    // Left root
    path.cubicTo(w * 0.90, h * 0.48, w * 0.92, h * 0.38, w * 0.96, h * 0.30);
    path.cubicTo(w * 1.0, h * 0.22, w * 1.0, h * 0.0, w * 0.82, h * 0.0);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ToothIconPainter old) => old.color != color;
}
