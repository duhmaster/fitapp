import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/features/auth/data/auth_repository.dart';
import 'package:fitflow/features/auth/domain/auth_models.dart';
import 'package:fitflow/features/profile/data/profile_repository.dart';
import 'package:fitflow/features/profile/domain/profile_models.dart';

final currentUserProvider = FutureProvider<CurrentUser>((ref) {
  return ref.watch(authRepositoryProvider).getMe();
});

final profileProvider = FutureProvider<Profile>((ref) {
  return ref.watch(profileRepositoryProvider).getProfile();
});

/// Combined profile page data: profile + email + latest height, weight, body fat.
final profilePageDataProvider = FutureProvider<ProfilePageData>((ref) async {
  final profileRepo = ref.watch(profileRepositoryProvider);
  final authRepo = ref.watch(authRepositoryProvider);
  final profile = await profileRepo.getProfile();
  final me = await authRepo.getMe();
  final metric = await profileRepo.getLatestMetric();
  final bodyFat = await profileRepo.getLatestBodyFat();
  return ProfilePageData(
    displayName: profile.displayName,
    avatarUrl: profile.avatarUrl,
    email: me.email,
    heightCm: metric['height_cm'],
    weightKg: metric['weight_kg'],
    bodyFatPct: bodyFat,
  );
});
