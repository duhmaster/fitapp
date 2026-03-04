import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/core/widgets/error_state_widget.dart';
import 'package:fitflow/core/widgets/loading_skeleton.dart';
import 'package:fitflow/features/progress/domain/progress_models.dart';
import 'package:fitflow/features/progress/presentation/progress_provider.dart';

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
    final weightAsync = ref.watch(weightHistoryProvider);
    final bodyFatAsync = ref.watch(bodyFatHistoryProvider);
    final inShell = GoRouterState.of(context).matchedLocation == '/progress';
    return Scaffold(
      appBar: inShell ? null : AppBar(title: Text(tr('progress'))),
      body: weightAsync.when(
        loading: () => const _ProgressSkeleton(),
        error: (e, _) => ErrorStateWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(weightHistoryProvider),
        ),
        data: (weightList) => bodyFatAsync.when(
          loading: () => const _ProgressSkeleton(),
          error: (e, _) => ErrorStateWidget(
            message: e.toString(),
            onRetry: () => ref.invalidate(bodyFatHistoryProvider),
          ),
          data: (bodyFatList) => _filterAndBuild(context, tr, weightList, bodyFatList),
        ),
      ),
    );
  }

  Widget _filterAndBuild(BuildContext context, String Function(String) tr, List<WeightEntry> weightList, List<BodyFatEntry> bodyFatList) {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: _dateRangeDays));
    final filteredWeight = weightList.where((e) => _parseDate(e.recordedAt).isAfter(start) || _parseDate(e.recordedAt).isAtSameMomentAs(start)).toList();
    final filteredBodyFat = bodyFatList.where((e) => _parseDate(e.recordedAt).isAfter(start) || _parseDate(e.recordedAt).isAtSameMomentAs(start)).toList();
    filteredWeight.sort((a, b) => _parseDate(a.recordedAt).compareTo(_parseDate(b.recordedAt)));
    filteredBodyFat.sort((a, b) => _parseDate(a.recordedAt).compareTo(_parseDate(b.recordedAt)));

    final latestWeight = filteredWeight.isNotEmpty ? filteredWeight.last.weightKg : null;
    final minWeight = filteredWeight.isEmpty ? null : filteredWeight.map((e) => e.weightKg).reduce((a, b) => a < b ? a : b);
    final maxWeight = filteredWeight.isEmpty ? null : filteredWeight.map((e) => e.weightKg).reduce((a, b) => a > b ? a : b);
    final latestBodyFat = filteredBodyFat.isNotEmpty ? filteredBodyFat.last.bodyFatPct : null;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(weightHistoryProvider);
        ref.invalidate(bodyFatHistoryProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('7d')),
                ButtonSegment(value: 30, label: Text('30d')),
                ButtonSegment(value: 90, label: Text('90d')),
              ],
              selected: {_dateRangeDays},
              onSelectionChanged: (s) => setState(() => _dateRangeDays = s.first),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _StatCard(title: tr('latest_weight'), value: latestWeight != null ? '${latestWeight.toStringAsFixed(1)} kg' : '—')),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(title: tr('body_fat_pct_label'), value: latestBodyFat != null ? '${latestBodyFat.toStringAsFixed(1)}%' : '—')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _StatCard(title: tr('min_weight'), value: minWeight != null ? '${minWeight.toStringAsFixed(1)} kg' : '—')),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(title: tr('max_weight'), value: maxWeight != null ? '${maxWeight.toStringAsFixed(1)} kg' : '—')),
              ],
            ),
            const SizedBox(height: 24),
            if (filteredWeight.isNotEmpty) ...[
              Text(tr('weight_chart'), style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
                child: LineChart(
                  _weightChartData(filteredWeight),
                  duration: const Duration(milliseconds: 250),
                ),
              ),
              const SizedBox(height: 24),
            ],
            if (filteredBodyFat.isNotEmpty) ...[
              Text(tr('body_fat_chart'), style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
                child: LineChart(
                  _bodyFatChartData(filteredBodyFat),
                  duration: const Duration(milliseconds: 250),
                ),
              ),
            ],
            if (filteredWeight.isEmpty && filteredBodyFat.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  tr('no_data_in_range'),
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  DateTime _parseDate(String s) {
    try {
      return DateTime.parse(s);
    } catch (_) {
      return DateTime(1970);
    }
  }

  LineChartData _weightChartData(List<WeightEntry> list) {
    final spots = list.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.weightKg)).toList();
    final minY = list.isEmpty ? 0.0 : list.map((e) => e.weightKg).reduce((a, b) => a < b ? a : b) - 2;
    final maxY = list.isEmpty ? 100.0 : list.map((e) => e.weightKg).reduce((a, b) => a > b ? a : b) + 2;
    return LineChartData(
      gridData: FlGridData(show: true),
      titlesData: FlTitlesData(show: false),
      borderData: FlBorderData(show: true),
      minX: 0,
      maxX: (list.length - 1).clamp(0, double.infinity).toDouble(),
      minY: minY,
      maxY: maxY,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: Theme.of(context).colorScheme.primary,
          barWidth: 2,
          dotData: FlDotData(show: list.length <= 20),
          belowBarData: BarAreaData(show: true, color: Theme.of(context).colorScheme.primary.withOpacity(0.1)),
        ),
      ],
    );
  }

  LineChartData _bodyFatChartData(List<BodyFatEntry> list) {
    final spots = list.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.bodyFatPct)).toList();
    final minY = list.isEmpty ? 0.0 : list.map((e) => e.bodyFatPct).reduce((a, b) => a < b ? a : b) - 2;
    final maxY = list.isEmpty ? 100.0 : list.map((e) => e.bodyFatPct).reduce((a, b) => a > b ? a : b) + 2;
    return LineChartData(
      gridData: FlGridData(show: true),
      titlesData: FlTitlesData(show: false),
      borderData: FlBorderData(show: true),
      minX: 0,
      maxX: (list.length - 1).clamp(0, double.infinity).toDouble(),
      minY: minY.clamp(0.0, 100.0),
      maxY: maxY.clamp(0.0, 100.0),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: Theme.of(context).colorScheme.secondary,
          barWidth: 2,
          dotData: FlDotData(show: list.length <= 20),
          belowBarData: BarAreaData(show: true, color: Theme.of(context).colorScheme.secondary.withOpacity(0.1)),
        ),
      ],
    );
  }
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
