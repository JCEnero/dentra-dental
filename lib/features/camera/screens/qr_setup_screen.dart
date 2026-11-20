import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/dentra_mascot.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/guide_kit.dart';
import '../providers/camera_providers.dart';
import '../state/qr_setup_controller.dart';
import '../services/qr_provisioning_codec.dart';
import '../widgets/qr_setup_prepare.dart';
import '../widgets/qr_setup_progress.dart';
import '../widgets/setup_page.dart';
import '../services/setup_sound.dart';
import 'camera_setup_screen.dart' show SetupOutcome;

final qrSetupCodecProvider =
    Provider<QrProvisioningCodec>((ref) => QrProvisioningCodec());

class QrSetupScreen extends ConsumerStatefulWidget {
  const QrSetupScreen({super.key});
  static Route<SetupOutcome> route() =>
      MaterialPageRoute(builder: (_) => const QrSetupScreen());
  @override
  ConsumerState<QrSetupScreen> createState() => _QrSetupScreenState();
}

class _QrSetupScreenState extends ConsumerState<QrSetupScreen> {
  late final QrSetupController _setup;
  late final AppLifecycleListener _lifecycle;
  final _ssid = TextEditingController();
  final _password = TextEditingController();
  bool _secured = true;
  bool _showPassword = false;
  bool _soundEnabled = true;
  bool _foreground = true;
  late final SetupSound _sound;
  String _cue = 'prepare';

  String get _currentCue => switch (_setup.phase) {
        QrSetupPhase.prepare => 'prepare',
        QrSetupPhase.details || QrSetupPhase.encoding => 'details',
        QrSetupPhase.ready => 'ready',
        QrSetupPhase.expired => 'expired',
        _ => _setup.qrConfirmed
            ? 'confirmed'
            : _setup.deviceFound
                ? 'found'
                : _setup.waitingLong
                    ? 'help'
                    : 'scanning',
      };

  void _tapSound() {
    _sound.unlock();
  }

  void _toggleSound() {
    _sound.unlock();
    setState(() => _soundEnabled = !_soundEnabled);
    if (_soundEnabled) {
      unawaited(_sound.play());
    } else {
      _sound.stop();
    }
  }

  Widget get _soundButton => IconButton(
      onPressed: _toggleSound,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      padding: EdgeInsets.zero,
      tooltip: _soundEnabled ? 'Mute mascot sounds' : 'Enable mascot sounds',
      icon: Icon(
          _soundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
          size: 18,
          color: AppColors.primary));

  @override
  void initState() {
    super.initState();
    _sound = ref.read(setupSoundFactoryProvider)();
    unawaited(_sound.prepare());
    _setup = QrSetupController(
      api: ref.read(cloudCamApiProvider),
      clientFor: ref.read(cloudCamClientFactoryProvider),
      codec: ref.read(qrSetupCodecProvider),
      onSaved: (camera) => ref.read(savedCameraProvider.notifier).save(camera),
    )..addListener(_changed);
    _lifecycle = AppLifecycleListener(
      onResume: () {
        _foreground = true;
        if (_setup.qr != null) {
          _wake(true);
          unawaited(_setup.check());
        }
      },
      onHide: () {
        _foreground = false;
        _sound.stop();
        _wake(false);
      },
    );
  }

  void _wake(bool enabled) =>
      unawaited(WakelockPlus.toggle(enable: enabled).catchError((_) {}));

  void _changed() {
    final cue = _currentCue;
    if (cue != _cue) {
      _cue = cue;
      if (_soundEnabled && _foreground) unawaited(_sound.play());
    }
    if (_setup.qr != null) {
      _password.clear();
    }
    _wake(_setup.qr != null);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _setup
      ..removeListener(_changed)
      ..dispose();
    unawaited(_sound.dispose());
    _ssid.dispose();
    _password.dispose();
    _wake(false);
    super.dispose();
  }

  void _close([SetupOutcome? outcome]) => Navigator.of(context)
      .pop(outcome ?? (_setup.saved == null ? null : SetupOutcome.done));

  void _generate() {
    _tapSound();
    FocusScope.of(context).unfocus();
    unawaited(_setup.generate(
        ssid: _ssid.text, password: _password.text, secured: _secured));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: _setup,
      builder: (context, _) {
        final step = switch (_setup.phase) {
          QrSetupPhase.prepare => 0,
          QrSetupPhase.details || QrSetupPhase.encoding => 1,
          QrSetupPhase.ready => 3,
          _ => 2,
        };
        return SetupFrame(
            step: step,
            icons: const [
              Icons.power_settings_new_rounded,
              Icons.wifi_rounded,
              Icons.qr_code_2_rounded,
              Icons.check_rounded
            ],
            label: const [
              'Prepare',
              'Wi-Fi details',
              'Show your code',
              'Ready'
            ][step],
            compactProgress: true,
            onClose: () => _close(),
            sceneKey: ValueKey(step),
            direction: 1,
            scene: _scene(step),
            actions: _actions(step));
      });

