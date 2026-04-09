import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/features/auth/data/auth_repository.dart';
import 'package:fitflow/features/auth/domain/auth_models.dart';
import 'package:fitflow/features/calendar/calendar_provider.dart';
import 'package:fitflow/features/gym/gym_screen.dart';
import 'package:fitflow/features/profile/presentation/profile_provider.dart';
import 'package:fitflow/features/progress/presentation/progress_exercises_screen.dart';
import 'package:fitflow/features/progress/presentation/progress_provider.dart';
import 'package:fitflow/features/templates/templates_provider.dart';
import 'package:fitflow/features/trainer/trainer_providers.dart';
import 'package:fitflow/features/trainer/trainer_trainees_screen.dart';
import 'package:fitflow/features/feed/feed_provider.dart';
import 'package:fitflow/features/gamification/presentation/gamification_provider.dart';
import 'package:fitflow/features/workouts/presentation/workouts_provider.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/core/theme/theme_provider.dart';

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
    ChangeNotifierProvider<AuthRedirectNotifier>(
        (ref) => AuthRedirectNotifier(ref));

/// True when we have a valid stored token (checked at app start / after login).
final isLoggedInProvider = FutureProvider<bool>((ref) {
  return ref.watch(authRepositoryProvider).isLoggedIn();
});

/// Call from login/register screens to perform login.
final loginProvider =
    Provider<Future<AuthResponse> Function(LoginRequest)>((ref) {
  return (LoginRequest req) => ref.read(authRepositoryProvider).login(req);
});

/// Call from register screen to perform registration.
final registerProvider =
    Provider<Future<AuthResponse> Function(RegisterRequest)>((ref) {
  return (RegisterRequest req) =>
      ref.read(authRepositoryProvider).register(req);
});

/// Call to logout and clear tokens.
final logoutProvider = Provider<Future<void> Function()>((ref) {
  return () => ref.read(authRepositoryProvider).logout();
});

void _invalidateAny(Object ref, ProviderOrFamily provider) {
  if (ref is Ref) {
    try {
      ref.invalidate(provider);
    } catch (_) {}
    return;
  }
  if (ref is WidgetRef) {
    try {
      ref.invalidate(provider);
    } catch (_) {}
    return;
  }
  throw StateError('Unsupported ref type: ${ref.runtimeType}');
}

/// Invalidates all user-scoped providers so cached data from the previous user is not shown.
void invalidateUserScopedProviders(Object ref) {
  _invalidateAny(ref, isLoggedInProvider);
  _invalidateAny(ref, workoutsListProvider);
  _invalidateAny(ref, workoutsCalendarProvider);
  _invalidateAny(ref, exercisesListProvider);
  _invalidateAny(ref, workoutDetailProvider);
  _invalidateAny(ref, currentUserProvider);
  _invalidateAny(ref, profileProvider);
  _invalidateAny(ref, profilePageDataProvider);
  _invalidateAny(ref, bodyMeasurementsProvider);
  _invalidateAny(ref, templatesListProvider);
  _invalidateAny(ref, workoutsCalendarCombinedProvider);
  _invalidateAny(ref, weightHistoryProvider);
  _invalidateAny(ref, bodyFatHistoryProvider);
  _invalidateAny(ref, progressExerciseIdsProvider);
  _invalidateAny(ref, exerciseVolumeHistoryProvider);
  _invalidateAny(ref, trainerProfileProvider);
  _invalidateAny(ref, isTrainerProvider);
  _invalidateAny(ref, myTrainerPublicProfileProvider);
  _invalidateAny(ref, myTrainersListProvider);
  _invalidateAny(ref, traineesListProvider);
  _invalidateAny(ref, myGymsProvider);
  _invalidateAny(ref, mePreferencesInitProvider);
  _invalidateAny(ref, selectedLocaleCodeInitProvider);
  _invalidateAny(ref, localeStringsProvider);
  _invalidateAny(ref, gamificationFeatureFlagsProvider);
  _invalidateAny(ref, gamificationProfileProvider);
  _invalidateAny(ref, gamificationXpHistoryProvider);
  _invalidateAny(ref, gamificationHomeMissionProvider);
  _invalidateAny(ref, gamificationLeaderboardMiniProvider);
  _invalidateAny(ref, gamificationBadgeWallProvider);
  _invalidateAny(ref, gamificationMissionsFullProvider);
  _invalidateAny(ref, gamificationLeaderboardFullProvider);
  _invalidateAny(ref, trainerClientsLeaderboardProvider);
  _invalidateAny(ref, feedListProvider);
}
