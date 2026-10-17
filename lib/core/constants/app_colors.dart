import 'package:flutter/material.dart';

/// DENTRA official color system — teal/coral dental palette.
abstract class AppColors {
  // ── Primary teal stops ────────────────────────────────────────
  // Bright cyan-mint → medium teal (matches reference card)
  static const Color g1 = Color(0xFF4DD8C8); // bright cyan-mint (light end)
  static const Color g2 = Color(0xFF2CA6A4); // medium teal (dark end)

  // ── Card / surface tones ──────────────────────────────────────
  static const Color cardSolid    = Color(0xFF3BBFB8); // mid teal
  static const Color cardSolidAlt = Color(0xFF4DD8C8); // bright teal-cyan
  static const Color cardDeep     = Color(0xFF2CA6A4); // deeper teal

  // ── Neutrals ──────────────────────────────────────────────────
  static const Color lavender      = Color(0xFFB2EDE7); // light mint
  static const Color lightLavender = Color(0xFFE8F8F7); // very light mint bg
  static const Color white         = Color(0xFFFFFFFF);
  static const Color offWhite      = Color(0xFFFAFAF8);
  static const Color navy          = Color(0xFF1A2E35); // dark navy/charcoal
  static const Color secondaryText = Color(0xFF6B7B80); // medium gray
  static const Color border        = Color(0xFFE0E5E4); // light gray

  // ── Accent / highlight ────────────────────────────────────────
  static const Color coral         = Color(0xFFE8896A); // coral/orange accent
  static const Color warmOrange    = Color(0xFFF4A261); // warm orange
  static const Color mintGreen     = Color(0xFFA8E6DF); // mint
  static const Color peachBg       = Color(0xFFF5D5C0); // soft peach background
  static const Color successGreen  = Color(0xFF4CAF93); // health score green

  /// Destructive actions (log out, delete). Dark enough for 4.5:1 text
  /// contrast on white and glass surfaces.
  static const Color danger        = Color(0xFFCF4141);

  // ── Aliases ───────────────────────────────────────────────────
  static const Color primary = g2; // use medium teal as primary for text/icons

  // ── Gradients ─────────────────────────────────────────────────

  // Main brand gradient — bright cyan-mint → medium teal (left→right like reference)
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [g1, g2],
  );

  // Top-left → bottom-right for cards (matches reference appointment card)
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF5DE0D0), // bright cyan-mint highlight
      Color(0xFF2CA6A4), // medium teal base
    ],
  );

  // Vertical variant (headers / scan screen)
  static const LinearGradient verticalGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF4DD8C8), // bright top
      Color(0xFF2CA6A4), // medium teal bottom
    ],
  );

  static const LinearGradient horizontalGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [g1, g2],
  );

  // ── Page background: very light mint tint → white ─────────────
  static const LinearGradient pageBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFEAFAF8), Color(0xFFF8FDFB)],
    stops: [0.0, 0.6],
  );
}
