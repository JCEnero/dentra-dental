/// Every word the Dentra Cam screens show: the setup guide, the live camera,
/// its tips and the review page. Edit wording here, or translate it, without
/// touching the screens.
///
/// Two things live elsewhere on purpose:
/// - Area names and positioning instructions ("Front Teeth", "Smile with your
///   teeth together…") come from the scan's guided views in
///   `scan/data/scan_regions.dart`, which results, history and the PDF share.
/// - Photo check reasons ("Photo is blurry"…) come from `photoProblemCopy` in
///   `scan/widgets/capture_stage.dart`, so the phone and the camera say the
///   same thing.
library;

abstract final class CamText {
  static const product = 'Dentra Cam';

  // ── Shared actions ──────────────────────────────────────────────
  static const back = 'Back';
  static const next = 'Next';
  static const close = 'Close';
  static const tryAgain = 'Try again';
  static const done = 'Done';

  // ── Setup guide: frame ──────────────────────────────────────────
  static const setupTitle = 'Connect your Dentra Cam';
  static const closeSetup = 'Close setup';
  static const rabiSays = 'Rabi says';

  /// Names of the six steps, read out with the progress line.
  static const stepNames = [
    'Welcome',
    'Bluetooth permission',
    'Turn on the camera',
    'Find your camera',
    'Choose Wi-Fi',
    'Connect',
  ];

  // ── Step 1: welcome ─────────────────────────────────────────────
  static const welcomeTitle = "Let's connect your Dentra Cam.";
  static const welcomeBody =
      'It takes about two minutes. Have these ready before you start:';
  static const welcomeItems = <(String, String)>[
    (
      'Camera charged and on',
      'Top it up over USB-C if the battery is low.',
    ),
    (
      'Bluetooth on',
      'Your phone uses it to find the camera nearby.',
    ),
    (
      'Your Wi-Fi name and password',
      'The camera joins your home Wi-Fi, just like your phone.',
    ),
    (
      'A 2.4 GHz Wi-Fi network',
      'The camera works on 2.4 GHz. Most home routers offer 2.4 GHz and 5 GHz '
          'together, so you are probably set. If you see two networks, pick '
          'the one without "5G" in its name.',
    ),
  ];
  static const welcomeRabi =
      "Hi, I'm Rabi. I'll walk you through it, one step at a time.";
  static const welcomeLater = 'Not now';
  static const welcomeStart = "Let's go";

  // ── Step 2: permissions ─────────────────────────────────────────
  static const permissionTitle = 'Allow Bluetooth';
  static const permissionBody =
      'Your phone finds the Dentra Cam over Bluetooth and uses it once to '
      'send your Wi-Fi details. After that, the camera talks to your phone '
      'over Wi-Fi.';
  static const permissionLocationNote =
      'On older Android phones, Bluetooth scanning also needs location '
      "access. DENTRA doesn't use or keep your location.";
  static const permissionAllow = 'Allow Bluetooth';
  static const permissionChecking = 'Checking Bluetooth…';
  static const permissionGranted = 'Bluetooth is ready.';
  static const permissionDeniedTitle = 'Bluetooth is blocked for DENTRA';
  static const permissionDeniedAndroid =
      'Open Settings, tap Permissions, and allow Nearby devices. On older '
      'Android phones, allow Location too. Then come back here.';
  static const permissionDeniedIos =
      'Open Settings, find DENTRA, and turn on Bluetooth. Then come back here.';
  static const openSettings = 'Open settings';
  static const settingsUnavailable =
      "Couldn't open settings. Open your phone's settings and find DENTRA.";
  static const bluetoothOffTitle = 'Bluetooth is off';
  static const bluetoothOffAndroid =
      'Turn on Bluetooth so your phone can find the camera.';
  static const bluetoothOffIos =
      'Open Control Center or Settings and turn on Bluetooth, then come back '
      'here.';
  static const turnOnBluetooth = 'Turn on Bluetooth';
  static const checkAgain = 'Check again';
  static const bluetoothUnsupported =
      "This phone can't use Bluetooth Low Energy, so it can't set up the "
      'camera.';
  static const permissionRabi =
      'Bluetooth is only for setup. Your photos travel over Wi-Fi.';

  // ── Step 3: turn on the camera ──────────────────────────────────
  static const powerTitle = 'Turn on the camera';
  static const powerBody =
      'Power on your Dentra Cam and keep it near your phone.';
  static const powerResetTitle = 'Set it up before?';
  static const powerResetBody =
      'Hold the BOOT button for 5 seconds to reset it, so your phone can find '
      'it again.';
  static const powerRabi =
      'Keep it close. Bluetooth works best within a few steps.';
  static const powerReady = "It's on";

