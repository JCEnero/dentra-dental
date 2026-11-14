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
