import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'setup_sound_native.dart'
    if (dart.library.js_interop) 'setup_sound_web.dart' as backend;
import 'setup_sound_contract.dart';
export 'setup_sound_contract.dart';

final setupSoundFactoryProvider =
    Provider<SetupSound Function()>((ref) => backend.createSetupSound);
