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
  static const closeSetup = 'Close setup';
  static const rabiSays = 'Rabi says';

  /// Names of the six steps, read out with the step rail.
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
  static const welcomeHighlight = 'Dentra Cam';
  static const welcomeBody = 'Charge it, and have these ready.';
  static const welcomeItems = [
    'Camera charged',
    'Bluetooth on',
    'A 2.4 GHz Wi-Fi network and its password',
  ];
  static const welcomeLater = 'Not now';
  static const welcomeStart = "Let's go";

  // ── Step 2: permissions ─────────────────────────────────────────
  static const permissionTitle = 'Allow Bluetooth';
  static const permissionHighlight = 'Bluetooth';
  static const permissionBody = 'Your phone uses it to find the camera.';
  static const permissionLocationNote =
      "Older Android phones also ask for location. DENTRA doesn't use or "
      'keep it.';
  static const permissionAllow = 'Allow';
  static const permissionChecking = 'Checking…';
  static const permissionGranted = 'Bluetooth is ready.';
  static const permissionDeniedTitle = 'Bluetooth is blocked';
  static const permissionDeniedAndroid =
      'In Settings, open Permissions and allow Nearby devices. On older '
      'Android phones, allow Location too.';
  static const permissionDeniedIos =
      'In Settings, open DENTRA and turn on Bluetooth.';
  static const openSettings = 'Open settings';
  static const settingsUnavailable =
      "Couldn't open settings. Open your phone's settings and find DENTRA.";
  static const bluetoothOffTitle = 'Bluetooth is off';
  static const bluetoothOffAndroid = 'Turn it on to find the camera.';
  static const bluetoothOffIos = 'Turn it on in Control Center or Settings.';
  static const turnOnBluetooth = 'Turn on Bluetooth';
  static const checkAgain = 'Check again';
  static const bluetoothUnsupportedTitle = "This phone can't set up the camera";
  static const bluetoothUnsupported = 'It has no Bluetooth Low Energy.';

  // ── Step 3: turn on the camera ──────────────────────────────────
  static const powerTitle = 'Turn on the camera';
  static const powerHighlight = 'Turn on';
  static const powerBody = 'Slide the switch on its side. Keep it near you.';
  static const powerSwitchLabel = 'Power';
  static const usbLabel = 'USB-C';
  static const artCharging =
      'How to charge the Dentra Cam: a USB-C cable plugs into its base.';
  static const artPower =
      'The Dentra Cam, with the power switch on its side lit up.';
  static const powerReset =
      'Set up before? Hold BOOT for 5 seconds to reset it.';
  static const powerReady = "It's on";

  // ── Step 4: find your camera ────────────────────────────────────
  static const findSearching = 'Looking for your Dentra Cam…';
  static const findPairHint = 'If your phone asks to pair, tap Pair.';
  static const findFoundTitle = 'Tap your camera';
  static String findConnecting(String name) => 'Connecting to $name…';
  static String findConnectFailed(String name) =>
      "Couldn't connect to $name. Move closer and try again.";
  static const findNothingTitle = 'No camera found';
  static const findTips = [
    'Move your phone closer.',
    'Turn the camera off and on.',
    'Set up before? Hold BOOT for 5 seconds.',
  ];

  /// Android only: scanning finds nothing on Android 11 and older while
  /// Location is switched off.
  static const findLocationTip = 'On older Android phones, turn on Location.';
  static const findAgain = 'Scan again';
  static const searching = 'Searching…';
  static const connectingShort = 'Connecting…';
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
  static const wifiLoading = 'Looking for networks…';
  static const wifiEmpty = 'No networks found.';
  static const wifiFailed = "Couldn't get the network list.";
  static const wifiRescan = 'Rescan';
  static const wifiNotListed = "My network isn't listed";
  static const wifiNotListedTips = [
    "Look for your 2.4 GHz network. The camera can't see 5 GHz.",
    'Move the camera closer to your router, then rescan.',
  ];
  static const wifiSecured = 'Secured';
  static const wifiOpen = 'Open';
  static const wifiPasswordLabel = 'Wi-Fi password';
  static const wifiPasswordBody = 'Enter its password.';
  static const wifiPrivacy =
      "Sent only to your camera. DENTRA doesn't keep it.";
  static const showPassword = 'Show password';
  static const hidePassword = 'Hide password';
  static const wifiPasswordShort =
      'Wi-Fi passwords have at least 8 characters.';
  static const wifiOpenNote =
      'No password needed. Anyone nearby can join this network.';
  static const wifiConnect = 'Connect';
  static const wifiChooseAnother = 'Choose another network';
  static const wifiOther = 'Other network';

  // ── Step 6: connecting ──────────────────────────────────────────
  static const stageSending = 'Sending Wi-Fi details';
  static const stageJoining = 'Camera joining Wi-Fi';
  static const stageRestarting = 'Camera restarting';
  static const stageFinding = 'Finding your camera';
  static const stageDone = 'Connected';
  static const connectHint = 'Up to a minute. Keep the camera on.';

  static const errorTitle = "That didn't work";
  static const errorWrongPassword =
      "That password didn't work. Check it and try again.";
  static const errorSsidNotFound =
      "The camera couldn't find that network. Move it closer to your router.";
  static const errorTimeout = 'The camera took too long to connect.';
  static String errorNotOnNetwork(String? ssid) => ssid == null
      ? 'Connect your phone to the same Wi-Fi as the camera.'
      : 'Connect your phone to the same Wi-Fi as the camera ($ssid).';

  /// iPhone only, after [errorNotOnNetwork]: a denied Local Network
  /// permission looks the same to the app.
  static const localNetworkHintIos =
      'Also turn on Local Network in Settings > DENTRA.';
  static const errorLinkLost = 'Lost touch with the camera. Keep it close.';
  static const errorFailed = "Couldn't connect.";
  static const startOver = 'Start over';

  // Success
  static const successTitle = 'Your Dentra Cam is ready!';
  static String successBody(String? ssid) =>
      ssid == null ? 'This is its live view.' : 'Connected to $ssid.';
  static const startCapturing = 'Start capturing';

  // ── Live camera ─────────────────────────────────────────────────
  static const captureScreen = 'Live camera';
  static const closeCamera = 'Close camera';
  static const connecting = 'Connecting to camera…';
  static const reconnecting = 'Reconnecting…';
  static const disconnectedTitle = 'Camera disconnected';
  static const disconnectedBody =
      'Check that your Dentra Cam is on and near your Wi-Fi router.';
  // On the website the camera comes through the internet, and lets go of
  // its link after a while unused.
  static const disconnectedBodyCloud =
      "Check that your Dentra Cam is on and near your Wi-Fi router. If it's "
      'been on a while, press its BOOT button once to connect it again.';
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
  static const tipsRabi = "Take your time. I'll name each area as we go.";
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

  // ── Choosing how to capture, at Start ───────────────────────────
  static const choiceTitle = 'How will you take your photos?';
  static const choiceSubtitle = 'You can choose again at your next scan.';
  static const choiceCam = 'Dentra Cam';
  static String choiceCamBody(String? name) =>
      name == null ? "We'll help you connect it first." : 'Use $name.';
  // Only where the camera can't be used at all (desktop builds).
  static const choiceCamAppOnly =
      'Works in the DENTRA phone app and on dentrascan.site.';
  static const choiceOwn = 'My own camera';
  static const choiceOwnBody = 'No device? Take the photos with your phone.';
  static const choiceOwnPhotos = 'No device? Choose photos you already have.';

  // ── Website setup: the camera's own hotspot ─────────────────────
  // iPhone browsers have no Bluetooth, so on the website the camera is set
  // up through its own Wi-Fi network and a code that links it to the
  // account.
  static const hotspotStepNames = [
    'Welcome',
    'Turn on the camera',
    'Connect',
    'Ready',
  ];
  static const hotspotWelcomeItems = [
    'Camera charged',
    'A 2.4 GHz Wi-Fi network and its password',
    'This page kept open',
  ];

  static const hotspotPowerBody =
      'Slide the switch on its side. It starts in setup mode.';
  static const hotspotPowerReset = 'Set up before? Hold BOOT for 5 seconds.';

  static const hotspotJoinTitle = 'Give the camera your Wi-Fi';
  static const hotspotJoinHighlight = 'your Wi-Fi';
  static const artHotspot =
      'The Dentra Cam sends out its own Wi-Fi, named Dentra Cam and four '
      'characters.';
  static const hotspotCodeLabel = 'Your code';
  static const hotspotCodeTime = '15 min';
  static const hotspotCodeHint = 'Works for 15 minutes.';
  static const hotspotCopy = 'Copy';
  static const hotspotCopyCode = 'Copy code';
  static const hotspotCodeCopied = 'Code copied';

  /// What to do away from this page, in order: the step, and a line for
  /// when it doesn't go to plan.
  static const hotspotSteps = <(String, String?)>[
    (
      'Join the Wi-Fi named "Dentra Cam" and four characters.',
      'If your phone says it has no internet, stay connected.',
    ),
    (
      'A setup page opens.',
      "If it doesn't, go to 192.168.4.1 in your browser.",
    ),
    ('Pick your home Wi-Fi. Enter its password and this code.', null),
    ('Tap Connect, then come back here.', null),
  ];
  static const hotspotGettingCode = 'Getting code…';
  static const hotspotWaiting = 'Waiting…';
  static const hotspotWaitingFor = 'Waiting for your Dentra Cam';
  static const hotspotSlowTitle = 'Still waiting?';
  static const hotspotSlowBody =
      "Join the camera's Wi-Fi again and check its setup page. The camera "
      'needs a 2.4 GHz network.';
  static const hotspotExpiredTitle = 'This code expired';
  static const hotspotExpiredBody =
      'Get a new one and enter it on the setup page.';
  static const hotspotCodeFailedTitle = "Couldn't get a code";
  static const hotspotCodeFailed = 'Check your internet and try again.';
  static const hotspotNewCode = 'New code';
  static const hotspotSuccessBody = 'Linked to your account.';
}
