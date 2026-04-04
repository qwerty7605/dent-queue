import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/app_empty_state.dart';

void main() {
  testWidgets('renders icon, copy, and optional action button', (
    WidgetTester tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppEmptyState(
            icon: Icons.inbox_outlined,
            title: 'No data yet',
            message: 'Records will appear here when data becomes available.',
            actionLabel: 'Refresh',
            actionIcon: Icons.refresh_rounded,
            onAction: () {
              tapped = true;
            },
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    expect(find.text('No data yet'), findsOneWidget);
    expect(
      find.text('Records will appear here when data becomes available.'),
      findsOneWidget,
    );
    expect(find.text('Refresh'), findsOneWidget);

    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });
}
