import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';

/// Google authentication button that matches the DENTRA design system.
/// Renders a white outlined button with the Google "G" logo and a label.
class GoogleAuthButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;

  const GoogleAuthButton({
    super.key,
    required this.label,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: AppRadius.mdAll,
          child: Ink(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: AppRadius.mdAll,
              border: Border.all(
                color: AppColors.border,
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isLoading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.secondaryText,
                        ),
                      ),
                    )
                  else ...[
                    // Google "G" logo — hand-drawn with Canvas for zero dependency
                    CustomPaint(
                      size: const Size(18, 18),
                      painter: _GoogleGPainter(),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      label,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.navy,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Draws the Google "G" logo using only Flutter's Canvas API.
class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background circle (white)
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = Colors.white,
    );

    // Google G segments: (startAngle, sweepAngle, color)
    final segments = <(double, double, Color)>[
      (0.0, 1.22, const Color(0xFF4285F4)), // blue — right, top
      (1.22, 1.05, const Color(0xFF34A853)), // green — bottom-right
      (2.27, 1.05, const Color(0xFFFBBC05)), // yellow — bottom-left
      (3.32, 0.96, const Color(0xFFEA4335)), // red — top-left
    ];

    final segPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.22
      ..strokeCap = StrokeCap.butt;

    final arcRect = Rect.fromCircle(
      center: center,
      radius: radius * 0.72,
    );

    for (final (start, sweep, color) in segments) {
      segPaint.color = color;
      canvas.drawArc(arcRect, start, sweep, false, segPaint);
    }

    // Horizontal bar of the G
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = size.width * 0.22
      ..strokeCap = StrokeCap.square;

    canvas.drawLine(
      Offset(center.dx, center.dy - 0.5),
      Offset(center.dx + radius * 0.55, center.dy - 0.5),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(_GoogleGPainter old) => false;
}
