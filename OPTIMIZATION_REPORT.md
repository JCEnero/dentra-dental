# Dentra optimization report

Work happens on branch `optimize/size-and-performance`, started from `main` at `a9e870f` on 2026-11-15.

Sizes use MB = 1,048,576 bytes, the same unit `flutter build` prints.

## Baseline

### Toolchain

| Item | Version |
|---|---|
| Flutter | 3.47.5 stable (framework `6a19cca564`, engine `ab59836859`) |
| Dart | 3.13.4 |
| DevTools | 2.60.0 |
| Android Gradle Plugin / Kotlin / Gradle | 9.1.0 / 2.4.0 / 9.3.1 |
| Java | 17 |
| compileSdk / targetSdk / minSdk | 36 / 36 / 24 (Flutter defaults) |
| App version | 1.0.0+2 |

### Release build sizes

| Build | Command | Size |
|---|---|---|
| APK, arm64 target, with size analysis | `flutter build apk --release --analyze-size --target-platform android-arm64` | 89.3 MB (93,659,253 bytes) |
| App bundle | `flutter build appbundle --release` | 117.5 MB (123,212,515 bytes) |
| Split APK, arm64-v8a | `flutter build apk --release --split-per-abi` | 65.8 MB (69,028,614 bytes) |
| Split APK, armeabi-v7a | same | 60.9 MB (63,897,772 bytes) |
| Split APK, x86_64 | same | 68.4 MB (71,670,873 bytes) |

Notes:

- The arm64-target APK is bigger than the arm64 split APK because `fvp` ships prebuilt native libraries for armeabi-v7a and x86_64 as well. `--target-platform` only limits Flutter's own libraries.
- About 40 MB of the AAB (compressed) is `BUNDLE-METADATA`: native debug symbols and the R8 mapping, used by Play Console for crash reports. Play never sends it to phones. A phone downloads roughly the split APK for its ABI, compressed further by Play.
- R8 code shrinking and resource shrinking are already on for release builds. The Flutter Gradle plugin turns them on by default (`FlutterPlugin.kt`: `isMinifyEnabled = true`, `isShrinkResources = true`), and the build writes `build/app/outputs/mapping/release/mapping.txt`.

### What is inside the arm64-v8a APK (65.8 MB)

| Part | Size | Notes |
|---|---|---|
| Native libraries (`lib/arm64-v8a`) | 36.3 MB | stored uncompressed, as Android expects by default |
| - `libapp.so` (Dart code, AOT) | 12.1 MB | |
| - `libflutter.so` (engine) | 11.2 MB | fixed cost |
| - fvp video stack: `libffmpeg` 8.0, `libmdk` 2.2, `libass` 1.4, `libc++_shared` 1.2, `libfvp` 0.07 | 12.8 MB | all from `fvp` |
| - other (`libdartjni`, datastore) | 0.13 MB | |
| Flutter assets | 27.7 MB | |
| - 23 treatment icons (PNG, 1024 to 1254 px) | 16.8 MB | |
| - `treatments/mascot.png` (2048 px) | 3.8 MB | |
| - `justhelogobig.png` (3202 x 3748 px) | 2.5 MB | |
| - `rabi_avatar.png` (1920 px) | 2.1 MB | |
| - everything else | 2.6 MB | |
| `classes.dex` | 1.4 MB | 928 of the kept classes are `androidx.media3` (ExoPlayer, pulled in by `video_player`) |
| `resources.arsc` + `res/` | 0.3 MB | |

### Dart code size by package (arm64, from `--analyze-size`)

| Package | Size |
|---|---|
| `package:flutter` | 3,298 KB |
| `package:dentra_mobile` (this app) | 2,718 KB |
| `package:image` (also used by `pdf`) | 778 KB |
| `package:pdf` + `package:bidi` | 481 KB |
| `vector_graphics_compiler` + `petitparser` + `xml` (runtime SVG parsing for `flutter_svg`) | 267 KB |
| `google_maps_flutter_android` + platform interface | 194 KB |
| `universal_ble` | 137 KB |
| `fvp` + `video_player_android` | 122 KB |
| `riverpod` | 76 KB |

### Code, assets and dependencies

- 264 Dart files in `lib/` (84,586 lines) and 31 test files.
- 47 files in `assets/`, 28 MB on disk.
- 22 direct dependencies, 2 dev dependencies, 134 transitive packages (158 in `pubspec.lock`).

