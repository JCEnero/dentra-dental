/// Printed once per unit. The key remains in memory only while setting up;
/// never log this payload or send it to the account API.
class DeviceSticker {
  const DeviceSticker._(this.hardwareId, this.key);

  final String hardwareId;
  final String key;
  String get name => 'Dentra Cam ${hardwareId.substring(8)}';
  String get payload => 'DENTRA-DEVICE-1:$hardwareId:$key';

  static DeviceSticker parse(String value) {
    if (value.length > 128) {
      throw const FormatException('This isn’t a Dentra device sticker.');
    }
    final match =
        RegExp(r'^DENTRA-DEVICE-1:([A-Fa-f0-9]{12}):([A-Fa-f0-9]{32})$')
            .firstMatch(value.trim());
    if (match == null) {
      throw const FormatException(
          'Scan the setup sticker on your Dentra Cam, not the Wi-Fi code on another screen.');
    }
    return DeviceSticker._(
        match.group(1)!.toUpperCase(), match.group(2)!.toUpperCase());
  }

  @override
  String toString() => 'DeviceSticker($hardwareId, key: hidden)';
}
