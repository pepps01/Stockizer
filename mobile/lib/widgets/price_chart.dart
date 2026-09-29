import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/market.dart';
import '../theme.dart';

class PriceChart extends StatelessWidget {
  final List<PricePoint> points;
  final double height;
  final bool compact;

  const PriceChart({super.key, required this.points, this.height = 220, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text('No chart data', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
      );
    }

    final spots = [for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].value)];
    final minY = points.map((p) => p.value).reduce((a, b) => a < b ? a : b);
    final maxY = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) * 0.1;

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: minY - padding,
          maxY: maxY + padding,
          gridData: FlGridData(
            show: !compact,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(color: Theme.of(context).dividerColor, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            show: !compact,
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48,
                getTitlesWidget: (value, meta) => Text(
                  value.toStringAsFixed(0),
                  style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(enabled: !compact),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.15,
              color: AppColors.gain,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.gain.withValues(alpha: 0.28), AppColors.gain.withValues(alpha: 0.0)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
