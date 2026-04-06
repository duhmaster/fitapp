import 'package:fitflow/features/gamification/domain/mission.dart';

/// Evaluates mission progress from lightweight counters (client preview).
/// Server must validate and grant rewards.
class MissionEngine {
  const MissionEngine();

  UserMissionProgress evaluate({
    required MissionDefinition def,
    required int currentCounter,
    DateTime? windowStart,
    DateTime? windowEnd,
  }) {
    final done = currentCounter >= def.targetValue;
    return UserMissionProgress(
      missionId: def.id,
      currentValue: currentCounter.clamp(0, def.targetValue),
      status: done ? MissionStatus.completed : MissionStatus.active,
      windowStart: windowStart,
      windowEnd: windowEnd,
    );
  }
}
