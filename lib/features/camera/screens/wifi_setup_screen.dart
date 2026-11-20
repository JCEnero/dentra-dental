import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../../shared/widgets/dentra_mascot.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/guide_kit.dart';
import '../data/camera_protocol.dart';
import '../providers/camera_providers.dart';
import '../services/account_wifi_provisioning.dart';
import '../services/browser_wifi_provisioning.dart';
import '../services/wifi_provisioning.dart';
import '../state/wifi_setup_controller.dart';
import '../widgets/setup_device_stage.dart';
import '../widgets/setup_page.dart';
import 'camera_setup_screen.dart' show SetupOutcome;

final wifiProvisioningProvider =
    Provider<ProvisioningTransport Function()>((ref) {
  if (ref.watch(camLinkProvider) != CamLink.cloud) return WifiProvisioning.new;
  final api = ref.watch(cloudCamApiProvider);
  final clientFor = ref.watch(cloudCamClientFactoryProvider);
  return () {
    if (api == null) throw StateError('Sign in to set up your device');
    if (kIsWeb) return BrowserWifiProvisioning(api: api, clientFor: clientFor);
    return AccountWifiProvisioning(
        transport: WifiProvisioning(), api: api, clientFor: clientFor);
  };
});

/// SoftAP setup stays in Flutter: no external device page or address entry.
class WifiSetupScreen extends ConsumerStatefulWidget {
  const WifiSetupScreen({super.key});
  static Route<SetupOutcome> route() =>
      MaterialPageRoute(builder: (_) => const WifiSetupScreen());
  @override
  ConsumerState<WifiSetupScreen> createState() => _WifiSetupScreenState();
}

class _WifiSetupScreenState extends ConsumerState<WifiSetupScreen> {
  late final WifiSetupController _setup;
  late final AppLifecycleListener _lifecycle;
  final _key = TextEditingController();
  final _password = TextEditingController();
  bool _showPassword = false;
  bool _showKey = false;

  @override
  void initState() {
    super.initState();
    final transport = ref.read(wifiProvisioningProvider)();
    _setup = WifiSetupController(
      transport: transport,
      verifyTimeout: transport.linksAccount
          ? const Duration(minutes: 3)
          : const Duration(seconds: 45),
      onSaved: (camera) => ref.read(savedCameraProvider.notifier).save(camera),
    )..addListener(_changed);
    _lifecycle =
        AppLifecycleListener(onResume: () => unawaited(_setup.resume()));
  }

  void _changed() {
    if (_setup.step == WifiSetupStep.network) _key.clear();
    if (_setup.step == WifiSetupStep.finish) _password.clear();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _setup
      ..removeListener(_changed)
      ..dispose();
    _key.dispose();
    _password.dispose();
    super.dispose();
  }

