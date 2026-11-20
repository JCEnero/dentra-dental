import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../data/saved_camera.dart';
import '../services/cloud_cam_api.dart';
import '../services/dentra_cam_client.dart';
import '../services/qr_provisioning_codec.dart';

enum QrSetupPhase {
  prepare,
  details,
  encoding,
  waiting,
  linking,
  verifying,
  expired,
  ready
}

/// The phone stays online. The device receives credentials optically and
/// echoes the random QR session in a fresh status before setup completes.
class QrSetupController extends ChangeNotifier {
  QrSetupController({
    required CloudCamApi? api,
    required CamClient Function(String) clientFor,
    required Future<void> Function(SavedCamera) onSaved,
    QrProvisioningCodec? codec,
    this.checkEvery = const Duration(seconds: 2),
    this.now = DateTime.now,
  })  : _api = api,
        _clientFor = clientFor,
        _onSaved = onSaved,
        _codec = codec ?? QrProvisioningCodec();

  final CloudCamApi? _api;
  final CamClient Function(String) _clientFor;
  final Future<void> Function(SavedCamera) _onSaved;
  final QrProvisioningCodec _codec;
  final Duration checkEvery;
  final DateTime Function() now;
  QrSetupPhase phase = QrSetupPhase.prepare;
  SetupQr? qr;
  String? error;
  String? ssid;
  bool deviceFound = false;
  bool qrConfirmed = false;
  bool waitingLong = false;
  DateTime? _waitingSince;
  SavedCamera? saved;
  CamPairing? _pairing;
  CamClient? _client;
  Timer? _poll;
  bool _checking = false;
  bool _disposed = false;
  int _generation = 0;
  bool get busy =>
      phase == QrSetupPhase.encoding || phase == QrSetupPhase.verifying;
  bool _current(int run) => !_disposed && _generation == run;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void next() {
    phase = QrSetupPhase.details;
    error = null;
    _notify();
  }

  void edit() {
    ++_generation;
    _poll?.cancel();
    _poll = null;
    _client?.close();
    _client = null;
    qr = null;
    deviceFound = qrConfirmed = waitingLong = false;
    _waitingSince = null;
    _pairing = null;
    error = null;
    phase = QrSetupPhase.details;
    _notify();
  }

  Future<void> generate(
      {required String ssid,
      required String password,
      bool secured = true}) async {
    if (busy || _disposed) return;
    if (_api == null) {
      error = 'Sign in while online to set up your device.';
      _notify();
      return;
    }
    try {
      QrProvisioningCodec.validateWifi(
          ssid: ssid, password: password, secured: secured);
    } on FormatException catch (e) {
      error = e.message;
      _notify();
      return;
    }
    final run = ++_generation;
    _poll?.cancel();
    _client?.close();
    _client = null;
    qr = null;
    deviceFound = qrConfirmed = waitingLong = false;
    error = null;
    phase = QrSetupPhase.encoding;
    _notify();
    try {
      final pairing = await _api!.createPairing();
      if (!_current(run)) return;
      if (!pairing.expiresAt.isAfter(now())) {
        throw const FormatException('Expired setup session');
      }
      final packet = await _codec.encodeSimple(
          ssid: ssid, password: password, code: pairing.code, secured: secured);
      if (!_current(run)) return;
      this.ssid = ssid;
      _pairing = pairing;
      qr = packet;
      _waitingSince = now();
      phase = QrSetupPhase.waiting;
      _notify();
      _poll = Timer.periodic(checkEvery, (_) => unawaited(check()));
    } catch (e) {
      if (!_current(run)) return;
      error = e is ApiException
          ? e.message
          : 'Couldn’t create your setup code. Check your internet connection and try again.';
      phase = QrSetupPhase.details;
      _notify();
    }
  }

  Future<void> check() async {
    final pairing = _pairing;
    final expected = qr;
    if (_disposed ||
        _checking ||
        pairing == null ||
        expected == null ||
        saved != null) {
      return;
    }
    final run = _generation;
    if (!pairing.expiresAt.isAfter(now())) {
      _expire();
      return;
    }
    _checking = true;
    try {
      final result = await _api!.pairing(pairing.id);
      if (!_current(run)) return;
      if (result.state == PairingState.expired) {
        _expire();
        return;
      }
      final camera = result.camera;
      if (result.state != PairingState.claimed || camera == null) {
        if (!waitingLong &&
            _waitingSince != null &&
            now().difference(_waitingSince!) >= const Duration(seconds: 30)) {
          waitingLong = true;
          _notify();
        }
        return;
      }
      final hardware = camera.hardwareId;
      if (hardware == null ||
          !RegExp(r'^[A-Fa-f0-9]{12}$').hasMatch(hardware)) {
        return;
      }
      deviceFound = true;
      if (!camera.online) {
        phase = QrSetupPhase.linking;
        error = null;
        _notify();
        return;
      }
      phase = QrSetupPhase.verifying;
      error = null;
      _notify();
      _client ??= _clientFor(camera.id);
      final status =
          await _client!.status(timeout: const Duration(seconds: 12));
      if (!_current(run)) return;
      if (status.deviceId?.toUpperCase() != hardware.toUpperCase() ||
          status.setupSession != expected.session) {
        error =
            'Waiting for the device that scanned this code. Keep your Dentra Cam powered on.';
        qrConfirmed = false;
        phase = QrSetupPhase.linking;
        _notify();
        return;
      }
      qrConfirmed = true;
      _notify();
      if (status.cameraReady != true) {
        error =
            'Your device is online, but its camera isn’t ready. Restart the device and check again.';
        phase = QrSetupPhase.verifying;
        _notify();
        return;
      }
      final selected = camera.toSaved();
      await _onSaved(selected);
      if (!_current(run)) return;
      saved = selected;
      phase = QrSetupPhase.ready;
      qr = null;
      _poll?.cancel();
      _poll = null;
      _notify();
    } catch (_) {
      if (!_current(run)) return;
      // Offline devices cannot report a wrong password through the cloud.
      // Keep the QR available and offer Edit rather than inventing progress.
      phase = deviceFound ? QrSetupPhase.linking : QrSetupPhase.waiting;
      error =
          'Still waiting for your device. Keep this phone online. If nothing changes, check your Wi-Fi details or show the QR again.';
      _notify();
    } finally {
      _checking = false;
    }
  }

  void _expire() {
    _poll?.cancel();
    _poll = null;
    qr = null;
    phase = QrSetupPhase.expired;
    error =
        'This setup code expired. Create a fresh code. If your device already joined Wi-Fi, hold its button for 5 seconds so it can scan again.';
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _poll?.cancel();
    _client?.close();
    qr = null;
    super.dispose();
  }
}
