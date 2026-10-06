import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilowatts_mobile/core/widgets/metric_card.dart';
import 'package:kilowatts_mobile/core/widgets/status_badge.dart';

void main() {
  testWidgets('MetricCard exposes one useful semantic value', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MetricCard(
            label: 'Active load power',
            value: '250',
            unit: 'W',
            icon: Icons.bolt_outlined,
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Active load power: 250 W'), findsOneWidget);
  });

  testWidgets('StatusBadge exposes status text independent of colour', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatusBadge(label: 'Offline', tone: StatusTone.negative),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Offline'), findsOneWidget);
    expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);
  });
}
