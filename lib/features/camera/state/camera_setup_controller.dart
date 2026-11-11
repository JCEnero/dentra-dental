import 'dart:async';

import 'package:flutter/foundation.dart';

import '../camera_strings.dart';
import '../data/camera_config.dart';
import '../data/camera_protocol.dart';
import '../data/saved_camera.dart';
import '../services/camera_setup_link.dart';
import '../services/dentra_cam_client.dart';

enum SetupStep { welcome, permissions, power, find, wifi, connect }

enum PermissionState {
  checking,
  needed,
  requesting,
  granted,
  denied,
  bluetoothOff,
  unsupported,
}

/// The connect step's progress, in order.
enum JoinStage { sending, joining, restarting, finding, done }

enum JoinProblem {
  ssidNotFound,
  timeout,
  notOnNetwork,
  linkLost,
  failed,
}

/// The setup guide, step by step: Bluetooth access, finding the camera,
/// choosing Wi-Fi, and following the camera onto the network.
///
/// The Wi-Fi password only passes through [join] on its way to the camera;
/// nothing here keeps it.
class CameraSetupController extends ChangeNotifier {
  CameraSetupController({
    required CameraSetupLink link,
    required DentraCamClient Function(String host) clientFor,
    required Future<void> Function(SavedCamera camera) onSaved,
    @visibleForTesting DateTime Function()? clock,
  })  : _link = link,
        _clientFor = clientFor,
        _onSaved = onSaved,
        _now = clock ?? DateTime.now;

  final CameraSetupLink _link;
  final DentraCamClient Function(String host) _clientFor;
  final Future<void> Function(SavedCamera camera) _onSaved;
  final DateTime Function() _now;

  bool _disposed = false;

  SetupStep _step = SetupStep.welcome;
  SetupStep get step => _step;

  /// 1 when the last move was forward, -1 when back.
  int _direction = 1;
  int get direction => _direction;

  bool get canLinkTurnOnBluetooth => _link.canTurnOnBluetooth;

  // ── Permissions ─────────────────────────────────────────────────
  PermissionState _permission = PermissionState.checking;
  PermissionState get permission => _permission;
  bool _asked = false;

  // ── Find ────────────────────────────────────────────────────────
  bool _searching = false;
  bool get searching => _searching;
  final Map<String, FoundCamera> _found = {};

  /// Strongest signal first.
  List<FoundCamera> get cameras => _found.values.toList()
    ..sort((a, b) => (b.rssi ?? -999).compareTo(a.rssi ?? -999));
  FoundCamera? _connecting;
  FoundCamera? get connecting => _connecting;
  String? _findError;
  String? get findError => _findError;
  StreamSubscription<FoundCamera>? _scan;
  Timer? _scanTimer;

  CameraSetupSession? _session;
  StreamSubscription<SetupEvent>? _sessionEvents;
  FoundCamera? _camera;

  // ── Wi-Fi ───────────────────────────────────────────────────────
  bool _wifiLoading = false;
  bool get wifiLoading => _wifiLoading;
  bool _wifiFailed = false;
  bool get wifiFailed => _wifiFailed;

  /// The camera dropped out of Bluetooth before setup finished.
  bool get linkLost => _session == null && _camera != null && !_manual;
  List<WifiNetwork> _networks = const [];
  List<WifiNetwork> get networks => _networks;
  WifiNetwork? _chosen;
  WifiNetwork? get chosen => _chosen;
  String? _passwordError;
  String? get passwordError => _passwordError;
  Timer? _wifiTimer;

  // ── Connect ─────────────────────────────────────────────────────
  JoinStage _stage = JoinStage.sending;
  JoinStage get stage => _stage;
  JoinProblem? _problem;
  JoinProblem? get problem => _problem;

  /// Added by address, so there was no Bluetooth or Wi-Fi step.
  bool _manual = false;
  bool get manual => _manual;
  String? _ip;
  SavedCamera? _saved;
  SavedCamera? get saved => _saved;

  /// The network the camera is on, for messages.
  String? get ssid => _chosen?.ssid;

  /// Invalidates timers and loops from an earlier attempt.
  int _run = 0;
  Timer? _joinTimer;
  Timer? _restartTimer;

  bool get canGoBack => switch (_step) {
        SetupStep.welcome => false,
        SetupStep.connect => _problem != null,
        _ => true,
      };

