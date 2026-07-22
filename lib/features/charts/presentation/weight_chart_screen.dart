import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../../../core/db/database.dart';
import '../../../core/widgets/empty_state.dart';
import '../application/weight_chart_providers.dart';

class WeightChartScreen extends ConsumerWidget {
  const WeightChartScreen({super.key, required this.petUuid});

  final String petUuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final async = ref.watch(weightsForPetProvider(petUuid));
    return Scaffold(
      appBar: AppBar(title: Text(l.weightChartTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (rows) {
          if (rows.length < 2) {
            return EmptyState(
              icon: Icons.show_chart,
              title: l.weightChartEmptyTitle,
              message: l.weightChartEmptyMessage,
            );
          }
          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 20, 24),
            child: _Chart(rows: rows),
          );
        },
      ),
    );
  }
}

class _Chart extends StatelessWidget {
  const _Chart({required this.rows});

  final List<PetWeightRow> rows;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final fmt = DateFormat.MMMd(locale);
    final x0 = rows.first.measuredAt.millisecondsSinceEpoch.toDouble();
    final xN = rows.last.measuredAt.millisecondsSinceEpoch.toDouble();
    final spots = rows
        .map((r) => FlSpot(
              r.measuredAt.millisecondsSinceEpoch.toDouble(),
              r.weightKg,
            ))
        .toList(growable: false);
    final minY = rows.map((r) => r.weightKg).reduce((a, b) => a < b ? a : b);
    final maxY = rows.map((r) => r.weightKg).reduce((a, b) => a > b ? a : b);
    final pad = ((maxY - minY).abs() * 0.15).clamp(0.1, 5.0);
    final trend = _trendline(spots);
    final theme = Theme.of(context);
    return LineChart(
      LineChartData(
        minX: x0,
        maxX: xN,
        minY: (minY - pad),
        maxY: (maxY + pad),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (v, _) => Text(
                v.toStringAsFixed(1),
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: ((xN - x0) / 4).clamp(1.0, double.infinity),
              getTitlesWidget: (v, _) {
                final d = DateTime.fromMillisecondsSinceEpoch(v.toInt());
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(fmt.format(d),
                      style: theme.textTheme.bodySmall),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            barWidth: 3,
            color: theme.colorScheme.primary,
            dotData: const FlDotData(show: true),
          ),
          if (trend != null)
            LineChartBarData(
              spots: trend,
              isCurved: false,
              barWidth: 2,
              color: theme.colorScheme.secondary.withValues(alpha: 0.7),
              dashArray: const [6, 4],
              dotData: const FlDotData(show: false),
            ),
        ],
      ),
    );
  }

  /// Simple linear regression trendline over the same X range.
  /// Returns null if the input is degenerate.
  List<FlSpot>? _trendline(List<FlSpot> pts) {
    if (pts.length < 2) return null;
    final n = pts.length;
    var sumX = 0.0, sumY = 0.0, sumXY = 0.0, sumX2 = 0.0;
    for (final p in pts) {
      sumX += p.x;
      sumY += p.y;
      sumXY += p.x * p.y;
      sumX2 += p.x * p.x;
    }
    final denom = n * sumX2 - sumX * sumX;
    if (denom == 0) return null;
    final slope = (n * sumXY - sumX * sumY) / denom;
    final intercept = (sumY - slope * sumX) / n;
    final x0 = pts.first.x, xN = pts.last.x;
    return [
      FlSpot(x0, slope * x0 + intercept),
      FlSpot(xN, slope * xN + intercept),
    ];
  }
}
