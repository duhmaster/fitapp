import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/core/analytics/gamification_analytics.dart';

final gamificationAnalyticsProvider = Provider<GamificationAnalytics>((ref) {
  return GamificationAnalytics();
});
