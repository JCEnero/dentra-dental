import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:universal_ble/universal_ble.dart';

import '../camera_strings.dart';
import '../data/camera_config.dart';
import '../data/camera_protocol.dart';

/// Whether Bluetooth can be used for setup right now.
enum BleReadiness { ready, needsPermission, bluetoothOff, unsupported }

/// A Dentra Cam in setup mode, seen while scanning.
class FoundCamera {
  const FoundCamera({required this.id, required this.name, this.rssi});

  /// The platform's id for it, only meaningful to [CameraSetupLink].
  final String id;
  final String name;
  final int? rssi;

  int? get bars => rssi == null ? null : signalBars(rssi!);
}

/// Bluetooth, as far as the setup guide needs it. The guide only talks to
/// this, so it can be tested without a radio.
abstract class CameraSetupLink {
  /// Never shows a system prompt.
  Future<BleReadiness> readiness();

  /// Shows the system prompt if needed. True once Bluetooth may be used.
  Future<bool> requestPermission();

  /// Only Android can switch Bluetooth on (after asking the user).
  bool get canTurnOnBluetooth;
  Future<bool> turnOnBluetooth();

  /// Cameras in setup mode, each reported again as its signal changes.
  /// Listening starts a scan and cancelling stops it.
  Stream<FoundCamera> discover();

  /// Connects and gets the camera ready for commands.
  Future<CameraSetupSession> connect(FoundCamera camera);
}

/// An open Bluetooth connection to one camera.
abstract class CameraSetupSession {
  /// What the camera says. Ends when the connection drops.
  Stream<SetupEvent> get events;

  Future<void> send(Map<String, Object?> command);

  Future<void> close();
}

/// [CameraSetupLink] through `universal_ble`.
class UniversalBleSetupLink implements CameraSetupLink {
  UniversalBleSetupLink({required this.isAndroid});

  final bool isAndroid;

  @override
  bool get canTurnOnBluetooth => isAndroid;

  @override
  Future<BleReadiness> readiness() async {
    // Permission first: on iPhones, reading the adapter state before access
    // is granted would show the system prompt before the explanation.
    try {
      if (!await UniversalBle.hasPermissions()) {
        return BleReadiness.needsPermission;
      }
    } catch (_) {
      return BleReadiness.needsPermission;
    }
    var state = await _availability();
    if (state == AvailabilityState.unknown ||
        state == AvailabilityState.resetting) {
      // The adapter is still starting up; one short wait is usually enough.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      state = await _availability();
    }
    return switch (state) {
      AvailabilityState.poweredOn => BleReadiness.ready,
      AvailabilityState.unsupported => BleReadiness.unsupported,
      AvailabilityState.unauthorized => BleReadiness.needsPermission,
      _ => BleReadiness.bluetoothOff,
    };
  }

  Future<AvailabilityState> _availability() async {
    try {
      return await UniversalBle.getBluetoothAvailabilityState();
    } catch (_) {
      return AvailabilityState.unknown;
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      // On Android 11 and older this also asks for location, which BLE
      // scanning needs there.
      await UniversalBle.requestPermissions();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> turnOnBluetooth() async {
    if (!isAndroid) return false;
    try {
      return await UniversalBle.enableBluetooth();
    } catch (_) {
      return false;
    }
  }

  @override
  Stream<FoundCamera> discover() {
    late final StreamController<FoundCamera> out;
    StreamSubscription<BleDevice>? results;
    out = StreamController<FoundCamera>(
      onListen: () async {
        results = UniversalBle.scanStream.listen((device) {
          final name = device.name ?? '';
          final isCamera = device.services.contains(CamBle.service) ||
              name.startsWith(CamBle.namePrefix);
          if (!isCamera) return;
          out.add(FoundCamera(
            id: device.deviceId,
            name: name.isEmpty ? CamText.product : name,
            rssi: device.rssi,
          ));
        });
        try {
          // Either condition matches: the service, or the name.
          await UniversalBle.startScan(
            scanFilter: ScanFilter(
              withServices: [CamBle.service],
              withNamePrefix: [CamBle.namePrefix],
            ),
          );
        } catch (e) {
          if (!out.isClosed) out.addError(e);
        }
      },
      onCancel: () async {
        await results?.cancel();
        try {
          await UniversalBle.stopScan();
        } catch (_) {
          // Already stopped.
        }
      },
    );
    return out.stream;
  }

  @override
  Future<CameraSetupSession> connect(FoundCamera camera) async {
    final id = camera.id;
    await UniversalBle.connect(id, timeout: CameraConfig.bleConnectTimeout);
    try {
      final services = await UniversalBle.discoverServices(
        id,
        timeout: CameraConfig.bleConnectTimeout,
      );
      final hasSetup = services.any(
        (s) => s.uuid.toLowerCase() == CamBle.service,
      );
      if (!hasSetup) throw StateError('Not a Dentra Cam in setup mode');
      try {
        await UniversalBle.requestMtu(id, CamBle.preferredMtu);
      } catch (_) {
        // Lines are framed, so the default MTU works too, only slower.
      }
      final session = _BleSession(id);
      await session.open();
      return session;
    } catch (_) {
      unawaited(UniversalBle.disconnect(id).catchError((_) {}));
      rethrow;
    }
  }
}

class _BleSession implements CameraSetupSession {
  _BleSession(this.id);

  final String id;
  final _events = StreamController<SetupEvent>.broadcast();
  final _lines = SetupLineDecoder();
  StreamSubscription<Uint8List>? _values;
  StreamSubscription<bool>? _link;

  Future<void> open() async {
    _values =
        UniversalBle.characteristicValueStream(id, CamBle.events).listen((v) {
      for (final line in _lines.add(v)) {
        final event = parseSetupEvent(line);
        if (event != null && !_events.isClosed) _events.add(event);
      }
    });
    _link = UniversalBle.connectionStream(id).listen((connected) {
      if (!connected) _end();
    });
    await UniversalBle.subscribeNotifications(
        id, CamBle.service, CamBle.events);
  }

  @override
  Stream<SetupEvent> get events => _events.stream;

  @override
  Future<void> send(Map<String, Object?> command) => UniversalBle.write(
        id,
        CamBle.service,
        CamBle.command,
        Uint8List.fromList(utf8.encode(jsonEncode(command))),
        timeout: CameraConfig.bleWriteTimeout,
      );

  @override
  Future<void> close() async {
    _end();
    try {
      await UniversalBle.disconnect(id);
    } catch (_) {
      // Already gone, e.g. after the camera restarted.
    }
  }

  void _end() {
    _values?.cancel();
    _link?.cancel();
    if (!_events.isClosed) _events.close();
  }
}
