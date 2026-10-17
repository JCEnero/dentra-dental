import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'app/app.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/services/auth_service.dart';
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
  // Signed-in users skip the login screen. Capped so a slow or offline
  // server never holds up launch; they just see login instead.
  final auth = AuthService.fromEnvironment();
  final signedIn = await auth
      .restoreSession()
      .timeout(const Duration(seconds: 4), onTimeout: () => false);
  runApp(
    ProviderScope(
      overrides: [authServiceProvider.overrideWith((ref) => auth)],
      child: DentraApp(
        onboardingCompleted: onboardingCompleted,
        signedIn: signedIn,
      ),
    ),
  );
}
