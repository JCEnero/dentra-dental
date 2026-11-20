import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

class SetupQr {
  const SetupQr({required this.data, required this.session});
  final String data;
  final String session;
}

/// Simple optical setup uses DENTRA2: followed by local, unencrypted JSON.
/// The older encrypted DENTRA1 codec remains for firmware compatibility tests.
class QrProvisioningCodec {
  static const aad = 'DENTRA-QR-1';
  static String normalizeKey(String key) =>
      key.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();

  static void validateWifi(
      {required String ssid, required String password, required bool secured}) {
    if (ssid.isEmpty ||
        utf8.encode(ssid).length > 32 ||
        ssid.contains(RegExp(r'[\x00-\x1f\x7f]'))) {
      throw const FormatException(
          'Enter your Wi-Fi name exactly as it appears in settings, up to 32 bytes.');
    }
    final length = utf8.encode(password).length;
    if (secured && (length < 8 || length > 63 || password.contains('\u0000'))) {
      throw const FormatException(
          'Enter a Wi-Fi password between 8 and 63 bytes.');
    }
  }

  static void validate(
      {required String ssid,
      required String password,
      required String deviceKey,
      required bool secured}) {
    validateWifi(ssid: ssid, password: password, secured: secured);
    if (!RegExp(r'^[A-F0-9]{32}$').hasMatch(normalizeKey(deviceKey))) {
      throw const FormatException('Invalid legacy device setup key.');
    }
  }

  Future<SetupQr> encodeSimple(
      {required String ssid,
      required String password,
      required String code,
      bool secured = true,
      DateTime? issuedAt,
      List<int>? nonce}) async {
    validateWifi(ssid: ssid, password: password, secured: secured);
    if (!RegExp(r'^[A-Z0-9]{6}$').hasMatch(code)) {
      throw const FormatException('Invalid pairing code');
    }
    final bytes =
        nonce ?? List.generate(12, (_) => Random.secure().nextInt(256));
    if (bytes.length != 12 || bytes.any((b) => b < 0 || b > 255)) {
      throw const FormatException('Invalid setup session');
    }
    final issued = (issuedAt ?? DateTime.now()).millisecondsSinceEpoch;
    if (issued < 1577836800000 || issued > 4102444800000) {
      throw const FormatException('Check your phone’s date and time.');
    }
    final session = bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
    final details = jsonEncode({
      's': ssid,
      'p': secured ? password : '',
      'c': code,
      'i': issued,
      'n': session,
    });
    if (utf8.encode(details).length > 552) {
      throw const FormatException('Wi-Fi details are too long.');
    }
    return SetupQr(data: 'DENTRA2:$details', session: session);
  }

  Future<SetupQr> encode(
      {required String ssid,
      required String password,
      required String deviceKey,
      required String code,
      String? deviceId,
      bool secured = true,
      DateTime? issuedAt,
      List<int>? nonce}) async {
    validate(
        ssid: ssid, password: password, deviceKey: deviceKey, secured: secured);
    if (!RegExp(r'^[A-Z0-9]{6}$').hasMatch(code)) {
      throw const FormatException('Invalid pairing code');
    }
    final key = normalizeKey(deviceKey);
    if (deviceId != null && !RegExp(r'^[A-Fa-f0-9]{12}$').hasMatch(deviceId)) {
      throw const FormatException('Invalid device sticker identity');
    }
    final bytes = [
      for (var i = 0; i < key.length; i += 2)
        int.parse(key.substring(i, i + 2), radix: 16)
    ];
    final iv = nonce ?? List.generate(12, (_) => Random.secure().nextInt(256));
    if (iv.length != 12) throw const FormatException('Invalid nonce');
    final clear = utf8.encode(jsonEncode({
      's': ssid,
      'p': secured ? password : '',
      'c': code,
      'i': (issuedAt ?? DateTime.now()).millisecondsSinceEpoch,
      if (deviceId != null) 'd': deviceId.toUpperCase(),
    }));
    if (clear.length > 384) {
      throw const FormatException('Wi-Fi details are too long.');
    }
    final box = await AesGcm.with128bits().encrypt(clear,
        secretKey: SecretKey(bytes), nonce: iv, aad: utf8.encode(aad));
    return SetupQr(
      data: 'DENTRA1:${base64Url.encode([
            ...iv,
            ...box.cipherText,
            ...box.mac.bytes
          ]).replaceAll('=', '')}',
      session: iv
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join()
          .toUpperCase(),
    );
  }
}