  // ── Moving between steps ────────────────────────────────────────

  void next() {
    switch (_step) {
      case SetupStep.welcome:
        _go(SetupStep.permissions);
      case SetupStep.permissions:
        if (_permission == PermissionState.granted) _go(SetupStep.power);
      case SetupStep.power:
        _go(SetupStep.find);
      case SetupStep.find:
      case SetupStep.wifi:
      case SetupStep.connect:
        break;
    }
  }

  void back() {
    if (!canGoBack) return;
    switch (_step) {
      case SetupStep.welcome:
        break;
      case SetupStep.permissions:
        _go(SetupStep.welcome, forward: false);
      case SetupStep.power:
        _go(SetupStep.permissions, forward: false);
      case SetupStep.find:
        _stopScan();
        _go(SetupStep.power, forward: false);
      case SetupStep.wifi:
        if (_chosen != null && !linkLost) {
          chooseNetwork(null);
          return;
        }
        unawaited(_closeSession());
        _go(SetupStep.find, forward: false);
      case SetupStep.connect:
        _run++;
        _problem = null;
        if (_session != null) {
          _go(SetupStep.wifi, forward: false, enter: false);
        } else {
          _manual = false;
          _go(SetupStep.find, forward: false);
        }
    }
  }

  void _go(SetupStep step, {bool forward = true, bool enter = true}) {
    _direction = forward ? 1 : -1;
    _step = step;
    _notify();
    if (!enter) return;
    switch (step) {
      case SetupStep.permissions:
        unawaited(_checkPermission());
      case SetupStep.find:
        _startScan();
      case SetupStep.wifi:
        unawaited(_requestNetworks());
      case SetupStep.welcome:
      case SetupStep.power:
      case SetupStep.connect:
        break;
    }
  }

  // ── Permissions ─────────────────────────────────────────────────

  /// Also called when the app comes back, e.g. from Settings.
  Future<void> recheck() async {
    if (_step == SetupStep.permissions &&
        _permission != PermissionState.requesting) {
      await _checkPermission();
    }
  }

  Future<void> _checkPermission({bool advance = false}) async {
    _permission = PermissionState.checking;
    _notify();
    final readiness = await _link.readiness();
    if (_disposed || _step != SetupStep.permissions) return;
    _permission = switch (readiness) {
      BleReadiness.ready => PermissionState.granted,
      BleReadiness.needsPermission =>
        _asked ? PermissionState.denied : PermissionState.needed,
      BleReadiness.bluetoothOff => PermissionState.bluetoothOff,
      BleReadiness.unsupported => PermissionState.unsupported,
    };
    _notify();
    if (advance && _permission == PermissionState.granted) {
      _go(SetupStep.power);
    }
  }

  /// Shows the system prompt, and moves on once Bluetooth may be used.
  Future<void> allowBluetooth() async {
    _permission = PermissionState.requesting;
    _notify();
    final granted = await _link.requestPermission();
    _asked = true;
    if (_disposed || _step != SetupStep.permissions) return;
    if (!granted) {
      _permission = PermissionState.denied;
      _notify();
      return;
    }
    await _checkPermission(advance: true);
  }

  Future<void> turnOnBluetooth() async {
    if (_link.canTurnOnBluetooth) await _link.turnOnBluetooth();
    if (_disposed || _step != SetupStep.permissions) return;
    await _checkPermission(advance: true);
  }

  // ── Find ────────────────────────────────────────────────────────

  void scanAgain() {
    if (_step == SetupStep.find && !_searching && _connecting == null) {
      _startScan();
    }
  }

  void _startScan() {
    _stopScan();
    _found.clear();
    _findError = null;
    _connecting = null;
    _searching = true;
    _notify();
    _scan = _link.discover().listen(
      (camera) {
        if (_step != SetupStep.find) return;
        _found[camera.id] = camera;
        _notify();
      },
      onError: (Object _) => _endScan(),
    );
    _scanTimer = Timer(CameraConfig.bleScanFor, _endScan);
  }

  void _endScan() {
    _stopScan();
    if (_searching) {
      _searching = false;
      _notify();
    }
  }

  void _stopScan() {
    _scanTimer?.cancel();
    _scanTimer = null;
    final scan = _scan;
    _scan = null;
    unawaited(scan?.cancel());
  }

