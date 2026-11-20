import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../../shared/widgets/dentra_mascot.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/guide_kit.dart';
import '../../../shared/widgets/mascot_stage.dart';
import '../camera_strings.dart';
import '../data/saved_camera.dart';
import '../providers/camera_providers.dart';
import '../state/hotspot_setup_controller.dart';
import '../state/live_camera_controller.dart';
import '../widgets/camera_bits.dart';
import '../widgets/setup_device_stage.dart';
import '../widgets/setup_page.dart';
import 'camera_setup_screen.dart' show SetupOutcome;
import 'camera_management_screen.dart';

/// The website's guide to putting the Dentra Cam on the home Wi-Fi and
/// linking it to the account. iPhone browsers have no Bluetooth, so the
/// camera takes the Wi-Fi from its own hotspot's setup page, along with a
/// code from here. Resolves to null when closed before the camera was
/// linked.
class HotspotSetupScreen extends ConsumerStatefulWidget {
  const HotspotSetupScreen({super.key});

  static Route<SetupOutcome> route() => MaterialPageRoute<SetupOutcome>(
        builder: (_) => const HotspotSetupScreen(),
      );

  @override
  ConsumerState<HotspotSetupScreen> createState() => _HotspotSetupScreenState();
}

class _HotspotSetupScreenState extends ConsumerState<HotspotSetupScreen> {
  late final HotspotSetupController _setup;
  late final AppLifecycleListener _lifecycle;
  CameraViewSettings _settings = const CameraViewSettings();

  /// The new camera's live picture on the last page.
  LiveCameraController? _preview;

  @override
  void initState() {
    super.initState();
    _setup = HotspotSetupController(
      api: ref.read(cloudCamApiProvider)!,
      onSaved: (camera) => ref.read(savedCameraProvider.notifier).save(camera),
    )..addListener(_onChanged);
    _lifecycle = AppLifecycleListener(
      onHide: () => _preview?.stop(),
      onShow: () => _preview?.start(),
    );
    unawaited(ref.read(cameraStoreProvider).loadSettings().then((s) {
      _settings = s;
    }));
  }

  void _onChanged() {
    final saved = _setup.saved;
    if (saved != null && _preview == null) {
      _preview = LiveCameraController(
        client: ref.read(cameraClientProvider)(saved),
        settings: _settings,
      )..start();
    }
  }

  @override
  void dispose() {
    _setup
      ..removeListener(_onChanged)
      ..dispose();
    _lifecycle.dispose();
    _preview?.dispose();
    super.dispose();
  }

  void _close([SetupOutcome? outcome]) {
    Navigator.of(context)
        .pop(outcome ?? (_setup.saved != null ? SetupOutcome.done : null));
  }

