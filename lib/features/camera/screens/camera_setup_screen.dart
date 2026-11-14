import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_glass.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../../shared/widgets/dentra_mascot.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/guide_kit.dart';
import '../../auth/widgets/auth_password_field.dart';
import '../../auth/widgets/auth_text_field.dart';
import '../../profile/utils/device_settings.dart';
import '../../scan/widgets/scan_theme.dart';
import '../camera_strings.dart';
import '../data/camera_protocol.dart';
import '../data/saved_camera.dart';
import '../providers/camera_providers.dart';
import '../services/camera_setup_link.dart';
import '../state/camera_setup_controller.dart';
import '../state/live_camera_controller.dart';
import '../widgets/camera_bits.dart';
import '../widgets/setup_page.dart';

/// What the user chose at the end of setup.
enum SetupOutcome { startCapturing, done }

/// The step-by-step guide to putting the Dentra Cam on the home Wi-Fi.
/// Resolves to null when closed before the camera was saved.
class CameraSetupScreen extends ConsumerStatefulWidget {
  const CameraSetupScreen({super.key});

  static Route<SetupOutcome> route() => MaterialPageRoute<SetupOutcome>(
        builder: (_) => const CameraSetupScreen(),
      );

  @override
  ConsumerState<CameraSetupScreen> createState() => _CameraSetupScreenState();
}

class _CameraSetupScreenState extends ConsumerState<CameraSetupScreen> {
  late final CameraSetupController _setup;
  late final AppLifecycleListener _lifecycle;
  final _password = TextEditingController();
  CameraViewSettings _settings = const CameraViewSettings();

  /// The new camera's live picture on the success page.
  LiveCameraController? _preview;

  @override
  void initState() {
    super.initState();
    _setup = CameraSetupController(
      link: ref.read(cameraSetupLinkProvider),
      clientFor: ref.read(camClientFactoryProvider),
      onSaved: (camera) => ref.read(savedCameraProvider.notifier).save(camera),
    )..addListener(_onChanged);
    _lifecycle = AppLifecycleListener(
      // Back from Settings: Bluetooth may be allowed now.
      onResume: () => unawaited(_setup.recheck()),
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
      // The password has done its job.
      _password.clear();
      _preview = LiveCameraController(
        client: ref.read(camClientFactoryProvider)(saved.host!),
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
    _password.dispose();
    _preview?.dispose();
    super.dispose();
  }

  void _close([SetupOutcome? outcome]) {
    Navigator.of(context)
        .pop(outcome ?? (_setup.saved != null ? SetupOutcome.done : null));
  }

  void _join() {
    FocusScope.of(context).unfocus();
    unawaited(_setup.join(_password.text));
  }

  Future<void> _enterAddress() async {
    final ip = await showGlassDialog<String>(
      context: context,
      builder: (_) => const _AddressDialog(),
    );
    if (ip != null && mounted) _setup.useAddress(ip);
  }

  /// One icon per step, for the rail.
  static const _stepIcons = [
    Icons.waving_hand_rounded,
    Icons.bluetooth_rounded,
    Icons.power_settings_new_rounded,
    Icons.search_rounded,
    Icons.wifi_rounded,
    Icons.link_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _setup,
      builder: (context, _) {
        final step = _setup.step;
        final pullToRescan =
            step == SetupStep.wifi && _setup.chosen == null && !_setup.linkLost;
        return PopScope(
          canPop: !_setup.canGoBack,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _setup.back();
          },
          child: SetupFrame(
            step: step.index,
            icons: _stepIcons,
            label: CamText.stepNames[step.index],
            onClose: () => _close(),
            sceneKey: ValueKey('${step.name}-${_sceneName()}'),
            direction: _setup.direction,
            scene: _scene(),
            actions: _actions(),
            onRefresh: pullToRescan ? _setup.rescanWifi : null,
          ),
        );
      },
    );
  }

  // ── Scenes ──────────────────────────────────────────────────────

  /// Which of a step's scenes is showing. Rabi pops out and in when it changes.
  String _sceneName() => switch (_setup.step) {
        SetupStep.find => _setup.cameras.isNotEmpty
            ? 'list'
            : _setup.searching || _setup.connecting != null
                ? 'search'
                : 'none',
        SetupStep.wifi => _setup.chosen == null ? 'list' : 'password',
        SetupStep.connect => _setup.saved == null ? 'progress' : 'done',
        _ => '',
      };

