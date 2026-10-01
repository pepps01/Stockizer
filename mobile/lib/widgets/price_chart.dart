import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../format.dart';
import '../models/market.dart';
import '../models/strategy.dart';
import '../theme.dart';

/// Close-price area chart, green when the range ends up and red when down.
class PriceChart extends StatelessWidget {
  const PriceChart({super.key, required this.bars, this.height = 240});

  final List<Bar> bars;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (bars.length < 2) {
      return SizedBox(height: height, child: Center(child: Text('Not enough history', style: TextStyle(color: p.mutedForeground))));
    }
    final color = bars.last.close >= bars.first.close ? p.gain : p.loss;
    final spots = [for (var i = 0; i < bars.length; i++) FlSpot(i.toDouble(), bars[i].close)];
    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (bars.length - 1).toDouble(),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(color: p.border, strokeWidth: 0.6),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            leftTitles: const AxisTitles(),
            bottomTitles: const AxisTitles(),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 52,
                getTitlesWidget: (value, meta) => value == meta.min || value == meta.max
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(formatCompact(value), style: TextStyle(fontSize: 10, color: p.mutedForeground)),
                      ),
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => p.foreground,
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    '${formatNumber(s.y)}\n${bars[s.x.toInt()].time.split('T').first}',
                    TextStyle(color: p.background, fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              color: color,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.0)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Growth of 1 unit: the Algizer signal strategy vs buying and holding.
class EquityChart extends StatelessWidget {
  const EquityChart({super.key, required this.points, this.height = 200});

  final List<CurvePoint> points;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (points.length < 2) return const SizedBox.shrink();
    LineChartBarData line(List<FlSpot> spots, Color color, {bool dashed = false}) => LineChartBarData(
          spots: spots,
          color: color,
          barWidth: 2,
          dashArray: dashed ? [5, 4] : null,
          dotData: const FlDotData(show: false),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: p.border, strokeWidth: 0.6)),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                leftTitles: const AxisTitles(),
                bottomTitles: const AxisTitles(),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) => value == meta.min || value == meta.max
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text(value.toStringAsFixed(2), style: TextStyle(fontSize: 10, color: p.mutedForeground)),
                          ),
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => p.foreground,
                  getTooltipItems: (spots) => [
                    for (final s in spots)
                      LineTooltipItem(
                        '${s.barIndex == 0 ? 'Signal' : 'B&H'} ${s.y.toStringAsFixed(3)}',
                        TextStyle(color: s.barIndex == 0 ? p.brandSoft : p.background, fontSize: 11),
                      ),
                  ],
                ),
              ),
              lineBarsData: [
                line([for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].strategy)], p.brand),
                line([for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].buyAndHold)], p.mutedForeground, dashed: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _Legend(color: p.brand, label: 'Algizer signal'),
            const SizedBox(width: 16),
            _Legend(color: p.mutedForeground, label: 'Buy & hold'),
          ],
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 3, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: context.palette.mutedForeground)),
      ],
    );
  }
}
