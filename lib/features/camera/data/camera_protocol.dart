/// How the app talks to the Dentra Cam (ESP32-S3 + OV5640). The firmware must
/// match this file, so change both together.
///
/// ## Captive Wi-Fi portal (firmware 2.2+, default on all clients)
///
/// Join the open Dentra Cam network; no hotspot password is needed. Wildcard
/// DNS and HTTP connectivity probes redirect to http://192.168.4.1/.
/// The self-contained glass page collects Wi-Fi credentials locally. Its
/// optional six-character account code uses the existing pairing API.
/// GET /setup/info supplies a per-boot token required by POST /join.
/// GET /networks lists nearby networks; GET /result reports join status.
/// Captive DNS and HTTP stop after successful handoff to home Wi-Fi.
/// /setup/info reports protected=false; the per-boot POST token remains required.
///
/// ## Legacy encrypted optical provisioning (firmware 1.7+, opt-in)
///
/// The phone remains online. The user enters SSID, password and the 32-hex
/// device QR key, then shows an encrypted QR to the device camera. Account
/// linking uses the existing pairing API; passwords never cross the cloud.
/// Envelope: DENTRA1: + unpadded base64url(12-byte nonce | ciphertext | 16-byte tag).
/// Cipher: AES-128-GCM. Key: 16 raw bytes from the unique label key.
/// AAD: UTF-8 DENTRA-QR-1. Plaintext JSON: s=SSID, p=password, c=pairing code,
/// i=Unix milliseconds. The device rejects timestamps no newer than its last
/// successful setup, joins the router, and saves the account code and nonce.
/// The nonce is echoed as uppercase hex in setup_session, alongside id and
/// camera_ok in the device's live status. All must match before completion.
/// Account codes expire server-side after 15 minutes; offline devices have
/// no trusted clock, so they cannot enforce wall-clock expiry before joining.
/// Firmware must be flashed and its unique QR key labeled before use.
///
/// ## Legacy protected SoftAP (firmware 1.5+, opt-in on firmware 1.7)
///
/// The OS asks to join "Dentra Cam XXXX" using the unique 16-character
/// WPA2 setup key on that device's label. No open-hotspot fallback is allowed.
/// Older apps can still configure via these local API endpoints.
/// At the fixed gateway 192.168.4.1:
///
/// - GET /setup/info: protocol=1, protected=true, id, name, host, token.
/// - GET /setup/networks: networks=[{ssid, rssi, secure}]. Device scans 2.4 GHz.
/// - POST /setup/join: form body ssid, password, token. Returns ok=true;
///   a lost acknowledgement must be reconciled, never treated as success.
/// - GET /setup/status: id, ssid, state (idle/connecting/connected/failed),
///   ip and host when connected, error when failed.
/// - POST /setup/finish: token. Accepted only after connected; acknowledges
///   before switching off the hotspot and starting the camera servers.
///
/// The AP remains for up to 120 seconds after joining if finish is lost.
/// The app releases its OS Wi-Fi request and verifies /status on the
/// reported IP, falling back to _dentracam._tcp discovery. Both device id
/// and camera_ok=true must match before saving or showing success.
/// Credentials are saved on the ESP32 only after joining, never on the phone.
/// BOOT held for five seconds clears the saved router and account link.
///
/// ## Legacy setup over Bluetooth LE (setup mode only)
///
/// A camera with no Wi-Fi saved, or one reset by holding its button for
/// 5 seconds, advertises [CamBle.service] under a name that starts with
/// [CamBle.namePrefix] (e.g. "Dentra Cam 3F2A"). The app connects, asks for a
/// larger MTU, subscribes to [CamBle.events] and writes commands to
/// [CamBle.command]:
///
///     {"cmd":"scan"}                                  → one "networks" event
///     {"cmd":"connect","ssid":"Home","password":"…"}  → "status" events
///
/// A fourth characteristic, 3e900004-…, is readable JSON (name, id,
/// firmware) for diagnostics; the app doesn't need it.
///
/// Commands are UTF-8 JSON written with response, at most 512 bytes, so the
/// phone's long writes cover them at any MTU. Events are UTF-8 JSON lines,
/// each ending in "\n", sent as notifications. A line longer than one
/// notification simply continues in the next: split it at MTU − 3 bytes and
/// send the pieces in order.
///
///     {"type":"networks","networks":[{"ssid":"Home","rssi":-52,"secure":true}]}
///     {"type":"status","state":"connecting"}
///     {"type":"status","state":"connected","ip":"192.168.1.40"}
///     {"type":"status","state":"restarting"}
///     {"type":"status","state":"failed","error":"wrong_password"}
///
/// `error` is `wrong_password` (WIFI_REASON_AUTH_FAIL, 4WAY_HANDSHAKE_TIMEOUT,
/// HANDSHAKE_TIMEOUT), `ssid_not_found` (NO_AP_FOUND) or `timeout` (no IP
/// within about 20 s). After "connected" the camera saves the network, waits
/// about a second so the phone receives the event, then hands over to Wi-Fi
/// mode and stops advertising. "ip" must be its IPv4 address on the home
/// network.
///
/// Give [CamBle.command] an encrypted-write permission (LE Secure
/// Connections, Just Works) so the Wi-Fi password never crosses the air in
/// the clear. Phones pair on the first write, which is why the app allows
/// 30 seconds for it.
///
/// ## Camera over Wi-Fi (plain HTTP on the home network)
///
///     GET :81/stream              MJPEG, multipart/x-mixed-replace, one JPEG
///                                 per part, each with a Content-Length
///     GET /capture?res=15&flash=1 one JPEG at framesize `res`; with flash=1
///                                 the light is on for the shot
///     GET /status                 JSON, e.g. {"rssi":-58,"framesize":10,
///                                 "vflip":0,"hmirror":0,"light":true,
///                                 "light_level":60,"light_available":true}
///     GET /light?on=1&level=60    white light on or off, level 0–100; 501
///                                 on a camera without one. While /status
///                                 says light_available false, the app
///                                 hides its light controls.
///     GET /control?var=vflip&val=1  sensor settings: framesize, vflip, hmirror
///
/// The stream runs on its own server (port 81) so captures and settings on
/// port 80 still answer while it streams.
///
/// ## The website (through the DENTRA API)
///
/// A web page can't use any of the above: iPhone browsers have no Bluetooth,
/// and an HTTPS page can't load the camera's plain-HTTP pictures. So:
///
/// - Setup mode opens an unprotected Wi-Fi hotspot with the setup page at
///   http://192.168.4.1. Firmware 2.1+ enables captive redirects.
///   The user picks the home Wi-Fi there and types the code the website
///   shows (POST /api/cam/pairings), which links the camera to the account.
/// - Once linked, the camera keeps a WebSocket open to the API (through
///   dentrascan.site/relay, see dentra_mobile/functions/), and the website
///   opens another (`CloudCamClient`). The API passes pictures, photos and
///   commands between them; the messages are described in
///   backend/src/modules/cam/cam.hub.ts.
library;

