import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/core/network/api_client.dart';

final trainerRepositoryProvider = Provider<TrainerRepository>((ref) {
  return TrainerRepository(dio: ref.watch(apiClientProvider));
});

class TrainerProfile {
  TrainerProfile({
    required this.aboutMe,
    required this.contacts,
    required this.createdAt,
    required this.updatedAt,
  });
  final String aboutMe;
  final String contacts;
  final String createdAt;
  final String updatedAt;
  static TrainerProfile fromJson(Map<String, dynamic> json) => TrainerProfile(
        aboutMe: json['about_me'] as String? ?? '',
        contacts: json['contacts'] as String? ?? '',
        createdAt: json['created_at'] as String? ?? '',
        updatedAt: json['updated_at'] as String? ?? '',
      );
}

class TrainerPhoto {
  TrainerPhoto({required this.id, required this.url, required this.position, required this.createdAt});
  final String id;
  final String url;
  final int position;
  final String createdAt;
  static TrainerPhoto fromJson(Map<String, dynamic> json) => TrainerPhoto(
        id: json['id'] as String,
        url: json['url'] as String,
        position: json['position'] as int? ?? 0,
        createdAt: json['created_at'] as String? ?? '',
      );
}

class TraineeItem {
  TraineeItem({
    required this.id,
    required this.clientId,
    required this.trainerId,
    this.displayName,
    this.city,
    required this.status,
    required this.createdAt,
  });
  final String id;
  final String clientId;
  final String trainerId;
  final String? displayName;
  final String? city;
  final String status;
  final String createdAt;
  static TraineeItem fromJson(Map<String, dynamic> json) => TraineeItem(
        id: json['id'] as String? ?? '',
        clientId: json['client_id'] as String? ?? '',
        trainerId: json['trainer_id'] as String? ?? '',
        displayName: json['display_name'] as String?,
        city: json['city'] as String?,
        status: json['status'] as String? ?? 'active',
        createdAt: json['created_at'] as String? ?? '',
      );
}

class MyTrainerItem {
  MyTrainerItem({
    required this.trainerId,
    this.displayName,
    this.city,
    required this.status,
    required this.createdAt,
  });
  final String trainerId;
  final String? displayName;
  final String? city;
  final String status;
  final String createdAt;
  static MyTrainerItem fromJson(Map<String, dynamic> json) => MyTrainerItem(
        trainerId: json['trainer_id'] as String? ?? '',
        displayName: json['display_name'] as String?,
        city: json['city'] as String?,
        status: json['status'] as String? ?? 'active',
        createdAt: json['created_at'] as String? ?? '',
      );
}

class TrainerSearchItem {
  TrainerSearchItem({required this.id, required this.displayName, required this.city});
  final String id;
  final String displayName;
  final String city;
  static TrainerSearchItem fromJson(Map<String, dynamic> json) => TrainerSearchItem(
        id: json['id'] as String,
        displayName: json['display_name'] as String? ?? '',
        city: json['city'] as String? ?? '',
      );
}

/// Public trainer profile (GET /api/v1/trainers/:user_id, no auth).
class TrainerPublicProfile {
  TrainerPublicProfile({
    required this.userId,
    required this.displayName,
    required this.city,
    required this.avatarUrl,
    required this.aboutMe,
    required this.contacts,
    required this.profileLink,
    required this.photos,
    required this.traineesCount,
    required this.workoutsCount,
    this.rating,
    required this.gyms,
  });
  final String userId;
  final String displayName;
  final String city;
  final String avatarUrl;
  final String aboutMe;
  final String contacts;
  final String profileLink;
  final List<TrainerPhoto> photos;
  final int traineesCount;
  final int workoutsCount;
  final double? rating;
  final List<TrainerPublicGym> gyms;

