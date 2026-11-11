import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../scan/data/models/captured_image.dart';
import '../data/camera_config.dart';
import '../data/camera_protocol.dart';
import '../data/saved_camera.dart';
import '../services/dentra_cam_client.dart';
import '../services/dentra_cam_device_service.dart';

enum LivePhase {
  /// No picture yet.
  connecting,
  live,

  /// The picture stopped; trying again every [CameraConfig.reconnectEvery].
  reconnecting,

  /// Nothing for the client's [CamClient.giveUpAfter].
  /// [LiveCameraController.retry] starts again.
  disconnected,
}

/// The live picture from one Dentra Cam: keeps the stream open, reconnects
/// when it drops, reads the signal strength, applies settings and takes
/// photos.
///
/// Pictures go to [frame] rather than through [notifyListeners], so twenty
/// a second don't rebuild the whole screen.
class LiveCameraController extends ChangeNotifier {
  LiveCameraController({
    required CamClient client,
    required CameraViewSettings settings,
    this.onSettingsChanged,
    @visibleForTesting DateTime Function()? clock,
  })  : _client = client,
        _settings = settings,
        _now = clock ?? DateTime.now;

  final CamClient _client;
  final DateTime Function() _now;

  /// Called with every change, to keep it for next time.
  final ValueChanged<CameraViewSettings>? onSettingsChanged;

  /// The latest picture, as JPEG bytes. Held still while a photo is taken.
  final ValueNotifier<Uint8List?> frame = ValueNotifier(null);

  LivePhase _phase = LivePhase.connecting;
  LivePhase get phase => _phase;
  bool get isLive => _phase == LivePhase.live;

  int? _rssi;

  /// Wi-Fi signal as 0–4 bars; null until the camera reports it.
  int? get signal => _rssi == null ? null : signalBars(_rssi!);

  CameraViewSettings _settings;
  CameraViewSettings get settings => _settings;

  bool _lightAvailable = true;

  /// False once the camera says it has no light, so its controls hide.
  bool get lightAvailable => _lightAvailable;

  bool _capturing = false;
  bool get capturing => _capturing;

  bool _running = false;
  bool _disposed = false;

  StreamSubscription<Uint8List>? _stream;

  /// Counts connection attempts, so a late callback from an old one is
  /// ignored.
  int _attempt = 0;
  Timer? _retry;
  Timer? _giveUp;
  Timer? _status;
  Timer? _watchdog;
  DateTime? _lastFrame;
  bool _readingStatus = false;

