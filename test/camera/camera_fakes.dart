import 'dart:async';
import 'dart:typed_data';

import 'package:dentra_mobile/features/camera/data/camera_protocol.dart';
import 'package:dentra_mobile/features/camera/services/camera_setup_link.dart';
import 'package:dentra_mobile/features/camera/services/dentra_cam_client.dart';
import 'package:dentra_mobile/features/scan/services/photo_check_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Fakes for the Dentra Cam: every change is driven by the test.

Uint8List frameBytes(int n) =>
    Uint8List.fromList([0xFF, 0xD8, ...List.filled(120, n), 0xFF, 0xD9]);

/// A camera on the network. Streams, status and captures answer when the
/// test says so.
class FakeCamClient extends DentraCamClient {
  FakeCamClient([super.host = '192.168.1.40'])
      : super(client: MockClient((_) async => http.Response('', 500)));

  final streams = <StreamController<Uint8List>>[];
  final commands = <String>[];
  int? rssi = -52;
  bool? lightAvailable;
  bool reachable = true;
  int statusCalls = 0;
  Completer<Uint8List>? pendingCapture;

  StreamController<Uint8List> get stream => streams.last;
  int get opened => streams.length;

  @override
  Stream<Uint8List> frames() {
    final c = StreamController<Uint8List>();
    streams.add(c);
    return c.stream;
  }

  @override
  Future<CamStatus> status({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    statusCalls++;
    if (!reachable) throw const DentraCamException(CamFailure.unreachable);
    return CamStatus(rssi: rssi, lightAvailable: lightAvailable);
  }

  @override
  Future<void> setLight({required bool on, required int level}) async =>
      commands.add('light ${on ? 'on' : 'off'} $level');

  @override
  Future<void> setControl(String name, int value) async =>
      commands.add('$name=$value');

  @override
  Future<Uint8List> capture({
    required CamFrameSize size,
    required bool light,
    Duration timeout = const Duration(seconds: 15),
  }) {
    commands.add('capture ${size.label} light=$light');
    pendingCapture = Completer<Uint8List>();
    return pendingCapture!.future;
  }

  @override
  void close() {}
}

/// The photo check, answered by the test one photo at a time.
class FakePhotoCheck implements PhotoCheckService {
  final pending = <Completer<PhotoVerdict>>[];

  @override
  Future<PhotoVerdict> check(Uint8List bytes) {
    final c = Completer<PhotoVerdict>();
    pending.add(c);
    return c.future;
  }

  void pass([int i = 0]) => pending[i].complete(const PhotoVerdict.passed());
  void reject(PhotoProblem problem, [int i = 0]) =>
      pending[i].complete(PhotoVerdict.rejected(problem));
  void fail([int i = 0]) =>
      pending[i].completeError(const PhotoCheckException(offline: true));
}

class FakeSetupSession implements CameraSetupSession {
  final _events = StreamController<SetupEvent>.broadcast();
  final sent = <Map<String, Object?>>[];
  bool closed = false;

  @override
  Stream<SetupEvent> get events => _events.stream;

  void emit(SetupEvent event) => _events.add(event);

  /// The camera drops the Bluetooth link, e.g. as it restarts.
  Future<void> drop() => _events.close();

  @override
  Future<void> send(Map<String, Object?> command) async => sent.add(command);

  @override
  Future<void> close() async {
    closed = true;
    if (!_events.isClosed) await _events.close();
  }
}

class FakeSetupLink implements CameraSetupLink {
  BleReadiness state = BleReadiness.needsPermission;
  bool grant = true;
  bool connectFails = false;
  int permissionRequests = 0;
  StreamController<FoundCamera>? scan;
  FakeSetupSession? session;

  @override
  Future<BleReadiness> readiness() async => state;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    if (grant) state = BleReadiness.ready;
    return grant;
  }

  @override
  bool get canTurnOnBluetooth => true;

  @override
  Future<bool> turnOnBluetooth() async {
    state = BleReadiness.ready;
    return true;
  }

  @override
  Stream<FoundCamera> discover() {
    scan = StreamController<FoundCamera>();
    return scan!.stream;
  }

  @override
  Future<CameraSetupSession> connect(FoundCamera camera) async {
    if (connectFails) throw StateError('out of range');
    return session = FakeSetupSession();
  }
}

const cam3f2a = FoundCamera(id: 'aa:bb', name: 'Dentra Cam 3F2A', rssi: -50);
