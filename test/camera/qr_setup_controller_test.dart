import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:dentra_mobile/features/camera/data/saved_camera.dart';
import 'package:dentra_mobile/features/camera/services/qr_provisioning_codec.dart';
import 'package:dentra_mobile/features/camera/state/qr_setup_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'qr_setup_fakes.dart';

void main() {
  group('encrypted optical payload', () {
    test(
        'AES-GCM authenticates details and never includes the label key in its envelope',
        () async {
      final packet = await QrProvisioningCodec().encode(
          ssid: 'Home',
          password: 'correct horse',
          deviceKey: qrKey,
          code: 'K7P2QX',
          deviceId: qrHardwareId.toLowerCase(),
          nonce: List.generate(12, (i) => i));
      final bytes =
          base64Url.decode(base64Url.normalize(packet.data.substring(8)));
      final clear = await AesGcm.with128bits().decrypt(
          SecretBox(bytes.sublist(12, bytes.length - 16),
              nonce: bytes.sublist(0, 12),
              mac: Mac(bytes.sublist(bytes.length - 16))),
          secretKey: SecretKey([
            for (var i = 0; i < qrKey.length; i += 2)
              int.parse(qrKey.substring(i, i + 2), radix: 16)
          ]),
          aad: utf8.encode(QrProvisioningCodec.aad));
      final details = jsonDecode(utf8.decode(clear));
      expect(details['s'], 'Home');
      expect(details['p'], 'correct horse');
      expect(details['c'], 'K7P2QX');
      expect(details['d'], qrHardwareId);
      expect(packet.session, '000102030405060708090A0B');
      expect(packet.data, isNot(contains('correct horse')));
      expect(packet.data, isNot(contains(qrKey)));
      expect(bytes, isNot(containsAll(utf8.encode('correct horse'))));
    });

    test('fresh nonces change the QR for identical credentials', () async {
      final codec = QrProvisioningCodec();
      final a = await codec.encode(
          ssid: 'Home',
          password: 'correct horse',
          deviceKey: qrKey,
          code: 'K7P2QX');
      final b = await codec.encode(
          ssid: 'Home',
          password: 'correct horse',
          deviceKey: qrKey,
          code: 'K7P2QX');
      expect(a.session, isNot(b.session));
      expect(a.data, isNot(b.data));
    });

    test('label grouping and lowercase are normalized', () {
      expect(
          QrProvisioningCodec.normalizeKey(
              '00112233-44556677 8899aabb-ccddeeff'),
          qrKey);
    });

    test(
        'invalid key, overlong UTF-8 name and invalid secure password are refused',
        () {
      for (final (ssid, password, key) in [
        ('Home', 'correct horse', '123'),
        ('界' * 11, 'correct horse', qrKey),
        ('Home', 'short', qrKey)
      ]) {
        expect(
            () => QrProvisioningCodec.validate(
                ssid: ssid, password: password, deviceKey: key, secured: true),
            throwsFormatException);
      }
      QrProvisioningCodec.validate(
          ssid: 'Open', password: '', deviceKey: qrKey, secured: false);
    });
  });

  group('simple optical payload', () {
    test(
        'Wi-Fi details and random session encode without a sticker or device key',
        () async {
      final packet = await QrProvisioningCodec().encodeSimple(
          ssid: 'Café & dental',
          password: 'correct horse',
          code: 'K7P2QX',
          nonce: List.generate(12, (i) => i));
      expect(packet.data, startsWith('DENTRA2:'));
      final details = jsonDecode(packet.data.substring(8));
      expect(details['s'], 'Café & dental');
      expect(details['p'], 'correct horse');
      expect(details['c'], 'K7P2QX');
      expect(details['n'], packet.session);
      expect(details.containsKey('d'), false);
      expect(packet.session, '000102030405060708090A0B');
    });
    test('each QR has a fresh session and open networks omit the password',
        () async {
      final codec = QrProvisioningCodec();
      final a = await codec.encodeSimple(
          ssid: 'Open', password: 'ignored', code: 'K7P2QX', secured: false);
      final b = await codec.encodeSimple(
          ssid: 'Open', password: '', code: 'K7P2QX', secured: false);
      expect(a.session, isNot(b.session));
      expect(jsonDecode(a.data.substring(8))['p'], '');
    });
    test('invalid sessions, clocks and pairing codes fail before rendering',
        () async {
      for (final arguments in [
        (code: 'invalid', nonce: List.filled(12, 0), date: DateTime(2026)),
        (code: 'K7P2QX', nonce: List.filled(11, 0), date: DateTime(2026)),
        (code: 'K7P2QX', nonce: List.filled(12, 256), date: DateTime(2026)),
        (code: 'K7P2QX', nonce: List.filled(12, 0), date: DateTime(1970)),
      ]) {
        await expectLater(
            QrProvisioningCodec().encodeSimple(
                ssid: 'Home',
                password: 'correct horse',
                code: arguments.code,
                nonce: arguments.nonce,
                issuedAt: arguments.date),
            throwsFormatException);
      }
    });
  });

  group('verified setup', () {
    late QrTestServer server;
    late QrTestCamera camera;
    late QrSetupController setup;
    late List<SavedCamera> saved;
    setUp(() {
      server = QrTestServer();
      camera = QrTestCamera();
      saved = [];
      setup = QrSetupController(
          api: server.api,
          clientFor: (_) => camera,
          onSaved: (camera) async => saved.add(camera),
          checkEvery: const Duration(hours: 1));
    });
    tearDown(() => setup.dispose());
    Future<void> generate() =>
        setup.generate(ssid: 'Home', password: 'correct horse');

    test('no passwords or device keys are sent to the cloud', () async {
      await generate();
      expect(setup.phase, QrSetupPhase.waiting);
      for (final request in server.requests) {
        expect(request.url.host, 'api.example');
        expect(request.body, isNot(contains('correct horse')));
        expect(request.body, isNot(contains(qrKey)));
      }
      expect(saved, isEmpty);
    });

    test(
        'claim, device identity, fresh QR session and readiness must all match',
        () async {
      await generate();
      await setup.check();
      expect(saved, isEmpty);
      server.state = 'claimed';
      camera.session = 'wrong nonce';
      await setup.check();
      expect(saved, isEmpty);
      expect(setup.deviceFound, true);
      expect(setup.qrConfirmed, false);
      camera.session = setup.qr!.session;
      camera.hardwareId = '000000000000';
      await setup.check();
      expect(saved, isEmpty);
      camera.hardwareId = qrHardwareId;
      camera.ready = false;
      await setup.check();
      expect(saved, isEmpty);
      expect(setup.qrConfirmed, true);
      camera.ready = true;
      await setup.check();
      expect(saved.single.cloudId, 'cloud-1');
      expect(setup.phase, QrSetupPhase.ready);
      expect(setup.qr, isNull);
    });

    test('an offline claimed camera never completes setup', () async {
      await generate();
      server
        ..state = 'claimed'
        ..online = false;
      await setup.check();
      expect(saved, isEmpty);
      expect(setup.qr, isNotNull);
      expect(setup.deviceFound, true);
      expect(setup.qrConfirmed, false);
      expect(setup.phase, QrSetupPhase.linking);
    });

    test('elapsed time offers tips and never invents a detected QR', () async {
      var clock = DateTime.now();
      setup.dispose();
      setup = QrSetupController(
          api: server.api,
          clientFor: (_) => camera,
          onSaved: (camera) async => saved.add(camera),
          checkEvery: const Duration(hours: 1),
          now: () => clock);
      await generate();
      clock = clock.add(const Duration(seconds: 31));
      await setup.check();
      expect(setup.waitingLong, true);
      expect(setup.deviceFound, false);
      expect(setup.qrConfirmed, false);
      expect(setup.phase, QrSetupPhase.waiting);
      expect(saved, isEmpty);
      setup.edit();
      expect(setup.waitingLong, false);
      expect(setup.deviceFound, false);
    });

    test('expired sessions remove the QR and offer a fresh code', () async {
      await generate();
      server.state = 'expired';
      await setup.check();
      expect(setup.phase, QrSetupPhase.expired);
      expect(setup.qr, isNull);
    });

    test('network interruptions retain the QR and allow recovery', () async {
      await generate();
      server.fail = true;
      await setup.check();
      expect(setup.phase, QrSetupPhase.waiting);
      expect(setup.qr, isNotNull);
      server
        ..fail = false
        ..state = 'claimed';
      camera.session = setup.qr!.session;
      await setup.check();
      expect(saved, hasLength(1));
    });

    test('editing cancels an in-flight result from the old session', () async {
      await generate();
      server
        ..state = 'claimed'
        ..checkGate = Completer<void>();
      camera.session = setup.qr!.session;
      final pending = setup.check();
      await Future<void>.delayed(Duration.zero);
      setup.edit();
      server.checkGate!.complete();
      await pending;
      expect(saved, isEmpty);
      expect(setup.phase, QrSetupPhase.details);
    });

    test('duplicate generation taps do not create competing pairings',
        () async {
      server.createGate = Completer<void>();
      final first = generate();
      await generate();
      server.createGate!.complete();
      await first;
      expect(server.creates, 1);
    });

    test('validation fails before creating a pairing', () async {
      await setup.generate(ssid: '', password: 'correct horse');
      expect(server.creates, 0);
      expect(setup.error, isNotNull);
    });
  });
}
