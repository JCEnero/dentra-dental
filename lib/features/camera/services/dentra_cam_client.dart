import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../data/camera_config.dart';
import '../data/camera_protocol.dart';
import 'mjpeg_frames.dart';

enum CamFailure { unreachable, timeout, badResponse }

class DentraCamException implements Exception {
  const DentraCamException(this.failure, {this.statusCode});

  final CamFailure failure;
  final int? statusCode;

  @override
  String toString() => 'DentraCamException($failure'
      '${statusCode == null ? '' : ', HTTP $statusCode'})';
}

/// What the camera reports on /status. Every field is optional, so older
/// firmware that leaves some out still works.
class CamStatus {
  const CamStatus({
    this.rssi,
    this.frameSize,
    this.vflip,
    this.hmirror,
    this.lightOn,
    this.lightLevel,
    this.lightAvailable,
  });

  /// Wi-Fi signal in dBm.
  final int? rssi;
  final CamFrameSize? frameSize;
  final bool? vflip;
  final bool? hmirror;
  final bool? lightOn;
  final int? lightLevel;

  /// False on a camera built without its LED; null when it doesn't say.
  final bool? lightAvailable;

  static CamStatus fromJson(Map<dynamic, dynamic> json) {
    int? integer(Object? v) => switch (v) {
          num() => v.round(),
          String() => int.tryParse(v),
          _ => null,
        };
    bool? flag(Object? v) {
      if (v is bool) return v;
      final n = integer(v);
      return n == null ? null : n != 0;
    }

    final rssi = integer(json['rssi']);
    return CamStatus(
      // The ESP32 reports 0 when it has no signal reading.
      rssi: rssi != null && rssi < 0 ? rssi : null,
      frameSize: CamFrameSize.fromValue(integer(json['framesize'])),
      vflip: flag(json['vflip']),
      hmirror: flag(json['hmirror']),
      lightOn: flag(json['light']),
      lightLevel: integer(json['light_level']),
      lightAvailable: flag(json['light_available']),
    );
  }
}

/// Talks to one Dentra Cam over the home network.
///
/// Plain HTTP, since the camera has no certificate. This goes through
/// dart:io sockets, which Android's cleartext policy and iOS App Transport
/// Security don't govern, so release builds reach the camera without
/// loosening either for the rest of the app.
class DentraCamClient {
  DentraCamClient(
    this.host, {
    http.Client? client,
    http.Client Function()? streamClient,
  })  : _client = client ?? _ioClient(),
        _newStreamClient = streamClient ?? _ioClient;

  /// The camera's IPv4 address.
  final String host;

  final http.Client _client;

  /// Each live stream gets its own client, so closing it ends just that
  /// connection.
  final http.Client Function() _newStreamClient;

  static http.Client _ioClient() => IOClient(HttpClient()
    ..connectionTimeout = CameraConfig.connectTimeout
    ..idleTimeout = const Duration(seconds: 10));

  Uri get streamUri => Uri(
        scheme: 'http',
        host: host,
        port: CamHttp.streamPort,
        path: CamHttp.streamPath,
      );

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri(scheme: 'http', host: host, path: path, queryParameters: query);

  /// Throws [DentraCamException] when the camera doesn't answer.
  Future<CamStatus> status({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final res = await _get(_uri(CamHttp.statusPath), timeout);
    // Firmware without /status still answered, so the camera is there.
    if (res.statusCode == 404) return const CamStatus();
    if (res.statusCode != 200) {
      throw DentraCamException(CamFailure.badResponse,
          statusCode: res.statusCode);
    }
    try {
      final json = jsonDecode(utf8.decode(res.bodyBytes));
      return json is Map ? CamStatus.fromJson(json) : const CamStatus();
    } on FormatException {
      return const CamStatus();
    }
  }

  Future<void> setLight({required bool on, required int level}) => _command(
        _uri(CamHttp.lightPath, {
          'on': on ? '1' : '0',
          'level': '${level.clamp(0, 100)}',
        }),
      );

  /// A sensor setting: 'framesize', 'vflip' or 'hmirror'.
  Future<void> setControl(String name, int value) => _command(
        _uri(CamHttp.controlPath, {'var': name, 'val': '$value'}),
      );

  /// Takes one photo at [size]. Throws [DentraCamException].
  Future<Uint8List> capture({
    required CamFrameSize size,
    required bool light,
    Duration timeout = CameraConfig.captureTimeout,
  }) async {
    final res = await _get(
      _uri(CamHttp.capturePath, {
        'res': '${size.value}',
        'flash': light ? '1' : '0',
      }),
      timeout,
    );
    if (res.statusCode != 200 || !looksLikeJpeg(res.bodyBytes)) {
      throw DentraCamException(CamFailure.badResponse,
          statusCode: res.statusCode);
    }
    return res.bodyBytes;
  }

  /// The live picture, one JPEG per event. The stream ends, after an error,
  /// when the connection drops; cancelling the subscription closes it.
  Stream<Uint8List> frames() {
    late final StreamController<Uint8List> out;
    http.Client? client;
    StreamSubscription<List<int>>? body;
    var closed = false;

    void finish(Object error) {
      if (closed) return;
      closed = true;
      out
        ..addError(error)
        ..close();
      body?.cancel();
      client?.close();
    }

    out = StreamController<Uint8List>(
      onListen: () async {
        final c = client = _newStreamClient();
        try {
          final res = await c
              .send(http.Request('GET', streamUri))
              .timeout(CameraConfig.connectTimeout);
          if (closed) return;
          if (res.statusCode != 200) {
            finish(DentraCamException(CamFailure.badResponse,
                statusCode: res.statusCode));
            return;
          }
          final splitter = MjpegFrameSplitter();
          body = res.stream.listen(
            (chunk) {
              for (final frame in splitter.add(chunk)) {
                if (!closed) out.add(frame);
              }
            },
            onError: (Object e) => finish(_failure(e)),
            onDone: () =>
                finish(const DentraCamException(CamFailure.unreachable)),
            cancelOnError: true,
          );
        } catch (e) {
          finish(_failure(e));
        }
      },
      onCancel: () {
        closed = true;
        body?.cancel();
        client?.close();
      },
    );
    return out.stream;
  }

  void close() => _client.close();

  Future<void> _command(Uri uri) async {
    final res = await _get(uri, const Duration(seconds: 3));
    if (res.statusCode != 200) {
      throw DentraCamException(CamFailure.badResponse,
          statusCode: res.statusCode);
    }
  }

  Future<http.Response> _get(Uri uri, Duration timeout) async {
    try {
      return await _client.get(uri).timeout(timeout);
    } catch (e) {
      throw _failure(e);
    }
  }

  static DentraCamException _failure(Object e) => switch (e) {
        DentraCamException() => e,
        TimeoutException() => const DentraCamException(CamFailure.timeout),
        _ => const DentraCamException(CamFailure.unreachable),
      };
}
