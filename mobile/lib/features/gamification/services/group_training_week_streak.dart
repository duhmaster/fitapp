import 'package:fitflow/features/group_trainings/domain/group_training_models.dart';

/// Buckets a local date into a year + week index (approximation for client-side streaks until server metrics exist).
String weekBucketLocal(DateTime d) {
  final l = DateTime(d.year, d.month, d.day);
  final start = DateTime(l.year, 1, 1);
  final week = (l.difference(start).inDays / 7).floor();
  return '${l.year}-$week';
}

/// Counts consecutive week buckets walking backward from the most recent past session.
int consecutiveWeekStreakWeeks(List<GroupTraining> trainings) {
  final now = DateTime.now().toLocal();
  final past = trainings.where((t) => t.scheduledAt.toLocal().isBefore(now)).toList();
  if (past.isEmpty) return 0;
  final keys = past.map((t) => weekBucketLocal(t.scheduledAt.toLocal())).toSet();
  var probe = past.map((t) => t.scheduledAt.toLocal()).reduce((a, b) => a.isAfter(b) ? a : b);
  var streak = 0;
  for (var i = 0; i < 52; i++) {
    if (!keys.contains(weekBucketLocal(probe))) break;
    streak++;
    probe = probe.subtract(const Duration(days: 7));
  }
  return streak;
}
