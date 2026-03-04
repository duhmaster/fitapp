class WeightEntry {
  WeightEntry({
    required this.id,
    required this.weightKg,
    required this.recordedAt,
  });
  final String id;
  final double weightKg;
  final String recordedAt;
  factory WeightEntry.fromJson(Map<String, dynamic> json) {
    return WeightEntry(
      id: (json['id'] as String?) ?? '',
      weightKg: (json['weight_kg'] as num).toDouble(),
      recordedAt: (json['recorded_at'] as String?) ?? '',
    );
  }
}

class BodyFatEntry {
  BodyFatEntry({
    required this.id,
    required this.bodyFatPct,
    required this.recordedAt,
  });
  final String id;
  final double bodyFatPct;
  final String recordedAt;
  factory BodyFatEntry.fromJson(Map<String, dynamic> json) {
    return BodyFatEntry(
      id: (json['id'] as String?) ?? '',
      bodyFatPct: (json['body_fat_pct'] as num).toDouble(),
      recordedAt: (json['recorded_at'] as String?) ?? '',
    );
  }
}
