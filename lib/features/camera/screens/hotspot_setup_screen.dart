import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_glass.dart';
import '../../../shared/widgets/app_backdrop.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../../shared/widgets/dentra_mascot.dart';
import '../../../shared/widgets/glass_card.dart';
import '../camera_strings.dart';
import '../data/saved_camera.dart';
import '../providers/camera_providers.dart';
import '../state/hotspot_setup_controller.dart';
import '../state/live_camera_controller.dart';
import '../widgets/camera_bits.dart';
import '../widgets/live_view.dart';
import '../widgets/setup_page.dart';
import 'camera_setup_screen.dart' show SetupOutcome;

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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _setup,
      builder: (context, _) {
        final step = _setup.step;
        return PopScope(
          canPop: !_setup.canGoBack,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _setup.back();
          },
          child: Scaffold(
            backgroundColor: AppColors.lightLavender,
            body: AppBackdrop(
              child: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SetupTopBar(
                          step: step.index,
                          total: HotspotStep.values.length,
                          label: CamText.hotspotStepNames[step.index],
                          onClose: () => _close(),
                        ),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: AppGlass.divider,
                        ),
                        Expanded(
                          child: SetupBody(
                            contentKey: ValueKey(step.name),
                            direction: _setup.direction,
                            child: _content(),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                          child: _buttons(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Content ─────────────────────────────────────────────────────

  Widget _content() => switch (_setup.step) {
        HotspotStep.welcome => _welcome(),
        HotspotStep.power => _power(),
        HotspotStep.join => _join(),
        HotspotStep.ready => _ready(),
      };

  static const _welcomeIcons = [
    Icons.battery_charging_full_rounded,
    Icons.wifi_password_rounded,
    Icons.router_outlined,
    Icons.open_in_browser_rounded,
  ];

  Widget _welcome() => SetupPage(
        step: 0,
        mood: MascotMood.wave,
        title: CamText.welcomeTitle,
        body: CamText.welcomeBody,
        rabi: CamText.hotspotWelcomeRabi,
        children: [
          for (var i = 0; i < CamText.hotspotWelcomeItems.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            CamInfoRow(
              icon: _welcomeIcons[i % _welcomeIcons.length],
              title: CamText.hotspotWelcomeItems[i].$1,
              body: CamText.hotspotWelcomeItems[i].$2,
            ),
          ],
        ],
      );

  Widget _power() => const SetupPage(
        step: 2,
        title: CamText.powerTitle,
        body: CamText.hotspotPowerBody,
        rabi: CamText.hotspotPowerRabi,
        children: [
          CamInfoRow(
            icon: Icons.restart_alt_rounded,
            title: CamText.powerResetTitle,
            body: CamText.hotspotPowerResetBody,
          ),
        ],
      );

  static const _joinIcons = [
    Icons.wifi_rounded,
    Icons.web_rounded,
    Icons.wifi_password_rounded,
    Icons.keyboard_return_rounded,
  ];

  Widget _join() {
    final state = _setup.codeState;
    final pairing = _setup.pairing;
    return SetupPage(
      step: 4,
      // Fetching the code, then pointing at it; worried if it's taking
      // too long or the code can't be used.
      mood: switch (state) {
        CodeState.loading => MascotMood.think,
        CodeState.failed || CodeState.expired => MascotMood.worried,
        CodeState.ready =>
          _setup.slow ? MascotMood.worried : MascotMood.point,
      },
      busy: state == CodeState.loading || state == CodeState.ready,
      title: CamText.hotspotJoinTitle,
      rabi: CamText.hotspotJoinRabi,
      children: [
        switch (state) {
          CodeState.loading => const CamBusyLine(CamText.hotspotGettingCode),
          CodeState.failed => const SetupNotice(body: CamText.hotspotCodeFailed),
          CodeState.expired => const SetupNotice(
              title: CamText.hotspotExpiredTitle,
              body: CamText.hotspotExpiredBody,
            ),
          CodeState.ready => _CodeCard(
              code: pairing!.displayCode,
              onCopy: () => _copy(pairing.code),
            ),
        },
        if (state == CodeState.ready) ...[
          for (var i = 0; i < CamText.hotspotSteps.length; i++)
            CamInfoRow(
              icon: _joinIcons[i % _joinIcons.length],
              title: '${i + 1}. ${CamText.hotspotSteps[i].$1}',
              body: CamText.hotspotSteps[i].$2,
            ),
          const CamBusyLine(CamText.hotspotWaiting),
          if (_setup.slow)
            const SetupNotice(
              title: CamText.hotspotSlowTitle,
              body: CamText.hotspotSlowBody,
            ),
        ],
      ],
    );
  }

  Future<void> _copy(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) showDentraSnack(context, CamText.hotspotCodeCopied);
  }

  Widget _ready() {
    final preview = _preview;
    return SetupPage(
      mood: MascotMood.cheer,
      title: CamText.successTitle,
      body: CamText.hotspotSuccessBody,
      rabi: CamText.successRabi,
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: ColoredBox(
              color: AppColors.lightLavender,
              child: preview == null
                  ? const Center(child: CamBusyCenter(CamText.connecting))
                  : ListenableBuilder(
                      listenable: preview,
                      builder: (context, _) => Stack(
                        fit: StackFit.expand,
                        children: [
                          LiveView(frames: preview.frame),
                          if (!preview.isLive)
                            const Center(
                              child: CamBusyCenter(CamText.connecting),
                            ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Buttons ─────────────────────────────────────────────────────

  Widget _buttons() {
    DentraPillButton back(VoidCallback onPressed, [String label = CamText.back]) =>
        DentraPillButton(
          label: label,
          variant: DentraButtonVariant.outline,
          onPressed: onPressed,
        );

    switch (_setup.step) {
      case HotspotStep.welcome:
        return DentraButtonRow(
          secondary: back(() => _close(), CamText.welcomeLater),
          primary: DentraPillButton(
            label: CamText.welcomeStart,
            onPressed: _setup.next,
          ),
        );
      case HotspotStep.power:
        return DentraButtonRow(
          secondary: back(_setup.back),
          primary: DentraPillButton(
            label: CamText.powerReady,
            onPressed: _setup.next,
          ),
        );
      case HotspotStep.join:
        final (String label, VoidCallback? action, bool busy) =
            switch (_setup.codeState) {
          CodeState.loading => (CamText.hotspotGettingCode, null, true),
          CodeState.failed => (
              CamText.tryAgain,
              () => unawaited(_setup.newCode()),
              false,
            ),
          CodeState.expired => (
              CamText.hotspotNewCode,
              () => unawaited(_setup.newCode()),
              false,
            ),
          CodeState.ready => (CamText.hotspotWaitingButton, null, true),
        };
        return DentraButtonRow(
          secondary: back(_setup.back),
          primary: DentraPillButton(
            label: label,
            loading: busy,
            loadingLabel: busy ? label : null,
            onPressed: action,
          ),
        );
      case HotspotStep.ready:
        return DentraButtonRow(
          secondary: back(() => _close(SetupOutcome.done), CamText.done),
          primary: DentraPillButton(
            label: CamText.startCapturing,
            icon: Icons.photo_camera_outlined,
            onPressed: () => _close(SetupOutcome.startCapturing),
          ),
        );
    }
  }
}

/// The pairing code, big enough to read across a room, with a copy button.
class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code, required this.onCopy});

  /// As shown, e.g. "K7P 2QX".
  final String code;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final spelled = code.replaceAll(' ', '').split('').join(', ');
    return GlassCard(
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  CamText.hotspotCodeLabel,
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Semantics(
                  label: '${CamText.hotspotCodeLabel}: $spelled',
                  excludeSemantics: true,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: SelectableText(
                      code,
                      maxLines: 1,
                      style: GoogleFonts.outfit(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  CamText.hotspotCodeHint,
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    color: AppColors.secondaryText,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onCopy,
            tooltip: CamText.hotspotCopyCode,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.white,
              foregroundColor: AppColors.primary,
              fixedSize: const Size(48, 48),
            ),
            icon: const Icon(Icons.copy_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}
