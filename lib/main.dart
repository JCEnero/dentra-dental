import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app/app.dart';
import 'features/onboarding/services/onboarding_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Every Outfit weight the app uses ships in assets/fonts, so never fetch
  // fonts from the network: a missing weight would otherwise show in the
  // system font until the download landed, then swap.
  GoogleFonts.config.allowRuntimeFetching = false;
  // Config and the onboarding flag are independent, so read them together.
  // The flag is read before the first frame so returning users never see
  // a flash of onboarding.
  final (_, onboardingCompleted) = await (
    dotenv.load(fileName: '.env'), // API_BASE_URL, MAPS_API_KEY, ...
    OnboardingStorage.isCompleted(),
  ).wait;
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
  // The session is restored by the launch loader, not here: the first
  // frame never waits on the network, and the loader only lets a user in
  // once the server has confirmed the session and their data is loaded.
  runApp(
    ProviderScope(
      child: DentraApp(onboardingCompleted: onboardingCompleted),
    ),
  );
}