  Future<void> choose(FoundCamera camera) async {
    if (_connecting != null || _step != SetupStep.find) return;
    // Scanning while connecting is unreliable on many phones.
    _stopScan();
    _searching = false;
    _connecting = camera;
    _findError = null;
    _notify();
    final CameraSetupSession session;
    try {
      session = await _link.connect(camera);
    } catch (_) {
      if (_disposed) return;
      _connecting = null;
      _findError = CamText.findConnectFailed(camera.name);
      _notify();
      return;
    }
    if (_disposed || _step != SetupStep.find) {
      unawaited(session.close());
      return;
    }
    _camera = camera;
    _session = session;
    _sessionEvents = session.events.listen(_onEvent, onDone: _onSessionDone);
    _connecting = null;
    _chosen = null;
    _passwordError = null;
    _networks = const [];
    _go(SetupStep.wifi);
  }

  /// For a camera that's already on Wi-Fi: no Bluetooth, straight to
  /// looking for it at [ip].
  void useAddress(String ip) {
    if (!isIpv4(ip)) return;
    _stopScan();
    _searching = false;
    unawaited(_closeSession());
    _manual = true;
    _camera = null;
    _chosen = null;
    _ip = ip;
    _problem = null;
    _stage = JoinStage.finding;
    _go(SetupStep.connect);
    unawaited(_findOnNetwork(++_run, within: const Duration(seconds: 8)));
  }

  // ── Wi-Fi ───────────────────────────────────────────────────────

  Future<void> rescanWifi() => _requestNetworks();

  Future<void> _requestNetworks() async {
    final session = _session;
    _wifiTimer?.cancel();
    if (session == null) {
      _wifiLoading = false;
      _wifiFailed = true;
      _notify();
      return;
    }
    _wifiLoading = true;
    _wifiFailed = false;
    _notify();
    // Set before sending: the list can arrive before the write returns.
    _endWifiWait();
    final answered = _wifiAnswered = Completer<void>();
    _wifiTimer = Timer(CameraConfig.wifiScanTimeout, () {
      if (_wifiLoading) {
        _wifiLoading = false;
        _wifiFailed = true;
        _notify();
      }
      _endWifiWait();
    });
    try {
      await session.send({'cmd': 'scan'});
    } catch (_) {
      _wifiTimer?.cancel();
      _endWifiWait();
      if (_disposed) return;
      _wifiLoading = false;
      _wifiFailed = true;
      _notify();
      return;
    }
    // Waits for the list, so pull-to-refresh spins until it's in.
    await answered.future;
  }

  /// Completes while a Wi-Fi list is awaited.
  Completer<void>? _wifiAnswered;

  void _endWifiWait() {
    final answered = _wifiAnswered;
    _wifiAnswered = null;
    if (answered != null && !answered.isCompleted) answered.complete();
  }

  /// Picks a network to join, or null to go back to the list.
  void chooseNetwork(WifiNetwork? network) {
    _chosen = network;
    _passwordError = null;
    _notify();
  }

  // ── Connect ─────────────────────────────────────────────────────

  /// Sends the chosen network to the camera and follows it onto Wi-Fi.
  Future<void> join(String password) async {
    final session = _session;
    final network = _chosen;
    if (session == null || network == null) return;
    if (network.secure && password.length < 8) {
      _passwordError = CamText.wifiPasswordShort;
      _notify();
      return;
    }
    _passwordError = null;
    final run = ++_run;
    _ip = null;
    _problem = null;
    _stage = JoinStage.sending;
    _go(SetupStep.connect);
    _joinTimer?.cancel();
    _joinTimer = Timer(CameraConfig.joinTimeout, () {
      if (run == _run && _stage.index < JoinStage.restarting.index) {
        _fail(JoinProblem.timeout);
      }
    });
    try {
      await session.send({
        'cmd': 'connect',
        'ssid': network.ssid,
        'password': network.secure ? password : '',
      });
    } catch (_) {
      if (run == _run && _stage == JoinStage.sending) {
        _fail(_session == null ? JoinProblem.linkLost : JoinProblem.failed);
      }
      return;
    }
    if (run == _run && _stage == JoinStage.sending) {
      _stage = JoinStage.joining;
      _notify();
    }
  }

  /// Looks for the camera on the network again.
  void findAgain() {
    if (_problem != JoinProblem.notOnNetwork || _ip == null) return;
    _problem = null;
    unawaited(_findOnNetwork(
      ++_run,
      within: _manual ? const Duration(seconds: 8) : null,
    ));
  }

