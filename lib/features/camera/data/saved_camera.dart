import 'camera_config.dart';
import 'camera_protocol.dart';

/// The camera this phone was set up with, or (on the website) the one
/// linked to the account. The Wi-Fi password is never kept.
class SavedCamera {
  const SavedCamera({
    this.host,
    this.cloudId,
    required this.name,
    required this.savedAt,
    this.ssid,
  }) : assert(host != null || cloudId != null);

  /// Its IPv4 address on the home network, for the phone apps.
  final String? host;

  /// Its id on the DENTRA API, for the website, which reaches it through
  /// the API's relay.
  final String? cloudId;

  /// Which camera this is, either way.
  String get key => cloudId ?? host!;

  /// As it advertised itself, e.g. "Dentra Cam 3F2A".
  final String name;

  /// The Wi-Fi network it joined, when the app set that up.
  final String? ssid;

  final DateTime savedAt;

  /// Only the phone apps keep their camera on the device; the website asks
  /// the API, so a cloud camera is never stored.
  Map<String, Object?> toJson() => {
        'host': host,
        'name': name,
        'ssid': ssid,
        'savedAt': savedAt.toIso8601String(),
      };

  /// Null for anything that isn't a camera saved by this app.
  static SavedCamera? fromJson(Object? json) {
    if (json is! Map) return null;
    final host = json['host'];
    final name = json['name'];
    if (host is! String || !isIpv4(host) || name is! String) return null;
    final ssid = json['ssid'];
    return SavedCamera(
      host: host,
      name: name,
      ssid: ssid is String ? ssid : null,
      savedAt: DateTime.tryParse('${json['savedAt']}') ?? DateTime.now(),
    );
  }
}

/// How the live picture is set up. Kept on this phone and sent to the camera
/// each time the live view opens.
class CameraViewSettings {
  const CameraViewSettings({
    this.lightOn = true,
    this.lightLevel = CameraConfig.defaultLightLevel,
    // The sensor sits upside down in the Dentra Cam, so upright is both
    // flips on (a 180° turn).
    this.vflip = true,
    this.hmirror = true,
    this.liveSize = CameraConfig.liveSize,
  });

  final bool lightOn;

  /// 0–100.
  final int lightLevel;
  final bool vflip;
  final bool hmirror;
  final CamFrameSize liveSize;

  CameraViewSettings copyWith({
    bool? lightOn,
    int? lightLevel,
    bool? vflip,
    bool? hmirror,
    CamFrameSize? liveSize,
  }) =>
      CameraViewSettings(
        lightOn: lightOn ?? this.lightOn,
        lightLevel: (lightLevel ?? this.lightLevel).clamp(0, 100),
        vflip: vflip ?? this.vflip,
        hmirror: hmirror ?? this.hmirror,
        liveSize: liveSize ?? this.liveSize,
      );

  Map<String, Object?> toJson() => {
        'lightOn': lightOn,
        'lightLevel': lightLevel,
        'vflip': vflip,
        'hmirror': hmirror,
        'liveSize': liveSize.name,
      };

  static CameraViewSettings fromJson(Object? json) {
    const defaults = CameraViewSettings();
    if (json is! Map) return defaults;
    final level = json['lightLevel'];
    return CameraViewSettings(
      lightOn: json['lightOn'] is bool ? json['lightOn'] as bool : true,
      lightLevel: level is num
          ? level.round().clamp(0, 100)
          : CameraConfig.defaultLightLevel,
      vflip: json['vflip'] is bool ? json['vflip'] as bool : defaults.vflip,
      hmirror:
          json['hmirror'] is bool ? json['hmirror'] as bool : defaults.hmirror,
      liveSize: CamFrameSize.values.firstWhere(
        (s) => s.name == json['liveSize'],
        orElse: () => defaults.liveSize,
      ),
    );
  }
}
