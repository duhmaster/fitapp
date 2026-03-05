import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/features/auth/data/auth_repository.dart';
import 'package:fitflow/features/auth/domain/auth_models.dart';

/// Notifier used by GoRouter refreshListenable so redirect re-runs when auth is known.
/// Avoids blocking the first frame on isLoggedIn() (e.g. SharedPreferences).
class AuthRedirectNotifier extends ChangeNotifier {
  AuthRedirectNotifier(this._ref);
  final Ref _ref;

  bool? _isLoggedIn;
  bool get isLoggedIn => _isLoggedIn ?? false;
  bool get isKnown => _isLoggedIn != null;

  bool _checkStarted = false;
  Future<void> check() async {
    if (_checkStarted) return;
    _checkStarted = true;
    try {
      _isLoggedIn = await _ref.read(authRepositoryProvider).isLoggedIn();
    } catch (_) {
      _isLoggedIn = false;
    }
    _checkStarted = false;
    notifyListeners();
  }

  /// Call after login/register so redirect sees the new auth state.
  void setLoggedIn(bool value) {
    _isLoggedIn = value;
    notifyListeners();
  }
}

final authRedirectNotifierProvider =
    ChangeNotifierProvider<AuthRedirectNotifier>((ref) => AuthRedirectNotifier(ref));

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
