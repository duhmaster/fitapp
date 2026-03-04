import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/features/profile/data/profile_repository.dart';
import 'package:fitflow/features/profile/domain/profile_models.dart';

final profileProvider = FutureProvider<Profile>((ref) {
  return ref.watch(profileRepositoryProvider).getProfile();
});
