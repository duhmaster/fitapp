import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fitflow/core/network/api_client.dart';
import 'package:fitflow/features/group_trainings/domain/group_training_models.dart';

final groupTrainingsRepositoryProvider = Provider<GroupTrainingsRepository>((ref) {
  return GroupTrainingsRepository(dio: ref.watch(apiClientProvider));
});

class GroupTrainingsRepository {
  GroupTrainingsRepository({required this.dio});
  final Dio dio;

  Future<List<GroupTrainingType>> listTypes() async {
    final res = await dio.get<Map<String, dynamic>>('/api/v1/me/group-training-types');
    final list = res.data?['types'] as List<dynamic>? ?? const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map((e) => GroupTrainingType.fromJson(e))
        .toList();
  }

  Future<List<GroupTrainingBookingItem>> listAvailable({
    String? city,
    String? gymId,
    String? trainerUserId,
    String? groupTypeId,
    DateTime? dateFrom,
    DateTime? dateTo,
    int limit = 50,
    int offset = 0,
  }) async {
    final params = <String, dynamic>{
      'limit': limit,
      'offset': offset,
      if (city != null && city.isNotEmpty) 'city': city,
      if (gymId != null && gymId.isNotEmpty) 'gym_id': gymId,
      if (trainerUserId != null && trainerUserId.isNotEmpty) 'trainer_user_id': trainerUserId,
      if (groupTypeId != null && groupTypeId.isNotEmpty) 'group_type_id': groupTypeId,
      if (dateFrom != null) 'date_from': dateFrom.toUtc().toIso8601String(),
      if (dateTo != null) 'date_to': dateTo.toUtc().toIso8601String(),
    };

    final res = await dio.get<Map<String, dynamic>>(
      '/api/v1/me/group-trainings/available',
      queryParameters: params,
    );
    final list = res.data?['available'] as List<dynamic>? ?? const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map((e) => GroupTrainingBookingItem.fromJson(e))
        .toList();
  }

  Future<List<GroupTraining>> listMy({
    required bool includePast,
    int limit = 50,
    int offset = 0,
  }) async {
    final res = await dio.get<Map<String, dynamic>>(
      '/api/v1/me/group-trainings',
      queryParameters: {
        'includePast': includePast ? 1 : 0,
        'limit': limit,
        'offset': offset,
      },
    );
    final list = res.data?['trainings'] as List<dynamic>? ?? const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map((e) => GroupTraining.fromJson(e))
        .toList();
  }

  Future<GroupTrainingDetail> getMyTrainingDetail(String trainingId) async {
    final res = await dio.get<Map<String, dynamic>>('/api/v1/me/group-trainings/$trainingId');
    final data = res.data;
    if (data == null || data is! Map<String, dynamic>) {
      throw Exception('Invalid response: expected JSON object');
    }
    if (coerceJsonMap(data['training']) == null) {
      final err = data['error']?.toString() ?? data['message']?.toString();
      throw Exception(err ?? 'Group training not found or no access');
    }
    return GroupTrainingDetail.fromJson(data);
  }

  Future<void> registerForTraining(String trainingId) async {
    await dio.post('/api/v1/me/group-trainings/$trainingId/register');
  }

  Future<void> unregisterFromTraining(String trainingId) async {
    await dio.delete('/api/v1/me/group-trainings/$trainingId/register');
  }

  /// Public landing (no auth). GET /api/v1/group-trainings/:id
  Future<GroupTrainingBookingItem> getPublicGroupTrainingLanding(String trainingId) async {
    final res = await dio.get<Map<String, dynamic>>('/api/v1/group-trainings/$trainingId');
    final m = coerceJsonMap(res.data?['landing']);
    if (m == null) {
      throw Exception('Invalid public group training response');
    }
    return GroupTrainingBookingItem.fromJson(m);
  }

  // ---- Trainer templates ----