import 'dart:convert';

abstract final class CamBle {
  /// Advertised names start with this.
  static const String namePrefix = 'Dentra Cam';

  static const String service = '3e900001-bbe8-4e1b-a18a-d032a6a1254c';

  /// App → camera: JSON commands, write with response.
  static const String command = '3e900002-bbe8-4e1b-a18a-d032a6a1254c';

  /// Camera → app: JSON lines, notify.
  static const String events = '3e900003-bbe8-4e1b-a18a-d032a6a1254c';

  /// Asked for after connecting. Lines are framed, so a smaller answer only
  /// means more notifications per line.
  static const int preferredMtu = 247;
}

abstract final class CamHttp {
  static const int streamPort = 81;
  static const String streamPath = '/stream';
  static const String capturePath = '/capture';
  static const String statusPath = '/status';
  static const String lightPath = '/light';
  static const String controlPath = '/control';
}

/// `framesize_t` values from esp32-camera as Arduino-ESP32 3.x ships it
/// (installed here: 3.3.12). That version added 128X128 and 320X320 to the
/// list, so VGA is 10 and UXGA 15. Cores before 3.0 had VGA 8, SVGA 9 and
/// UXGA 13: if the firmware is built with one of those, change the numbers.
enum CamFrameSize {
  vga(10, 'VGA', 640, 480),
  svga(11, 'SVGA', 800, 600),
  uxga(15, 'UXGA', 1600, 1200);

  const CamFrameSize(this.value, this.label, this.width, this.height);

  final int value;
  final String label;
  final int width;
  final int height;

  static CamFrameSize? fromValue(int? value) {
    for (final size in values) {
      if (size.value == value) return size;
    }
    return null;
  }
}

/// A Wi-Fi network the camera can see.
class WifiNetwork {
  const WifiNetwork({
    required this.ssid,
    required this.rssi,
    required this.secure,
  });

  final String ssid;

  /// Signal strength in dBm, e.g. -52.
  final int rssi;

  /// Whether it needs a password.
  final bool secure;

  int get bars => signalBars(rssi);

