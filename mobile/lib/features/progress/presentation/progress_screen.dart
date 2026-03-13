import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/core/widgets/error_state_widget.dart';
import 'package:fitflow/core/widgets/loading_skeleton.dart';
import 'package:fitflow/features/profile/domain/profile_models.dart';
import 'package:fitflow/features/profile/presentation/profile_provider.dart';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  int _dateRangeDays = 30; // 7, 30, 90

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final measurementsAsync = ref.watch(bodyMeasurementsProvider);
    final profileData = ref.watch(profilePageDataProvider).valueOrNull;
    final profileHeight = profileData?.heightCm;
    final inShell = GoRouterState.of(context).matchedLocation == '/progress';
    return Scaffold(
      appBar: inShell ? null : AppBar(title: Text(tr('progress_measurements'))),
      body: measurementsAsync.when(
        loading: () => const _ProgressSkeleton(),
        error: (e, _) => ErrorStateWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(bodyMeasurementsProvider),
        ),
        data: (list) => _buildFromMeasurements(context, tr, list, profileHeight),
      ),
    );
  }

  Widget _buildFromMeasurements(BuildContext context, String Function(String) tr, List<BodyMeasurement> list, double? profileHeight) {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: _dateRangeDays));
    final filtered = list.where((m) {
      final local = m.recordedAt.toLocal();
      return local.isAfter(start) || local.isAtSameMomentAs(start);
    }).toList();
    filtered.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));

    final withInterp = filtered.map((m) {
      final h = m.heightCm ?? profileHeight;
      final interp = interpretBodyMeasurement(m.weightKg, m.bodyFatPct, h, (_) => '');
      return _ChartPoint(
        date: m.recordedAt,
        weight: m.weightKg,
        bodyFat: m.bodyFatPct ?? 0,
        ffmi: interp.ffmi,
        bmi: interp.bmi,
      );
    }).toList();

    final latestWeight = withInterp.isNotEmpty ? withInterp.last.weight : null;
    final latestBodyFat = withInterp.isNotEmpty ? withInterp.last.bodyFat : null;
    final latestFfmi = withInterp.isNotEmpty ? withInterp.last.ffmi : null;
    final latestBmi = withInterp.isNotEmpty ? withInterp.last.bmi : null;
    final minWeight = withInterp.isEmpty ? null : withInterp.map((e) => e.weight).reduce((a, b) => a < b ? a : b);
    final maxWeight = withInterp.isEmpty ? null : withInterp.map((e) => e.weight).reduce((a, b) => a > b ? a : b);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(bodyMeasurementsProvider);
        ref.invalidate(profilePageDataProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 7, label: Text(tr('date_range_7d'))),
                ButtonSegment(value: 30, label: Text(tr('date_range_30d'))),
                ButtonSegment(value: 90, label: Text(tr('date_range_90d'))),
              ],
              selected: {_dateRangeDays},
              onSelectionChanged: (s) => setState(() => _dateRangeDays = s.first),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _StatCard(title: tr('latest_weight'), value: latestWeight != null ? '${latestWeight.toStringAsFixed(1)} kg' : '—')),
                Expanded(child: _StatCard(title: tr('body_fat_pct_label'), value: latestBodyFat != null ? '${latestBodyFat.toStringAsFixed(1)}%' : '—')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _StatCard(title: tr('min_weight'), value: minWeight != null ? '${minWeight.toStringAsFixed(1)} kg' : '—')),
                Expanded(child: _StatCard(title: tr('max_weight'), value: maxWeight != null ? '${maxWeight.toStringAsFixed(1)} kg' : '—')),
              ],
            ),
            if (latestFfmi != null || latestBmi != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (latestFfmi != null) Expanded(child: _StatCard(title: tr('ffmi_interpretation'), value: latestFfmi.toStringAsFixed(1))),
                  if (latestBmi != null) Expanded(child: _StatCard(title: tr('bmi_interpretation'), value: latestBmi.toStringAsFixed(1))),
                ],
              ),
            ],
            const SizedBox(height: 24),
            if (withInterp.isNotEmpty) ...[
              Text(tr('weight_chart'), style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SizedBox(height: _chartHeight(context), child: LineChart(_chartData(withInterp.map((e) => e.weight).toList(), context), duration: const Duration(milliseconds: 250))),
              const SizedBox(height: 24),
              Text(tr('body_fat_chart'), style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SizedBox(height: _chartHeight(context), child: LineChart(_chartData(withInterp.map((e) => e.bodyFat).toList(), context, isPct: true), duration: const Duration(milliseconds: 250))),
              if (withInterp.any((e) => e.ffmi != null)) ...[
                const SizedBox(height: 24),
                Text(tr('ffmi_interpretation'), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SizedBox(height: _chartHeight(context), child: LineChart(_chartData(withInterp.map((e) => e.ffmi ?? 0).toList(), context), duration: const Duration(milliseconds: 250))),
              ],
              if (withInterp.any((e) => e.bmi != null)) ...[
                const SizedBox(height: 24),
                Text(tr('bmi_interpretation'), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SizedBox(height: _chartHeight(context), child: LineChart(_chartData(withInterp.map((e) => e.bmi ?? 0).toList(), context), duration: const Duration(milliseconds: 250))),
              ],
            ],
            if (withInterp.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(tr('no_data_in_range'), style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
              ),
          ],
        ),
      ),
    );
  }

  double _chartHeight(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    if (h < 500) return 140;
    if (h < 700) return 180;
    return 200;
  }

  LineChartData _chartData(List<double> values, BuildContext context, {bool isPct = false}) {
    final spots = values.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList();
    final minY = values.isEmpty ? 0.0 : values.reduce((a, b) => a < b ? a : b) - (isPct ? 2 : 1);
    final maxY = values.isEmpty ? 100.0 : values.reduce((a, b) => a > b ? a : b) + (isPct ? 2 : 1);
    return LineChartData(
      gridData: FlGridData(show: true),
      titlesData: FlTitlesData(show: false),
      borderData: FlBorderData(show: true),
      minX: 0,
      maxX: (values.length - 1).clamp(0, double.infinity).toDouble(),
      minY: isPct ? minY.clamp(0.0, 100.0) : minY,
      maxY: isPct ? maxY.clamp(0.0, 100.0) : maxY,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: Theme.of(context).colorScheme.primary,
          barWidth: 2,
          dotData: FlDotData(show: values.length <= 20),
          belowBarData: BarAreaData(show: true, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)),
        ),
      ],
    );
  }
}

class _ChartPoint {
  _ChartPoint({required this.date, required this.weight, required this.bodyFat, this.ffmi, this.bmi});
  final DateTime date;
  final double weight;
  final double bodyFat;
  final double? ffmi;
  final double? bmi;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value});
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _ProgressSkeleton extends StatelessWidget {
  const _ProgressSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        LoadingSkeleton(height: 40, borderRadius: 8),
        SizedBox(height: 24),
        LoadingSkeleton(height: 80, borderRadius: 12),
        SizedBox(height: 24),
        LoadingSkeleton(height: 200, borderRadius: 12),
      ],
    );
  }
}