  void _close([SetupOutcome? outcome]) => Navigator.of(context)
      .pop(outcome ?? (_setup.saved == null ? null : SetupOutcome.done));

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _setup,
        builder: (context, _) => Theme(
            data: Theme.of(context).copyWith(
              textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(foregroundColor: AppColors.navy)),
              iconButtonTheme: IconButtonThemeData(
                  style:
                      IconButton.styleFrom(foregroundColor: AppColors.primary)),
            ),
            child: SetupFrame(
              step: _setup.step.index,
              icons: const [
                Icons.power_settings_new_rounded,
                Icons.wifi_tethering_rounded,
                Icons.wifi_rounded,
                Icons.check_rounded
              ],
              label: const [
                'Prepare',
                'Connect camera',
                'Home Wi-Fi',
                'Ready'
              ][_setup.step.index],
              compactProgress: true,
              onClose: () => _close(),
              sceneKey: ValueKey(
                  '${_setup.step}-${_setup.selected?.ssid}-${_setup.saved != null}'),
              direction: 1,
              scene: _scene(context),
              actions: _actions(),
            )),
      );

  Widget _scene(BuildContext context) {
    final setup = _setup;
    final children = <Widget>[
      const Padding(
        padding: EdgeInsets.only(top: 8, bottom: 18),
        child: _SetupPill(
            icon: Icons.videocam_outlined, label: 'DENTRA CAM  /  WI-FI SETUP'),
      ),
    ];
    switch (setup.step) {
      case WifiSetupStep.prepare:
        children.addAll([
          const RabiSays(
              title: 'A little setup.\nA clearer smile.',
              body: 'Your camera. Your Wi-Fi. All here in Dentra.',
              mood: MascotMood.wave,
              place: RabiPlace.right,
              size: 96),
          const SizedBox(height: 20),
          _surface(Column(children: [
            const _SetupPill(
                icon: Icons.wifi_tethering_rounded, label: 'CONNECT DIRECTLY'),
            const SetupDeviceStage(scene: DeviceScene.hotspot, height: 168),
            _heading('Power on your device'),
            const SizedBox(height: 8),
            const Text('Keep your Dentra Cam charged and close to your phone.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.secondaryText, height: 1.5)),
          ])),
          const SizedBox(height: 16),
          _surface(Column(children: [
            _infoRow(Icons.key_outlined, 'Device setup key',
                'Have the key on your device label ready.'),
            const Divider(height: 24, color: Color(0x1A167D8D)),
            _infoRow(Icons.wifi_rounded, 'Home Wi-Fi',
                'Use a 2.4 GHz network and its password.'),
          ])),
          const SizedBox(height: 16),
          const SetupHint(
              'Already configured? Hold BOOT for 5 seconds to start setup again.',
              icon: Icons.restart_alt_rounded),
          if (setup.linksAccount || setup.isBrowser) ...[
            const SizedBox(height: 12),
            const SetupHint(
                'Stay online until the next step so we can prepare your account link.',
                icon: Icons.cloud_outlined),
          ],
        ]);
      case WifiSetupStep.device:
        children.addAll([
          RabiSays(
              title: 'Meet your\nDentra Cam.',
              body: 'A private connection, just for setup.',
              mood: setup.busy ? MascotMood.wait : MascotMood.point,
              busy: setup.busy,
              place: RabiPlace.right,
              size: 96),
          const SizedBox(height: 20),
          _surface(
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SetupDeviceStage(scene: DeviceScene.hotspot, height: 145),
            const SizedBox(height: 8),
            _heading(
                setup.isBrowser ? 'Join Dentra Wi-Fi' : 'Device setup key'),
            const SizedBox(height: 10),
            Text(
                setup.isBrowser
                    ? 'Open Wi-Fi settings and join the Dentra Cam network using the setup key on your device label. Then return here.'
                    : 'Enter the 16-character key on your device label. Your phone will ask to join Dentra Wi-Fi.',
                style: const TextStyle(
                    color: AppColors.secondaryText, height: 1.5)),
            if (!setup.isBrowser) ...[
              const SizedBox(height: 20),
              TextField(
                controller: _key,
                enabled: !setup.busy,
                obscureText: !_showKey,
                autocorrect: false,
                enableSuggestions: false,
                maxLength: 16,
                autofillHints: const [],
                textInputAction: TextInputAction.done,
                style: const TextStyle(
                    letterSpacing: 1.5, fontWeight: FontWeight.w600),
                decoration: _input('Setup key', Icons.key_rounded).copyWith(
                    counterText: '',
                    suffixIcon: IconButton(
                        tooltip: _showKey ? 'Hide setup key' : 'Show setup key',
                        onPressed: () => setState(() => _showKey = !_showKey),
                        icon: Icon(_showKey
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined))),
                onSubmitted: (_) => _connect(),
              ),
            ],
            const SizedBox(height: 18),
            _infoRow(
                Icons.phonelink_lock_rounded,
                'Stay connected',
                setup.isBrowser
                    ? 'Tap “I’ve joined Dentra Wi-Fi” below and allow Local network access.'
                    : 'Approve “Connect” or “Join”. A “no internet” message is normal during this step.'),
          ])),
          const SizedBox(height: 16),
          const SetupHint('The setup form stays here in Dentra.',
              icon: Icons.check_circle_outline_rounded),
          if (setup.isBrowser) ...[
            const SizedBox(height: 12),
            const SetupHint(
                'Use current Chrome or Edge on Android or a computer. If local access is blocked, use the installed Dentra app.'),
          ],
        ]);
      case WifiSetupStep.network:
        final network = setup.selected;
        children.addAll([
          RabiSays(
              title: network == null
                  ? 'Make yourself\nat home.'
                  : 'One last\nlittle detail.',
              body: network == null
                  ? 'Choose the 2.4 GHz Wi-Fi your camera will use.'
                  : 'Connect your Dentra Cam to ${network.ssid}.',
              mood: setup.busy ? MascotMood.think : MascotMood.wave,
              busy: setup.busy,
              place: RabiPlace.right,
              size: 96),
          const SizedBox(height: 20),
          const Align(
              alignment: Alignment.centerLeft,
              child: _SetupPill(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'CAMERA CONNECTED')),
          const SizedBox(height: 14),
          if (network == null)
            _surface(Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(child: _heading('Available networks')),
                    IconButton(
                        onPressed:
                            setup.busy ? null : () => unawaited(setup.scan()),
                        tooltip: 'Look again',
                        icon: const Icon(Icons.refresh_rounded)),
                  ]),
                  const Text('2.4 GHz networks near your camera',
                      style: TextStyle(
                          color: AppColors.secondaryText, fontSize: 13)),
                  const SizedBox(height: 14),
                  if (setup.networks.isEmpty && !setup.busy)
                    const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text('No networks yet. Tap Look again.')),
                  for (var i = 0; i < setup.networks.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 1, color: Color(0x14167D8D)),
                    _networkRow(setup.networks[i]),
                  ],
                  const SizedBox(height: 8),
                  TextButton.icon(
                      onPressed: setup.busy ? null : _hiddenNetwork,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('My network is hidden')),
                ]))
          else
            _surface(Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    _iconTile(Icons.wifi_rounded),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(network.ssid,
                            style: GoogleFonts.outfit(
                                fontSize: 19,
                                fontWeight: FontWeight.w600,
                                color: AppColors.navy))),
                    TextButton(
                        onPressed: setup.busy
                            ? null
                            : () {
                                _password.clear();
                                _showPassword = false;
                                setup.clearSelection();
                              },
                        child: const Text('Change')),
                  ]),
                  const SizedBox(height: 22),
                  if (network.secure)
                    TextField(
                        controller: _password,
                        enabled: !setup.busy,
                        obscureText: !_showPassword,
                        autocorrect: false,
                        enableSuggestions: false,
                        autofillHints: const [],
                        textInputAction: TextInputAction.done,
                        decoration: _input(
                                'Wi-Fi password', Icons.lock_outline_rounded)
                            .copyWith(
                                suffixIcon: IconButton(
                                    tooltip: _showPassword
                                        ? 'Hide password'
                                        : 'Show password',
                                    onPressed: () => setState(
                                        () => _showPassword = !_showPassword),
                                    icon: Icon(_showPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined))),
                        onSubmitted: (_) => _join())
                  else
                    const Text('This network doesn’t require a password.'),
                  const SizedBox(height: 18),
                  _infoRow(
                      Icons.shield_outlined,
                      'Sent directly to your camera',
                      'Your Wi-Fi password travels over the protected setup connection. It isn’t sent to your account.'),
                ])),
          if (!setup.busy)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton(
                    onPressed: () => unawaited(setup.reconnect()),
                    child: const Text('Reconnect to Dentra Wi-Fi'))),
        ]);
      case WifiSetupStep.finish:
        final ready = setup.saved != null;
        children.addAll([
          RabiSays(
              title: ready
                  ? 'You’re all\nconnected.'
                  : 'A moment\nfor the connection.',
              body: ready
                  ? 'Your Dentra Cam is ready for a closer look.'
                  : setup.linksAccount
                      ? 'We’re bringing your camera online and linking it to your account.'
                      : 'Your camera joined home Wi-Fi. We’re checking the connection.',
              mood: ready
                  ? MascotMood.cheer
                  : setup.error == null
                      ? MascotMood.wait
                      : MascotMood.worried,
              busy: setup.busy,
              place: RabiPlace.above,
              live: true,
              size: 130),
          const SizedBox(height: 24),
          _surface(
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Align(
                child: _SetupPill(
                    icon: ready ? Icons.verified_outlined : Icons.sync_rounded,
                    label: ready
                        ? 'READY FOR YOUR NEXT SCAN'
                        : 'FINISHING SETUP')),
            const SizedBox(height: 20),
            _milestone('Device connected', true),
            _milestone('Joined ${setup.selected?.ssid ?? 'home Wi-Fi'}',
                setup.deviceJoinedHome),
            _milestone(
                setup.linksAccount
                    ? 'Account linked and camera verified'
                    : 'Camera verified and ready',
                ready),
          ])),
          if (!ready) ...[
            const SizedBox(height: 16),
            SetupHint(
                setup.isBrowser
                    ? 'Return to your home Wi-Fi and keep this tab open. We’ll finish here.'
                    : 'If your phone stays on Dentra Wi-Fi, return to home Wi-Fi so we can check the camera. Keep it powered on.',
                icon: Icons.wifi_rounded),
          ],
        ]);
    }
    if (setup.busy) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: 18),
        child: _surface(Semantics(
            liveRegion: true,
            child: Row(children: [
              const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(_busyLabel,
                      style:
                          const TextStyle(color: AppColors.navy, height: 1.4))),
            ]))),
      ));
    }
    if (setup.error != null) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: 16),
        child: SetupNotice(title: 'Let’s try that again', body: setup.error!),
      ));
    }
    return SetupScene(children: children);
  }

  String get _busyLabel => switch (_setup.phase) {
        WifiSetupPhase.preparing => 'Starting your secure setup session…',
        WifiSetupPhase.joiningDevice => 'Connecting to your device…',
        WifiSetupPhase.scanning => 'Looking for home networks…',
        WifiSetupPhase.joiningHome => 'Your device is joining Wi-Fi…',
        WifiSetupPhase.returningHome => 'Returning to home Wi-Fi…',
        _ => 'Checking your camera…',
      };

  Widget _surface(Widget child) {
    final radius = BorderRadius.circular(28);
    return ClipRRect(
        borderRadius: radius,
        child: GlassBlur(
            child: DecoratedBox(
          decoration: BoxDecoration(
              borderRadius: radius,
              gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xCFFFFFFF), Color(0x65FFFFFF)]),
              border: Border.all(color: const Color(0xE6FFFFFF), width: 1.3)),
          child: Padding(padding: const EdgeInsets.all(20), child: child),
        )));
  }

  Widget _heading(String text) => Text(text,
      style: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.navy,
          height: 1.2));

  Widget _iconTile(IconData icon) => Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white)),
      child: Icon(icon, size: 21, color: AppColors.primary));

  Widget _infoRow(IconData icon, String title, String body) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _iconTile(icon),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w600,
                  height: 1.4)),
          const SizedBox(height: 3),
          Text(body,
              style: const TextStyle(
                  color: AppColors.secondaryText, fontSize: 13, height: 1.45)),
        ])),
      ]);

  InputDecoration _input(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
        filled: true,
        fillColor: AppColors.white.withValues(alpha: 0.65),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide:
                BorderSide(color: AppColors.primary.withValues(alpha: 0.18))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      );

  Widget _networkRow(WifiNetwork network) => ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 5),
        leading: _iconTile(network.bars < 2
            ? Icons.network_wifi_1_bar_rounded
            : Icons.wifi_rounded),
        title: Text(network.ssid,
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: AppColors.navy)),
        subtitle: Text(network.secure ? 'Password protected' : 'Open network',
            style:
                const TextStyle(fontSize: 12, color: AppColors.secondaryText)),
        trailing: Icon(
            network.secure
                ? Icons.lock_outline_rounded
                : Icons.chevron_right_rounded,
            size: 18,
            color: AppColors.primary),
        onTap: _setup.busy
            ? null
            : () {
                _password.clear();
                _showPassword = false;
                _setup.select(network);
              },
      );

  Widget _milestone(String text, bool complete) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Icon(
              complete
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: complete ? AppColors.primary : AppColors.secondaryText,
              size: 22),
          const SizedBox(width: 12),
          Expanded(
              child: Text(text,
                  style: TextStyle(
                      color:
                          complete ? AppColors.navy : AppColors.secondaryText,
                      height: 1.4))),
        ]),
      );

  void _connect() {
    FocusScope.of(context).unfocus();
    unawaited(_setup.connectDevice(_setup.isBrowser ? '' : _key.text.trim()));
  }

  void _join() {
    FocusScope.of(context).unfocus();
    unawaited(_setup.joinHome(_password.text));
  }

  Future<void> _hiddenNetwork() async {
    final network = await showModalBottomSheet<WifiNetwork>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HiddenNetworkSheet(
          decoration: _input('Network name', Icons.wifi_rounded)),
    );
    if (!mounted || network == null) return;
    _password.clear();
    _showPassword = false;
    _setup.select(network);
  }

  Widget _actions() {
    if (_setup.step == WifiSetupStep.network &&
        _setup.selected == null &&
        !_setup.busy) {
      return const GuidePrimaryButton(
          label: 'Choose a network above', onPressed: null);
    }
    if (_setup.busy) {
      return GuidePrimaryButton(label: _busyLabel, onPressed: null);
    }
    final (label, action) = switch (_setup.step) {
      WifiSetupStep.prepare => ('My device is on', _setup.next),
      WifiSetupStep.device => (
          _setup.isBrowser
              ? 'I’ve joined Dentra Wi-Fi'
              : _setup.requiresManualJoin
                  ? 'Check device connection'
                  : 'Connect to device',
          _connect
        ),
      WifiSetupStep.network => ('Connect to home Wi-Fi', _join),
      WifiSetupStep.finish => _setup.saved != null
          ? ('Continue', () => _close(SetupOutcome.done))
          : ('Check connection', () => unawaited(_setup.verify())),
    };
    return GuidePrimaryButton(
        label: label,
        icon: Icons.arrow_forward_rounded,
        iconAfter: true,
        onPressed:
            _setup.step == WifiSetupStep.network && _setup.selected == null
                ? null
                : action);
  }
}

