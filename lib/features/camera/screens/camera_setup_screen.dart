import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_glass.dart';
import '../../../shared/widgets/app_backdrop.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../auth/widgets/auth_password_field.dart';
import '../../auth/widgets/auth_text_field.dart';
import '../../dental_profile/widgets/question_block.dart'
    show QuestionnaireProgress;
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
import '../widgets/live_view.dart';

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
        client: ref.read(camClientFactoryProvider)(saved.host),
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
                        _TopBar(
                          step: step.index,
                          total: SetupStep.values.length,
                          onClose: () => _close(),
                        ),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: AppGlass.divider,
                        ),
                        Expanded(child: _body()),
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

  Widget _body() {
    final sub = switch (_setup.step) {
      SetupStep.wifi => _setup.chosen == null ? 'list' : 'password',
      SetupStep.connect => _setup.saved == null ? 'progress' : 'done',
      _ => '',
    };
    final key = ValueKey('${_setup.step.name}-$sub');
    final motion = camMotion(context);
    final scroll = SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: AnimatedSize(
        duration: motion,
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: motion,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [
              for (final old in previous)
                Positioned(top: 0, left: 0, right: 0, child: old),
              if (current != null) current,
            ],
          ),
          transitionBuilder: (child, animation) {
            // In from the side we're heading to; out toward the other.
            final incoming = child.key == key;
            final dx = 0.12 * _setup.direction * (incoming ? 1 : -1);
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(begin: Offset(dx, 0), end: Offset.zero)
                    .animate(animation),
                child: child,
              ),
            );
          },
          child: KeyedSubtree(key: key, child: _content()),
        ),
      ),
    );
    final pullToRescan = _setup.step == SetupStep.wifi &&
        _setup.chosen == null &&
        !_setup.linkLost;
    return pullToRescan
        ? RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _setup.rescanWifi,
            child: scroll,
          )
        : scroll;
  }

  Widget _content() => switch (_setup.step) {
        SetupStep.welcome => _welcome(),
        SetupStep.permissions => _permissions(),
        SetupStep.power => _power(),
        SetupStep.find => _find(),
        SetupStep.wifi => _setup.chosen == null ? _networks() : _passwordStep(),
        SetupStep.connect => _setup.saved == null ? _connecting() : _success(),
      };

  static const _welcomeIcons = [
    Icons.battery_charging_full_rounded,
    Icons.bluetooth_rounded,
    Icons.wifi_password_rounded,
    Icons.router_outlined,
  ];

  Widget _welcome() => _Page(
        art: const SetupArt(
          step: 0,
          icon: Icons.videocam_rounded,
          badge: Icons.wifi_rounded,
        ),
        title: CamText.welcomeTitle,
        body: CamText.welcomeBody,
        rabi: CamText.welcomeRabi,
        children: [
          for (var i = 0; i < CamText.welcomeItems.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            CamInfoRow(
              icon: _welcomeIcons[i % _welcomeIcons.length],
              title: CamText.welcomeItems[i].$1,
              body: CamText.welcomeItems[i].$2,
            ),
          ],
        ],
      );

  Widget _permissions() {
    final p = _setup.permission;
    final android = _setup.canLinkTurnOnBluetooth;
    final busy =
        p == PermissionState.checking || p == PermissionState.requesting;
    return _Page(
      art: SetupArt(
        step: 1,
        icon: Icons.bluetooth_rounded,
        badge: p == PermissionState.granted
            ? Icons.check_rounded
            : Icons.lock_open_rounded,
        active: busy,
      ),
      title: CamText.permissionTitle,
      body: CamText.permissionBody,
      rabi: CamText.permissionRabi,
      children: [
        if (android)
          Text(
            CamText.permissionLocationNote,
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              color: AppColors.secondaryText,
              height: 1.45,
            ),
          ),
        switch (p) {
          PermissionState.checking ||
          PermissionState.requesting =>
            const CamBusyLine(CamText.permissionChecking),
          PermissionState.granted => const CamInfoRow(
              icon: Icons.check_circle_rounded,
              title: CamText.permissionGranted,
            ),
          PermissionState.needed => const SizedBox.shrink(),
          PermissionState.denied => _Notice(
              title: CamText.permissionDeniedTitle,
              body: android
                  ? CamText.permissionDeniedAndroid
                  : CamText.permissionDeniedIos,
            ),
          PermissionState.bluetoothOff => _Notice(
              title: CamText.bluetoothOffTitle,
              body: android
                  ? CamText.bluetoothOffAndroid
                  : CamText.bluetoothOffIos,
            ),
          PermissionState.unsupported =>
            const _Notice(body: CamText.bluetoothUnsupported),
        },
      ],
    );
  }

  Widget _power() => const _Page(
        art: SetupArt(
          step: 2,
          icon: Icons.power_settings_new_rounded,
          badge: Icons.smartphone_rounded,
        ),
        title: CamText.powerTitle,
        body: CamText.powerBody,
        rabi: CamText.powerRabi,
        children: [
          CamInfoRow(
            icon: Icons.restart_alt_rounded,
            title: CamText.powerResetTitle,
            body: CamText.powerResetBody,
          ),
        ],
      );

  static const _findTipIcons = [
    Icons.near_me_outlined,
    Icons.power_settings_new_rounded,
    Icons.restart_alt_rounded,
  ];

  Widget _find() {
    final cameras = _setup.cameras;
    final searching = _setup.searching;
    final connecting = _setup.connecting;
    return _Page(
      art: SetupArt(
        step: 3,
        icon: Icons.bluetooth_searching_rounded,
        badge: Icons.videocam_rounded,
        active: searching || connecting != null,
      ),
      title: CamText.findTitle,
      rabi: CamText.findRabi,
      children: [
        if (searching)
          const CamBusyLine(CamText.findSearching)
        else if (cameras.isNotEmpty)
          Text(CamText.findFoundHint, style: camBodyStyle()),
        if (cameras.isNotEmpty)
          GlassCard(
            borderRadius: BorderRadius.circular(20),
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
        if (_setup.findError != null)
          DentraInlineNotice(message: _setup.findError),
        if (!searching && cameras.isEmpty && connecting == null) ...[
          Text(
            CamText.findNothingTitle,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          for (var i = 0; i < CamText.findTips.length; i++)
            CamInfoRow(
              icon: _findTipIcons[i % _findTipIcons.length],
              title: CamText.findTips[i],
            ),
          if (_setup.canLinkTurnOnBluetooth)
            const CamInfoRow(
              icon: Icons.location_on_outlined,
              title: CamText.findLocationTip,
            ),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: connecting == null ? _enterAddress : null,
            style: _linkStyle,
            child: const Text(CamText.manualLink),
          ),
        ),
      ],
    );
  }

  Widget _networks() {
    final networks = _setup.networks;
    final Widget status;
    if (_setup.linkLost) {
      status = const _Notice(body: CamText.errorLinkLost);
    } else if (_setup.wifiLoading && networks.isEmpty) {
      status = const CamBusyLine(CamText.wifiLoading);
    } else if (_setup.wifiFailed) {
      status = const _Notice(body: CamText.wifiFailed);
    } else if (networks.isEmpty) {
      status = Text(CamText.wifiEmpty, style: camBodyStyle());
    } else {
      status = const SizedBox.shrink();
    }
    return _Page(
      art: SetupArt(
        step: 4,
        icon: Icons.wifi_rounded,
        badge: Icons.router_outlined,
        active: _setup.wifiLoading,
      ),
      title: CamText.wifiTitle,
      body: CamText.wifiBody,
      rabi: CamText.wifiRabi,
      children: [
        status,
        if (networks.isNotEmpty && !_setup.linkLost)
          GlassCard(
            borderRadius: BorderRadius.circular(20),
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
        const _NotListed(),
      ],
    );
  }

  Widget _passwordStep() {
    final network = _setup.chosen!;
    return _Page(
      art: SetupArt(
        step: 4,
        icon: Icons.wifi_password_rounded,
        badge: network.secure ? Icons.lock_rounded : null,
      ),
      title: network.ssid,
      body: network.secure ? CamText.wifiPasswordFor(network.ssid) : null,
      rabi: CamText.wifiRabi,
      children: [
        if (network.secure)
          AuthPasswordField(
            label: CamText.wifiPasswordLabel,
            placeholder: CamText.wifiPasswordLabel,
            controller: _password,
            errorText: _setup.passwordError,
            textInputAction: TextInputAction.done,
            onEditingComplete: _join,
            autofillHints: const [AutofillHints.password],
          )
        else ...[
          const _Notice(body: CamText.wifiOpenNote),
          if (_setup.passwordError != null)
            DentraInlineNotice(message: _setup.passwordError),
        ],
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
    final stages = _setup.manual
        ? const [JoinStage.finding]
        : const [
            JoinStage.sending,
            JoinStage.joining,
            JoinStage.restarting,
            JoinStage.finding,
          ];
    return _Page(
      art: SetupArt(
        step: 5,
        icon: Icons.wifi_tethering_rounded,
        badge: Icons.videocam_rounded,
        active: problem == null,
      ),
      title: CamText.connectTitle,
      rabi: CamText.connectRabi,
      children: [
        GlassCard(
          borderRadius: BorderRadius.circular(20),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            children: [
              for (final stage in [...stages, JoinStage.done])
                _StageRow(
                  label: _stageLabel(stage),
                  state: stage.index < _setup.stage.index
                      ? _StageState.done
                      : stage == _setup.stage
                          ? (problem == null
                              ? _StageState.active
                              : _StageState.failed)
                          : _StageState.pending,
                ),
            ],
          ),
        ),
        if (problem != null) _Notice(body: _problemText(problem)),
      ],
    );
  }

  Widget _success() {
    final preview = _preview;
    return _Page(
      title: CamText.successTitle,
      body: CamText.successBody(_setup.saved?.ssid),
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

  // ── Buttons ─────────────────────────────────────────────────────

  Widget _buttons() {
    DentraPillButton back(VoidCallback onPressed, [String label = CamText.back]) =>
        DentraPillButton(
          label: label,
          variant: DentraButtonVariant.outline,
          onPressed: onPressed,
        );

    switch (_setup.step) {
      case SetupStep.welcome:
        return DentraButtonRow(
          secondary: back(() => _close(), CamText.welcomeLater),
          primary: DentraPillButton(
            label: CamText.welcomeStart,
            onPressed: _setup.next,
          ),
        );
      case SetupStep.permissions:
        final p = _setup.permission;
        final busy =
            p == PermissionState.checking || p == PermissionState.requesting;
        final (String label, VoidCallback? action) = switch (p) {
          PermissionState.needed => (
              CamText.permissionAllow,
              () => unawaited(_setup.allowBluetooth()),
            ),
          PermissionState.checking ||
          PermissionState.requesting =>
            (CamText.permissionAllow, null),
          PermissionState.granted => (CamText.next, _setup.next),
          PermissionState.denied => (
              CamText.openSettings,
              () => unawaited(openDeviceSettings(context)),
            ),
          PermissionState.bluetoothOff => _setup.canLinkTurnOnBluetooth
              ? (
                  CamText.turnOnBluetooth,
                  () => unawaited(_setup.turnOnBluetooth()),
                )
              : (CamText.checkAgain, () => unawaited(_setup.recheck())),
          PermissionState.unsupported => (CamText.close, () => _close()),
        };
        return DentraButtonRow(
          secondary: back(_setup.back),
          primary: DentraPillButton(
            label: label,
            loading: busy,
            onPressed: action,
          ),
        );
      case SetupStep.power:
        return DentraButtonRow(
          secondary: back(_setup.back),
          primary: DentraPillButton(
            label: CamText.powerReady,
            onPressed: _setup.next,
          ),
        );
      case SetupStep.find:
        return DentraButtonRow(
          secondary: back(_setup.back),
          primary: DentraPillButton(
            label: CamText.findAgain,
            loading: _setup.searching,
            loadingLabel: CamText.findSearchingButton,
            onPressed: _setup.connecting == null ? _setup.scanAgain : null,
          ),
        );
      case SetupStep.wifi:
        if (_setup.linkLost) {
          return DentraButtonRow(
            secondary: back(_setup.back),
            primary: DentraPillButton(
              label: CamText.startOver,
              onPressed: _setup.startOver,
            ),
          );
        }
        if (_setup.chosen == null) {
          return DentraButtonRow(
            secondary: back(_setup.back),
            primary: DentraPillButton(
              label: CamText.wifiRescan,
              loading: _setup.wifiLoading,
              onPressed: () => unawaited(_setup.rescanWifi()),
            ),
          );
        }
        return DentraButtonRow(
          secondary: back(_setup.back),
          primary: DentraPillButton(
            label: CamText.wifiConnect,
            onPressed: _join,
          ),
        );
      case SetupStep.connect:
        if (_setup.saved != null) {
          return DentraButtonRow(
            secondary: back(() => _close(SetupOutcome.done), CamText.done),
            primary: DentraPillButton(
              label: CamText.startCapturing,
              icon: Icons.photo_camera_outlined,
              onPressed: () => _close(SetupOutcome.startCapturing),
            ),
          );
        }
        return switch (_setup.problem) {
          null => const SizedBox.shrink(),
          JoinProblem.linkLost => DentraPillButton(
              label: CamText.startOver,
              onPressed: _setup.startOver,
            ),
          JoinProblem.notOnNetwork => DentraButtonRow(
              secondary: back(_setup.startOver, CamText.startOver),
              primary: DentraPillButton(
                label: CamText.tryAgain,
                onPressed: _setup.findAgain,
              ),
            ),
          _ => DentraButtonRow(
              secondary: back(_setup.back, CamText.wifiChooseAnother),
              primary: DentraPillButton(
                label: CamText.tryAgain,
                onPressed: () => unawaited(_setup.join(_password.text)),
              ),
            ),
        };
    }
  }
}

// ── Pieces ───────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.step,
    required this.total,
    required this.onClose,
  });

  final int step;
  final int total;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  CamText.setupTitle,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 8),
                QuestionnaireProgress(
                  step: step,
                  total: total,
                  label: CamText.stepNames[step],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onClose,
            tooltip: CamText.closeSetup,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.white.withValues(alpha: 0.7),
              foregroundColor: AppColors.navy,
              fixedSize: const Size(44, 44),
            ),
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

/// One step's layout: picture, title, text, its own content, then Rabi.
class _Page extends StatelessWidget {
  const _Page({
    this.art,
    required this.title,
    this.body,
    required this.rabi,
    this.children = const [],
  });

  final Widget? art;
  final String title;
  final String? body;
  final String rabi;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (art != null) ...[art!, const SizedBox(height: 8)],
        Semantics(
          header: true,
          child: Text(title, style: camTitleStyle()),
        ),
        if (body != null) ...[
          const SizedBox(height: 6),
          Text(body!, style: camBodyStyle()),
        ],
        for (final child in children) ...[
          const SizedBox(height: 14),
          child,
        ],
        const SizedBox(height: 22),
        RabiTip(rabi),
      ],
    );
  }
}