  Widget _scene() => switch (_setup.step) {
        SetupStep.welcome => _welcome(),
        SetupStep.permissions => _permissions(),
        SetupStep.power => _power(),
        SetupStep.find => _find(),
        SetupStep.wifi => _setup.chosen == null ? _networks() : _passwordStep(),
        SetupStep.connect => _setup.saved == null ? _connecting() : _success(),
      };

  Widget _welcome() => const SetupWelcomeScene(
        items: CamText.welcomeItems,
        icons: [
          Icons.battery_charging_full_rounded,
          Icons.bluetooth_rounded,
          Icons.wifi_password_rounded,
        ],
      );

  Widget _permissions() {
    final p = _setup.permission;
    final android = _setup.canLinkTurnOnBluetooth;
    final (String title, String? body, MascotMood mood) = switch (p) {
      PermissionState.needed ||
      PermissionState.checking ||
      PermissionState.requesting =>
        (
          CamText.permissionTitle,
          CamText.permissionBody,
          p == PermissionState.needed ? MascotMood.point : MascotMood.think,
        ),
      PermissionState.granted => (
          CamText.permissionGranted,
          null,
          MascotMood.cheer
        ),
      PermissionState.denied => (
          CamText.permissionDeniedTitle,
          android
              ? CamText.permissionDeniedAndroid
              : CamText.permissionDeniedIos,
          MascotMood.worried,
        ),
      PermissionState.bluetoothOff => (
          CamText.bluetoothOffTitle,
          android ? CamText.bluetoothOffAndroid : CamText.bluetoothOffIos,
          MascotMood.worried,
        ),
      PermissionState.unsupported => (
          CamText.bluetoothUnsupportedTitle,
          CamText.bluetoothUnsupported,
          MascotMood.worried,
        ),
    };
    return SetupScene(
      centered: true,
      children: [
        RabiSays(
          place: RabiPlace.above,
          mood: mood,
          aim: MascotAim.down,
          title: title,
          highlight:
              p == PermissionState.needed ? CamText.permissionHighlight : null,
          body: body,
          live: p != PermissionState.needed,
        ),
        if (android && p == PermissionState.needed) ...[
          const SizedBox(height: 28),
          const SetupHint(CamText.permissionLocationNote),
        ],
      ],
    );
  }

  Widget _power() => const SetupPowerScene(
        body: CamText.powerBody,
        reset: CamText.powerReset,
      );

  static const _findTipIcons = [
    Icons.near_me_outlined,
    Icons.power_settings_new_rounded,
    Icons.restart_alt_rounded,
  ];

  Widget _find() {
    final cameras = _setup.cameras;
    final connecting = _setup.connecting;
    final manual = Align(
      alignment: Alignment.center,
      child: TextButton(
        onPressed: connecting == null ? _enterAddress : null,
        style: _linkStyle,
        child: const Text(CamText.manualLink, textAlign: TextAlign.center),
      ),
    );

    if (cameras.isNotEmpty) {
      return SetupScene(
        children: [
          // Standing on the list, pointing down at it.
          RabiSays(
            place: RabiPlace.right,
            perched: true,
            mood: connecting == null ? MascotMood.point : MascotMood.think,
            aim: MascotAim.down,
            title: connecting == null
                ? CamText.findFoundTitle
                : CamText.findConnecting(connecting.name),
            body: CamText.findPairHint,
            live: connecting != null,
          ),
          GlassCard(
            borderRadius: BorderRadius.circular(22),
            child: Column(
              children: [
                for (var i = 0; i < cameras.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 64,
                      color: AppGlass.divider,
                    ),
                  _CameraRow(
                    camera: cameras[i],
                    connecting: connecting?.id == cameras[i].id,
                    onTap: connecting == null
                        ? () => unawaited(_setup.choose(cameras[i]))
                        : null,
                  ),
                ],
              ],
            ),
          ),
          if (_setup.findError != null) ...[
            const SizedBox(height: 12),
            DentraInlineNotice(message: _setup.findError),
          ],
          const SizedBox(height: 6),
          manual,
        ],
      );
    }

    if (_setup.searching || connecting != null) {
      // In the middle of his own radar, ears turning.
      return SetupScene(
        centered: true,
        children: [
          const RabiSays(
            place: RabiPlace.above,
            mood: MascotMood.watch,
            busy: true,
            title: CamText.findSearching,
            body: CamText.findPairHint,
            live: true,
            size: 144,
          ),
          const SizedBox(height: 10),
          manual,
        ],
      );
    }

