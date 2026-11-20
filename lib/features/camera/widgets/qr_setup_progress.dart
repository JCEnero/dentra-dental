import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../../shared/widgets/dentra_mascot.dart';
import '../../../shared/widgets/glass_card.dart';
import '../state/qr_setup_controller.dart';
import 'setup_page.dart';
import 'qr_scan_scene.dart';

/// A single glass sheet: Rabi, the readable code, and a quiet how-to scene.
/// Confirmed states come only from the controller's device observations.
class QrSetupProgress extends StatelessWidget {
  const QrSetupProgress(
      {super.key,
      required this.phase,
      required this.deviceFound,
      required this.qrConfirmed,
      this.waitingLong = false,
      this.qrData,
      this.soundControl});
  final QrSetupPhase phase;
  final bool deviceFound, qrConfirmed, waitingLong;
  final String? qrData;
  final Widget? soundControl;

  @override
  Widget build(BuildContext context) {
    final done = phase == QrSetupPhase.ready;
    final expired = phase == QrSetupPhase.expired;
    final state = expired
        ? 'expired'
        : done
            ? 'ready'
            : qrConfirmed
                ? 'checking'
                : deviceFound
                    ? 'connecting'
                    : waitingLong
                        ? 'help'
                        : 'scanning';
    final title = expired
        ? 'A fresh start?'
        : done
            ? 'You’re all\nconnected.'
            : qrConfirmed
                ? 'Got it. One last check.'
                : deviceFound
                    ? 'Your camera found us.'
                    : waitingLong
                        ? 'Let’s try a little closer.'
                        : 'Let your camera take a look.';
    final body = expired
        ? 'Create a new QR to keep going.'
        : done
            ? 'Your Dentra Cam is verified and ready.'
            : qrConfirmed
                ? 'The code matches. I’m checking the camera.'
                : deviceFound
                    ? 'Finishing the connection to your account.'
                    : waitingLong
                        ? 'Brighten your screen and adjust the camera’s distance.'
                        : 'Point the Dentra lens at this code and hold steady.';
    final mood = expired || waitingLong
        ? MascotMood.worried
        : done
            ? MascotMood.cheer
            : qrConfirmed
                ? MascotMood.watch
                : deviceFound
                    ? MascotMood.think
                    : MascotMood.point;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      borderRadius: const BorderRadius.all(Radius.circular(30)),
      borderWidth: 1.4,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        RabiSays(
            key: ValueKey('qr-rabi-$state'),
            title: title,
            body: body,
            mood: mood,
            aim: MascotAim.down,
            place: RabiPlace.right,
            size: 78,
            live: true,
            compact: true),
        if (!expired && !done && !qrConfirmed && qrData != null) ...[
          const SizedBox(height: 18),
          Center(child: CompactSetupQr(data: qrData!)),
        ],
        const SizedBox(height: 10),
        QrScanScene(
            key: const ValueKey('qr-device-model'),
            confirmed: qrConfirmed,
            connected: done,
            paused: expired,
            height: qrConfirmed || done ? 174 : 124),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
              child: Semantics(
                  liveRegion: true,
                  child: Text(
                      expired
                          ? 'Setup code expired'
                          : done
                              ? 'Connected · camera verified'
                              : qrConfirmed
                                  ? 'QR confirmed · checking camera'
                                  : deviceFound
                                      ? 'Device found · connecting'
                                      : 'Waiting for your camera',
                      key: const ValueKey('qr-progress-title'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)))),
          if (soundControl != null) soundControl!,
        ]),
        if (!deviceFound && !expired && !done) ...[
          const SizedBox(height: 8),
          const Text('Confirmation appears once your device reaches Wi-Fi.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11, height: 1.4, color: AppColors.secondaryText)),
        ],
      ]),
    );
  }
}

/// The quiet zone and data modules stay square, opaque, and high contrast.
/// Styling belongs to the glass surround, never over the machine-readable area.
class CompactSetupQr extends StatelessWidget {
  const CompactSetupQr({super.key, required this.data, this.expanded = false});
  final String data;
  final bool expanded;
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, expanded ? 340.0 : 220.0);
        return SizedBox(
            width: size,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: DecoratedBox(
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: AppColors.g2.withValues(alpha: .12))),
                      child: QrImageView(
                          key: expanded
                              ? const ValueKey('expanded-setup-qr')
                              : const ValueKey('setup-qr'),
                          data: data,
                          size: size,
                          padding: const EdgeInsets.all(20),
                          backgroundColor: Colors.white,
                          gapless: true,
                          eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: AppColors.navy),
                          dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: AppColors.navy),
                          errorCorrectionLevel: QrErrorCorrectLevel.M,
                          semanticsLabel:
                              'Dentra Wi-Fi setup QR. Contains your Wi-Fi password. Show it to your device camera.'))),
              if (!expanded)
                TextButton.icon(
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary),
                    onPressed: () => showGlassSheet<void>(
                        context: context,
                        title: 'A closer look',
                        subtitle: 'Keep the phone bright and steady.',
                        builder: (_) => Center(
                            child: CompactSetupQr(data: data, expanded: true))),
                    icon: const Icon(Icons.open_in_full_rounded, size: 13),
                    label: const Text('Enlarge code',
                        style: TextStyle(fontSize: 11))),
            ]));
      });
}