| Package | Constraint | Resolved |
|---|---|---|
| google_fonts | ^6.2.1 | 6.3.3 |
| video_player | ^2.9.2 | 2.14.0 |
| fvp | ^0.38.1 | 0.38.1 |
| flutter_riverpod | ^2.6.1 | 2.6.1 |
| geolocator | ^13.0.2 | 13.0.4 |
| google_maps_flutter | ^2.18.0 | 2.18.1 |
| url_launcher | ^6.3.2 | 6.3.2 |
| http | ^1.6.0 | 1.6.0 |
| flutter_dotenv | ^6.0.1 | 6.0.1 |
| image_picker | ^1.1.2 | 1.2.3 |
| shared_preferences | 2.5.5 | 2.5.5 |
| google_sign_in | 7.2.0 | 7.2.0 |
| flutter_secure_storage | 11.2.0 | 11.2.0 |
| file_selector | 1.1.0 | 1.1.0 |
| pdf | 3.11.3 | 3.11.3 |
| printing | 5.14.2 | 5.14.2 |
| image | 4.5.4 | 4.5.4 |
| universal_ble | 3.2.0 | 3.2.0 |
| wakelock_plus | 1.8.2 | 1.8.2 |
| web_socket_channel | 3.0.3 | 3.0.3 |
| flutter_svg | 2.3.0 | 2.3.0 |
| flutter_lints (dev) | ^4.0.0 | 4.0.0 |

### Analyzer

`flutter analyze`: no issues found (0 errors, 0 warnings, 0 infos), using the `flutter_lints` 4.0.0 rule set.

### Tests

`flutter test`: 494 passed, 0 failed (31 test files, about 1 minute).

## Phase 1: audit

Read only. Nothing was deleted or changed in this phase.

### 1A. Unused code

Method:

- An import graph from `lib/main.dart`, following `import`, `export`, `part` and conditional imports, found which files are never reached.
- A resolver-based reachability check (a scratch script on `package:analyzer` 10.2.0, so nothing was added to `pubspec.yaml`) walked from `main()` through every top-level declaration and class member. It treats `@override` members, `toJson`, operators and `@pragma('vm:entry-point')` as used, ignores doc-comment mentions, and separately walks from `test/` to tag test-only code. It scanned 9,593 declarations.
- Every finding was cross-checked with a plain text search. Where a name is common (`of`, `read`, `clear`, `fromJson`), the hits were checked by hand.

Dart's AOT compiler already leaves unreachable code out of `libapp.so`, so deleting dead code does not make the APK smaller. The benefit is less code to read and maintain.

Only 1 of the 264 files is unreachable. The code base is tidy at the file level.

**Proposed for deletion**

| Code | Location | Lines | Reason | Confidence |
|---|---|---|---|---|
| `SectionLabel` (whole file) | `lib/shared/widgets/section_label.dart` | 23 | No file imports it | high |
| `SetupPowerArt` and `_PowerPainter` | `lib/features/camera/widgets/setup_page.dart:847-918` | 72 | Never built; left over from the earlier camera setup art | high |
| `ReportLegend` and `ReportLegendItem` | `lib/features/scan/widgets/report/report_style.dart:184-230` | 47 | Never built (`ReportSwatch` next to them is used and stays) | high |
| `GuideSpeech` | `lib/shared/widgets/guide_kit.dart:221-256` | 36 | Never built | high |
| `projectPoint()` | `lib/features/scan/rendering/scan_scene.dart:148-162` | 15 | Never called | high |
| Unused constants: `AppColors.cardSolidAlt`, `cardDeep`, `verticalGradient`, `horizontalGradient`, `pageBackground`; `AppRadius.xl`, `xlAll`, `xxlAll`; `AppSpacing.xxl`; `ScanColors.clear`; `GlassBarEdge.bottom` | `lib/core/constants/*`, `scan_theme.dart`, `glass_card.dart` | about 20 | Never read | high |
| Unused strings: `CamText.settingsUnavailable`, `showPassword`, `hidePassword`, `statusConnected`, `statusOffline`, `areaProgress()` | `lib/features/camera/camera_strings.dart` | about 12 | Never read | high |
| Unused methods and getters: `CameraStore.forgetCamera`, `setupOffered`, `markSetupOffered` (and its key); `CloudCamApi.forget`; `CloudCamClient.cameraOnline`; `GeminiService.resetSession`; `AuthService.usesBackend`; `ClinicFilterNotifier.setOpenNowOnly`, `reset`; `DentalRecordsNotifier.byId`; `ScanSessionNotifier.dismissFailure`; `ScreeningSessionsNotifier.clear`; `CareLevel.of`, `CareLevel.max`; `ReportSpot.sideOfPhoto`; `ConditionRow.read`; `ScanTrend.oneLine`; `ChamberTimeline.activeIndex`; `ToothDimensions.totalLength`; `ToothInfo.quadrantName`; `ToothContent.numberBreakdown`; `DentitionRenderer.drawnTriangles`; `ExplorerCamera.isAttached` | various | about 120 | Never called | high |
| Unused model constructors: `ClinicModel.fromJson`, `ClinicService.fromJson`, `OperatingHours.fromJson`, `ClinicModel.copyWith` | `lib/features/clinic_finder/data/models/clinic_model.dart` | about 90 | Never called; clinics are built another way | medium (keep if a clinic API is planned) |

