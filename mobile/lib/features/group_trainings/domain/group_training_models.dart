/// Coerces JSON-decoded nested objects to [Map<String, dynamic>] (fixes web / interop maps).
Map<String, dynamic>? coerceJsonMap(dynamic value) {
  if (value == null) return null;
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    try {
      return Map<String, dynamic>.from(value);
    } catch (_) {
      return null;
    }
  }
  return null;
}

class GroupTrainingType {
  const GroupTrainingType({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  final String id;
  final String name;
  final DateTime createdAt;

  factory GroupTrainingType.fromJson(Map<String, dynamic> json) {
    return GroupTrainingType(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class ParticipantProfile {
  const ParticipantProfile({
    required this.userId,
    this.displayName,
    this.city,
    this.avatarUrl,
  });

  final String userId;
  final String? displayName;
  final String? city;
  final String? avatarUrl;

  factory ParticipantProfile.fromJson(Map<String, dynamic> json) {
    return ParticipantProfile(
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String?,
      city: json['city'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  String displayLabel() => displayName?.trim().isNotEmpty == true ? displayName!.trim() : userId;
}

class GroupTraining {
  const GroupTraining({
    required this.id,
    required this.templateId,
    this.templateName,
    required this.scheduledAt,
    required this.trainerUserId,
    required this.gymId,
    required this.city,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String templateId;
  final String? templateName;
  final DateTime scheduledAt;
  final String trainerUserId;
  final String gymId;
  final String city;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory GroupTraining.fromJson(Map<String, dynamic> json) {
    return GroupTraining(
      id: json['id'] as String,
      templateId: json['template_id'] as String,
      templateName: json['template_name'] as String?,
      scheduledAt: DateTime.parse(json['scheduled_at'] as String),
      trainerUserId: json['trainer_user_id'] as String,
      gymId: json['gym_id'] as String,
      city: json['city'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class GroupTrainingBookingItem {
  const GroupTrainingBookingItem({
    required this.trainingId,
    required this.templateId,
    required this.templateName,
    required this.description,
    required this.durationMinutes,
    required this.equipment,
    required this.levelOfPreparation,
    this.photoPath,
    required this.maxPeopleCount,
    required this.groupTypeId,
    required this.groupTypeName,
    required this.scheduledAt,
    required this.trainerUserId,
    required this.gymId,
    required this.city,
    required this.participantsCount,
  });

  final String trainingId;
  final String templateId;
  final String templateName;
  final String description;
  final int durationMinutes;
  final List<String> equipment;
  final String levelOfPreparation;
  final String? photoPath;
  final int maxPeopleCount;
  final String groupTypeId;
  final String groupTypeName;
  final DateTime scheduledAt;
  final String trainerUserId;
  final String gymId;
  final String city;
  final int participantsCount;

  int get remainingSeats => maxPeopleCount - participantsCount;

  factory GroupTrainingBookingItem.fromJson(Map<String, dynamic> json) {
    return GroupTrainingBookingItem(
      trainingId: json['training_id'] as String,
      templateId: json['template_id'] as String,
      templateName: json['template_name'] as String,
      description: json['description'] as String,
      durationMinutes: (json['duration_minutes'] as num).toInt(),
      equipment: (json['equipment'] as List<dynamic>? ?? const []).map((e) => e as String).toList(),
      levelOfPreparation: json['level_of_preparation'] as String,
      photoPath: json['photo_path'] as String?,
      maxPeopleCount: (json['max_people_count'] as num).toInt(),
      groupTypeId: json['group_type_id'] as String,
      groupTypeName: json['group_type_name'] as String,
      scheduledAt: DateTime.parse(json['scheduled_at'] as String),
      trainerUserId: json['trainer_user_id'] as String,
      gymId: json['gym_id'] as String,
      city: json['city'] as String,
      participantsCount: (json['participants_count'] as num).toInt(),
    );
  }
}

class GroupTrainingDetail {
  const GroupTrainingDetail({
    required this.training,
    required this.participants,
    this.display,
  });

  final GroupTraining training;
  final List<ParticipantProfile> participants;
  /// Rich card data (template name, description, seats…) when API returns `display`.
  final GroupTrainingBookingItem? display;

  factory GroupTrainingDetail.fromJson(Map<String, dynamic> json) {
    final trainingMap = coerceJsonMap(json['training']);
    if (trainingMap == null) {
      final hint = json['error']?.toString() ?? json['message']?.toString();
      throw FormatException(hint ?? 'Missing "training" in API response');
    }
    final rawParticipants = json['participants'];
    final participants = <ParticipantProfile>[];
    if (rawParticipants is List) {
      for (final e in rawParticipants) {
        final m = coerceJsonMap(e);
        if (m != null) {
          participants.add(ParticipantProfile.fromJson(m));
        }
      }
    }
    GroupTrainingBookingItem? display;
    final disp = coerceJsonMap(json['display']);
    if (disp != null) {
      try {
        display = GroupTrainingBookingItem.fromJson(disp);
      } catch (_) {}
    }
    return GroupTrainingDetail(
      training: GroupTraining.fromJson(trainingMap),
      participants: participants,
      display: display,
    );
  }
}

class GroupTrainingTemplate {
  const GroupTrainingTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.durationMinutes,
    required this.equipment,
    required this.levelOfPreparation,
    this.photoPath,
    this.photoId,
    required this.maxPeopleCount,
    required this.trainerUserId,
    required this.isActive,
    required this.groupTypeId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String description;
  final int durationMinutes;
  final List<String> equipment;
  final String levelOfPreparation;
  final String? photoPath;
  final String? photoId;
  final int maxPeopleCount;
  final String trainerUserId;
  final bool isActive;
  final String groupTypeId;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory GroupTrainingTemplate.fromJson(Map<String, dynamic> json) {
    return GroupTrainingTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      durationMinutes: (json['duration_minutes'] as num).toInt(),
      equipment: (json['equipment'] as List<dynamic>? ?? const []).map((e) => e as String).toList(),
      levelOfPreparation: json['level_of_preparation'] as String? ?? '',
      photoPath: json['photo_path'] as String?,
      photoId: json['photo_id'] as String?,
      maxPeopleCount: (json['max_people_count'] as num).toInt(),
      trainerUserId: json['trainer_user_id'] as String,
      isActive: json['is_active'] as bool? ?? true,
      groupTypeId: json['group_type_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