class _SetupPill extends StatelessWidget {
  const _SetupPill({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.85))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: AppColors.primary),
          const SizedBox(width: 7),
          Flexible(
              child: Text(label,
                  style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: AppColors.primary))),
        ]),
      );
}

class _HiddenNetworkSheet extends StatefulWidget {
  const _HiddenNetworkSheet({required this.decoration});
  final InputDecoration decoration;
  @override
  State<_HiddenNetworkSheet> createState() => _HiddenNetworkSheetState();
}

class _HiddenNetworkSheetState extends State<_HiddenNetworkSheet> {
  final _ssid = TextEditingController();
  bool _secure = true;
  String? _error;
  @override
  void dispose() {
    _ssid.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: GlassSurface(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Add a hidden network',
                          style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: AppColors.navy)),
                      const SizedBox(height: 10),
                      const Text(
                          'Enter the exact name of your 2.4 GHz Wi-Fi network.'),
                      const SizedBox(height: 20),
                      TextField(
                          controller: _ssid,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration:
                              widget.decoration.copyWith(errorText: _error)),
                      SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Requires a password'),
                          value: _secure,
                          onChanged: (value) =>
                              setState(() => _secure = value)),
                      const SizedBox(height: 12),
                      GuidePrimaryButton(
                          label: 'Use this network',
                          onPressed: () {
                            final name = _ssid.text;
                            if (name.trim().isEmpty ||
                                utf8.encode(name).length > 32) {
                              setState(() => _error =
                                  'Enter a network name of 1–32 bytes.');
                              return;
                            }
                            Navigator.pop(
                                context,
                                WifiNetwork(
                                    ssid: name, rssi: -70, secure: _secure));
                          }),
                    ]),
              )),
        ),
      );
}
