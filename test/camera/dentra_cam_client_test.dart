import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dentra_mobile/features/camera/data/camera_protocol.dart';
import 'package:dentra_mobile/features/camera/services/dentra_cam_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;

final _photo = Uint8List.fromList(img.encodeJpg(img.Image(width: 16, height: 12)));

void main() {
  late List<Uri> requests;

  DentraCamClient client(http.Response Function(Uri) answer) {
    requests = [];
    return DentraCamClient(
      '192.168.1.40',
      client: MockClient((req) async {
        requests.add(req.url);
        return answer(req.url);
      }),
    );
  }

  test('status reads the signal and settings', () async {
    final cam = client((_) => http.Response(
          jsonEncode({
            'rssi': -61,
            'framesize': 10,
            'vflip': 1,
            'hmirror': 0,
            'light': true,
            'light_level': 60,
            'light_available': false,
          }),
          200,
        ));
    final status = await cam.status();
    expect(requests.single.toString(), 'http://192.168.1.40/status');
    expect(status.rssi, -61);
    expect(status.frameSize, CamFrameSize.vga);
    expect(status.vflip, isTrue);
    expect(status.hmirror, isFalse);
    expect(status.lightOn, isTrue);
    expect(status.lightLevel, 60);
    expect(status.lightAvailable, isFalse);
  });

  test('firmware without /status still counts as there', () async {
    final status = await client((_) => http.Response('', 404)).status();
    expect(status.rssi, isNull);
  });

  test('a camera that is not there throws', () async {
    final cam = DentraCamClient(
      '192.168.1.40',
      client: MockClient((_) async => throw http.ClientException('refused')),
    );
    await expectLater(
      cam.status(),
      throwsA(isA<DentraCamException>()
          .having((e) => e.failure, 'failure', CamFailure.unreachable)),
    );
  });

  test('settings go to /light and /control', () async {
    final cam = client((_) => http.Response('OK', 200));
    await cam.setLight(on: true, level: 140);
    await cam.setControl('vflip', 1);
    expect(requests.map((u) => u.toString()), [
      'http://192.168.1.40/light?on=1&level=100',
      'http://192.168.1.40/control?var=vflip&val=1',
    ]);
  });

  test('capture asks for the size and the light, and wants a JPEG', () async {
    final cam = client((_) => http.Response.bytes(_photo, 200));
    final bytes = await cam.capture(size: CamFrameSize.uxga, light: true);
    expect(bytes, _photo);
    expect(requests.single.toString(),
        'http://192.168.1.40/capture?res=15&flash=1');

    final broken = client((_) => http.Response('no frame', 200));
    await expectLater(
      broken.capture(size: CamFrameSize.uxga, light: true),
      throwsA(isA<DentraCamException>()),
    );
  });

  test('the stream comes from port 81 as whole frames, and ends in an error',
      () async {
    final frame = Uint8List.fromList([0xFF, 0xD8, ...List.filled(120, 7), 0xFF, 0xD9]);
    final body = StreamController<List<int>>();
    late Uri asked;
    final cam = DentraCamClient(
      '192.168.1.40',
      client: MockClient((_) async => http.Response('', 404)),
      streamClient: () => MockClient.streaming((req, _) async {
        asked = req.url;
        return http.StreamedResponse(body.stream, 200);
      }),
    );
    final frames = <Uint8List>[];
    Object? error;
    final done = Completer<void>();
    cam.frames().listen(
          frames.add,
          onError: (Object e) => error = e,
          onDone: done.complete,
        );
    final part = [
      ...latin1.encode('\r\n--b\r\nContent-Type: image/jpeg\r\n'
          'Content-Length: ${frame.length}\r\n\r\n'),
      ...frame,
    ];
    body
      ..add(part.sublist(0, 50))
      ..add(part.sublist(50))
      ..add(part);
    await body.close();
    await done.future;
    expect(asked.toString(), 'http://192.168.1.40:81/stream');
    expect(frames, [frame, frame]);
    expect(error, isA<DentraCamException>());
  });

  test('a stream the camera refuses ends in an error', () async {
    final cam = DentraCamClient(
      '192.168.1.40',
      client: MockClient((_) async => http.Response('', 404)),
      streamClient: () => MockClient.streaming(
          (_, __) async => http.StreamedResponse(const Stream.empty(), 503)),
    );
    await expectLater(cam.frames(), emitsError(isA<DentraCamException>()));
  });
}