  /// One icon per step, for the rail.
  static const _stepIcons = [
    Icons.waving_hand_rounded,
    Icons.power_settings_new_rounded,
    Icons.wifi_rounded,
    Icons.check_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _setup,
      builder: (context, _) {
        final step = _setup.step;
        // The join step has two scenes: the code, and a code gone wrong.
        final sub = step == HotspotStep.join && _codeTrouble ? 'trouble' : '';
        return PopScope(
          canPop: !_setup.canGoBack,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _setup.back();
          },
          child: SetupFrame(
            step: step.index,
            icons: _stepIcons,
            label: CamText.hotspotStepNames[step.index],
            onClose: () => _close(),
            sceneKey: ValueKey('${step.name}-$sub'),
            direction: _setup.direction,
            scene: _scene(),
            actions: _actions(),
          ),
        );
      },
    );
  }

  bool get _codeTrouble =>
      _setup.codeState == CodeState.failed ||
      _setup.codeState == CodeState.expired;

  // ── Scenes ──────────────────────────────────────────────────────

  Widget _scene() => switch (_setup.step) {
        HotspotStep.welcome => const SetupWelcomeScene(
            items: CamText.hotspotWelcomeItems,
            icons: [
              Icons.battery_charging_full_rounded,
              Icons.wifi_password_rounded,
              Icons.open_in_browser_rounded,
            ],
          ),
        HotspotStep.power => const SetupPowerScene(
            body: CamText.hotspotPowerBody,
            reset: CamText.hotspotPowerReset,
          ),
        HotspotStep.join => _join(),
        HotspotStep.ready => SetupDoneScene(
            body: CamText.hotspotSuccessBody,
            preview: _preview,
          ),
      };

  Widget _join() {
    final pairing = _setup.pairing;
    if (_codeTrouble) {
      final expired = _setup.codeState == CodeState.expired;
      return SetupScene(
        centered: true,
        children: [
          RabiSays(
            place: RabiPlace.above,
            mood: MascotMood.worried,
            title: expired
                ? CamText.hotspotExpiredTitle
                : CamText.hotspotCodeFailedTitle,
            body: expired
                ? CamText.hotspotExpiredBody
                : CamText.hotspotCodeFailed,
            live: true,
          ),
        ],
      );
    }
    // Rabi waits down by the status while the user is away on the camera's
    // own page, so the code and what to do with it have the scene.
    final ready = pairing != null && _setup.codeState == CodeState.ready;
    return SetupScene(
      children: [
        const GuideWords(
          title: CamText.hotspotJoinTitle,
          highlight: CamText.hotspotJoinHighlight,
          large: true,
        ),
        const SizedBox(height: 16),
        SetupDeviceStage(
          scene: DeviceScene.hotspot,
          height:
              (MediaQuery.sizeOf(context).height * 0.19).clamp(132.0, 170.0),
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: camMotion(context),
          child: ready
              ? _CodeCard(
                  key: const ValueKey('code'),
                  code: pairing.code,
                  onCopy: () => _copy(pairing.code),
                )
              : const SizedBox(height: 118, width: double.infinity),
        ),
        const SizedBox(height: 22),
        SetupTimeline(
          steps: [
            for (var i = 0; i < CamText.hotspotSteps.length; i++)
              (
                _todoIcons[i % _todoIcons.length],
                CamText.hotspotSteps[i].$1,
                CamText.hotspotSteps[i].$2,
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          icon: const Icon(Icons.videocam_off_outlined),
          label: const Text(CamText.manageCameras),
          onPressed: () async {
            await Navigator.of(context)
                .push(CameraManagementScreen.route(allowSetup: false));
            if (mounted && _setup.step == HotspotStep.join) {
              await _setup.newCode();
            }
          },
        ),
        if (_setup.slow) ...[
          const SizedBox(height: 18),
          const SetupNotice(
            title: CamText.hotspotSlowTitle,
            body: CamText.hotspotSlowBody,
          ),
        ],
      ],
    );
  }

  /// One per thing to do on the camera's page.
  static const _todoIcons = [
    Icons.wifi_rounded,
    Icons.open_in_browser_rounded,
    Icons.password_rounded,
    Icons.keyboard_return_rounded,
  ];

  Future<void> _copy(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) showDentraSnack(context, CamText.hotspotCodeCopied);
  }

  // ── Actions ─────────────────────────────────────────────────────

  Widget _actions() {
    final back = GuideBackButton(onPressed: _setup.back, label: CamText.back);
    Widget primary(String label, VoidCallback onPressed, {IconData? icon}) =>
        GuidePrimaryButton(
          key: ValueKey(label),
          label: label,
          icon: icon,
          onPressed: onPressed,
        );

    switch (_setup.step) {
      case HotspotStep.welcome:
        return GuideActions(
          leading: GuideQuietButton(
            label: CamText.welcomeLater,
            onPressed: () => _close(),
          ),
          trailing: primary(CamText.welcomeStart, _setup.next),
        );
      case HotspotStep.power:
        return GuideActions(
          leading: back,
          trailing: primary(CamText.powerReady, _setup.next),
        );
      case HotspotStep.join:
        return GuideActions(
          leading: back,
          trailing: switch (_setup.codeState) {
            CodeState.failed =>
              primary(CamText.tryAgain, () => unawaited(_setup.newCode())),
            CodeState.expired => primary(
                CamText.hotspotNewCode,
                () => unawaited(_setup.newCode()),
              ),
            // Nothing to press: Rabi waits here with the status.
            CodeState.loading || CodeState.ready => Row(
                key: const ValueKey('waiting'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: _setup.codeState == CodeState.loading
                        ? const GuideStatus(CamText.hotspotGettingCode)
                        : const GuideStatus(
                            CamText.hotspotWaiting,
                            semanticLabel: CamText.hotspotWaitingFor,
                          ),
                  ),
                  const SizedBox(width: 6),
                  MascotSpot(
                    size: 64,
                    mood: _setup.codeState == CodeState.loading
                        ? MascotMood.think
                        : MascotMood.wait,
                  ),
                ],
              ),
          },
        );
      case HotspotStep.ready:
        return GuideActions(
          leading: GuideQuietButton(
            label: CamText.done,
            onPressed: () => _close(SetupOutcome.done),
          ),
          trailing: primary(
            CamText.startCapturing,
            () => _close(SetupOutcome.startCapturing),
            icon: Icons.photo_camera_outlined,
          ),
        );
    }
  }
}