**Fields that are set but never read (proposed to keep)**

`AuthResult.userId`, `CamFrameSize.width`/`height`, `CloudCamera.online`, `CamPairing.expiresAt`, `AreaReport.photoIds`, `ToothUrgency.short`, `SpotMarker.strength`, `ToothAnchor.occlusal`, `DentalProfileException.sessionEnded`, `ChamberPainter.clock`, `_ScopeLine.report`, `_TreatmentCard.index`. Most mirror server payloads or constructor arguments. Removing them means changing constructors and call sites for no size gain. The last three are private widget or painter fields and could go if you want them gone.

**Used only by tests (keep)**

`MemoryQuestionnaireDraftStore` (a fake store the tests inject), `AuthResult.needsTwoFactor`, `CamPairing.displayCode`, `CamStatus.frameSize`/`vflip`/`hmirror`/`lightOn`/`lightLevel`, `GuidedCaptureController.allVisited`, `CarePlan.drivenByContext`, `PatientContext.isEmpty`, `ScreeningReport.sentence`, `Procedures.all`, `HeroStory.taken`, `ScanCheckIn.copyWith`.

**Keep: used indirectly**

| Code | Why it looks unused | How it is used |
|---|---|---|
| `lib/core/services/maps_loader_web.dart` | The VM-side analysis never resolves it | Web half of a conditional import in `maps_loader.dart` |
| `toJson()` methods | Not called by name | `jsonEncode` calls them |
| `@override` members (`build`, `dispose`, `paint`, ...) | Not called by name | The framework calls them |
| `'/home'` route | String-based | `onGenerateRoute` in `lib/app/app.dart` |
| `lib/shared/widgets/mascot_rig.g.dart` | Generated | Written by `tool/mascot_rig.py`, used by `dentra_mascot.dart` |

There are no platform channels, background handlers, `@pragma('vm:entry-point')` functions, code-generation packages (freezed, json_serializable) or dependency-injection containers in this app.

### 1B. Assets

Each file was searched for by name across `lib/`, `test/`, `web/`, `android/`, `ios/` and `tool/`. No asset path is built at runtime: there is no interpolated `'assets/...$x'` string, and every `Image.asset(variable)` traces back to a constant. The `scan_region_*.png` names in `scan_regions.dart` sit in comments only.

| Asset | Size | Referenced | Shown at | Proposal | Estimated result |
|---|---|---|---|---|---|
| `treatments/icons/*.png` (23 files, 1024 to 1254 px, opaque) | 16.8 MB | `treatment_data.dart` | 48 x 48 points (`treatment_screen.dart:317`, `treatment_detail_screen.dart:334`) | WebP quality 82, 256 px | 0.09 MB |
| `treatments/mascot.png` (2048 px) | 3.8 MB | Only by `tool/mascot_rig.py`, as the source render for the Rabi rig | Never in the app | Move out of the bundled folder, to `tool/source/mascot.png`, and update the tool's note | 0 in the APK |
| `justhelogobig.png` (3202 x 3748) | 2.5 MB | Nowhere | - | Delete | 0 |
| `rabi_avatar.png` (1920 px) | 2.1 MB | `ai_assistant.dart`, `next_steps.dart` | 28 to 96 points | WebP quality 82, 384 px | 0.04 MB |
| `rabi.png` (3000 px) | 0.76 MB | Nowhere | - | Delete | 0 |
| `logowithtext.png` (3982 x 1542) | 0.49 MB | Nowhere | - | Delete | 0 |
| `videos/BUNNY.webm` | 0.16 MB | `home_screen.dart` (Android/iOS) | 100 x 100 points | Delete with `video_player`/`fvp`; `bunny_wave.webp` takes over | 0 |
| `treatments/*.jpg` (4 files, 1024 px) | 0.23 MB | `treatment_data.dart` | Only as a 60 x 60 fallback that never shows, since every treatment has an icon | WebP quality 82, 512 px | 0.06 MB |
| `dentralogoforapp.png` (1024 px) | 63 KB | Nowhere | - | Delete | 0 |
| `fonts/Outfit-*.ttf` (4 weights) | 188 KB | `google_fonts` by file name, and the PDF report | - | Keep all four, and add `Outfit-ExtraBold.ttf` (about 48 KB) | +48 KB |
| `dentra_mark.png`, `dentra_logo.png` | 175 KB | Logo widget, launch loader, PDF report | - | Keep as PNG. The PDF embeds the mark, and the gain is small | - |
| `bunny_wave.webp`, `mascot/rabi_rig.webp`, 4 SVGs, `OFL.txt`, `.env` | 0.5 MB | yes | - | Keep. `OFL.txt` is the font licence | - |

