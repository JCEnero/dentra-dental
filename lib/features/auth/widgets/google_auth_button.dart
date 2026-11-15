import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';

/// Google sign-in on a frosted glass bar: the "G" and the label centred,
/// a hairline teal rim, and a soft press.
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

  static const BorderRadius _radius = BorderRadius.all(Radius.circular(16));

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !isLoading;
    // One labelled button for screen readers; the spinner replaces the
    // visible text while loading, so the label says what is happening.
    return Semantics(
      button: true,
      enabled: enabled,
      label: isLoading ? 'Signing in with Google…' : label,
      onTap: enabled ? onTap : null,
      excludeSemantics: true,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: onTap == null && !isLoading ? 0.5 : 1,
        child: SizedBox(
          width: double.infinity,
          child: Material(
            color: AppColors.white.withValues(alpha: 0.78),
            shape: RoundedRectangleBorder(
              borderRadius: _radius,
              side: BorderSide(color: AppColors.g2.withValues(alpha: 0.16)),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: isLoading ? null : onTap,
              splashColor: AppColors.g1.withValues(alpha: 0.14),
              highlightColor: AppColors.g1.withValues(alpha: 0.06),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
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
                              AppColors.primary,
                            ),
                          ),
                        )
                      else ...[
                        // Google "G" logo, drawn with Canvas for zero
                        // dependencies.
                        CustomPaint(
                          size: const Size(18, 18),
                          painter: _GoogleGPainter(),
                        ),
                        const SizedBox(width: 10),
                        // Wraps instead of overflowing on narrow screens or
                        // with large accessibility text.
                        Flexible(
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.navy,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
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