  Future<List<GroupTrainingTemplate>> listTrainerTemplates({int limit = 50, int offset = 0}) async {
    final res = await dio.get<Map<String, dynamic>>(
      '/api/v1/me/trainer/group-training-templates',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    final list = res.data?['templates'] as List<dynamic>? ?? const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map((e) => GroupTrainingTemplate.fromJson(e))
        .toList();
  }

  Future<GroupTrainingTemplate> getTrainerTemplate(String templateId) async {
    final res = await dio.get<Map<String, dynamic>>('/api/v1/me/trainer/group-training-templates/$templateId');
    final tpl = res.data?['template'];
    if (tpl == null || tpl is! Map<String, dynamic>) {
      throw Exception('Invalid response: expected template object');
    }
    return GroupTrainingTemplate.fromJson(tpl);
  }

  /// Upload photo for group training template. Returns {photo_id, url}.
  Future<({String photoId, String url})> uploadPhoto(XFile file) async {
    final bytes = Uint8List.fromList(await file.readAsBytes());
    final name = file.name;
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: name.isNotEmpty ? name : 'photo.jpg'),
    });
    final res = await dio.post<Map<String, dynamic>>(
      '/api/v1/me/photos/upload',
      data: formData,
    );
    final data = res.data;
    if (data == null) throw Exception('Invalid upload response');
    final photoId = data['photo_id'] as String?;
    final url = data['url'] as String?;
    if (photoId == null || url == null) throw Exception('Missing photo_id or url in response');
    return (photoId: photoId, url: url);
  }

  Future<GroupTrainingTemplate> createTrainerTemplate({
    required String name,
    required String description,
    required int durationMinutes,
    required List<String> equipment,
    required String levelOfPreparation,
    String? photoPath,
    String? photoId,
    required int maxPeopleCount,
    required String groupTypeId,
    required bool isActive,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'description': description,
      'duration_minutes': durationMinutes,
      'equipment': equipment,
      'level_of_preparation': levelOfPreparation,
      if (photoPath != null) 'photo_path': photoPath,
      if (photoId != null) 'photo_id': photoId,
      'max_people_count': maxPeopleCount,
      'group_type_id': groupTypeId,
      'is_active': isActive,
    };
    final res = await dio.post<Map<String, dynamic>>(
      '/api/v1/me/trainer/group-training-templates',
      data: payload,
    );
    return GroupTrainingTemplate.fromJson(res.data!['template'] as Map<String, dynamic>);
  }

  Future<GroupTrainingTemplate> updateTrainerTemplate({
    required String templateId,
    required String name,
    required String description,
    required int durationMinutes,
    required List<String> equipment,
    required String levelOfPreparation,
    String? photoPath,
    String? photoId,
    required int maxPeopleCount,
    required String groupTypeId,
    required bool isActive,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'description': description,
      'duration_minutes': durationMinutes,
      'equipment': equipment,
      'level_of_preparation': levelOfPreparation,
      if (photoPath != null) 'photo_path': photoPath,
      if (photoId != null) 'photo_id': photoId,
      'max_people_count': maxPeopleCount,
      'group_type_id': groupTypeId,
      'is_active': isActive,
    };
    final res = await dio.put<Map<String, dynamic>>(
      '/api/v1/me/trainer/group-training-templates/$templateId',
      data: payload,
    );
    return GroupTrainingTemplate.fromJson(res.data!['template'] as Map<String, dynamic>);
  }

  Future<void> softDeleteTrainerTemplate(String templateId) async {
    await dio.delete('/api/v1/me/trainer/group-training-templates/$templateId');
  }

  // ---- Trainer trainings ----

  Future<List<GroupTraining>> listTrainerTrainings({
    required bool includePast,
    int limit = 50,
    int offset = 0,
  }) async {
    final res = await dio.get<Map<String, dynamic>>(
      '/api/v1/me/trainer/group-trainings',
      queryParameters: {
        'includePast': includePast ? 1 : 0,
        'limit': limit,
        'offset': offset,
      },
    );
    final list = res.data?['trainings'] as List<dynamic>? ?? const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map((e) => GroupTraining.fromJson(e))
        .toList();
  }

  Future<GroupTrainingDetail> getTrainerTrainingDetail(String trainingId) async {
    final res = await dio.get<Map<String, dynamic>>('/api/v1/me/trainer/group-trainings/$trainingId');
    final data = res.data;
    if (data == null || data is! Map<String, dynamic>) {
      throw Exception('Invalid response: expected JSON object');
    }
    if (coerceJsonMap(data['training']) == null) {
      final err = data['error']?.toString() ?? data['message']?.toString();
      throw Exception(err ?? 'Group training not found or no access');
    }
    return GroupTrainingDetail.fromJson(data);
  }

  Future<GroupTraining> createTrainerTraining({
    required String templateId,
    required DateTime scheduledAt,
    required String gymId,
  }) async {
    final payload = <String, dynamic>{
      'template_id': templateId,
      'scheduled_at': scheduledAt.toUtc().toIso8601String(),
      'gym_id': gymId,
    };
    final res = await dio.post<Map<String, dynamic>>(
      '/api/v1/me/trainer/group-trainings',
      data: payload,
    );
    return GroupTraining.fromJson(res.data!['training'] as Map<String, dynamic>);
  }

  Future<GroupTraining> updateTrainerTraining({
    required String trainingId,
    required String templateId,
    required DateTime scheduledAt,
    required String gymId,
  }) async {
    final payload = <String, dynamic>{
      'template_id': templateId,
      'scheduled_at': scheduledAt.toUtc().toIso8601String(),
      'gym_id': gymId,
    };
    final res = await dio.put<Map<String, dynamic>>(
      '/api/v1/me/trainer/group-trainings/$trainingId',
      data: payload,
    );
    return GroupTraining.fromJson(res.data!['training'] as Map<String, dynamic>);
  }

  Future<void> deleteTrainerTraining(String trainingId) async {
    await dio.delete('/api/v1/me/trainer/group-trainings/$trainingId');
  }
}

