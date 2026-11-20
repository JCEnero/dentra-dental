import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dentra_mobile/features/camera/data/camera_protocol.dart';
import 'package:dentra_mobile/features/camera/services/cloud_cam_client.dart';
import 'package:dentra_mobile/features/camera/services/dentra_cam_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'camera_fakes.dart';

/// The relay's side of the socket, driven by the test.
class FakeSocket implements CamSocket {
  final incoming = StreamController<Object?>();
  final sent = <Map<String, Object?>>[];
  bool closed = false;

  @override
  Stream<Object?> get messages => incoming.stream;

  @override
  void send(String message) =>
      sent.add(jsonDecode(message) as Map<String, Object?>);

  @override
  Future<void> close() async {
    closed = true;
    await incoming.close();
  }

  void json(Map<String, Object?> message) => incoming.add(jsonEncode(message));

  void ready({bool online = true}) => json({
        'type': 'ready',
        'online': online,
        'status': {'rssi': -50}
      });

  /// The last command of [cmd] the client sent.
  Map<String, Object?> lastSent(String cmd) =>
      sent.lastWhere((m) => m['cmd'] == cmd);
}

Uint8List framed(int kind, List<int> body, {int? id}) => Uint8List.fromList([
      kind,
      if (id != null) ...[
        id >> 24 & 0xFF,
        id >> 16 & 0xFF,
        id >> 8 & 0xFF,
        id & 0xFF
      ],
      ...body,
    ]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeSocket socket;
  late List<Uri> opened;
  late CloudCamClient client;

  setUp(() {
    socket = FakeSocket();
    opened = [];
    client = CloudCamClient(
      deviceId: 'cam-1',
      socketUri: Uri.parse('wss://api.example/api/cam/ws'),
      accessToken: () async => 'user-token',
      connect: (uri) async {
        opened.add(uri);
        return socket;
      },
    );
  });

  tearDown(() => client.close());

  test('the relay address comes from the API base URL', () {
    expect(cloudCamSocketUri('https://dentra-api.example').toString(),
        'wss://dentra-api.example/api/cam/ws');
    expect(cloudCamSocketUri('http://10.0.2.2:4000/').toString(),
        'ws://10.0.2.2:4000/api/cam/ws');
  });

  test('signs in first, then pictures flow while someone watches', () async {
    final frames = <Uint8List>[];
    final sub = client.frames().listen(frames.add);
    await pumpEventQueue();
    expect(socket.sent.first,
        {'type': 'auth', 'token': 'user-token', 'device': 'cam-1'});

    socket.ready();
    await pumpEventQueue();
    expect(socket.lastSent('stream'), {'cmd': 'stream', 'on': true});

    socket.incoming.add(framed(1, frameBytes(4)));
    await pumpEventQueue();
    expect(frames.single, frameBytes(4));
    // Safari's Flutter fallback decodes the whole backing buffer. It must
    // contain only the JPEG, without the relay's message-type prefix.
    expect(frames.single.offsetInBytes, 0);
    expect(frames.single.buffer.asUint8List(), frameBytes(4));

    await sub.cancel();
    await pumpEventQueue();
    expect(socket.lastSent('stream'), {'cmd': 'stream', 'on': false});
    expect(opened, hasLength(1));
  });

  test('a camera that is away fails the picture at once', () async {
    final errors = <Object>[];
    client.frames().listen((_) {}, onError: errors.add);
    await pumpEventQueue();
    socket.ready(online: false);
    await pumpEventQueue();
    expect(errors.single, isA<DentraCamException>());
    expect(
      (errors.single as DentraCamException).failure,
      CamFailure.unreachable,
    );
  });

  test('the camera leaving ends the picture and what was waiting', () async {
    final errors = <Object>[];
    client.frames().listen((_) {}, onError: errors.add);
    await pumpEventQueue();
    socket.ready();
    await pumpEventQueue();

    final status = expectLater(
      client.status(),
      throwsA(isA<DentraCamException>()
          .having((e) => e.failure, 'failure', CamFailure.unreachable)),
    );
    await pumpEventQueue();
    socket.json({'type': 'online', 'online': false});
    await pumpEventQueue();
    expect(errors, hasLength(1));
    await status;
  });

  test('commands carry their own ids, and answers find their way back',
      () async {
    final status = client.status();
    await pumpEventQueue();
    socket.ready();
    await pumpEventQueue();
    final ask = socket.lastSent('status');
    socket.json({
      'type': 'result',
      'id': ask['id'],
      'ok': true,
      'status': {'rssi': -61, 'light_available': false, 'vflip': 1},
    });
    final result = await status;
    expect(result.rssi, -61);
    expect(result.lightAvailable, isFalse);
    expect(result.vflip, isTrue);

    final control = client.setControl('vflip', 0);
    await pumpEventQueue();
    final sent = socket.lastSent('control');
    expect(sent['var'], 'vflip');
    expect(sent['val'], 0);
    expect(sent['id'], isNot(ask['id']));
    socket.json({'type': 'result', 'id': sent['id'], 'ok': true});
    await control;

    // The camera answered, but couldn't.
    final light = client.setLight(on: true, level: 140);
    await pumpEventQueue();
    final lightSent = socket.lastSent('light');
    expect(lightSent['level'], 100);
    socket.json({
      'type': 'result',
      'id': lightSent['id'],
      'ok': false,
      'error': 'no_light',
    });
    await expectLater(
      light,
      throwsA(isA<DentraCamException>()
          .having((e) => e.failure, 'failure', CamFailure.badResponse)),
    );
  });

  test('a photo comes back as its own binary message', () async {
    final photo = client.capture(size: CamFrameSize.uxga, light: false);
    await pumpEventQueue();
    socket.ready();
    await pumpEventQueue();
    final ask = socket.lastSent('capture');
    expect(ask['res'], CamFrameSize.uxga.value);
    expect(ask['flash'], isFalse);

    // Another photo's answer is not this one's.
    socket.incoming.add(framed(2, frameBytes(1), id: 999));
    socket.incoming.add(framed(2, frameBytes(7), id: ask['id']! as int));
    final bytes = await photo;
    expect(bytes, frameBytes(7));
    expect(bytes.offsetInBytes, 0);
    expect(bytes.buffer.asUint8List(), frameBytes(7));
  });

  test('a cloud JPEG backing buffer decodes without relay headers', () async {
    final jpeg = Uint8List.fromList(img.encodeJpg(
        img.Image(width: 32, height: 24)..clear(img.ColorRgb8(20, 150, 90))));
    final frames = <Uint8List>[];
    final sub = client.frames().listen(frames.add);
    await pumpEventQueue();
    socket.ready();
    await pumpEventQueue();
    final message = framed(1, jpeg);
    socket.incoming.add(message);
    await pumpEventQueue();
    final bytes = frames.single;
    // Reproduce the browser fallback's buffer access, not just the view.
    expect(bytes.buffer.asUint8List(), jpeg);
    final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
    final decoded = await codec.getNextFrame();
    expect(decoded.image.width, 32);
    expect(decoded.image.height, 24);
    decoded.image.dispose();
    codec.dispose();
    // A relay buffer can be reused without changing the decoded frame bytes.
    message.fillRange(0, message.length, 0);
    expect(bytes, jpeg);
    await sub.cancel();
  });

  // A widget test, for its fake clock.
  testWidgets('an answer that never comes is a timeout', (tester) async {
    Object? error;
    final done = client.setControl('hmirror', 1).catchError((Object e) {
      error = e;
    });
    await tester.pump();
    socket.ready();
    await tester.pump();
    await tester.pump(const Duration(seconds: 13));
    await done;
    expect(error, isA<DentraCamException>());
    expect((error! as DentraCamException).failure, CamFailure.timeout);
  });

  test('a closed link opens again for the next request', () async {
    final first = client.status();
    await pumpEventQueue();
    socket.ready();
    await pumpEventQueue();
    await socket.incoming.close();
    await expectLater(first, throwsA(isA<DentraCamException>()));

    socket = FakeSocket();
    final second = client.status();
    await pumpEventQueue();
    socket.ready();
    await pumpEventQueue();
    socket.json(
        {'type': 'result', 'id': socket.lastSent('status')['id'], 'ok': true});
    await second;
    expect(opened, hasLength(2));
  });

  test('without a session there is nothing to sign in with', () async {
    final signedOut = CloudCamClient(
      deviceId: 'cam-1',
      socketUri: Uri.parse('wss://api.example/api/cam/ws'),
      accessToken: () async => null,
      connect: (uri) async => socket,
    );
    await expectLater(signedOut.status(), throwsA(isA<DentraCamException>()));
    signedOut.close();
  });
}
