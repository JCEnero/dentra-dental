import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Set on `window` when Google rejects the key. The Maps script stays
/// loaded across hot restarts, so the flag has to outlive the Dart app.
const String _authFailedFlag = '__dentraMapsAuthFailed';

/// True once Google rejects the Maps key (API not enabled, referrer not
/// allowed, billing off). Maps should show a placeholder instead.
final ValueNotifier<bool> mapsAuthFailed = ValueNotifier(false);

Future<void>? _loading;

/// Injects the Maps JavaScript API once and completes when it's ready.
/// Throws if the key is missing, was rejected, or the script fails to load.
Future<void> ensureMapsLoaded() => _loading ??= _load().catchError((Object e) {
      _loading = null; // allow a retry
      throw e;
    });

Future<void> _load() async {
  // Google calls this global when the key is rejected. Registered on
  // every run so the callback reaches the current app, not a stale one.
  globalContext['gm_authFailure'] = (() {
    globalContext[_authFailedFlag] = true.toJS;
    mapsAuthFailed.value = true;
  }).toJS;

  // A map built after a rejection breaks inside the Maps script, so stop
  // here until the page is reloaded with a working key.
  if (globalContext.has(_authFailedFlag)) {
    mapsAuthFailed.value = true;
    throw StateError('Google rejected MAPS_API_KEY');
  }

  final google = globalContext['google'] as JSObject?;
  if (google != null && google.has('maps')) return;

  final key = dotenv.maybeGet('MAPS_API_KEY') ?? '';
  if (key.isEmpty) {
    throw StateError('MAPS_API_KEY is missing from .env');
  }

  final done = Completer<void>();
  final document = globalContext['document']! as JSObject;
  final script =
      document.callMethod<JSObject>('createElement'.toJS, 'script'.toJS);
  script['src'] = 'https://maps.googleapis.com/maps/api/js'
          '?key=${Uri.encodeQueryComponent(key)}'
      .toJS;
  script['async'] = true.toJS;
  script['onload'] = (() => done.complete()).toJS;
  script['onerror'] =
      ((JSAny _) => done.completeError(StateError('Maps script failed'))).toJS;
  (document['head']! as JSObject).callMethod('appendChild'.toJS, script);

  await done.future;
}