    return SetupScene(
      children: [
        const RabiSays(
          place: RabiPlace.left,
          mood: MascotMood.worried,
          title: CamText.findNothingTitle,
          live: true,
        ),
        const SizedBox(height: 18),
        if (_setup.findError != null) ...[
          DentraInlineNotice(message: _setup.findError),
          const SizedBox(height: 12),
        ],
        for (var i = 0; i < CamText.findTips.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          CamInfoRow(
            icon: _findTipIcons[i % _findTipIcons.length],
            title: CamText.findTips[i],
          ),
        ],
        if (_setup.canLinkTurnOnBluetooth) ...[
          const SizedBox(height: 12),
          const CamInfoRow(
            icon: Icons.location_on_outlined,
            title: CamText.findLocationTip,
          ),
        ],
        const SizedBox(height: 10),
        manual,
      ],
    );
  }

  Widget _networks() {
    final networks = _setup.networks;
    final lost = _setup.linkLost;
    final listed = networks.isNotEmpty && !lost;
    final loading = _setup.wifiLoading && !lost;
    final String? status = lost
        ? CamText.errorLinkLost
        : loading && networks.isEmpty
            ? CamText.wifiLoading
            : _setup.wifiFailed
                ? CamText.wifiFailed
                : networks.isEmpty
                    ? CamText.wifiEmpty
                    : null;
    return SetupScene(
      children: [
        RabiSays(
          place: RabiPlace.right,
          perched: listed,
          mood: lost || _setup.wifiFailed
              ? MascotMood.worried
              : loading
                  ? MascotMood.watch
                  : MascotMood.point,
          aim: MascotAim.down,
          busy: loading,
          title: CamText.wifiTitle,
          body: status,
          live: true,
        ),
        if (listed)
          GlassCard(
            borderRadius: BorderRadius.circular(22),
            child: Column(
              children: [
                for (var i = 0; i < networks.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 56,
                      color: AppGlass.divider,
                    ),
                  _NetworkRow(
                    network: networks[i],
                    onTap: () {
                      _password.clear();
                      _setup.chooseNetwork(networks[i]);
                    },
                  ),
                ],
              ],
            ),
          ),
        if (!lost) ...[
          const SizedBox(height: 6),
          const _NotListed(),
        ],
      ],
    );
  }

  /// The password field has the keyboard: Rabi shuts his eyes.
  bool _typing = false;

  Widget _passwordStep() {
    final network = _setup.chosen!;
    final failed = _setup.passwordError != null;
    return SetupScene(
      children: [
        RabiSays(
          place: RabiPlace.left,
          mood: failed
              ? MascotMood.worried
              : _typing
                  ? MascotMood.hush
                  : MascotMood.point,
          title: network.ssid,
          body:
              network.secure ? CamText.wifiPasswordBody : CamText.wifiOpenNote,
        ),
        const SizedBox(height: 18),
        if (network.secure) ...[
          Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onFocusChange: (focused) => setState(() => _typing = focused),
            child: AuthPasswordField(
              label: CamText.wifiPasswordLabel,
              placeholder: CamText.wifiPasswordLabel,
              controller: _password,
              errorText: _setup.passwordError,
              textInputAction: TextInputAction.done,
              onEditingComplete: _join,
              autofillHints: const [AutofillHints.password],
            ),
          ),
          const SizedBox(height: 12),
          const SetupHint(
            CamText.wifiPrivacy,
            icon: Icons.lock_outline_rounded,
          ),
        ] else if (failed)
          DentraInlineNotice(message: _setup.passwordError),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => _setup.chooseNetwork(null),
            style: _linkStyle,
            child: const Text(CamText.wifiChooseAnother),
          ),
        ),
      ],
    );
  }

  Widget _connecting() {
    final problem = _setup.problem;
    final stage = _setup.stage;
    return SetupScene(
      centered: true,
      children: [
        SetupLinkArt(
          phase: LinkPhase.values[stage.index],
          stuck: problem != null,
          direct: _setup.manual,
        ),
        const SizedBox(height: 14),
        // Thinking it over, then waiting, then looking out for the camera.
        RabiSays(
          place: RabiPlace.above,
          mood: problem != null
              ? MascotMood.worried
              : switch (stage) {
                  JoinStage.sending => MascotMood.think,
                  JoinStage.joining || JoinStage.restarting => MascotMood.wait,
                  JoinStage.finding => MascotMood.watch,
                  JoinStage.done => MascotMood.cheer,
                },
          busy: problem == null,
          title: problem == null ? _stageLabel(stage) : CamText.errorTitle,
          body: problem == null ? CamText.connectHint : _problemText(problem),
          live: true,
          size: 128,
        ),
      ],
    );
  }

  Widget _success() => SetupDoneScene(
        body: CamText.successBody(_setup.saved?.ssid),
        preview: _preview,
      );

  static String _stageLabel(JoinStage stage) => switch (stage) {
        JoinStage.sending => CamText.stageSending,
        JoinStage.joining => CamText.stageJoining,
        JoinStage.restarting => CamText.stageRestarting,
        JoinStage.finding => CamText.stageFinding,
        JoinStage.done => CamText.stageDone,
      };

  String _problemText(JoinProblem problem) => switch (problem) {
        JoinProblem.ssidNotFound => CamText.errorSsidNotFound,
        JoinProblem.timeout => CamText.errorTimeout,
        // The guide only runs on Android and iPhone.
        JoinProblem.notOnNetwork => _setup.canLinkTurnOnBluetooth
            ? CamText.errorNotOnNetwork(_setup.ssid)
            : '${CamText.errorNotOnNetwork(_setup.ssid)} '
                '${CamText.localNetworkHintIos}',
        JoinProblem.linkLost => CamText.errorLinkLost,
        JoinProblem.failed => CamText.errorFailed,
      };

  static final _linkStyle = TextButton.styleFrom(
    foregroundColor: AppColors.primary,
    padding: const EdgeInsets.symmetric(horizontal: 4),
    minimumSize: const Size(48, 44),
    textStyle: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w700),
  );

  // ── Actions ─────────────────────────────────────────────────────

  Widget _actions() {
    final back = GuideBackButton(onPressed: _setup.back, label: CamText.back);
    // Keyed by its label, so one action fades into the next.
    Widget primary(String label, VoidCallback? onPressed, {IconData? icon}) =>
        GuidePrimaryButton(
          key: ValueKey(label),
          label: label,
          icon: icon,
          onPressed: onPressed,
        );
    Widget status(String label) => GuideStatus(label, key: ValueKey(label));

    switch (_setup.step) {
      case SetupStep.welcome:
        return GuideActions(
          leading: GuideQuietButton(
            label: CamText.welcomeLater,
            onPressed: () => _close(),
          ),
          trailing: primary(CamText.welcomeStart, _setup.next),
        );
      case SetupStep.permissions:
        return GuideActions(
          leading: back,
          trailing: switch (_setup.permission) {
            PermissionState.needed => primary(
                CamText.permissionAllow,
                () => unawaited(_setup.allowBluetooth()),
              ),
            PermissionState.checking ||
            PermissionState.requesting =>
              status(CamText.permissionChecking),
            PermissionState.granted => primary(CamText.next, _setup.next),
            PermissionState.denied => primary(
                CamText.openSettings,
                () => unawaited(openDeviceSettings(context)),
              ),
            PermissionState.bluetoothOff => _setup.canLinkTurnOnBluetooth
                ? primary(
                    CamText.turnOnBluetooth,
                    () => unawaited(_setup.turnOnBluetooth()),
                  )
                : primary(
                    CamText.checkAgain,
                    () => unawaited(_setup.recheck()),
                  ),
            PermissionState.unsupported => primary(CamText.close, _close),
          },
        );
      case SetupStep.power:
        return GuideActions(
          leading: back,
          trailing: primary(CamText.powerReady, _setup.next),
        );
      case SetupStep.find:
        return GuideActions(
          leading: back,
          trailing: _setup.connecting != null
              ? status(CamText.connectingShort)
              : _setup.searching
                  ? status(CamText.searching)
                  : primary(
                      CamText.findAgain,
                      _setup.scanAgain,
                      icon: Icons.refresh_rounded,
                    ),
        );
      case SetupStep.wifi:
        if (_setup.linkLost) {
          return GuideActions(
            leading: back,
            trailing: primary(CamText.startOver, _setup.startOver),
          );
        }
        if (_setup.chosen == null) {
          return GuideActions(
            leading: back,
            trailing: _setup.wifiLoading
                ? status(CamText.searching)
                : primary(
                    CamText.wifiRescan,
                    () => unawaited(_setup.rescanWifi()),
                    icon: Icons.refresh_rounded,
                  ),
          );
        }
        return GuideActions(
          leading: back,
          trailing: primary(CamText.wifiConnect, _join),
        );
      case SetupStep.connect:
        if (_setup.saved != null) {
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
        return switch (_setup.problem) {
          null => GuideActions(trailing: status(CamText.connectingShort)),
          JoinProblem.linkLost => GuideActions(
              trailing: primary(CamText.startOver, _setup.startOver),
            ),
          JoinProblem.notOnNetwork => GuideActions(
              leading: GuideQuietButton(
                label: CamText.startOver,
                onPressed: _setup.startOver,
              ),
              trailing: primary(CamText.tryAgain, _setup.findAgain),
            ),
          _ => GuideActions(
              leading: GuideQuietButton(
                label: CamText.wifiOther,
                semanticLabel: CamText.wifiChooseAnother,
                onPressed: _setup.back,
              ),
              trailing: primary(
                CamText.tryAgain,
                () => unawaited(_setup.join(_password.text)),
              ),
            ),
        };
    }
  }
}

