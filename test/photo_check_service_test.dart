import 'dart:convert';
import 'dart:typed_data';

import 'package:dentra_mobile/core/network/api_client.dart';
import 'package:dentra_mobile/features/scan/services/photo_check_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;

final _png =
    Uint8List.fromList([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 1, 2]);

http.Response _json(int status, Object body) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

http.Response _error(int status, String code, [String message = 'Nope.']) =>
    _json(status, {
      'error': {'code': code, 'message': message},
    });

/// Answers like the server's on-device stand-in, so tests can see it was used.
class _Unavailable implements PhotoCheckService {
  int calls = 0;

  @override
  Future<PhotoVerdict> check(Uint8List bytes) async {
    calls++;
    return const PhotoVerdict.passed(teethChecked: false);
  }
}

void main() {
  group('the server check', () {
    late List<http.Request> requests;
    late _Unavailable unavailable;

    ApiPhotoCheckService service(Future<http.Response> Function() answer) {
      requests = [];
      unavailable = _Unavailable();
      return ApiPhotoCheckService(
        ApiClient(
          baseUrl: 'https://api.test',
          accessToken: () async => 'token',
          client: MockClient((req) {
            requests.add(req);
            return answer();
          }),
        ),
        whenUnavailable: unavailable,
      );
    }

    test('sends only the photo, as an image', () async {
      final verdict = await service(() async => _json(200, {
            'valid': true,
            'reason': null,
            'message': null,
          })).check(_png);
      expect(verdict.passed, isTrue);
      expect(verdict.teethChecked, isTrue);
      final req = requests.single;
      expect('${req.method} ${req.url.path}',
          'POST /api/screenings/validate-photo');
      expect(req.headers['Content-Type'], 'image/png');
      expect(req.bodyBytes, _png);
    });

    test('a rejection carries its reason and the server\'s advice', () async {
      final verdict = await service(() async => _json(200, {
            'valid': false,
            'reason': 'no_teeth',
            'message': 'No teeth found in this photo.',
          })).check(_png);
      expect(verdict.passed, isFalse);
      expect(verdict.problem, PhotoProblem.noTeeth);
      expect(verdict.message, 'No teeth found in this photo.');

      final unknown = await service(() async => _json(200, {
            'valid': false,
            'reason': 'brand_new_reason',
            'message': 'Try something else.',
          })).check(_png);
      expect(unknown.problem, PhotoProblem.other);
      expect(unknown.message, 'Try something else.');
    });

    test('a server with no analysis falls back to the on-device check',
        () async {
      final verdict =
          await service(() async => _error(503, 'analysis_unavailable'))
              .check(_png);
      expect(unavailable.calls, 1);
      expect(verdict.teethChecked, isFalse);
    });

    test('a file the server won\'t take as a photo is rejected with its reason',
        () async {
      final verdict = await service(() async => _error(
              415, 'unsupported_image', 'Use a JPEG, PNG or WebP photo.'))
          .check(_png);
      expect(verdict.problem, PhotoProblem.other);
      expect(verdict.message, 'Use a JPEG, PNG or WebP photo.');
    });

    test('anything else is no verdict, never a pass', () async {
      await expectLater(
        service(() async => _error(503, 'check_unavailable')).check(_png),
        throwsA(isA<PhotoCheckException>()
            .having((e) => e.offline, 'offline', isFalse)),
      );
      await expectLater(
        service(() async => _error(429, 'rate_limited', 'Slow down.'))
            .check(_png),
        throwsA(isA<PhotoCheckException>()
            .having((e) => e.message, 'message', 'Slow down.')),
      );
      await expectLater(
        service(() async => throw http.ClientException('no route')).check(_png),
        throwsA(isA<PhotoCheckException>()
            .having((e) => e.offline, 'offline', isTrue)),
      );
      expect(unavailable.calls, 0);
    });
  });

  group('the on-device check', () {
    Uint8List png(int w, int h, int Function(int x, int y) gray) {
      final image = img.Image(width: w, height: h);
      for (final p in image) {
        final v = gray(p.x, p.y);
        p.setRgb(v, v, v);
      }
      return img.encodePng(image);
    }

    int checker(int x, int y) => (x ~/ 4 + y ~/ 4).isEven ? 90 : 170;

    testWidgets('passes a clear photo, without claiming teeth', (tester) async {
      await tester.runAsync(() async {
        final verdict =
            await const LocalPhotoCheckService().check(png(400, 300, checker));
        expect(verdict.passed, isTrue);
        expect(verdict.teethChecked, isFalse);
      });
    });

    testWidgets('rejects dark, glaring, flat, small and unreadable photos',
        (tester) async {
      await tester.runAsync(() async {
        Future<PhotoProblem?> problem(Uint8List bytes) async =>
            (await const LocalPhotoCheckService().check(bytes)).problem;
        expect(await problem(png(400, 300, (x, y) => checker(x, y) ~/ 6)),
            PhotoProblem.tooDark);
        expect(await problem(png(400, 300, (x, y) => 255)),
            PhotoProblem.tooBright);
        expect(
            await problem(png(400, 300, (x, y) => 128)), PhotoProblem.blurry);
        expect(await problem(png(200, 150, checker)), PhotoProblem.tooSmall);
        expect(await problem(Uint8List.fromList([1, 2, 3, 4])),
            PhotoProblem.unreadable);
      });
    });
  });
}
