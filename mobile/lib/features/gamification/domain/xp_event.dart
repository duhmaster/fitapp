/// Single ledger row: XP gained for a reason (mirrors planned `xp_ledger` on server).
class XpEvent {
  const XpEvent({
    required this.id,
    required this.deltaXp,
    required this.reason,
    required this.createdAt,
    this.sourceType,
    this.sourceId,
    this.label,
  });

  final String id;
  final int deltaXp;
  /// Opaque code: workout_finished, mission_daily, badge_bonus, etc.
  final String reason;
  final DateTime createdAt;
  final String? sourceType;
  final String? sourceId;
  final String? label;

  factory XpEvent.fromJson(Map<String, dynamic> json) {
    return XpEvent(
      id: json['id'] as String? ?? '',
      deltaXp: (json['delta_xp'] as num?)?.toInt() ?? 0,
      reason: json['reason'] as String? ?? 'unknown',
      createdAt: _parseDate(json['created_at']),
      sourceType: json['source_type'] as String?,
      sourceId: json['source_id'] as String?,
      label: json['label'] as String?,
    );
  }

  static DateTime _parseDate(dynamic v) {
    if (v is String) {
      return DateTime.tryParse(v) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
