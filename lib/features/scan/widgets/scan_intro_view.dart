import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/models/captured_image.dart';
import 'device_reach_panel.dart';
import 'how_it_works_card.dart';
import 'scan_hero.dart';
import 'scan_theme.dart';

/// Before the scan: the device, how to get it ready, and how a scan works.
class ScanIntroView extends StatelessWidget {
  const ScanIntroView({
    super.key,
    required this.source,
    this.heroHeight = 300,
    this.deviceStatus,
  });

  /// What this scan will capture with.
  final CaptureSource source;

  final double heroHeight;

  /// The device's connection card, in builds that can pair with one.
  final Widget? deviceStatus;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Reveal(child: ScanHero(height: heroHeight, source: source)),
        if (deviceStatus != null) ...[
          const SizedBox(height: 12),
          Reveal(
            delay: const Duration(milliseconds: 60),
            child: deviceStatus!,
          ),
        ],
        const SizedBox(height: 22),
        const Reveal(
          delay: Duration(milliseconds: 100),
          child: _Section(title: 'Before you start', child: _Prep()),
        ),
        const SizedBox(height: 22),
        const Reveal(
          delay: Duration(milliseconds: 180),
          child: _Section(title: 'How it works', child: HowItWorksCard()),
        ),
        const SizedBox(height: 16),
        const Reveal(delay: Duration(milliseconds: 240), child: _Disclaimer()),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScanSectionTitle(title),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

// ── Before you start ──────────────────────────────────────────────

/// What the device can reach, then four tips for getting it ready: two columns
/// of tiles, or one when the text is too large.
class _Prep extends StatelessWidget {
  const _Prep();

  static const _tips = [
    _ReadyTile(
      icon: Icons.battery_charging_full_rounded,
      label: 'Keep it charged',
      hint: 'Top it up over USB-C before you scan.',
    ),
    _ReadyTile(
      icon: Icons.cleaning_services_outlined,
      label: 'Wipe the tip',
      hint: 'A clean, dry lens keeps every image sharp.',
    ),
    _ReadyTile(
      icon: Icons.light_mode_outlined,
      label: 'Lights are built in',
      hint: 'Lights around the lens brighten your teeth for you.',
    ),
    _ReadyTile(
      icon: Icons.back_hand_outlined,
      label: 'Hold it still',
      hint: 'Each capture takes a photo, then a NIR frame. Stay steady for '
          'both.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DeviceReachPanel(),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, constraints) {
          if (constraints.maxWidth / scale < 310) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final tip in _tips) ...[
                  tip,
                  if (tip != _tips.last) const SizedBox(height: 10),
                ],
              ],
            );
          }
          return Column(
            children: [
              for (var i = 0; i < _tips.length; i += 2) ...[
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _tips[i]),
                      const SizedBox(width: 10),
                      Expanded(child: _tips[i + 1]),
                    ],
                  ),
                ),
                if (i + 2 < _tips.length) const SizedBox(height: 10),
              ],
            ],
          );
        }),
      ],
    );
  }
}

class _ReadyTile extends StatelessWidget {
  const _ReadyTile({
    required this.icon,
    required this.label,
    required this.hint,
  });

  final IconData icon;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: const BorderRadius.all(Radius.circular(20)),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScanIconDisc(icon),
          const SizedBox(height: 10),
          _TipLabel(label),
          const SizedBox(height: 3),
          _TipHint(hint),
        ],
      ),
    );
  }
}

class _TipLabel extends StatelessWidget {
  const _TipLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        height: 1.25,
        color: AppColors.navy,
      ),
    );
  }
}

class _TipHint extends StatelessWidget {
  const _TipHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        fontSize: 12,
        height: 1.36,
        color: AppColors.secondaryText,
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        'Screening information is not a diagnosis. If you have concerns about '
        'your oral health, consider speaking with a licensed dentist.',
        textAlign: TextAlign.center,
        style: GoogleFonts.outfit(
          fontSize: 11.5,
          height: 1.45,
          color: AppColors.secondaryText,
        ),
      ),
    );
  }
}