/// The pairing code as six letter tiles, big enough to read across a room,
/// with how long it lasts and a Copy action. Tapping the tiles copies too.
class _CodeCard extends StatelessWidget {
  const _CodeCard({super.key, required this.code, required this.onCopy});

  /// Without spaces, e.g. "K7P2QX".
  final String code;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final letters = code.split('');
    final spelled = letters.join(', ');
    final half = (letters.length / 2).ceil();
    final motion = dentraMotion(context, 640);
    return GlassCard(
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          CamText.hotspotCodeLabel,
                          maxLines: 1,
                          softWrap: false,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Semantics(
                      label: CamText.hotspotCodeHint,
                      excludeSemantics: true,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            size: 14,
                            color: AppColors.secondaryText,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            CamText.hotspotCodeTime,
                            style: GoogleFonts.outfit(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onCopy,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  minimumSize: const Size(48, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  textStyle: GoogleFonts.outfit(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                icon: const Icon(Icons.copy_rounded, size: 17),
                label: Semantics(
                  label: CamText.hotspotCopyCode,
                  excludeSemantics: true,
                  child: const Text(CamText.hotspotCopy),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Semantics(
              button: true,
              label: '${CamText.hotspotCodeLabel}: $spelled',
              hint: CamText.hotspotCopyCode,
              excludeSemantics: true,
              child: GestureDetector(
                key: ValueKey('pairing-code $code'),
                onTap: onCopy,
                child: LayoutBuilder(builder: (context, constraints) {
                  const gap = 7.0, split = 18.0;
                  final tile = ((constraints.maxWidth -
                              gap * (letters.length - 2) -
                              split) /
                          letters.length)
                      .clamp(28.0, 52.0);
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < letters.length; i++) ...[
                        if (i > 0) SizedBox(width: i == half ? split : gap),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: motion,
                          curve: Interval(
                            i * 0.08,
                            0.5 + i * 0.08,
                            curve: Curves.easeOutBack,
                          ),
                          builder: (context, v, child) => Opacity(
                            opacity: v.clamp(0.0, 1.0),
                            child: Transform.translate(
                              offset: Offset(0, 8 * (1 - v)),
                              child: child,
                            ),
                          ),
                          child: _Tile(letters[i], size: tile),
                        ),
                      ],
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One letter of the code on a white tile.
class _Tile extends StatelessWidget {
  const _Tile(this.letter, {required this.size});

  final String letter;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size * 1.22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.white, Color(0xFFF2FBFA)],
        ),
        border: Border.all(color: AppColors.g2.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: AppColors.g2.withValues(alpha: 0.14),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          letter,
          style: GoogleFonts.outfit(
            fontSize: size * 0.56,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
      ),
    );
  }
}