  /// One entry per name, strongest first. Hidden networks (no name) are left
  /// out, since there's nothing to show for them.
  static List<WifiNetwork> strongestFirst(Iterable<WifiNetwork> networks) {
    final best = <String, WifiNetwork>{};
    for (final n in networks) {
      if (n.ssid.trim().isEmpty) continue;
      final seen = best[n.ssid];
      if (seen == null || n.rssi > seen.rssi) best[n.ssid] = n;
    }
    return best.values.toList()..sort((a, b) => b.rssi.compareTo(a.rssi));
  }

  @override
  bool operator ==(Object other) =>
      other is WifiNetwork &&
      other.ssid == ssid &&
      other.rssi == rssi &&
      other.secure == secure;

  @override
  int get hashCode => Object.hash(ssid, rssi, secure);
}

/// Wi-Fi signal as 0–4 bars, for the network list and the live camera.
int signalBars(int rssi) {
  if (rssi >= -55) return 4;
  if (rssi >= -65) return 3;
  if (rssi >= -75) return 2;
  if (rssi >= -85) return 1;
  return 0;
}

/// Whether [value] is a plain IPv4 address such as "192.168.1.40". The app
/// only ever talks to the camera by address, never by a name it was handed.
bool isIpv4(String value) {
  final parts = value.split('.');
  if (parts.length != 4) return false;
  for (final p in parts) {
    if (p.isEmpty || p.length > 3 || !RegExp(r'^\d+$').hasMatch(p)) {
      return false;
    }
    // No leading zeros, which some parsers read as octal.
    if (p.length > 1 && p.startsWith('0')) return false;
    if (int.parse(p) > 255) return false;
  }
  return true;
}

// ── Setup events ─────────────────────────────────────────────────

enum JoinState { connecting, connected, restarting, failed }

enum JoinError { wrongPassword, ssidNotFound, timeout, other }

sealed class SetupEvent {
  const SetupEvent();
}

/// The answer to {"cmd":"scan"}, as sent (not yet sorted).
final class NetworksEvent extends SetupEvent {
  const NetworksEvent(this.networks);
  final List<WifiNetwork> networks;
}

/// Progress after {"cmd":"connect"}.
final class JoinEvent extends SetupEvent {
  const JoinEvent(this.state, {this.ip, this.error});

  final JoinState state;

  /// Set with [JoinState.connected], when it's a valid IPv4 address.
  final String? ip;

  /// Set with [JoinState.failed].
  final JoinError? error;
}

/// Reads one event line. Unknown or malformed lines give null, so a newer
/// firmware can add events without breaking older apps.
SetupEvent? parseSetupEvent(String line) {
  final Object? json;
  try {
    json = jsonDecode(line);
  } on FormatException {
    return null;
  }
  if (json is! Map) return null;
  switch (json['type']) {
    case 'networks':
      final list = json['networks'];
      if (list is! List) return null;
      return NetworksEvent([
        for (final n in list)
          if (n is Map && n['ssid'] is String && n['rssi'] is num)
            WifiNetwork(
              ssid: n['ssid'] as String,
              rssi: (n['rssi'] as num).round(),
              // Assume a password unless the camera says there is none.
              secure: n['secure'] != false,
            ),
      ]);
    case 'status':
      final state = switch (json['state']) {
        'connecting' => JoinState.connecting,
        'connected' => JoinState.connected,
        'restarting' => JoinState.restarting,
        'failed' => JoinState.failed,
        _ => null,
      };
      if (state == null) return null;
      final ip = json['ip'];
      return JoinEvent(
        state,
        ip: ip is String && isIpv4(ip.trim()) ? ip.trim() : null,
        error: state == JoinState.failed
            ? switch (json['error']) {
                'wrong_password' => JoinError.wrongPassword,
                'ssid_not_found' => JoinError.ssidNotFound,
                'timeout' => JoinError.timeout,
                _ => JoinError.other,
              }
            : null,
      );
  }
  return null;
}

/// Joins notification bytes back into the lines the camera sent.
class SetupLineDecoder {
  /// A line this long without an end is junk; it's dropped.
  static const int maxLine = 16 * 1024;

  final List<int> _pending = [];

  List<String> add(List<int> bytes) {
    final lines = <String>[];
    for (final b in bytes) {
      if (b == 0x0A) {
        final line = utf8.decode(_pending, allowMalformed: true).trim();
        _pending.clear();
        if (line.isNotEmpty) lines.add(line);
      } else {
        _pending.add(b);
        if (_pending.length > maxLine) _pending.clear();
      }
    }
    return lines;
  }
}