  /// Opens the stream and starts watching it. Called when the screen opens
  /// and when the app comes back to the front.
  void start() {
    if (_running || _disposed) return;
    _running = true;
    _setPhase(
        frame.value == null ? LivePhase.connecting : LivePhase.reconnecting);
    _troubleStarted();
    _open();
    _status = Timer.periodic(CameraConfig.statusEvery, (_) => _readStatus());
    unawaited(_readStatus());
    _watchdog = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _checkStall(),
    );
  }

  /// Closes the stream and switches the light off, e.g. when the app goes to
  /// the background or another page covers the camera.
  void stop() => unawaited(_halt());

  /// Starts over after [LivePhase.disconnected], with a fresh
  /// [CamClient.giveUpAfter].
  void retry() {
    if (_disposed) return;
    if (!_running) {
      start();
      return;
    }
    _giveUp?.cancel();
    _giveUp = null;
    _setPhase(
        frame.value == null ? LivePhase.connecting : LivePhase.reconnecting);
    _troubleStarted();
    _open();
  }

  /// Takes a full-size photo. The picture holds still meanwhile. Throws
  /// [DentraCamException] when the camera can't.
  Future<CapturedImage> capture() async {
    if (_capturing) throw StateError('Already taking a photo');
    _capturing = true;
    _notify();
    try {
      final bytes = await _client.capture(
        size: CameraConfig.captureSize,
        light: CameraConfig.captureWithLight,
      );
      return dentraCamImage(bytes);
    } finally {
      _capturing = false;
      // The camera may pause the stream while it takes the photo.
      _lastFrame = _now();
      _notify();
    }
  }

  // ── Settings ────────────────────────────────────────────────────
  // Each shows at once and is kept; the camera gets it now and again
  // whenever the picture reconnects. False when it didn't take it.

  Future<bool> setLight({bool? on, int? level}) => _update(
        _settings.copyWith(lightOn: on, lightLevel: level),
        (s) => _client.setLight(on: s.lightOn, level: s.lightLevel),
      );

  /// Turns the picture upside down.
  Future<bool> rotate() => _update(
        _settings.copyWith(
            vflip: !_settings.vflip, hmirror: !_settings.hmirror),
        (s) async {
          await _client.setControl('vflip', s.vflip ? 1 : 0);
          await _client.setControl('hmirror', s.hmirror ? 1 : 0);
        },
      );

  /// Swaps left and right.
  Future<bool> mirror() => _update(
        _settings.copyWith(hmirror: !_settings.hmirror),
        (s) => _client.setControl('hmirror', s.hmirror ? 1 : 0),
      );

  Future<bool> setLiveSize(CamFrameSize size) => _update(
        _settings.copyWith(liveSize: size),
        (s) => _client.setControl('framesize', s.liveSize.value),
      );

  Future<bool> _update(
    CameraViewSettings next,
    Future<void> Function(CameraViewSettings) send,
  ) async {
    _settings = next;
    _notify();
    onSettingsChanged?.call(next);
    try {
      await send(next);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Sends every setting, e.g. after the camera restarted. Stops at the
  /// first sign it can't be reached; skips what older firmware lacks.
  Future<void> _applySettings() async {
    final s = _settings;
    final sends = <Future<void> Function()>[
      () => _client.setControl('framesize', s.liveSize.value),
      () => _client.setControl('vflip', s.vflip ? 1 : 0),
      () => _client.setControl('hmirror', s.hmirror ? 1 : 0),
      if (_lightAvailable)
        () => _client.setLight(on: s.lightOn, level: s.lightLevel),
    ];
    for (final send in sends) {
      if (!_running) return;
      try {
        await send();
      } on DentraCamException catch (e) {
        if (e.failure != CamFailure.badResponse) return;
      } catch (_) {
        return;
      }
    }
  }

  // ── Stream ──────────────────────────────────────────────────────

  void _open() {
    _retry?.cancel();
    _stream?.cancel();
    final attempt = ++_attempt;
    _stream = _client.frames().listen(
      (bytes) {
        if (attempt != _attempt) return;
        _lastFrame = _now();
        if (_phase != LivePhase.live) {
          _giveUp?.cancel();
          _giveUp = null;
          _setPhase(LivePhase.live);
          unawaited(_applySettings());
        }
        if (!_capturing) frame.value = bytes;
      },
      onError: (Object _) => _dropped(attempt),
      onDone: () => _dropped(attempt),
      cancelOnError: true,
    );
  }

  void _dropped(int attempt) {
    if (attempt != _attempt || !_running || _phase == LivePhase.disconnected) {
      return;
    }
    _attempt++;
    _stream?.cancel();
    _stream = null;
    if (_phase == LivePhase.live) _setPhase(LivePhase.reconnecting);
    _troubleStarted();
    _retry?.cancel();
    _retry = Timer(CameraConfig.reconnectEvery, () {
      if (_running && _phase != LivePhase.disconnected) _open();
    });
  }

  /// Starts the clock on giving up, unless it's already running.
  void _troubleStarted() {
    _giveUp ??= Timer(_client.giveUpAfter, () {
      _giveUp = null;
      if (!_running || _phase == LivePhase.live) return;
      _attempt++;
      _stream?.cancel();
      _stream = null;
      _retry?.cancel();
      _setPhase(LivePhase.disconnected);
    });
  }

  /// A stream can stall without closing, e.g. when Wi-Fi fades.
  void _checkStall() {
    if (_phase != LivePhase.live || _capturing) return;
    final last = _lastFrame;
    if (last != null && _now().difference(last) > _client.stallAfter) {
      _dropped(_attempt);
    }
  }

  Future<void> _readStatus() async {
    if (!_running || _readingStatus) return;
    _readingStatus = true;
    int? rssi;
    var lightAvailable = _lightAvailable;
    try {
      final status = await _client.status();
      rssi = status.rssi;
      lightAvailable = status.lightAvailable ?? lightAvailable;
    } catch (_) {
      rssi = null;
    } finally {
      _readingStatus = false;
    }
    if (_running && (rssi != _rssi || lightAvailable != _lightAvailable)) {
      _rssi = rssi;
      _lightAvailable = lightAvailable;
      _notify();
    }
  }

  /// Stops everything; resolves once the light-off request is done.
  Future<void> _halt() async {
    if (!_running) return;
    _running = false;
    _attempt++;
    _stream?.cancel();
    _stream = null;
    for (final timer in [_retry, _giveUp, _status, _watchdog]) {
      timer?.cancel();
    }
    _retry = _giveUp = _status = _watchdog = null;
    if (!_settings.lightOn || !_lightAvailable) return;
    try {
      await _client.setLight(on: false, level: _settings.lightLevel);
    } catch (_) {
      // The camera may be gone already.
    }
  }

  void _setPhase(LivePhase phase) {
    if (_phase == phase) return;
    _phase = phase;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    final halted = _halt();
    _disposed = true;
    frame.dispose();
    // Closing the client right away would cancel the light-off request.
    unawaited(halted.whenComplete(_client.close));
    super.dispose();
  }
}
