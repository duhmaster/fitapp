import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/features/auth/data/auth_repository.dart';
import 'package:fitflow/features/auth/domain/auth_models.dart';

/// True when we have a valid stored token (checked at app start / after login).
final isLoggedInProvider = FutureProvider<bool>((ref) {
  return ref.watch(authRepositoryProvider).isLoggedIn();
});

/// Call from login/register screens to perform login.
final loginProvider = Provider<Future<AuthResponse> Function(LoginRequest)>((ref) {
  return (LoginRequest req) => ref.read(authRepositoryProvider).login(req);
});

/// Call from register screen to perform registration.
final registerProvider = Provider<Future<AuthResponse> Function(RegisterRequest)>((ref) {
  return (RegisterRequest req) => ref.read(authRepositoryProvider).register(req);
});

/// Call to logout and clear tokens.
final logoutProvider = Provider<Future<void> Function()>((ref) {
  return () => ref.read(authRepositoryProvider).logout();
});