A 512 px WebP of a treatment icon was compared side by side with the original at the same size and showed no visible difference. These are smooth illustrations, which WebP compresses very well.

If you'd rather keep the unused logo and Rabi renders as design sources, they can move to a folder that isn't bundled, the same as `mascot.png`, instead of being deleted.

Font weights in use: w400 (11 styles), w500 (56), w600 (139), w700 (156), w800 (47). Only w400 to w700 are bundled. For w800, `google_fonts` looks for `Outfit-ExtraBold.ttf`, doesn't find it, and downloads it from fonts.gstatic.com at runtime, because `GoogleFonts.config.allowRuntimeFetching` is never turned off outside tests. See 1D.

Estimated effect of all asset changes: Flutter assets go from 27.7 MB to about 1.2 MB in every APK.

### 1C. Dependencies

| Package | Used in | What it costs (arm64) | Verdict |
|---|---|---|---|
| `fvp` | `main.dart` only (`fvp.registerWith()`) | 12.8 MB of native libraries per ABI, plus 73 KB Dart | **Remove** (see below) |
| `video_player` | `home_screen.dart` only: the waving Tooth Bunny on the device card | ExoPlayer (928 kept classes in `classes.dex`) plus 49 KB Dart | **Remove** together with `fvp` |
| `flutter_svg` | `home_screen.dart`: 4 small icons (`teeth.svg`, `treatment.svg`, `comparison.svg`, `rabi-ai.svg`) | 267 KB Dart for parsing SVG XML at runtime | Optional: precompile the 4 SVGs at build time with `vector_graphics_compiler` and draw them with `vector_graphics`. Same vectors, no XML parsing on the device |
| `google_fonts` | 113 files, 551 call sites, all `GoogleFonts.outfit` | Small code; loads bundled Outfit files by name at runtime | **Keep**, but bundle the missing ExtraBold file and turn off runtime fetching (see 1B and 1D) |
| `image` | `report_download.dart` | 778 KB Dart | Keep. `pdf` depends on it anyway |
| `pdf`, `printing` | Scan report PDF | 481 KB Dart (`pdf` + `bidi`) | Keep |
| `google_maps_flutter`, `geolocator` | Clinic finder | 194 KB Dart plus Play Services Maps and Location | Keep |
| `universal_ble`, `web_socket_channel`, `wakelock_plus` | Dentra Cam setup and live capture | 137 KB Dart plus a small Kotlin plugin | Keep |
| `google_sign_in`, `flutter_secure_storage`, `shared_preferences`, `http`, `url_launcher`, `image_picker`, `file_selector`, `flutter_dotenv`, `flutter_riverpod` | Sign-in, storage, network, links, photos, record files, config, state | Small | Keep |

The Tooth Bunny is a 360 px VP9 WebM with an alpha channel. Android's built-in player can't show that alpha, which is why `fvp` (ffmpeg plus the mdk player) was added. The same animation already ships as `assets/images/bunny_wave.webp`, an animated WebP the web build uses because Safari has the same alpha problem. Both are 12 fps, 5 seconds, looping (60 frames of 83 ms in the WebP; 83.3 ms per frame in the WebM). The WebP is 270 px against the WebM's 360 px, shown in a 100 x 100 point box (300 px on a 3x screen). Showing the WebP on every platform removes both packages, about 12.8 MB per ABI of native code, ExoPlayer, `fvp.registerWith()` at startup, and the 170 KB WebM. Flutter's `Image` already pauses animated images when `TickerMode` is off, so the existing pause-when-hidden behavior carries over.

No duplicate-purpose packages were found. `image_picker` (camera and gallery photos) and `file_selector` (record documents) do different jobs, as do `shared_preferences` and `flutter_secure_storage` (tokens).

`android/app/build.gradle.kts` declares no native dependencies of its own. Every native library comes from a Flutter plugin.

### 1D. Performance hotspots

Method: a pattern scan of all 264 files (blur, Opacity, clips, saveLayer, tickers, setState, list builders, image decode sizes, JSON, isolates), then a read-through of the chat, the app shell and tabs, the glass kit, the lists, the camera and scan pipeline, startup, and the 3D and custom-painted visuals. Framework behavior was checked against the local Flutter 3.47.5 source. The top items below were confirmed by reading the code directly. Frame times can't be measured statically, so impact is an estimate until Phase 5 profiles on a phone.

Ranked by expected impact:

