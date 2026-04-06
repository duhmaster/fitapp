/// Client-side **preview** XP estimates for UI hints only. Server is source of truth.
class XpCalculationService {
  const XpCalculationService();

  /// Rough bonus from completed workout volume (kg × reps aggregated externally).
  int previewXpForWorkoutVolumeKg(double totalVolumeKg) {
    if (totalVolumeKg <= 0) return 0;
    // Tunable placeholder curve: diminishing returns.
    final base = (totalVolumeKg / 50).floor();
    return base.clamp(1, 500);
  }

  /// Bonus for finishing any workout (engagement), preview only.
  int previewCompletionBonus() => 10;
}