  // ── Step 4: find your camera ────────────────────────────────────
  static const findTitle = 'Find your camera';
  static const findSearching = 'Looking for your Dentra Cam…';
  static const findFoundHint = 'Tap your camera to connect.';
  static String findConnecting(String name) => 'Connecting to $name…';
  static String findConnectFailed(String name) =>
      "Couldn't connect to $name. Move closer and try again.";
  static const findNothingTitle = 'No camera found yet';
  static const findTips = [
    'Move your phone closer to the camera.',
    'Turn the camera off and on again.',
    'Set up before? Hold the BOOT button for 5 seconds to reset it.',
  ];
  /// Android only: scanning finds nothing on Android 11 and older while
  /// Location is switched off.
  static const findLocationTip =
      'On older Android phones, switch Location on too. Bluetooth scanning '
      'needs it there.';
  static const findAgain = 'Scan again';
  static const findSearchingButton = 'Searching…';
  static const findRabi =
      'If your phone asks to pair with the Dentra Cam, tap Pair.';
  static String cameraSignal(int bars) => 'Signal $bars of 4';

  /// For cameras already on Wi-Fi, e.g. a development build that joins a
  /// network by itself.
  static const manualLink = 'Camera already on Wi-Fi? Enter its address';
  static const manualTitle = 'Camera address';
  static const manualBody =
      'Enter the IP address the camera shows or prints, for example '
      '192.168.1.40.';
  static const manualHint = '192.168.1.40';
  static const manualInvalid = 'Enter an address like 192.168.1.40.';
  static const manualConnect = 'Connect';

  // ── Step 5: choose Wi-Fi ────────────────────────────────────────
  static const wifiTitle = 'Choose your Wi-Fi';
  static const wifiBody = 'These are the networks your camera can see.';
  static const wifiLoading = 'Looking for Wi-Fi networks…';
  static const wifiEmpty = "Your camera didn't find any Wi-Fi networks.";
  static const wifiFailed = "Couldn't get the network list from your camera.";
  static const wifiRescan = 'Rescan';
  static const wifiNotListed = "My network isn't listed";
  static const wifiNotListedTips = [
    'The camera only sees 2.4 GHz Wi-Fi. If your router shows a separate '
        '5 GHz network, look for its 2.4 GHz twin, or turn 2.4 GHz on in your '
        'router settings.',
    'Move the camera closer to your router, then tap Rescan.',
  ];
  static const wifiSecured = 'Secured';
  static const wifiOpen = 'Open';
  static const wifiPasswordLabel = 'Wi-Fi password';
  static String wifiPasswordFor(String ssid) => 'Password for $ssid';
  static const showPassword = 'Show password';
  static const hidePassword = 'Hide password';
  static const wifiPasswordShort = 'Wi-Fi passwords have at least 8 characters.';
  static const wifiOpenNote =
      "This network has no password. Anyone nearby can join it, so a secured "
      'network is safer.';
  static const wifiConnect = 'Connect';
  static const wifiChooseAnother = 'Choose another network';
  static const wifiRabi =
      "Your password goes straight to your camera. DENTRA doesn't keep it.";

  // ── Step 6: connecting ──────────────────────────────────────────
  static const connectTitle = 'Connecting your camera';
  static const stageSending = 'Sending Wi-Fi details';
  static const stageJoining = 'Camera joining Wi-Fi';
  static const stageRestarting = 'Camera restarting';
  static const stageFinding = 'Finding camera on your network';
  static const stageDone = 'Connected!';

  static const errorWrongPassword =
      "That password didn't work. Please check it and try again.";
  static const errorSsidNotFound =
      "The camera couldn't find that network. Move closer to your router, "
      "and make sure it's 2.4 GHz.";
  static const errorTimeout =
      'The camera took too long to connect. Let\'s try again.';
  static String errorNotOnNetwork(String? ssid) => ssid == null
      ? 'Make sure your phone is connected to the same Wi-Fi as the camera.'
      : 'Make sure your phone is connected to the same Wi-Fi ($ssid) as the '
          'camera.';
  /// iPhone only, after [errorNotOnNetwork]: a denied Local Network
  /// permission looks the same to the app.
  static const localNetworkHintIos =
      'Also check that Local Network is on in Settings > DENTRA.';
  static const errorLinkLost =
      'We lost touch with the camera before it finished. Keep it close and '
      "let's try again.";
  static const errorFailed =
      "Something went wrong while connecting. Let's try again.";
  static const startOver = 'Start over';
  static const connectRabi = 'This can take up to a minute. Keep the camera on.';

  // Success
  static const successTitle = 'Your Dentra Cam is ready!';
  static String successBody(String? ssid) => ssid == null
      ? "Here's what it sees right now."
      : "It's on $ssid. Here's what it sees right now.";
  static const startCapturing = 'Start capturing';
  static const successRabi = "All set! You won't need to do this again.";