| # | Issue | Where | Why it costs frames | Fix (no visual change unless noted) |
|---|---|---|---|---|
| 1 | Hidden tabs never stop animating | `lib/app/app.dart:159` | In 3.47 `IndexedStack` adds no `TickerMode`. The Scan tab's intro runs four endless animations (`scan_hero.dart:40`, `how_it_works_card.dart:84`, `device_reach_panel.dart:66`, `scan_theme.dart:114`), so the app renders a full frame, including the dock blur, every vsync on every tab. It never idles: heat, battery, and UI-thread time taken from scrolling | Wrap each tab in `TickerMode(enabled: i == _tab)` |
| 2 | Each streamed Rabi chunk rebuilds the whole chat | `ai_chat_controller.dart:355`, `ai_assistant.dart:85-121, 1162-1225` | `notifyListeners()` per chunk rebuilds the overlay, header, input and every built bubble. Each bubble re-parses its markdown, and the screening suggestion (a full `ScreeningReport`) is rebuilt too | Put the partial text in a `ValueNotifier` that only the streaming bubble listens to; notify the controller only at start and end; cache the parsed markdown and the suggestion |
| 3 | Switching tabs rebuilds four tabs | `lib/app/app.dart:140-146` | The tab widgets are created inside `build()`, so `setState(_tab)` re-runs Home, Scan, History and Profile. History rebuilds every card and its `ScreeningReport` | Create the tab list once in the State |
| 4 | Full-resolution decodes of tiny images | `treatment_screen.dart:317`, `treatment_detail_screen.dart:334`, `ai_assistant.dart:633`, `next_steps.dart:310` | Each 48-point treatment icon decodes to 4.2 to 6.3 MB. All 23 together are about 100 MB, the whole default image cache, so scrolling evicts and re-decodes them. The Rabi avatar decodes to 14.7 MB for at most 96 points | Resize the files (1B) and add `cacheWidth` at the call sites |
| 5 | PDF export blocks the UI | `report_download.dart:103-111`, `report_pdf.dart:140-165, 785, 1095` | `img.encodeJpg` runs in pure Dart on the UI isolate for each photo (about 1000 x 750), and the PDF layout runs there too. A new `pw.MemoryImage` per tooth crop embeds the same photo again | Encode in `Isolate.run`; reuse one `MemoryImage` per photo; optionally build the whole PDF in an isolate |
| 6 | Missing ExtraBold font is downloaded at runtime | `lib/app/theme.dart`, 47 `FontWeight.w800` styles | Until the download finishes, which is never when offline, that text uses the system font. When it lands, text re-lays out. Offline, every later w800 style retries the lookup and the HTTP request | Bundle `Outfit-ExtraBold.ttf`; set `GoogleFonts.config.allowRuntimeFetching = false` in `main()`. Text now shows in Outfit ExtraBold from the first frame, as designed |
| 7 | Chat open/close and waiting are costly | `ai_assistant.dart:92-121, 1364, 1541, 1902` | The panel is built inside the slide's `AnimatedBuilder`, so it rebuilds about 20 times per open. The two loading spinners have no `RepaintBoundary`, so each tick repaints Home, the dock and the panel. The input bar calls `setState` on every keystroke | Pass the panel as `AnimatedBuilder.child`; wrap the spinners in `RepaintBoundary`; rebuild only the send button and counter per keystroke |
| 8 | History builds everything, and again on every keystroke | `history_screen.dart:156-203, 250-253`, `history_query.dart:155-208` | The calendar and all cards sit in one `ListView` child, so nothing is lazy. The results key includes the query, so each keystroke remounts every card, and the search text of every entry is rebuilt | `CustomScrollView` with `SliverList.builder`; cache each entry's search text; keep the key stable |
| 9 | JSON on the UI isolate, every body decoded twice | `core/network/api_client.dart:162-164`, `api_screening_repository.dart:17-23` | `response.body` is a getter that re-decodes the bytes, and it is read twice. `/api/screenings` is unpaged (the backend caps it at 500 sessions) and is parsed during the launch loader animation | Read the body once; decode large lists in `Isolate.run` |
| 10 | Clinics map rebuilt on every visit | `clinics_screen.dart:289, 330`, `clinic_map.dart:75-151, 438-459` | The map is unmounted when the tab hides. Each return creates a new GoogleMap platform view and redraws every pin with `toImage` plus a PNG encode | Cache the pin images by look and DPR. Keeping the hidden map mounted is the bigger fix but needs a device check |

**Further items, lower impact**

