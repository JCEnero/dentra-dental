import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:qr/qr.dart';
import 'package:dentra_mobile/features/camera/services/qr_provisioning_codec.dart';

Future<void> main(List<String> arguments) async {
  final directory = Directory(arguments.single)..createSync(recursive: true);
  const key = '00112233445566778899AABBCCDDEEFF';
  final vectors = <Map<String, Object>>[];
  final networks = [
    ('Home', 'correct horse'),
    ('Café & dental', 'a+b & café'),
    ('Open network', ''),
    ('S' * 32, 'p' * 63),
    ('Office "Wi-Fi"', 'pass\\word"123'),
  ];
  final cases = [
    for (final simple in [false, true])
      for (final (ssid, password) in networks) (ssid, password, simple),
    ('"' * 32, '\u0001' * 63, true),
  ];
  for (var i = 0; i < cases.length; ++i) {
    final (ssid, password, simple) = cases[i];
    final nonce = List.generate(12, (index) => index + i);
    final codec = QrProvisioningCodec();
    final packet = simple
        ? await codec.encodeSimple(
            ssid: ssid,
            password: password,
            code: 'K7P2QX',
            secured: password.isNotEmpty,
            nonce: nonce,
            issuedAt: DateTime.fromMillisecondsSinceEpoch(1800000000000 + i))
        : await codec.encode(
            ssid: ssid,
            password: password,
            deviceKey: key,
            code: 'K7P2QX',
            deviceId: i.isOdd ? 'AABBCCDD3F2A' : null,
            secured: password.isNotEmpty,
            nonce: nonce,
            issuedAt: DateTime.fromMillisecondsSinceEpoch(1800000000000 + i));
    final image = QrImage(QrCode.fromData(
        data: packet.data, errorCorrectLevel: QrErrorCorrectLevel.M));
    final scale = math.min(6, 400 ~/ (image.moduleCount + 8));
    final frame = Uint8List(640 * 480)..fillRange(0, 640 * 480, 255);
    final left = (640 - image.moduleCount * scale) ~/ 2;
    final top = (480 - image.moduleCount * scale) ~/ 2;
    for (var row = 0; row < image.moduleCount; row++) {
      for (var col = 0; col < image.moduleCount; col++) {
        if (!image.isDark(row, col)) continue;
        for (var dy = 0; dy < scale; ++dy) {
          for (var dx = 0; dx < scale; ++dx) {
            frame[(top + row * scale + dy) * 640 + left + col * scale + dx] = 0;
          }
        }
      }
    }
    final file = '${directory.path}/qr-$i.pgm';
    File(file)
        .writeAsBytesSync([...ascii.encode('P5\n640 480\n255\n'), ...frame]);
    vectors.add({
      'key': key,
      'simple': simple,
      'packet': packet.data,
      'ssid': ssid,
      'password': password,
      'code': 'K7P2QX',
      'device_id': !simple && i.isOdd ? 'AABBCCDD3F2A' : '',
      'session': packet.session,
      'issued': 1800000000000 + i,
      'image': file
    });
    if (simple) {
      // The compact UI uses a 220 px white plate, 20 px quiet margin,
      // square navy modules. Sample at pixel centres, as a display raster.
      const plate = 220, quiet = 20;
      final compact = Uint8List(640 * 480)..fillRange(0, 640 * 480, 255);
      final moduleSize = (plate - 2 * quiet) / image.moduleCount;
      for (var y = 0; y < plate - 2 * quiet; ++y) {
        for (var x = 0; x < plate - 2 * quiet; ++x) {
          final row = ((y + 0.5) / moduleSize).floor();
          final col = ((x + 0.5) / moduleSize).floor();
          if (image.isDark(row, col)) {
            compact[(130 + quiet + y) * 640 + 210 + quiet + x] = 42;
          }
        }
      }
      final smallFile = '${directory.path}/qr-$i-compact.pgm';
      File(smallFile).writeAsBytesSync(
          [...ascii.encode('P5\n640 480\n255\n'), ...compact]);
      vectors.add({...vectors.last, 'image': smallFile});
    }
  }
  File('${directory.path}/vectors.json').writeAsStringSync(jsonEncode(vectors));
}