  /// Back to finding the camera, from scratch.
  void startOver() {
    _run++;
    _problem = null;
    _manual = false;
    _chosen = null;
    unawaited(_closeSession());
    _go(SetupStep.find, forward: false);
  }

  void _onEvent(SetupEvent event) {
    switch (event) {
      case NetworksEvent(:final networks):
        if (_step != SetupStep.wifi) return;
        _wifiTimer?.cancel();
        _networks = WifiNetwork.strongestFirst(networks);
        _wifiLoading = false;
        _wifiFailed = false;
        _notify();
        _endWifiWait();
      case JoinEvent(:final state, :final ip, :final error):
        if (_step != SetupStep.connect || _problem != null) return;
        if (_stage.index >= JoinStage.restarting.index) return;
        switch (state) {
          case JoinState.connecting:
            _stage = JoinStage.joining;
            _notify();
          case JoinState.connected:
            _joinTimer?.cancel();
            if (ip == null) {
              _fail(JoinProblem.notOnNetwork);
              return;
            }
            _ip = ip;
            _stage = JoinStage.restarting;
            _notify();
            final run = _run;
            _restartTimer?.cancel();
            _restartTimer = Timer(CameraConfig.restartPause, () {
              if (run == _run) unawaited(_findOnNetwork(run));
            });
          case JoinState.restarting:
            break;
          case JoinState.failed:
            _joinTimer?.cancel();
            if (error == JoinError.wrongPassword) {
              _run++;
              _passwordError = CamText.errorWrongPassword;
              _go(SetupStep.wifi, forward: false, enter: false);
              return;
            }
            _fail(switch (error) {
              JoinError.ssidNotFound => JoinProblem.ssidNotFound,
              JoinError.timeout => JoinProblem.timeout,
              _ => JoinProblem.failed,
            });
        }
    }
  }

  /// The Bluetooth link closed. Expected once the camera restarts onto
  /// Wi-Fi; anywhere else it means the camera is gone.
  void _onSessionDone() {
    _session = null;
    _sessionEvents = null;
    if (_disposed) return;
    if (_step == SetupStep.connect) {
      if (_problem == null && _stage.index < JoinStage.restarting.index) {
        _fail(JoinProblem.linkLost);
      }
      return;
    }
    if (_step == SetupStep.wifi) {
      _wifiTimer?.cancel();
      _endWifiWait();
      _wifiLoading = false;
      _wifiFailed = true;
    }
    _notify();
  }

  Future<void> _findOnNetwork(int run, {Duration? within}) async {
    final ip = _ip;
    if (ip == null) return;
    _stage = JoinStage.finding;
    _notify();
    final client = _clientFor(ip);
    final until = _now().add(within ?? CameraConfig.findOnNetworkFor);
    try {
      while (run == _run && !_disposed) {
        try {
          await client.status(timeout: const Duration(seconds: 2));
          if (run != _run || _disposed) return;
          await _finish(ip);
          return;
        } catch (_) {
          // Not there yet: it may still be restarting.
        }
        if (!_now().isBefore(until)) break;
        await Future<void>.delayed(CameraConfig.findEvery);
      }
      if (run == _run && !_disposed) _fail(JoinProblem.notOnNetwork);
    } finally {
      client.close();
    }
  }

  Future<void> _finish(String ip) async {
    final camera = SavedCamera(
      host: ip,
      name: _camera?.name ?? CamText.product,
      ssid: _chosen?.ssid,
      savedAt: _now(),
    );
    _saved = camera;
    _stage = JoinStage.done;
    _notify();
    unawaited(_closeSession());
    await _onSaved(camera);
  }

  void _fail(JoinProblem problem) {
    _run++;
    _joinTimer?.cancel();
    _restartTimer?.cancel();
    _problem = problem;
    _notify();
  }

  Future<void> _closeSession() async {
    final session = _session;
    final events = _sessionEvents;
    _session = null;
    _sessionEvents = null;
    // Stops listening at once, so closing isn't mistaken for a lost link.
    unawaited(events?.cancel());
    await session?.close();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _run++;
    _stopScan();
    _wifiTimer?.cancel();
    _joinTimer?.cancel();
    _restartTimer?.cancel();
    _endWifiWait();
    unawaited(_closeSession());
    super.dispose();
  }
}
