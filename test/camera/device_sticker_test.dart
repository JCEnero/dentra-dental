import 'package:dentra_mobile/features/camera/data/device_sticker.dart';
import 'package:flutter_test/flutter_test.dart';

import 'qr_setup_fakes.dart';

void main() {
  test('sticker normalizes hex, identifies the unit and redacts diagnostics',
      () {
    final sticker = DeviceSticker.parse(
        ' DENTRA-DEVICE-1:${qrHardwareId.toLowerCase()}:${qrKey.toLowerCase()}\n');
    expect(sticker.hardwareId, qrHardwareId);
    expect(sticker.key, qrKey);
    expect(sticker.name, 'Dentra Cam 3F2A');
    expect(sticker.payload, 'DENTRA-DEVICE-1:$qrHardwareId:$qrKey');
    expect(sticker.toString(), isNot(contains(qrKey)));
  });

  test('rejects URLs, Wi-Fi codes, optical packets and malformed stickers', () {
    for (final value in [
      'https://dentrascan.site/?key=$qrKey',
      'WIFI:S:Home;P:password;;',
      'DENTRA1:abc',
      'DENTRA-DEVICE-1:$qrHardwareId:short',
      'DENTRA-DEVICE-1:AABBCCDD3F2Z:$qrKey',
      'DENTRA-DEVICE-1:$qrHardwareId:$qrKey:extra',
      'x' * 129,
    ]) {
      expect(() => DeviceSticker.parse(value), throwsFormatException);
    }
  });
}
