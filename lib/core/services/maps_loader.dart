// Makes sure the Google Maps SDK is ready before a `GoogleMap` is built.
//
// Android and iOS configure their key natively, so there is nothing to do.
// On web the Maps JavaScript API must be on the page first; it's injected
// at runtime with the key from `.env`, so the key never lives in
// `web/index.html`.
export 'maps_loader_stub.dart' if (dart.library.js_interop) 'maps_loader_web.dart';
