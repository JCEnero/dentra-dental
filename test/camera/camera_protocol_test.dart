import 'dart:convert';

import 'package:dentra_mobile/features/camera/data/camera_config.dart';
import 'package:dentra_mobile/features/camera/data/camera_protocol.dart';
import 'package:dentra_mobile/features/camera/data/saved_camera.dart';
import 'package:dentra_mobile/features/scan/data/scan_regions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('setup events', () {
    test('a network list, with a missing "secure" read as secured', () {
      final event = parseSetupEvent(jsonEncode({
        'type': 'networks',
        'networks': [
          {'ssid': 'Home', 'rssi': -52, 'secure': true},
          {'ssid': 'Cafe', 'rssi': -70.4, 'secure': false},
          {'ssid': 'Guest', 'rssi': -80},
          {'rssi': -40}, // no name: skipped
        ],
      }));
      expect(event, isA<NetworksEvent>());
      final networks = (event as NetworksEvent).networks;
      expect(networks.map((n) => n.ssid), ['Home', 'Cafe', 'Guest']);
      expect(networks[1].rssi, -70);
      expect(networks[1].secure, isFalse);
      expect(networks[2].secure, isTrue);
    });

    test('joining, joined with an address, and each failure', () {
      JoinEvent read(Map<String, Object> json) =>
          parseSetupEvent(jsonEncode({'type': 'status', ...json})) as JoinEvent;

      expect(read({'state': 'connecting'}).state, JoinState.connecting);
      final joined = read({'state': 'connected', 'ip': '192.168.1.40'});
      expect(joined.state, JoinState.connected);
      expect(joined.ip, '192.168.1.40');
      expect(read({'state': 'restarting'}).state, JoinState.restarting);
      expect(read({'state': 'failed', 'error': 'wrong_password'}).error,
          JoinError.wrongPassword);
      expect(read({'state': 'failed', 'error': 'ssid_not_found'}).error,
          JoinError.ssidNotFound);
      expect(read({'state': 'failed', 'error': 'timeout'}).error,
          JoinError.timeout);
      expect(read({'state': 'failed', 'error': 'new_reason'}).error,
          JoinError.other);
    });

    test('an address that is not plain IPv4 is not trusted', () {
      final event = parseSetupEvent(jsonEncode(
          {'type': 'status', 'state': 'connected', 'ip': 'evil.example'}));
      expect((event as JoinEvent).ip, isNull);
    });

    test('unknown or broken lines are ignored', () {
      expect(parseSetupEvent('not json'), isNull);
      expect(parseSetupEvent('[1, 2]'), isNull);
      expect(parseSetupEvent('{"type":"battery","level":80}'), isNull);
      expect(parseSetupEvent('{"type":"status","state":"dancing"}'), isNull);
    });

    test('lines come back together across notifications', () {
      final decoder = SetupLineDecoder();
      final bytes = utf8.encode('{"type":"status","state":"connecting"}\n'
          '{"type":"status","state":"connected","ip":"10.0.0.7"}\n');
      final lines = <String>[];
      for (var i = 0; i < bytes.length; i += 20) {
        lines.addAll(
            decoder.add(bytes.sublist(i, (i + 20).clamp(0, bytes.length))));
      }
      expect(lines, hasLength(2));
      expect((parseSetupEvent(lines[1]) as JoinEvent).ip, '10.0.0.7');
    });
  });

  test('networks: one per name, strongest first, hidden ones left out', () {
    final sorted = WifiNetwork.strongestFirst(const [
      WifiNetwork(ssid: 'Home', rssi: -70, secure: true),
      WifiNetwork(ssid: 'Cafe', rssi: -50, secure: false),
      WifiNetwork(ssid: 'Home', rssi: -48, secure: true),
      WifiNetwork(ssid: '  ', rssi: -30, secure: true),
    ]);
    expect(sorted.map((n) => '${n.ssid} ${n.rssi}'), ['Home -48', 'Cafe -50']);
  });

  test('signal bars', () {
    expect([-40, -60, -70, -80, -90].map(signalBars), [4, 3, 2, 1, 0]);
  });

  test('IPv4 addresses only', () {
    expect(isIpv4('192.168.1.40'), isTrue);
    expect(isIpv4('10.0.0.255'), isTrue);
    for (final bad in [
      '192.168.1',
      '192.168.1.256',
      '192.168.01.4',
      'dentra.local',
      '1.2.3.4.5',
      '',
      '1..2.3',
    ]) {
      expect(isIpv4(bad), isFalse, reason: bad);
    }
  });

  test('every capture area is a guided view the API accepts', () {
    expect(CameraConfig.captureAreas.map((a) => a.id),
        CameraConfig.captureAreaIds);
    for (final area in CameraConfig.captureAreas) {
      expect(scanRegions.map((r) => r.id), contains(area.id));
    }
  });

  test('frame sizes match esp32-camera in Arduino-ESP32 3.x', () {
    expect(CameraConfig.liveSize, CamFrameSize.vga);
    expect(CamFrameSize.vga.value, 10);
    expect(CamFrameSize.svga.value, 11);
    expect(CamFrameSize.uxga.value, 15);
  });

  group('saved camera', () {
    test('round-trips, and never stores a password', () {
      final camera = SavedCamera(
        host: '192.168.1.40',
        name: 'Dentra Cam 3F2A',
        ssid: 'Home',
        savedAt: DateTime(2026, 11, 11),
      );
      final json = camera.toJson();
      expect(json.keys, isNot(contains('password')));
      final back = SavedCamera.fromJson(jsonDecode(jsonEncode(json)))!;
      expect(back.host, camera.host);
      expect(back.name, camera.name);
      expect(back.ssid, camera.ssid);
    });

    test('anything without a valid address is no camera', () {
      expect(
          SavedCamera.fromJson({'host': 'example.com', 'name': 'x'}), isNull);
      expect(SavedCamera.fromJson('nope'), isNull);
    });

    test('view settings fall back to defaults', () {
      final s = CameraViewSettings.fromJson({'lightLevel': 400, 'vflip': true});
      expect(s.lightLevel, 100);
      expect(s.vflip, isTrue);
      expect(s.lightOn, isTrue);
      expect(s.liveSize, CamFrameSize.vga);
      // Upright in the Dentra Cam is both flips on.
      expect(s.hmirror, isTrue);
      expect(CameraViewSettings.fromJson(null).vflip, isTrue);
    });
  });
}
