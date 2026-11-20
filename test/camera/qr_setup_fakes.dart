import 'dart:async';
import 'dart:convert';
import 'package:dentra_mobile/features/camera/services/setup_sound.dart';

import 'package:dentra_mobile/core/network/api_client.dart';
import 'package:dentra_mobile/features/camera/services/cloud_cam_api.dart';
import 'package:dentra_mobile/features/camera/services/dentra_cam_client.dart';
import 'package:dentra_mobile/features/camera/services/qr_provisioning_codec.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'camera_fakes.dart';

const qrKey = '00112233445566778899AABBCCDDEEFF';
const qrHardwareId = 'AABBCCDD3F2A';

class FixedQrCodec extends QrProvisioningCodec {
  SetupQr? last;
  @override
  Future<SetupQr> encodeSimple(
          {required String ssid,
          required String password,
          required String code,
          bool secured = true,
          DateTime? issuedAt,
          List<int>? nonce}) async =>
      last = await super.encodeSimple(
          ssid: ssid,
          password: password,
          code: code,
          secured: secured,
          issuedAt: issuedAt,
          nonce: List.generate(12, (i) => i));
}

class QrTestServer {
  String state = 'pending';
  bool online = true;
  bool fail = false;
  int creates = 0;
  int checks = 0;
  Completer<void>? createGate;
  Completer<void>? checkGate;
  final requests = <http.Request>[];
  Map<String, Object> get device => {
        'id': 'cloud-1',
        'name': 'Dentra Cam 3F2A',
        'hardware_id': qrHardwareId,
        'online': online
      };

  late final api = CloudCamApi(ApiClient(
      baseUrl: 'https://api.example',
      accessToken: () async => 'test-token',
      client: MockClient((request) async {
        requests.add(request);
        if (fail) throw http.ClientException('Offline');
        if (request.method == 'POST') {
          creates++;
          await createGate?.future;
          return http.Response(
              jsonEncode({
                'pairing': {
                  'id': 'pair-$creates',
                  'code': 'K7P2QX',
                  'expires_at': DateTime.now()
                      .add(const Duration(minutes: 15))
                      .toIso8601String()
                }
              }),
              201);
        }
        if (request.url.path == '/api/cam/devices') {
          return http.Response(
              jsonEncode({
                'devices': state == 'claimed' ? [device] : []
              }),
              200);
        }
        checks++;
        await checkGate?.future;
        return http.Response(
            jsonEncode({
              'pairing': {
                'status': state,
                'device': state == 'claimed' ? device : null
              }
            }),
            200);
      })));
}

class QrTestCamera extends FakeCamClient {
  String? session;
  String hardwareId = qrHardwareId;
  bool ready = true;
  bool closed = false;
  @override
  Future<CamStatus> status(
          {Duration timeout = const Duration(seconds: 3)}) async =>
      CamStatus(
          deviceId: hardwareId, cameraReady: ready, setupSession: session);
  @override
  void close() {
    closed = true;
  }
}

class QrTestSound implements SetupSound {
  int prepares = 0, plays = 0, unlocks = 0, stops = 0;
  bool closed = false;
  @override
  Future<void> prepare() async {
    prepares++;
  }

  @override
  void unlock() {
    unlocks++;
  }

  @override
  Future<void> play() async {
    if (!closed) plays++;
  }

  @override
  void stop() {
    stops++;
  }

  @override
  Future<void> dispose() async {
    closed = true;
  }
}
