import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tickizer/main.dart';

void main() {
  testWidgets('App boots to the dashboard with bottom navigation', (WidgetTester tester) async {
    await tester.pumpWidget(const TickizerApp());
    await tester.pump();

    expect(find.text('Market summary'), findsOneWidget);
    expect(find.byIcon(Icons.show_chart), findsOneWidget);
    expect(find.byIcon(Icons.tune), findsOneWidget);
  });
}
