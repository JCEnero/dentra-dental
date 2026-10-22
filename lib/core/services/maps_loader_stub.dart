import 'package:flutter/foundation.dart';

/// Native SDKs don't report key rejections to the app, so this stays false.
final ValueNotifier<bool> mapsAuthFailed = ValueNotifier(false);

/// Native platforms load the Maps SDK themselves.
Future<void> ensureMapsLoaded() async {}