  static TrainerPublicProfile fromJson(Map<String, dynamic> json) {
    final photosList = json['photos'] as List<dynamic>? ?? [];
    final gymsList = json['gyms'] as List<dynamic>? ?? [];
    return TrainerPublicProfile(
      userId: json['user_id'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      city: json['city'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String? ?? '',
      aboutMe: json['about_me'] as String? ?? '',
      contacts: json['contacts'] as String? ?? '',
      profileLink: json['profile_link'] as String? ?? '',
      photos: photosList.map((e) => TrainerPhoto.fromJson(e as Map<String, dynamic>)).toList(),
      traineesCount: json['trainees_count'] as int? ?? 0,
      workoutsCount: json['workouts_count'] as int? ?? 0,
      rating: (json['rating'] as num?)?.toDouble(),
      gyms: gymsList.map((e) => TrainerPublicGym.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class TrainerPublicGym {
  TrainerPublicGym({required this.id, required this.name, this.city});
  final String id;
  final String name;
  final String? city;
  static TrainerPublicGym fromJson(Map<String, dynamic> json) => TrainerPublicGym(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        city: json['city'] as String?,
      );
}

class ClientProfileGym {
  ClientProfileGym({required this.id, required this.name, this.city});
  final String id;
  final String name;
  final String? city;
  static ClientProfileGym fromJson(Map<String, dynamic> json) => ClientProfileGym(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        city: json['city'] as String?,
      );
}

class ClientProfileMeasurement {
  ClientProfileMeasurement({
    required this.id,
    required this.recordedAt,
    required this.weightKg,
    this.bodyFatPct,
    this.heightCm,
  });
  final String id;
  final String recordedAt;
  final double weightKg;
  final double? bodyFatPct;
  final double? heightCm;

  static ClientProfileMeasurement fromJson(Map<String, dynamic> json) => ClientProfileMeasurement(
        id: json['id'] as String? ?? '',
        recordedAt: json['recorded_at'] as String? ?? '',
        weightKg: (json['weight_kg'] as num?)?.toDouble() ?? 0,
        bodyFatPct: (json['body_fat_pct'] as num?)?.toDouble(),
        heightCm: (json['height_cm'] as num?)?.toDouble(),
      );
}

class ClientProfileWorkout {
  ClientProfileWorkout({
    required this.id,
    required this.userId,
    this.templateId,
    this.scheduledAt,
    this.startedAt,
    this.finishedAt,
    required this.createdAt,
    this.volumeKg,
  });
  final String id;
  final String userId;
  final String? templateId;
  final String? scheduledAt;
  final String? startedAt;
  final String? finishedAt;
  final String createdAt;
  final double? volumeKg;

  bool get isActive => startedAt != null && finishedAt == null;
  bool get isCompleted => finishedAt != null;

  static ClientProfileWorkout fromJson(Map<String, dynamic> json) => ClientProfileWorkout(
        id: json['id'] as String? ?? '',
        userId: json['user_id'] as String? ?? '',
        templateId: json['template_id'] as String?,
        scheduledAt: json['scheduled_at'] as String?,
        startedAt: json['started_at'] as String?,
        finishedAt: json['finished_at'] as String?,
        createdAt: json['created_at'] as String? ?? '',
        volumeKg: (json['volume_kg'] as num?)?.toDouble(),
      );
}

class ClientProfileData {
  ClientProfileData({
    required this.clientId,
    this.displayName,
    this.city,
    this.avatarUrl,
    this.heightCm,
    this.weightKg,
    this.bodyFatPct,
    this.measurements = const [],
    this.gyms = const [],
    this.workouts = const [],
  });
  final String clientId;
  final String? displayName;
  final String? city;
  final String? avatarUrl;
  final double? heightCm;
  final double? weightKg;
  final double? bodyFatPct;
  final List<ClientProfileMeasurement> measurements;
  final List<ClientProfileGym> gyms;
  final List<ClientProfileWorkout> workouts;

  static ClientProfileData fromJson(Map<String, dynamic> json) {
    final measurementsList = json['measurements'] as List<dynamic>? ?? [];
    final gymsList = json['gyms'] as List<dynamic>? ?? [];
    final workoutsList = json['workouts'] as List<dynamic>? ?? [];
    return ClientProfileData(
      clientId: json['client_id'] as String? ?? '',
      displayName: json['display_name'] as String?,
      city: json['city'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      heightCm: (json['height_cm'] as num?)?.toDouble(),
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      bodyFatPct: (json['body_fat_pct'] as num?)?.toDouble(),
      measurements: measurementsList.map((e) => ClientProfileMeasurement.fromJson(e as Map<String, dynamic>)).toList(),
      gyms: gymsList.map((e) => ClientProfileGym.fromJson(e as Map<String, dynamic>)).toList(),
      workouts: workoutsList.map((e) => ClientProfileWorkout.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class ClientExerciseVolumeEntry {
  ClientExerciseVolumeEntry({required this.workoutId, required this.workoutDate, required this.volumeKg});
  final String workoutId;
  final String workoutDate;
  final double volumeKg;
  static ClientExerciseVolumeEntry fromJson(Map<String, dynamic> json) => ClientExerciseVolumeEntry(
        workoutId: json['workout_id'] as String? ?? '',
        workoutDate: json['workout_date'] as String? ?? '',
        volumeKg: (json['volume_kg'] as num?)?.toDouble() ?? 0,
      );
}

class TrainerRepository {
  TrainerRepository({required this.dio});
  final Dio dio;

  /// GET /me/trainer/profile — 404 if not a trainer
  Future<TrainerProfile?> getMyTrainerProfile() async {
    try {
      final res = await dio.get<Map<String, dynamic>>('/api/v1/me/trainer/profile');
      return TrainerProfile.fromJson(res.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<TrainerProfile> updateMyTrainerProfile({required String aboutMe, required String contacts}) async {
    final res = await dio.put<Map<String, dynamic>>(
      '/api/v1/me/trainer/profile',
      data: {'about_me': aboutMe, 'contacts': contacts},
    );
    return TrainerProfile.fromJson(res.data!);
  }

  Future<List<TrainerPhoto>> listMyTrainerPhotos() async {
    final res = await dio.get<Map<String, dynamic>>('/api/v1/me/trainer/photos');
    final list = res.data?['photos'] as List<dynamic>? ?? [];
    return list.map((e) => TrainerPhoto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<TrainerPhoto> uploadTrainerPhoto(FormData formData) async {
    final res = await dio.post<Map<String, dynamic>>('/api/v1/me/trainer/photos', data: formData);
    return TrainerPhoto.fromJson(res.data!);
  }

  Future<void> deleteTrainerPhoto(String photoId) async {
    await dio.delete('/api/v1/me/trainer/photos/$photoId');
  }

  Future<List<TraineeItem>> listMyTrainees() async {
    final res = await dio.get<Map<String, dynamic>>('/api/v1/me/trainer/clients');
    final list = res.data?['clients'] as List<dynamic>? ?? [];
    return list.map((e) => TraineeItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// DELETE /me/trainer/clients/:client_id — remove trainee from list.
  Future<void> removeTrainee(String clientId) async {
    await dio.delete('/api/v1/me/trainer/clients/$clientId');
  }

  Future<List<dynamic>> listMyTrainerWorkouts({int limit = 20, int offset = 0}) async {
    final res = await dio.get<Map<String, dynamic>>(
      '/api/v1/me/trainer/workouts',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    return res.data?['workouts'] as List<dynamic>? ?? [];
  }

  Future<List<MyTrainerItem>> listMyTrainers() async {
    final res = await dio.get<Map<String, dynamic>>('/api/v1/me/trainers');
    final list = res.data?['trainers'] as List<dynamic>? ?? [];
    return list.map((e) => MyTrainerItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<TrainerSearchItem>> searchTrainers(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return [];
    final res = await dio.get<Map<String, dynamic>>(
      '/api/v1/trainers',
      queryParameters: {'q': query, 'limit': limit},
    );
    final list = res.data?['trainers'] as List<dynamic>? ?? [];
    return list.map((e) => TrainerSearchItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> addMyTrainer(String trainerId) async {
    await dio.post<Map<String, dynamic>>('/api/v1/me/trainers', data: {'trainer_id': trainerId});
  }

  Future<void> removeMyTrainer(String trainerId) async {
    await dio.delete('/api/v1/me/trainers/$trainerId');
  }

  /// GET /me/trainer/clients/:client_id/profile — full client profile for trainer.
  Future<ClientProfileData> getClientProfile(String clientId) async {
    final res = await dio.get<Map<String, dynamic>>('/api/v1/me/trainer/clients/$clientId/profile');
    return ClientProfileData.fromJson(res.data!);
  }

  /// GET /me/trainer/clients/:client_id/progress/exercise-ids
  Future<List<String>> getClientExerciseIDs(String clientId) async {
    final res = await dio.get<Map<String, dynamic>>(
      '/api/v1/me/trainer/clients/$clientId/progress/exercise-ids',
    );
    final list = res.data?['exercise_ids'] as List<dynamic>? ?? [];
    return list.map((e) => e.toString()).toList();
  }

  /// GET /me/trainer/clients/:client_id/progress/exercises/:exerciseId/volume-history
  Future<List<ClientExerciseVolumeEntry>> getClientExerciseVolumeHistory(String clientId, String exerciseId) async {
    final res = await dio.get<Map<String, dynamic>>(
      '/api/v1/me/trainer/clients/$clientId/progress/exercises/$exerciseId/volume-history',
    );
    final list = res.data?['history'] as List<dynamic>? ?? [];
    return list.map((e) => ClientExerciseVolumeEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// GET /api/v1/trainers/:user_id — public, no auth.
  Future<TrainerPublicProfile> getTrainerPublicProfile(String userId) async {
    final res = await dio.get<Map<String, dynamic>>('/api/v1/trainers/$userId');
    return TrainerPublicProfile.fromJson(res.data!);
  }
}