  Widget _surface(Widget child) => GlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(24),
      child: child);

  Widget _scene(int step) => SetupScene(children: [
        if (step == 1)
          Align(alignment: Alignment.centerRight, child: _soundButton),
        if (step == 0) QrSetupPrepare(soundControl: _soundButton),
        if (step == 1) ...[
          RabiSays(
              title: 'Make yourself\nat home.',
              body: 'Enter your 2.4 GHz Wi-Fi, then create your setup QR.',
              mood: _setup.busy ? MascotMood.think : MascotMood.hush,
              busy: _setup.busy,
              place: RabiPlace.right,
              size: 96),
          const SizedBox(height: 24),
          _surface(
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(
                controller: _ssid,
                enabled: !_setup.busy,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                    labelText: 'Home Wi-Fi name',
                    hintText: 'Enter the exact network name',
                    prefixIcon: Icon(Icons.wifi_rounded),
                    border: OutlineInputBorder())),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Wi-Fi requires a password'),
                value: _secured,
                onChanged: _setup.busy
                    ? null
                    : (value) => setState(() => _secured = value)),
            if (_secured) ...[
              const SizedBox(height: 8),
              TextField(
                  controller: _password,
                  enabled: !_setup.busy,
                  obscureText: !_showPassword,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                      labelText: 'Wi-Fi password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                          tooltip:
                              _showPassword ? 'Hide password' : 'Show password',
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                          icon: Icon(_showPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined)))),
            ],
            const SizedBox(height: 16),
            const Text(
                'Your Wi-Fi details go directly to your device in this QR, never to your Dentra account. Anyone who can see or photograph the QR can read the password.',
                style: TextStyle(
                    fontSize: 13, height: 1.5, color: AppColors.secondaryText)),
          ])),
          if (_setup.busy)
            const Padding(
                padding: EdgeInsets.only(top: 20),
                child: GuideStatus('Creating your setup QR…')),
        ],
        if (step == 2 || step == 3) ...[
          QrSetupProgress(
              phase: _setup.phase,
              deviceFound: _setup.deviceFound,
              qrConfirmed: _setup.qrConfirmed,
              waitingLong: _setup.waitingLong,
              qrData: _setup.qr?.data,
              soundControl: _soundButton),
          if (step == 3) ...[
            const SizedBox(height: 16),
            Center(
                child: Text('Connected to ${_setup.ssid ?? "home Wi-Fi"}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.secondaryText, fontSize: 13))),
          ],
        ],
        if (_setup.error case final error?)
          Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Semantics(
                  liveRegion: true,
                  child: Text(error,
                      style: const TextStyle(
                          height: 1.5, color: AppColors.navy)))),
      ]);

  Widget _actions(int step) {
    if (_setup.phase == QrSetupPhase.encoding) {
      return const SizedBox(height: 48);
    }
    if (step == 0) {
      return GuidePrimaryButton(
          label: 'My device is on',
          icon: Icons.arrow_forward_rounded,
          iconAfter: true,
          onPressed: () {
            _tapSound();
            _setup.next();
          });
    }
    if (step == 1) {
      return GuideActions(
          leading: GuideQuietButton(label: 'Cancel', onPressed: () => _close()),
          trailing:
              GuidePrimaryButton(label: 'Generate QR', onPressed: _generate));
    }
    if (step == 2) {
      return GuideActions(
          leading: GuideQuietButton(
              label: 'Edit details',
              onPressed: () {
                _tapSound();
                _setup.edit();
              }),
          trailing: _setup.phase == QrSetupPhase.expired
              ? GuidePrimaryButton(
                  label: 'Create a fresh code',
                  onPressed: () {
                    _tapSound();
                    _setup.edit();
                  })
              : GuideQuietButton(
                  label: 'Check connection',
                  onPressed: () => unawaited(_setup.check())));
    }
    return GuideActions(
        leading: GuideQuietButton(
            label: 'Done', onPressed: () => _close(SetupOutcome.done)),
        trailing: GuidePrimaryButton(
            label: 'Start capturing',
            onPressed: () => _close(SetupOutcome.startCapturing)));
  }
}