- When the launch loader exits, all five tabs build in one frame (`session_loader.dart:425`), together with the records fetch and Home's video start. Fix: mount the active tab first and the rest over the next frames.
- Opacity layers wrap glass cards during entrance fades: clinic cards (`clinics_screen.dart:633`), treatment cards (`treatment_screen.dart:281`, replayed for every card scrolled into view), skeleton pulses, and the dimmed calendar (`history_calendar.dart:73`). Each adds an offscreen pass with a blur inside. Playing the fade once per item is a small behavior change, so it needs your call.
- The dock's bubble has its own `BackdropFilter` outside the shared group (`app_bottom_nav.dart:214`), an extra blur on every frame of every tab. It sits over the dock's already-blurred glass, so removing it is probably invisible, but it is a visual change and needs a screenshot comparison and your OK.
- Scroll pages without a `RepaintBoundary` around their content redraw it all per scroll frame: `home_screen.dart:46`, `profile_screen.dart:310`, `screening_detail_screen.dart:159`, `comparison_screen.dart:70`, `clinics_screen.dart:422`.
- The chat list has keyed items but no `findChildIndexCallback`, so every send shifts indexes and rebuilds each visible bubble from scratch (`ai_assistant.dart:690-719`). The chat's saved sessions are re-encoded on the UI isolate after every reply (`ai_chat_controller.dart:527-544`).
- While the chat covers the screen, the home video keeps playing under its full-height blur. Disabling tickers under an open panel stops that.
- Live camera view: `setState` per frame with no `RepaintBoundary` around it (`live_view.dart:73`, `live_capture_screen.dart:481`).
- Clinics search and the comparison slider call `setState` on the whole screen per keystroke or drag event (`clinics_screen.dart:229`, `image_comparison.dart:125`).
- Mouth3D, the welcome stage and the auth backdrop call `canvas.saveLayer` every frame while animating (`mouth_3d.dart:321`, `welcome_stage.dart:600`, `auth_abstract_backdrop.dart:108`). They pause correctly when hidden; cost is limited to those screens.
- About 550 `GoogleFonts.outfit(...)` calls build a new `TextStyle` inside `build()`, some in list items and one per animation frame (`screening_activity_card.dart:299`). Cheap on its own; moving hot ones to `static final` helps items 3 and 8.
- `GlossPillButton` ticks every frame though the sheen draws only 30% of each loop (`gloss_pill_button.dart:62-70`).
- The local photo check loops over about 200K pixels on the UI isolate (`photo_quality.dart:74-114`), only in demo mode or when analysis is unavailable.

**Startup**

Before the first frame, `main()` awaits `dotenv.load`, calls `fvp.registerWith()` (which also schedules native player setup), and awaits `OnboardingStorage.isCompleted()`. Removing `fvp` takes its work away. `dotenv.load` and the onboarding read can run in parallel. The launch loader correctly waits for the server-confirmed session and user data. The daily tip and SVG precache then run serially after that data, inside a 2.5 s cap, and could start earlier and run in parallel without changing what the user sees.

The Android launch theme is the Flutter template: a white window in light mode, and black in dark mode, before the first mint (`#E8F8F7`) Flutter frame. That's a visible flash. Setting the window background to `#E8F8F7` in `values`, `values-night` and a new `values-v31` (Android 12 splash) removes it without a new package. `flutter_native_splash` isn't needed for a solid color.

**Memory and leaks**

All controllers, focus nodes, tickers, timers and subscriptions on Android paths are disposed. Three small issues:

- `hotspot_setup_controller.dart:89-108` (website-only flow): two overlapping `newCode()` calls orphan a 2 s polling timer.
- `report_download.dart:118-135`: after the 30 s timeout the image listener stays attached.
- `clinics_screen.dart:136`: `_cardKeys` keeps a GlobalKey for every clinic ever shown.

The session photo cache (`screening_sessions_provider.dart:155-169`) keeps up to 18 JPEGs per scan for the whole app run. Capping it is a small behavior change (older scans would load their photos from the network again), so it is listed, not proposed.

**Already done well (leave as is)**

- One `BackdropGroup` per page with a single shared sigma-18 blur, so Impeller reads the backdrop and blurs once per frame. Page glass should stay on that one sigma.
- The ambient backdrop painter sits in a `RepaintBoundary`.
- The home video, Mouth3D, GuideStage, the Rabi mascot and the clinics map already pause or unmount when not visible.
- The camera pipeline: Content-Length MJPEG splitting, one decode in flight, old images disposed, frames delivered via `ValueNotifier`.
- 3D meshes are built with `compute`. Thumbnails decode at display size (`CoverResizeImage`, `cacheWidth`). Phone photos are capped at 2048 px and avatars at 512 px.
- The chat's reversed list keeps the newest message at offset 0 with no per-chunk scrolling, and its typing dots respect reduced motion.
- Records and notifications are paged. Treatments use a lazy list. There is no `shrinkWrap: true` in a scroll view anywhere.
- Impeller is on (no opt-out in the manifest).

## Expected outcome (estimate)