// ── Pieces ───────────────────────────────────────────────────────────

class _CameraRow extends StatelessWidget {
  const _CameraRow({
    required this.camera,
    required this.connecting,
    required this.onTap,
  });

  final FoundCamera camera;
  final bool connecting;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bars = camera.bars;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: [
        connecting ? CamText.findConnecting(camera.name) : camera.name,
        if (bars != null) CamText.cameraSignal(bars),
      ].join(', '),
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              const ScanIconDisc(Icons.videocam_rounded, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  camera.name,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
              ),
              if (bars != null) ...[
                SignalBars(bars: bars),
                const SizedBox(width: 12),
              ],
              if (connecting)
                const GuideDots()
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.secondaryText,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NetworkRow extends StatelessWidget {
  const _NetworkRow({required this.network, required this.onTap});

  final WifiNetwork network;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: [
        network.ssid,
        network.secure ? CamText.wifiSecured : CamText.wifiOpen,
        CamText.cameraSignal(network.bars),
      ].join(', '),
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: SignalBars(bars: network.bars, height: 14),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  network.ssid,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
              ),
              if (network.secure)
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 18,
                  color: AppColors.secondaryText,
                ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.secondaryText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "My network isn't listed", opening to what usually fixes it.
class _NotListed extends StatefulWidget {
  const _NotListed();

