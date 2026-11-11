import '../../scan/data/scan_regions.dart';
import 'camera_protocol.dart';

/// Settings for the Dentra Cam screens. Wording is in `camera_strings.dart`.
abstract final class CameraConfig {
  /// The areas the live camera asks for, in order. Reorder or remove ids
  /// freely, but each must be one of the scan's guided views in
  /// `scan_regions.dart` ('front', 'upper-occlusal', 'lower-occlusal',
  /// 'left', 'right', 'upper-lingual', 'lower-lingual', 'back-left',
  /// 'back-right'): the DENTRA API, the photo check and the analysis only
  /// accept those.
  static const List<String> captureAreaIds = [
    'front',
    'upper-occlusal',
    'lower-occlusal',
    'left',
    'right',
    'upper-lingual',
    'lower-lingual',
    'back-left',
    'back-right',
  ];

  /// [captureAreaIds] as views, skipping any id the scan doesn't know.
  static List<ScanRegion> get captureAreas => [
        for (final id in captureAreaIds)
          if (scanRegionIndex(id) >= 0 && !isSecondPhoto(id))
            scanRegionById(id),
      ];

  // ── Camera ──────────────────────────────────────────────────────
  /// Live view size: VGA keeps the stream smooth over home Wi-Fi.
  static const CamFrameSize liveSize = CamFrameSize.vga;

  /// Photo size. The photo check and the analysis scale it down anyway.
  static const CamFrameSize captureSize = CamFrameSize.uxga;
  static const bool captureWithLight = true;
  static const int defaultLightLevel = 60;

  // ── Live stream ─────────────────────────────────────────────────
  /// While the stream is down, try again this often…
  static const Duration reconnectEvery = Duration(seconds: 2);

  /// …and say the camera is disconnected after this long.
  static const Duration giveUpAfter = Duration(seconds: 15);

  /// No new picture for this long counts as a dropped stream.
  static const Duration frameStall = Duration(seconds: 3);

  /// How often the signal strength is read.
  static const Duration statusEvery = Duration(seconds: 5);

  static const Duration connectTimeout = Duration(seconds: 4);
  static const Duration captureTimeout = Duration(seconds: 15);

  // ── Setup ───────────────────────────────────────────────────────
  static const Duration bleScanFor = Duration(seconds: 15);
  static const Duration bleConnectTimeout = Duration(seconds: 12);

  /// Writes allow time for the phone's pairing prompt.
  static const Duration bleWriteTimeout = Duration(seconds: 30);
  static const Duration wifiScanTimeout = Duration(seconds: 15);

  /// From sending the Wi-Fi details to the camera saying it joined.
  static const Duration joinTimeout = Duration(seconds: 45);

  /// How long "Camera restarting" shows before the app starts looking.
  static const Duration restartPause = Duration(seconds: 3);

  /// How long to look for the camera on the network after it restarts.
  static const Duration findOnNetworkFor = Duration(seconds: 45);
  static const Duration findEvery = Duration(milliseconds: 1500);

  /// Pictures for each setup step, in order (welcome, permissions, power,
  /// find, Wi-Fi, connect). Null draws the built-in placeholder; to replace
  /// one, add a transparent PNG to `assets/images/` (about 600×360) and put
  /// its path here, e.g. 'assets/images/camera_setup_power.png'.
  static const List<String?> setupArt = [null, null, null, null, null, null];
}
