# Dentra

## Simple camera Wi-Fi setup

Connect Camera shows one connection card on the website and app. Wi-Fi
credentials are entered on the camera’s own glass setup page. Safari and
other phone browsers do not need to make local requests from the HTTPS app.

1. Power on a Dentra Cam running **firmware 2.2.0 or later**. For a camera
   already configured, hold BOOT for five seconds to reset Wi-Fi and linking.
2. For account live view, open Connect Camera while online and copy the
   six-character account code. Wi-Fi-only setup can start directly in Settings.
3. In phone Wi-Fi settings, join **Dentra Cam XXXX**. No hotspot password
   is needed. Stay connected if prompted about no internet. The camera advertises captive DNS and redirects phone
   connectivity probes to its setup page.
4. Complete the page that opens. If the phone does not open it, visit
   **http://192.168.4.1/** in Safari or another browser while on Dentra Wi-Fi.
   Choose the home 2.4 GHz network, or enter its exact name if hidden. Enter
   the Wi-Fi password. Paste the account code into the visible Account code
   field to enable account live view. No app Wi-Fi wizard is required.
5. On confirmed Wi-Fi success, the camera saves credentials and closes the
   hotspot after 15 seconds. Rejoin home Wi-Fi and return to Dentra; account
   linking is confirmed through the backend. The portal does not call a lost
   connection success. Failed passwords keep the form available for retry.

The portal bundles all styles, scripts and the original Dentra logo in firmware
and needs no internet or external fonts. Regenerate the embedded logo after
changing the app asset with `python3 firmware/tools/embed_portal_logo.py`. It
includes password visibility, open-network handling, network rescanning, hidden
networks and recovery after an interrupted reply.
The setup hotspot is intentionally open (no WPA2 encryption). Credentials are
sent directly to the camera, not posted to the account API or stored in browser
storage. Both
legacy `/setup/join` and portal `/join` require the per-boot setup token.
Older in-app setup screens remain for earlier firmware; they require the old
protected hotspot and are not the current entry route. The current guide uses
the camera’s real 3D mesh, floating motion, gentle page transitions, one glass
card and collapsible help. Reduced motion disables the decorative animation.

Without a configured account API, the native app can save a local camera:
after portal setup, return to home Wi-Fi and use the camera IP displayed on
the portal success page under “Use camera on home Wi-Fi”. Dentra checks the
camera identity and readiness before saving it.

### Build and verification

```sh
/opt/arduino-ide/resources/app/lib/backend/resources/arduino-cli compile \
  --fqbn 'esp32:esp32:esp32s3:PSRAM=opi,PartitionScheme=huge_app,CDCOnBoot=cdc' \
  firmware/dentra_cam
cd dentra_mobile
flutter analyze --no-pub
flutter test --no-pub test/camera
flutter test --no-pub tool/capture_captive_setup_screenshots_test.dart
flutter build web --release --no-pub
```

The portal browser checks use `firmware/tests/check_portal.cjs` with Playwright
available on `NODE_PATH` and `DENTRA_CHROMIUM` pointing at an installed browser.
They exercise the actual firmware HTML with mocked device endpoints; they do
not verify Wi-Fi radio behavior or OS captive-page detection.

The previous per-unit setup key is no longer used to join the hotspot. Device
identity and existing NVS values are preserved. Keep flash backups private. Build commands do not flash hardware. Existing 2.0.0
release binaries still contain the earlier in-app-only behavior. New release
files are `../firmware/releases/dentra_cam-2.2.0-app.bin` and
`../firmware/releases/dentra_cam-2.2.0-merged.bin`, with hashes in
`../firmware/releases/SHA256SUMS`. Flash the new firmware before using captive
setup. For an existing camera,
update only the application at `0x10000` with a matching partition layout to
retain NVS and device identity. Website changes also need a separate deployment.

Physical iPhone/Android tests must still verify automatic portal opening,
password-free joining, radio channel changes, wrong-password recovery,
hotspot teardown, account claiming, camera capture, power-cycle reconnect and
BOOT reset. iOS signing and builds require macOS/Xcode.

## Legacy QR support

Optical screens, protocol checks and old factory tooling are retained for
existing deployments. They are no longer the default entry route. The
legacy 32-character QR key remains separate from the retired hotspot key.
See [legacy factory tooling](../firmware/tools/README.md).