| | Baseline | After proposals |
|---|---|---|
| Split APK, arm64-v8a | 65.8 MB | about 26 MB (about -60%) |
| Native libraries per ABI | 36.3 MB | about 23.5 MB (without `fvp`) |
| Flutter assets | 27.7 MB | about 1.2 MB |

`--obfuscate --split-debug-info` should trim `libapp.so` further. Phase 5 will replace these estimates with measured numbers.

## Phase 2: cleanup (done)

Approved in full. Deleted everything in the 1A deletion table, the three never-read private fields (`ChamberPainter.clock` became a plain constructor argument), the `GlassBarEdge` enum (only `top` was ever used), every unused asset in 1B, and the `video_player` and `fvp` packages. The waving Tooth Bunny now plays `bunny_wave.webp` on every platform. `Image` pauses its frames when `TickerMode` is off or animations are disabled, so the old pause-when-hidden code was no longer needed.

`tool/mascot_rig.py` still documents its 2048 px source render, which now lives only in git history (`git show 774951e:assets/images/treatments/mascot.png`).

`dart fix --apply` had nothing to fix. `dart format lib test` reformatted 130 files. That is in its own commit (`20bab35`), so it can be reverted alone if it gets in the way of other branches. A follow-up commit braces the 7 `if` statements the formatter split over two lines. Analyzer: 0 issues. Tests: 494 passed.

## Phase 3: size (done)

- **Images:** 23 treatment icons converted to 256 px WebP, the Rabi avatar to 384 px WebP, and the 4 treatment photos to 512 px WebP, all at quality 82. All references were updated.
- **Fonts:** added `Outfit-ExtraBold.ttf`. It is byte-identical to the file `google_fonts` downloaded at runtime, verified against the SHA-256 pinned in the package (the bundled Bold file matches its pinned hash too). `GoogleFonts.config.allowRuntimeFetching = false` is now set in `main()`.
- **SVG icons:** the 4 Services icons moved to `assets/images/icons/` and are compiled to vector_graphics format at build time by the `vector_graphics_compiler` transformer. `flutter_svg` was replaced by `vector_graphics` 1.2.3, with `vector_graphics_compiler` 1.3.0 as a dev dependency. Both were already in the lockfile at those versions. The icons are still precached before Home appears.
- **Android:** `androidResources.localeFilters += "en"` (the AGP 9 replacement for `resConfigs`). R8 and resource shrinking are now spelled out in `build.gradle.kts` (the Flutter plugin already enabled them). Added `proguard-rules.pro`. No extra keep rules are needed today, because every plugin ships consumer rules.
- **Icons:** Material icon tree shaking is on (1.6 MB down to 29 KB in the build log).
- **Deferred loading:** not used. On Android, `deferred as` only splits code when the app ships as Play Feature Delivery modules. No feature here is large enough to justify that.

Measured after Phase 3 (AAB and split APKs built with `--obfuscate --split-debug-info=build/symbols`):

| Build | Baseline | After Phase 3 | Change |
|---|---|---|---|
| Split APK, arm64-v8a | 65.8 MB | 23.3 MB | -42.5 MB (-64.6%) |
| Split APK, armeabi-v7a | 60.9 MB | 21.4 MB | -39.5 MB (-64.8%) |
| Split APK, x86_64 | 68.4 MB | 25.0 MB | -43.4 MB (-63.5%) |
| App bundle | 117.5 MB | 62.2 MB | -55.3 MB (-47.1%) |
| APK, arm64 target, size analysis (not obfuscated) | 89.3 MB | 25.2 MB | -64.1 MB (-71.8%) |

Inside the arm64 split APK: `libapp.so` 12.1 to 9.9 MB, the fvp libraries (12.8 MB) are gone, Flutter assets 27.7 to 1.07 MB, `classes.dex` 1.39 to 0.77 MB, and `resources.arsc` 183 to 34 KB.

## Phase 4: smoothness (done)

Everything below keeps the design as it was, except the four items you approved: the reduced dock blur, one-time card fades, the mint launch screen, and precompiled SVGs (Phase 3).

