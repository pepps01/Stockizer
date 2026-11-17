import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tickizer/models/market.dart';
import 'package:tickizer/theme.dart';
import 'package:tickizer/widgets/motion.dart';
import 'package:tickizer/widgets/price_chart.dart';

Widget _host(Widget child) => MaterialApp(theme: buildLightTheme(), home: Scaffold(body: Center(child: SizedBox(width: 400, child: child))));

void main() {
  testWidgets('dragging across the chart reports bars, then null on release', (tester) async {
    final bars = [
      for (var i = 0; i < 60; i++)
        Bar(time: '2026-01-${(i % 28 + 1).toString().padLeft(2, '0')}', open: 10, high: 12, low: 9, close: 10 + i / 10, volume: 1000),
    ];
    final seen = <Bar?>[];
    await tester.pumpWidget(_host(PriceChart(bars: bars, onScrub: seen.add)));

    final chart = tester.getRect(find.byType(PriceChart));
    final gesture = await tester.startGesture(Offset(chart.left + 60, chart.center.dy));
    await tester.pump();
    await gesture.moveBy(const Offset(120, 0));
    await tester.pump();

    final scrubbed = seen.whereType<Bar>().toList();
    expect(scrubbed, isNotEmpty);
    expect(bars.indexOf(scrubbed.last), greaterThan(bars.indexOf(scrubbed.first)), reason: 'moving right scrubs forward in time');

    await gesture.up();
    await tester.pump();
    expect(seen.last, isNull, reason: 'lifting the finger returns the header to the live quote');
  });

  testWidgets('a live tick flashes and settles on the new price', (tester) async {
    await tester.pumpWidget(_host(const TickingPrice(value: 100)));
    expect(find.text('100.00'), findsOneWidget);

    await tester.pumpWidget(_host(const TickingPrice(value: 101.5)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.widget<Container>(find.descendant(of: find.byType(TickingPrice), matching: find.byType(Container))).decoration, isNotNull);

    await tester.pumpAndSettle();
    expect(find.text('101.50'), findsOneWidget);
  });

  testWidgets('staggered entrance ends fully visible', (tester) async {
    await tester.pumpWidget(_host(const FadeSlideIn(delay: Duration(milliseconds: 90), child: Text('hello'))));
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0);
    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
  });
}