  // ── Live camera ─────────────────────────────────────────────────
  static const captureScreen = 'Live camera';
  static const closeCamera = 'Close camera';
  static const connecting = 'Connecting to camera…';
  static const reconnecting = 'Reconnecting…';
  static const disconnectedTitle = 'Camera disconnected';
  static const disconnectedBody =
      'Check that your Dentra Cam is on and near your Wi-Fi router.';
  static const retry = 'Retry';
  static const checkDevice = 'Check device';
  static const statusConnected = 'Connected';
  static const statusOffline = 'Not connected';
  static String signalWord(int bars) => switch (bars) {
        >= 4 => 'Strong',
        3 => 'Good',
        2 => 'Fair',
        _ => 'Weak',
      };
  static String statusSemantics(bool connected, int? bars) => [
        connected ? 'Camera connected' : 'Camera not connected',
        if (bars != null) 'Wi-Fi signal ${signalWord(bars).toLowerCase()}',
      ].join(', ');
  static String areaProgress(int n, int total) => '$n of $total';
  static const skip = 'Skip';
  static String skipArea(String area) => 'Skip $area';
  static String takePhoto(String area) => 'Take photo of $area';
  static const takingPhoto = 'Taking photo…';
  static const captureFailed = "Couldn't take the photo. Please try again.";
  static const settingFailed = "The camera didn't take that setting.";
  static const thumbsEmpty = 'Photos you take appear here.';
  static String thumbSemantics(String area, String status) =>
      '$area photo, $status';
  static const review = 'Review';
  static const howToCapture = 'How to capture';

  // Photo check states, on thumbnails, the viewer and the review page.
  static const checking = 'Checking…';
  static const checkPassed = 'Looks good';
  static const checkRejected = 'Retake needed';
  static const checkError = "Couldn't check";
  static const checkSkipped = 'Skipped';
  static const checkErrorBody =
      "The photo check didn't answer, so this photo can't be kept yet.";

  // Controls
  static const controls = 'Camera settings';
  static const light = 'Light';
  static const lightOn = 'Turn light on';
  static const lightOff = 'Turn light off';
  static const brightness = 'Brightness';
  static const rotate = 'Rotate';
  static const rotateHint = 'Turn the picture upside down';
  static const mirror = 'Mirror';
  static const mirrorHint = 'Swap left and right';
  static const liveView = 'Live view';
  static const liveSmooth = 'Smoother';
  static const liveSharp = 'Sharper';

  // Photo viewer
  static const retake = 'Retake';
  static const delete = 'Delete';
  static const deleteTitle = 'Delete this photo?';
  static const deleteBody = "It won't be part of this scan.";

  // ── Review & Save ───────────────────────────────────────────────
  static const reviewTitle = 'Review & Save';
  static String reviewSummary(int kept, int total) =>
      '$kept of $total areas ready';
  static const reviewNote =
      "Areas you skip, or that still need a retake, aren't saved with this "
      'scan.';
  static const reviewReady = 'Ready';
  static const notTaken = 'Not taken yet';
  static const takeNow = 'Take now';
  static const saveAndAnalyze = 'Save & analyze';
  static const waitingForChecks = 'Checking photos…';
  static const reviewNeedsPhoto = 'Take at least one photo to save.';
  static const backToCamera = 'Back to camera';

  // ── How to capture ──────────────────────────────────────────────
  static const tipsTitle = 'How to capture';
  static const tipsSubtitle = 'Four habits for clear, useful photos.';
  static const tips = <(String, String)>[
    (
      'Hold it like a toothbrush',
      'Rest your hand on your chin to keep it steady.',
    ),
    (
      'Light on',
      'Keep the camera light on so your teeth show clearly.',
    ),
    (
      'Move slowly',
      'Glide from tooth to tooth and pause before each photo.',
    ),
    (
      'Keep the lens clean and dry',
      'Wipe it before you start, and again if the picture looks misty.',
    ),
  ];
  static const tipsDontShow = "Don't show again";
  static const tipsGotIt = 'Got it';

  // ── Scan page and settings ──────────────────────────────────────
  static const cardNotSetUpTitle = 'Not set up';
  static const cardNotSetUpBody =
      'Connect your Dentra Cam to Wi-Fi in a few steps.';
  static const cardSetUp = 'Set up';
  static const settingsGroup = 'Dentra Cam';
  static const settingsSetupAgain = 'Set up camera again';
  static String settingsSaved(String name, String? ssid) =>
      ssid == null ? name : '$name on $ssid';
  static const settingsNone = 'Connect your Dentra Cam to Wi-Fi';
}
