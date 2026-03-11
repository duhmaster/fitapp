class Profile {
  Profile({
    required this.id,
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.city,
  });
  final String id;
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String? city;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: (json['id'] as String?) ?? '',
      userId: (json['user_id'] as String?) ?? '',
      displayName: (json['display_name'] as String?) ?? '',
      avatarUrl: json['avatar_url'] as String?,
      city: json['city'] as String?,
    );
  }

  Profile copyWith({String? displayName, String? avatarUrl, String? city}) {
    return Profile(
      id: id,
      userId: userId,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      city: city ?? this.city,
    );
  }
}

/// Combined data for the profile page: profile + email + metrics + subscription.
class ProfilePageData {
  ProfilePageData({
    required this.displayName,
    this.avatarUrl,
    required this.email,
    this.city,
    this.heightCm,
    this.weightKg,
    this.bodyFatPct,
    this.paidSubscriber = false,
    this.subscriptionExpiresAt,
  });
  final String displayName;
  final String? avatarUrl;
  final String email;
  final String? city;
  final double? heightCm;
  final double? weightKg;
  final double? bodyFatPct;
  final bool paidSubscriber;
  final String? subscriptionExpiresAt;
}

/// Single body measurement record (date, weight, body fat %, height for FFMI/BMI).
class BodyMeasurement {
  BodyMeasurement({
    required this.id,
    required this.recordedAt,
    required this.weightKg,
    this.bodyFatPct,
    this.heightCm,
  });
  final String id;
  final DateTime recordedAt;
  final double weightKg;
  final double? bodyFatPct;
  final double? heightCm;

  factory BodyMeasurement.fromJson(Map<String, dynamic> json) {
    final recordedAtStr = json['recorded_at'] as String?;
    DateTime recordedAt = DateTime.now();
    if (recordedAtStr != null) {
      recordedAt = DateTime.tryParse(recordedAtStr) ?? recordedAt;
    }
    return BodyMeasurement(
      id: (json['id'] as String?) ?? '',
      recordedAt: recordedAt,
      weightKg: (json['weight_kg'] as num?)?.toDouble() ?? 0,
      bodyFatPct: (json['body_fat_pct'] as num?)?.toDouble(),
      heightCm: (json['height_cm'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'recorded_at': recordedAt.toIso8601String(),
        'weight_kg': weightKg,
        if (bodyFatPct != null) 'body_fat_pct': bodyFatPct,
        if (heightCm != null) 'height_cm': heightCm,
      };
}

/// LBM (lean body mass) in kg, FFMI, BMI and their text interpretations.
class BodyMeasurementInterpretation {
  BodyMeasurementInterpretation({
    required this.lbmKg,
    required this.leanMassPct,
    this.ffmi,
    required this.ffmiText,
    this.bmi,
    required this.bmiText,
  });
  final double lbmKg;
  final double leanMassPct;
  final double? ffmi;
  final String ffmiText;
  final double? bmi;
  final String bmiText;
}

/// Compute LBM (kg), lean mass %, FFMI, BMI and return interpretation texts (keys for tr()).
BodyMeasurementInterpretation interpretBodyMeasurement(
  double weightKg,
  double? bodyFatPct,
  double? heightCm,
  String Function(String) tr,
) {
  final fatPct = bodyFatPct ?? 0.0;
  final lbmKg = weightKg * (1 - fatPct / 100);
  final leanMassPct = 100 - fatPct;

  double? ffmi;
  String ffmiText;
  if (heightCm != null && heightCm > 0) {
    final heightM = heightCm / 100;
    ffmi = lbmKg / (heightM * heightM);
    if (ffmi! < 18) {
      ffmiText = tr('ffmi_low');
    } else if (ffmi < 20) {
      ffmiText = tr('ffmi_avg');
    } else if (ffmi < 22) {
      ffmiText = tr('ffmi_good');
    } else if (ffmi < 24) {
      ffmiText = tr('ffmi_excellent');
    } else if (ffmi < 26) {
      ffmiText = tr('ffmi_natural_limit');
    } else {
      ffmiText = tr('ffmi_very_high');
    }
  } else {
    ffmiText = tr('ffmi_no_height');
  }

  double? bmi;
  String bmiText;
  if (heightCm != null && heightCm > 0) {
    final heightM = heightCm / 100;
    bmi = weightKg / (heightM * heightM);
    if (bmi! <= 16) {
      bmiText = tr('bmi_severe_underweight');
    } else if (bmi < 18.5) {
      bmiText = tr('bmi_underweight');
    } else if (bmi < 25) {
      bmiText = tr('bmi_normal');
    } else if (bmi < 30) {
      bmiText = tr('bmi_overweight');
    } else if (bmi < 35) {
      bmiText = tr('bmi_obese_1');
    } else if (bmi < 40) {
      bmiText = tr('bmi_obese_2');
    } else {
      bmiText = tr('bmi_obese_3');
    }
  } else {
    bmiText = tr('bmi_no_height');
  }

  return BodyMeasurementInterpretation(
    lbmKg: lbmKg,
    leanMassPct: leanMassPct,
    ffmi: ffmi,
    ffmiText: ffmiText,
    bmi: bmi,
    bmiText: bmiText,
  );
}
