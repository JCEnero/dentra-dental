import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_backdrop.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../auth/widgets/dentra_logo.dart';
import '../data/camera_protocol.dart';
import '../data/saved_camera.dart';
import '../providers/camera_providers.dart';
import '../state/hotspot_setup_controller.dart';
import '../widgets/camera_connection_art.dart';
import 'camera_setup_screen.dart' show SetupOutcome;

/// Wi-Fi credentials belong on the camera's captive portal. This page only
/// explains how to join and prepares the existing account ownership code.
class CaptiveSetupScreen extends ConsumerStatefulWidget {
  const CaptiveSetupScreen({super.key});

  static Route<SetupOutcome> route() => MaterialPageRoute<SetupOutcome>(
        builder: (_) => const CaptiveSetupScreen(),
      );

  @override
  ConsumerState<CaptiveSetupScreen> createState() => _CaptiveSetupScreenState();
}

class _CaptiveSetupScreenState extends ConsumerState<CaptiveSetupScreen> {
  HotspotSetupController? _account;
  final _address = TextEditingController();
  String? _notice;
  bool _checkingLocal = false;
  SavedCamera? _localCamera;

  @override
  void initState() {
    super.initState();
    final api = ref.read(cloudCamApiProvider);
    if (ref.read(camLinkProvider) == CamLink.cloud && api != null) {
      _account = HotspotSetupController(
        api: api,
        onSaved: (camera) =>
            ref.read(savedCameraProvider.notifier).save(camera),
      )
        ..addListener(_changed)
        // A single card replaces the welcome/power/join wizard.
        ..next()
        ..next();
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _account
      ?..removeListener(_changed)
      ..dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _copyCode() async {
    final code = _account?.pairing?.code;
    if (code == null) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) showDentraSnack(context, 'Account code copied');
  }

  Future<void> _openPortal() async {
    try {
      final opened = await launchUrl(Uri.parse('http://192.168.4.1/'),
          mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
      if (opened) return;
    } catch (_) {
      // The address stays visible and selectable if external opening fails.
    }
    if (mounted) {
      setState(() => _notice =
          'While connected to Dentra Wi-Fi, open http://192.168.4.1 in your browser.');
    }
  }

  Future<void> _saveLocalCamera() async {
    final host = _address.text.trim();
    if (!isIpv4(host) || host == '192.168.4.1') {
      setState(() => _notice = 'Enter the home-network IP shown after setup.');
      return;
    }
    setState(() {
      _checkingLocal = true;
      _notice = null;
    });
    final client = ref.read(camClientFactoryProvider)(host);
    try {
      final status = await client.status();
      final id = status.deviceId;
      if (id == null ||
          !RegExp(r'^[a-fA-F0-9]{12}$').hasMatch(id) ||
          status.cameraReady != true) {
        throw const FormatException('Camera not ready');
      }
      if (!mounted) return;
      final camera = SavedCamera(
        host: host,
        name: 'Dentra Cam ${id.substring(8).toUpperCase()}',
        savedAt: DateTime.now(),
      );
      await ref.read(savedCameraProvider.notifier).save(camera);
      if (mounted) setState(() => _localCamera = camera);
    } catch (_) {
      if (mounted) {
        setState(() => _notice =
            'Camera not ready at this address. Join your home Wi-Fi and check the IP shown on the setup page.');
      }
    } finally {
      client.close();
      if (mounted) setState(() => _checkingLocal = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = _account;
    final saved = account?.saved ?? _localCamera;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      body: AppBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) => Opacity(
                  opacity: value,
                  child: Transform.translate(
                      offset: Offset(0, 12 * (1 - value)), child: child),
                ),
                child: Column(children: [
                  _header(saved),
                  Expanded(
                      child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CameraConnectionArt(connected: saved != null),
                        AnimatedSwitcher(
                          duration: reduceMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 300),
                          child: Text(
                            saved == null
                                ? 'Connect. Then smile.'
                                : 'Your camera is linked.',
                            key: ValueKey(saved != null),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 29,
                                height: 1.18,
                                letterSpacing: -.9,
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          saved == null
                              ? 'Power on your camera. A quick setup awaits.'
                              : '${saved.name} is saved in Dentra.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: AppColors.secondaryText),
                        ),
                        const SizedBox(height: 24),
                        if (saved != null)
                          DentraPillButton(
                            label: 'Start capturing',
                            onPressed: () => Navigator.of(context)
                                .pop(SetupOutcome.startCapturing),
                          )
                        else ...[
                          GlassCard(
                            padding: const EdgeInsets.all(22),
                            borderRadius: BorderRadius.circular(26),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _instruction(
                                    Icons.wifi_rounded,
                                    'Join Dentra Cam XXXX',
                                    'Open Wi-Fi settings. No password needed.'),
                                const SizedBox(height: 20),
                                _instruction(
                                    Icons.open_in_browser_rounded,
                                    'Choose your home Wi-Fi',
                                    'Enter its password on the page that opens.'),
                                if (account != null) ...[
                                  const Divider(
                                      height: 32, color: Color(0x1A167D8D)),
                                  _accountCode(account),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Theme(
                            data: Theme.of(context)
                                .copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              title: const Text('Setup page didn’t open?',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.navy)),
                              tilePadding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              childrenPadding:
                                  const EdgeInsets.fromLTRB(6, 0, 6, 12),
                              expandedCrossAxisAlignment:
                                  CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                    'While connected to Dentra Wi-Fi, open:',
                                    style:
                                        TextStyle(fontSize: 14, height: 1.5)),
                                const SizedBox(height: 6),
                                const SelectableText('http://192.168.4.1/',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600)),
                                TextButton(
                                    onPressed: _openPortal,
                                    child:
                                        const Text('Open camera setup page')),
                                const Text(
                                    'Already configured? Hold BOOT for 5 seconds to start setup again.',
                                    style: TextStyle(
                                        fontSize: 14,
                                        height: 1.5,
                                        color: AppColors.secondaryText)),
                              ],
                            ),
                          ),
                          if (account == null &&
                              ref.read(camLinkProvider) == CamLink.local)
                            _localAddress(),
                        ],
                        if (_notice != null) ...[
                          const SizedBox(height: 12),
                          DentraInlineNotice(message: _notice),
                        ],
                      ],
                    ),
                  )),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(SavedCamera? saved) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        child: Row(children: [
          const DentraLogo(size: .9),
          const Spacer(),
          IconButton(
            tooltip: 'Close setup',
            onPressed: () => Navigator.of(context)
                .pop(saved == null ? null : SetupOutcome.done),
            icon: const Icon(Icons.close_rounded, size: 22),
          ),
        ]),
      );

  Widget _accountCode(HotspotSetupController account) => AnimatedSize(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 250),
        alignment: Alignment.topCenter,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Your account code',
              style: TextStyle(fontSize: 14, color: AppColors.secondaryText)),
          if (account.codeState == CodeState.ready) ...[
            Row(children: [
              Expanded(
                  child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SelectableText(
                      account.pairing!.displayCode,
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3,
                          color: AppColors.navy),
                    )),
              )),
              IconButton(
                  tooltip: 'Copy account code',
                  onPressed: _copyCode,
                  icon: const Icon(Icons.copy_rounded,
                      size: 20, color: AppColors.primary)),
            ]),
            const Text(
                'Add this code on the setup page for live view. Then return here.',
                style: TextStyle(
                    fontSize: 14, height: 1.5, color: AppColors.secondaryText)),
          ] else if (account.codeState == CodeState.loading) ...[
            const SizedBox(height: 10),
            const Text('Preparing your code…', style: TextStyle(fontSize: 15)),
          ] else ...[
            const SizedBox(height: 8),
            Text(
                account.codeState == CodeState.expired
                    ? 'Code expired. Reconnect to the internet for a new one.'
                    : 'Go online to get your code before joining Dentra Wi-Fi.',
                style: const TextStyle(fontSize: 14, height: 1.5)),
            Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                    onPressed: () => unawaited(account.newCode()),
                    child: const Text('Get account code'))),
          ],
          if (account.slow) ...[
            const SizedBox(height: 12),
            const Text(
                'Still waiting? Enter your account code on the camera’s page, then rejoin home Wi-Fi.',
                style: TextStyle(fontSize: 14, height: 1.5)),
          ],
        ]),
      );

  Widget _localAddress() => ExpansionTile(
        title: const Text('Use camera on home Wi-Fi',
            style: TextStyle(fontSize: 14)),
        tilePadding: const EdgeInsets.symmetric(horizontal: 6),
        children: [
          const Text(
              'Rejoin home Wi-Fi and enter the camera IP shown after setup.',
              style: TextStyle(fontSize: 14, height: 1.5)),
          const SizedBox(height: 12),
          TextField(
              controller: _address,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Camera IP address'),
              onSubmitted: (_) {
                if (!_checkingLocal) unawaited(_saveLocalCamera());
              }),
          const SizedBox(height: 12),
          DentraPillButton(
              label: 'Use this camera',
              loading: _checkingLocal,
              onPressed: _checkingLocal ? null : _saveLocalCamera),
        ],
      );

  Widget _instruction(IconData icon, String title, String body) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .55),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: .8))),
            child: Icon(icon, color: const Color(0xFF247B73), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.navy)),
                const SizedBox(height: 4),
                Text(body,
                    style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: AppColors.secondaryText)),
              ])),
        ],
      );
}
