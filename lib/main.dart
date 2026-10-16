import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'app/app.dart';
import 'features/onboarding/services/onboarding_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env'); // load GEMINI_API_KEY
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
  runApp(
    ProviderScope(
      child: DentraApp(onboardingCompleted: onboardingCompleted),
    ),
  );
}
