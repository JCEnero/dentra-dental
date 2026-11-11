import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/saved_camera.dart';
import '../services/cloud_cam_api.dart';

/// The website's setup guide: the camera gets the home Wi-Fi from its own
/// hotspot, and a code from here links it to the account.
enum HotspotStep { welcome, power, join, ready }

/// The code shown on the join step.
enum CodeState { loading, ready, failed, expired }

/// Runs the website's setup guide. The camera does the joining; this side
/// gets a code from the API and waits for the camera to use it.
class HotspotSetupController extends ChangeNotifier {
  HotspotSetupController({
    required CloudCamApi api,
    required Future<void> Function(SavedCamera camera) onSaved,
    @visibleForTesting Duration checkEvery = const Duration(seconds: 2),
    @visibleForTesting Duration slowAfter = const Duration(minutes: 3),
  })  : _api = api,
        _onSaved = onSaved,
        _checkEvery = checkEvery,
        _slowAfter = slowAfter;

  final CloudCamApi _api;
  final Future<void> Function(SavedCamera camera) _onSaved;
  final Duration _checkEvery;
  final Duration _slowAfter;

  HotspotStep _step = HotspotStep.welcome;
  HotspotStep get step => _step;

  /// 1 moving forward, -1 back: which way the pages slide.
  int _direction = 1;
  int get direction => _direction;

  CodeState _codeState = CodeState.loading;
  CodeState get codeState => _codeState;

  CamPairing? _pairing;
  CamPairing? get pairing => _pairing;

  /// Waiting long enough that something probably went wrong.
  bool _slow = false;
  bool get slow => _slow;

  SavedCamera? _saved;

  /// The camera, once linked.
  SavedCamera? get saved => _saved;

  bool get canGoBack =>
      _step == HotspotStep.power || _step == HotspotStep.join;

  Timer? _check;
  Timer? _slowTimer;
  bool _checking = false;
  bool _disposed = false;

  void next() {
    switch (_step) {
      case HotspotStep.welcome:
        _go(HotspotStep.power);
      case HotspotStep.power:
        _go(HotspotStep.join);
        unawaited(newCode());
      case HotspotStep.join:
      case HotspotStep.ready:
        break;
    }
  }

  void back() {
    switch (_step) {
      case HotspotStep.power:
        _go(HotspotStep.welcome, back: true);
      case HotspotStep.join:
        _stopWaiting();
        _go(HotspotStep.power, back: true);
      case HotspotStep.welcome:
      case HotspotStep.ready:
        break;
    }
  }

  /// A fresh code (the old one stops working), then waiting for the camera.
  Future<void> newCode() async {
    _stopWaiting();
    _codeState = CodeState.loading;
    _slow = false;
    _notify();
    try {
      final pairing = await _api.createPairing();
      if (_disposed || _step != HotspotStep.join) return;
      _pairing = pairing;
      _codeState = CodeState.ready;
      _check = Timer.periodic(_checkEvery, (_) => unawaited(_checkPairing()));
      _slowTimer = Timer(_slowAfter, () {
        _slow = true;
        _notify();
      });
    } catch (_) {
      if (_disposed) return;
      _codeState = CodeState.failed;
    }
    _notify();
  }

  Future<void> _checkPairing() async {
    final pairing = _pairing;
    if (_checking || pairing == null || _codeState != CodeState.ready) return;
    _checking = true;
    try {
      final status = await _api.pairing(pairing.id);
      if (_disposed || _pairing != pairing) return;
      switch (status.state) {
        case PairingState.pending:
          break;
        case PairingState.expired:
          _stopWaiting();
          _codeState = CodeState.expired;
          _notify();
        case PairingState.claimed:
          final camera = status.camera ?? (await _api.cameras()).firstOrNull;
          // Asked again on the next tick.
          if (camera == null || _disposed) return;
          _stopWaiting();
          final saved = camera.toSaved();
          await _onSaved(saved);
          if (_disposed) return;
          _saved = saved;
          _go(HotspotStep.ready);
      }
    } catch (_) {
      // Most likely still on the camera's Wi-Fi, which has no internet.
      // Keep asking.
    } finally {
      _checking = false;
    }
  }

  void _stopWaiting() {
    _check?.cancel();
    _slowTimer?.cancel();
    _check = _slowTimer = null;
  }

  void _go(HotspotStep step, {bool back = false}) {
    _direction = back ? -1 : 1;
    _step = step;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _stopWaiting();
    super.dispose();
  }
}
