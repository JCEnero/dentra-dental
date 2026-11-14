import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'app/app.dart';
import 'features/onboarding/services/onboarding_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env'); // GEMINI_API_KEY, API_BASE_URL, ...
  fvp.registerWith(); // enables VP9-alpha / transparent WebM via fvp
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  // Read before the first frame so returning users never see a flash of
  // onboarding.
  final onboardingCompleted = await OnboardingStorage.isCompleted();
  // The session is restored by the launch loader, not here: the first
  // frame never waits on the network, and the loader only lets a user in
  // once the server has confirmed the session and their data is loaded.
  runApp(
    ProviderScope(
      child: DentraApp(onboardingCompleted: onboardingCompleted),
    ),
  );
}