/// A soft teal panel for something to know or do.
class _Notice extends StatelessWidget {
  const _Notice({this.title, required this.body});

  final String? title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
        decoration: BoxDecoration(
          color: AppColors.g2.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.g2.withValues(alpha: 0.26)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) ...[
                    Text(
                      title!,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 3),
                  ],
                  Text(
                    body,
                    style: GoogleFonts.outfit(
                      fontSize: 13.5,
                      color: AppColors.navy,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              const ScanIconDisc(Icons.videocam_rounded, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  connecting ? CamText.findConnecting(camera.name) : camera.name,
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
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
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

enum _StageState { pending, active, done, failed }

class _StageRow extends StatelessWidget {
  const _StageRow({required this.label, required this.state});

  final String label;
  final _StageState state;

  @override
  Widget build(BuildContext context) {
    final Widget mark = switch (state) {
      _StageState.done => const Icon(
          Icons.check_circle_rounded,
          size: 20,
          color: ScanColors.clearInk,
        ),
      _StageState.active => const Padding(
          padding: EdgeInsets.all(2),
          child: SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        ),
      _StageState.failed => const Icon(
          Icons.error_outline_rounded,
          size: 20,
          color: AppColors.navy,
        ),
      _StageState.pending => Icon(
          Icons.radio_button_unchecked_rounded,
          size: 20,
          color: ScanColors.muted.withValues(alpha: 0.9),
        ),
    };
    return Semantics(
      liveRegion: state == _StageState.active,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            SizedBox.square(dimension: 20, child: Center(child: mark)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: state == _StageState.pending
                      ? FontWeight.w500
                      : FontWeight.w700,
                  color: state == _StageState.pending
                      ? AppColors.secondaryText
                      : AppColors.navy,
                ),
              ),
            ),
          ],
        ),
      ),
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
