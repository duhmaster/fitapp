enum MissionPeriod {
  daily,
  weekly,
}

enum MissionStatus {
  active,
  completed,
  claimed,
  expired,
}

class MissionDefinition {
  const MissionDefinition({
    required this.id,
    required this.code,
    required this.title,
    this.description,
    this.period = MissionPeriod.daily,
    this.targetValue = 1,
    this.rewardXp = 0,
  });

  final String id;
  final String code;
  final String title;
  final String? description;
  final MissionPeriod period;
  final int targetValue;
  final int rewardXp;

  factory MissionDefinition.fromJson(Map<String, dynamic> json) {
    return MissionDefinition(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      period: (json['period'] as String?) == 'weekly' ? MissionPeriod.weekly : MissionPeriod.daily,
      targetValue: (json['target_value'] as num?)?.toInt() ?? 1,
      rewardXp: (json['reward_xp'] as num?)?.toInt() ?? 0,
    );
  }
}

class UserMissionProgress {
  const UserMissionProgress({
    required this.missionId,
    required this.currentValue,
    required this.status,
    this.windowStart,
    this.windowEnd,
  });

  final String missionId;
  final int currentValue;
  final MissionStatus status;
  final DateTime? windowStart;
  final DateTime? windowEnd;

  factory UserMissionProgress.fromJson(Map<String, dynamic> json) {
    return UserMissionProgress(
      missionId: json['mission_id'] as String? ?? '',
      currentValue: (json['current_value'] as num?)?.toInt() ?? 0,
      status: _statusFrom(json['status'] as String?),
      windowStart: DateTime.tryParse(json['window_start'] as String? ?? ''),
      windowEnd: DateTime.tryParse(json['window_end'] as String? ?? ''),
    );
  }

  static MissionStatus _statusFrom(String? s) {
    switch (s) {
      case 'completed':
        return MissionStatus.completed;
      case 'claimed':
        return MissionStatus.claimed;
      case 'expired':
        return MissionStatus.expired;
      default:
        return MissionStatus.active;
    }
  }
}
