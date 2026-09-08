import 'package:flutter/material.dart';

/// DENTRA official color system — matches the web frontend exactly.
abstract class AppColors {
  // ── Primary gradient stops ───────────────────────────────────
  static const Color g1 = Color(0xFF6250D0); // gradient start
  static const Color g2 = Color(0xFF3A24A0); // gradient end

  // ── Card / surface tones ─────────────────────────────────────
  static const Color cardSolid    = Color(0xFF6250D0);
  static const Color cardSolidAlt = Color(0xFF6A58D8);
  static const Color cardDeep     = Color(0xFF3A24A0);

  // ── Neutrals ─────────────────────────────────────────────────
  static const Color lavender      = Color(0xFFE9E7FF);
  static const Color lightLavender = Color(0xFFF5F4FF);
  static const Color white         = Color(0xFFFFFFFF);
  static const Color offWhite      = Color(0xFFFAFAFF);
  static const Color navy          = Color(0xFF171735);
  static const Color secondaryText = Color(0xFF6F7085);
  static const Color border        = Color(0xFFE7E7F0);

  // ── Aliases ───────────────────────────────────────────────────
  static const Color primary = g1;

  // ── Gradients ─────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [g1, g2],
  );

  static const LinearGradient verticalGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [g1, g2],
  );

  static const LinearGradient horizontalGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [g1, g2],
  );

  // ── Helper: card surface gradient for embossed look ───────────
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [g1, g2],
  );

  // ── Page background: soft purple tint → near-white ────────────
  // Mimics the reference UI — subtle lavender at top blending
  // smoothly into an almost-white base.
  static const LinearGradient pageBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFEBE8FF), Color(0xFFF8F7FF)],
    stops: [0.0, 0.55],
  );
}
