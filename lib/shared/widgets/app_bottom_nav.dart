import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

// ── Icon painters (color-parameterised) ────────────────────────

class _HomePainter extends CustomPainter {
  final Color color;
  const _HomePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = _sp(color);
    final s = size.width / 24;
    final house = Path()
      ..moveTo(3 * s, 9.5 * s)
      ..lineTo(12 * s, 3 * s)
      ..lineTo(21 * s, 9.5 * s)
      ..lineTo(21 * s, 20 * s)
      ..lineTo(4 * s, 20 * s)
      ..lineTo(3 * s, 20 * s)
      ..close();
    canvas.drawPath(house, p);
    final door = Path()
      ..moveTo(9 * s, 21 * s)
      ..lineTo(9 * s, 12 * s)
      ..lineTo(15 * s, 12 * s)
      ..lineTo(15 * s, 21 * s);
    canvas.drawPath(door, p);
  }

  @override
  bool shouldRepaint(_HomePainter old) => old.color != color;
}

class _ScanPainter extends CustomPainter {
  final Color color;
  const _ScanPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = _sp(color);
    final s = size.width / 24;
    canvas.drawCircle(Offset(12 * s, 12 * s), 3 * s, p);
    // top-left bracket
    _bracket(canvas, p, 3 * s, 7 * s, 7 * s, 3 * s, s);
    // top-right bracket
    _bracket(canvas, p, 21 * s, 7 * s, 17 * s, 3 * s, s);
    // bottom-right bracket
    _bracket(canvas, p, 21 * s, 17 * s, 17 * s, 21 * s, s);
    // bottom-left bracket
    _bracket(canvas, p, 3 * s, 17 * s, 7 * s, 21 * s, s);
  }

  void _bracket(Canvas c, Paint p, double x1, double y1, double x2, double y2, double s) {
    final path = Path()
      ..moveTo(x1, y1)
      ..lineTo(x1, (y1 + y2) / 2)
      ..moveTo(x1, y1)
      ..lineTo((x1 + x2) / 2, y1);
    c.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_ScanPainter old) => old.color != color;
}

class _HistoryPainter extends CustomPainter {
  final Color color;
  const _HistoryPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = _sp(color);
    final s = size.width / 24;
    canvas.drawCircle(Offset(12 * s, 12 * s), 9 * s, p);
    final clock = Path()
      ..moveTo(12 * s, 7 * s)
      ..lineTo(12 * s, 12 * s)
      ..lineTo(15 * s, 15 * s);
    canvas.drawPath(clock, p);
  }

  @override
  bool shouldRepaint(_HistoryPainter old) => old.color != color;
}

class _ClinicsPainter extends CustomPainter {
  final Color color;
  const _ClinicsPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = _sp(color);
    final s = size.width / 24;
    // Pin teardrop
    final path = Path();
    path.addOval(Rect.fromCircle(center: Offset(12 * s, 10 * s), radius: 9 * s));
    // Overdraw lower portion to make teardrop shape
    final pin = Path()
      ..moveTo(3 * s, 10 * s)
      ..arcToPoint(
        Offset(21 * s, 10 * s),
        radius: Radius.circular(9 * s),
        clockwise: false,
      )
      ..cubicTo(21 * s, 16 * s, 12 * s, 23 * s, 12 * s, 23 * s)
      ..cubicTo(12 * s, 23 * s, 3 * s, 16 * s, 3 * s, 10 * s);
    canvas.drawPath(pin, p);
    canvas.drawCircle(Offset(12 * s, 10 * s), 3 * s, p);
  }

  @override
  bool shouldRepaint(_ClinicsPainter old) => old.color != color;
}

class _ProfilePainter extends CustomPainter {
  final Color color;
  const _ProfilePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = _sp(color);
    final s = size.width / 24;
    canvas.drawCircle(Offset(12 * s, 7 * s), 4 * s, p);
    final body = Path()
      ..moveTo(20 * s, 21 * s)
      ..lineTo(20 * s, 19 * s)
      ..arcToPoint(
        Offset(16 * s, 15 * s),
        radius: Radius.circular(4 * s),
        clockwise: false,
      )
      ..lineTo(8 * s, 15 * s)
      ..arcToPoint(
        Offset(4 * s, 19 * s),
        radius: Radius.circular(4 * s),
        clockwise: false,
      )
      ..lineTo(4 * s, 21 * s);
    canvas.drawPath(body, p);
  }

  @override
  bool shouldRepaint(_ProfilePainter old) => old.color != color;
}

Paint _sp(Color c) => Paint()
  ..color = c
  ..strokeWidth = 2.0
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..style = PaintingStyle.stroke;

// ── Bottom navigation ──────────────────────────────────────────

class AppBottomNav extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({
    super.key,
    required this.activeIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final onHome = activeIndex == 0;

    final List<CustomPainter Function(Color)> painterFactories = [
      (c) => _HomePainter(c),
      (c) => _ScanPainter(c),
      (c) => _HistoryPainter(c),
      (c) => _ClinicsPainter(c),
      (c) => _ProfilePainter(c),
    ];

    return Container(
      decoration: BoxDecoration(
        gradient: onHome ? AppColors.verticalGradient : null,
        color: onHome ? null : AppColors.white,
        border: Border(
          top: BorderSide(
            color: onHome
                ? Colors.white.withValues(alpha: 0.10)
                : AppColors.border,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: List.generate(5, (i) {
              final isActive = i == activeIndex;
              final activeColor   = onHome ? Colors.white : AppColors.g1;
              final inactiveColor = onHome
                  ? Colors.white.withValues(alpha: 0.38)
                  : AppColors.secondaryText;
              final activeBg = onHome
                  ? Colors.white.withValues(alpha: 0.14)
                  : AppColors.lightLavender;

              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 7),
                      decoration: BoxDecoration(
                        color: isActive ? activeBg : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: CustomPaint(
                        painter: painterFactories[i](
                            isActive ? activeColor : inactiveColor),
                        size: const Size(22, 22),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
