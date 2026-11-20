import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/dentra_mascot.dart';
import '../../../shared/widgets/guide_kit.dart';
import 'setup_device_stage.dart';
import 'setup_page.dart';

/// The original power-switch demonstration, with a short, scannable guide.
class QrSetupPrepare extends StatelessWidget {
  const QrSetupPrepare({super.key, required this.soundControl});

  final Widget soundControl;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
              child: Text('MEET YOUR DENTRA CAM',
                  style: GoogleFonts.outfit(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.7,
                      color: guideAccent)),
            ),
            soundControl,
          ]),
          const RabiSays(
              title: 'A little power.\nA closer look.',
              highlight: 'A little power.',
              body: 'Let’s get your Dentra Cam connected.',
              mood: MascotMood.point,
              aim: MascotAim.down,
              place: RabiPlace.right,
              size: 86),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) => SetupDeviceStage(
                scene: DeviceScene.power,
                height: (constraints.maxWidth * .64).clamp(180.0, 244.0)),
          ),
          const SizedBox(height: 20),
          const _PrepareStep(
              icon: Icons.power_settings_new_rounded,
              title: 'Power on your Dentra Cam',
              body:
                  'Slide the side switch to ON. Keep it powered during setup.'),
          const SizedBox(height: 16),
          const _PrepareStep(
              icon: Icons.wifi_rounded,
              title: 'Have your home Wi-Fi ready',
              body:
                  'You’ll need its name and password. Keep your phone online.'),
          const SizedBox(height: 16),
          const _PrepareStep(
              icon: Icons.qr_code_2_rounded,
              title: 'One code connects it all',
              body: 'Next, create a QR and show it to your Dentra Cam.'),
          const SizedBox(height: 20),
          const _SetupHelp(),
        ],
      );
}

class _PrepareStep extends StatelessWidget {
  const _PrepareStep({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon,
                  size: 22, color: AppColors.navy.withValues(alpha: .65)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.navy,
                        height: 1.25)),
                const SizedBox(height: 4),
                Text(body,
                    style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        height: 1.4,
                        color: AppColors.navy.withValues(alpha: .7))),
              ],
            ),
          ),
        ],
      );
}

class _SetupHelp extends StatelessWidget {
  const _SetupHelp();

  @override
  Widget build(BuildContext context) => Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
                top: BorderSide(color: guideAccent.withValues(alpha: .14))),
          ),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(left: 31, bottom: 12),
            minTileHeight: 48,
            visualDensity: VisualDensity.compact,
            expandedAlignment: Alignment.centerLeft,
            iconColor: guideAccent,
            collapsedIconColor: guideAccent,
            title: Row(children: [
              const Icon(Icons.help_outline_rounded,
                  size: 17, color: guideAccent),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Setting up again?',
                    style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: guideAccent)),
              ),
            ]),
            children: [
              Text(
                  'Hold the device button for 5 seconds to start setup again. '
                  'QR setup requires firmware v1.9.1 or later.',
                  style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      height: 1.5,
                      color: AppColors.navy.withValues(alpha: .7))),
            ],
          ),
        ),
      );
}
