import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tickizer/models/market.dart';
import 'package:tickizer/screens/markets_screen.dart';
import 'package:tickizer/theme.dart';
import 'package:tickizer/widgets/paged_list.dart';

Exchange _exchange(int i) => Exchange.fromJson({
  'id': 'e$i',
  'code': 'EX$i',
  'name': 'Exchange $i',
  'country_code': 'NG',
  'country': 'Nigeria',
  'opens_at': '10:00',
  'closes_at': '14:30',
  'trading_days': [0, 1, 2, 3, 4],
  'currency': 'NGN',
  'data_source': 'synthetic',
  'is_open': true,
  'local_time': '2026-09-30T11:00:00',
  'stock_count': 12,
});

void main() {
  testWidgets('exchanges show six per page with previous and next', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: SingleChildScrollView(child: PagedExchanges(exchanges: [for (var i = 1; i <= 14; i++) _exchange(i)])),
        ),
      ),
    );

    expect(find.text('1–6 of 14'), findsOneWidget);
    expect(find.text('Exchange 1'), findsOneWidget);
    expect(find.text('Exchange 7'), findsNothing);

    await tester.ensureVisible(find.byTooltip('Next exchanges'));
    await tester.tap(find.byTooltip('Next exchanges'));
    await tester.pumpAndSettle();
    expect(find.text('7–12 of 14'), findsOneWidget);
    expect(find.text('Exchange 7'), findsOneWidget);
    expect(find.text('Exchange 1'), findsNothing);

    await tester.ensureVisible(find.byTooltip('Next exchanges'));
    await tester.tap(find.byTooltip('Next exchanges'));
    await tester.pumpAndSettle();
    expect(find.text('13–14 of 14'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('Previous exchanges'));
    await tester.tap(find.byTooltip('Previous exchanges'));
    await tester.pumpAndSettle();
    expect(find.text('7–12 of 14'), findsOneWidget);
  });

  testWidgets('a short list shows no pager', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(body: PagedExchanges(exchanges: [_exchange(1), _exchange(2)])),
      ),
    );
    expect(find.byTooltip('Next exchanges'), findsNothing);
  });

  testWidgets('indices page six at a time', (tester) async {
    MarketRow row(int i) => MarketRow.fromJson({
      'id': 'i$i',
      'symbol': 'IDX$i',
      'display_symbol': 'IDX$i',
      'name': 'Index $i',
      'kind': 'index',
      'currency': 'USD',
      'data_source': 'yahoo',
      'exchange': 'NYSE',
      'exchange_name': 'New York Stock Exchange',
      'country': 'United States',
      'country_code': 'US',
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: PagedList<MarketRow>(
              items: [for (var i = 1; i <= 9; i++) row(i)],
              noun: 'indices',
              builder: (context, page) => Column(children: [for (final r in page) Text(r.info.name)]),
            ),
          ),
        ),
      ),
    );
    expect(find.text('1–6 of 9'), findsOneWidget);
    expect(find.text('Index 7'), findsNothing);
    await tester.ensureVisible(find.byTooltip('Next indices'));
    await tester.tap(find.byTooltip('Next indices'));
    await tester.pumpAndSettle();
    expect(find.text('7–9 of 9'), findsOneWidget);
    expect(find.text('Index 7'), findsOneWidget);
  });
}
