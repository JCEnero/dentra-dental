import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';

/// App-wide auth session shared by the sign-in and sign-up screens.
/// Riverpod disposes the service with the ProviderScope.
final authServiceProvider =
    ChangeNotifierProvider<AuthService>((ref) => AuthService());
