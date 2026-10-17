import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void>? _loading;

/// Injects the Maps JavaScript API once and completes when it's ready.
/// Throws if the key is missing or the script fails to load.
Future<void> ensureMapsLoaded() => _loading ??= _load().catchError((Object e) {
      _loading = null; // allow a retry
      throw e;
    });

Future<void> _load() async {
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