  @override
  State<_NotListed> createState() => _NotListedState();
}

class _NotListedState extends State<_NotListed> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _open = !_open),
            style: _CameraSetupScreenState._linkStyle,
            icon: AnimatedRotation(
              turns: _open ? 0.5 : 0,
              duration: dentraMotion(context),
              child: const Icon(Icons.expand_more_rounded, size: 20),
            ),
            label: const Text(CamText.wifiNotListed),
          ),
        ),
        AnimatedSize(
          duration: dentraMotion(context),
          alignment: Alignment.topCenter,
          child: !_open
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    children: [
                      CamInfoRow(
                        icon: Icons.wifi_rounded,
                        title: CamText.wifiNotListedTips[0],
                      ),
                      const SizedBox(height: 12),
                      CamInfoRow(
                        icon: Icons.router_outlined,
                        title: CamText.wifiNotListedTips[1],
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

/// Asks for a camera's IP address. Resolves to it, or null.
class _AddressDialog extends StatefulWidget {
  const _AddressDialog();

  @override
  State<_AddressDialog> createState() => _AddressDialogState();
}

class _AddressDialogState extends State<_AddressDialog> {
  final _address = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  void _submit() {
    final ip = _address.text.trim();
    if (!isIpv4(ip)) {
      setState(() => _error = CamText.manualInvalid);
      return;
    }
    Navigator.of(context).pop(ip);
  }

  @override
  Widget build(BuildContext context) {
    return GlassDialogFrame(
      icon: Icons.lan_outlined,
      title: CamText.manualTitle,
      message: CamText.manualBody,
      children: [
        AuthTextField(
          label: CamText.manualTitle,
          placeholder: CamText.manualHint,
          controller: _address,
          errorText: _error,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          autofocus: true,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          maxLength: 15,
          onEditingComplete: _submit,
        ),
        const SizedBox(height: 16),
        DentraButtonRow(
          secondary: DentraPillButton(
            label: CamText.close,
            variant: DentraButtonVariant.outline,
            onPressed: () => Navigator.of(context).pop(),
          ),
          primary: DentraPillButton(
            label: CamText.manualConnect,
            onPressed: _submit,
          ),
        ),
      ],
    );
  }
}