| # (from 1D) | Fix | Files |
|---|---|---|
| 1 | Each tab is wrapped in `TickerMode(enabled: i == _tab)`, so hidden tabs stop animating and the app can go idle. The whole shell also pauses its tickers while the chat panel covers it (the panel slides over everything, so nothing visible stops). | `lib/app/app.dart` |
| 2 | Streamed chunks go into `AiChatController.partialReply`, a `ValueNotifier` that only the pending bubble listens to. Chunks no longer call `notifyListeners()`, so the panel, header, input and saved bubbles stay put while Rabi types. | `ai_chat_controller.dart`, `ai_assistant.dart` |
| 3 | The five tab widgets are created once in the shell's State instead of in every `build()`, so switching tabs no longer rebuilds four tabs. | `lib/app/app.dart` |
| 4 | Images are now stored at the size they're shown (Phase 3). A treatment icon decodes to 256 KB instead of 4 to 6 MB, the avatar to 576 KB instead of 14.7 MB. | assets |
| 5 | Report photos are JPEG-encoded with `compute()` (a background isolate on phones, inline on web where isolates don't exist). Each photo becomes one shared `pw.MemoryImage`, so a photo used for several teeth is embedded once. A load timeout now also detaches its image listener. | `report_download.dart`, `report_pdf.dart` |
| 6 | `Outfit-ExtraBold.ttf` ships and runtime font fetching is off (Phase 3), so w800 text is right from the first frame and never swaps. | `main.dart`, `assets/fonts` |
| 7 | The chat panel is built once per state change and handed to the slide animation as its `child`, inside a `RepaintBoundary`. Both loading spinners sit in their own `RepaintBoundary`. Typing rebuilds only the send button and the character counter (`ValueListenableBuilder` on the text controller). The pill reads `MediaQuery.sizeOf`/`paddingOf` instead of `MediaQuery.of`. The screening suggestion is rebuilt only when the latest screening changes. | `ai_assistant.dart` |
| 7 | Rabi's markdown is parsed once per reply and cached (64 replies, least recently used out). The streaming bubble skips the cache. The line patterns now stop at the first match. | `ai_assistant.dart` |
| 7 | The chat list has a `findChildIndexCallback`, so sending a message moves the built bubbles instead of rebuilding each one. | `ai_assistant.dart` |
| 8 | History search text is built once per screening or record (cached on the immutable objects) instead of for every entry on every keystroke. | `history_query.dart` |
| 9 | API responses read `response.body` once (it decodes the bytes on every read). Bodies over 64 KB, such as the full screening history, are parsed with `compute()`. | `core/network/api_client.dart` |
| 10 | Rendered map pins are cached for the app's lifetime, keyed by pixel ratio, so returning to Clinics doesn't redraw every pin. | `clinic_map.dart` |
| Further | `RepaintBoundary` around the scroll content of Home, Profile, screening detail, comparison and the clinic list, and around the live camera picture. | 6 files |
| Further | Dock bubble blur reduced from sigma 8 to 4 as approved; the frosted tint and border are unchanged. The filter is now one shared object instead of a new one per build. | `app_bottom_nav.dart` |
| Further | Treatment cards fade in once per screen visit instead of every time they scroll back into view. | `treatment_screen.dart` |
| Startup | `.env` and the onboarding flag load in parallel. `fvp` setup is gone from `main()`. | `main.dart` |
| Startup | The Android launch window is the app's mint (`#E8F8F7`) in light and dark mode, including the Android 12+ system splash (`values-v31`, `values-night-v31`). No white or black flash, no new package. | `android/app/src/main/res` |
| Leaks | The pairing-code poll can no longer be orphaned by two overlapping requests (website flow). Clinic card keys are pruned to the clinics on screen. | `hotspot_setup_controller.dart`, `clinics_screen.dart` |
| Lints | `prefer_const_constructors`, `prefer_const_literals_to_create_immutables` and `prefer_const_declarations` are now listed in `analysis_options.yaml`. They were already on through `flutter_lints`, and the code already passed them. | `analysis_options.yaml` |

**Not changed, and why**

- **History list:** it still builds every card in one `ListView` child, and the results key still includes the query. Making it lazy and keeping the key stable would drop the cross-fade that plays when the results change while typing. That is a visible change you didn't approve. The search-text cache removes the heaviest part of each keystroke.
- **Mounting tabs one at a time after the loader:** deferred. The tabs no longer rebuild or animate while hidden, so the remaining cost is a single frame at the end of the loader's fade. Profile it first (Phase 5 checklist).
- **Opacity over glass** on the History calendar's dimmed state and on skeleton pulses: removing these layers would change how they look.
- **`GoogleFonts.outfit(...)` in `build()`** (about 550 call sites): each call is cheap. With the rebuild fixes above, they run far less often. Converting them all to `static final` styles is a large, mechanical change for a small gain.
- **Per-frame `saveLayer`** in Mouth3D, the welcome stage and the auth backdrop: needed for their look, and they already stop when hidden.
- **The chat's saved-session JSON** is still encoded on the UI isolate after each reply. It applies only to chats saved on the device (demo mode), and stays small.
- **Photo quality check pixel loops:** only used in demo mode or when the server analysis is unavailable.
- **The session photo cache** keeps photos for the whole run. Capping it would make older scans reload their photos from the network.
- **Impeller:** on by default for Android in Flutter 3.47, with no opt-out in the manifest. Nothing to change.

Tests: 494 passed. Analyzer: 0 issues.
