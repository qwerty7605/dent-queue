import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/app_dialog_scaffold.dart';

void main() {
  testWidgets('renders a consistent header, body, footer, and close action', (
    WidgetTester tester,
  ) async {
    int closeCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppDialogScaffold(
            title: 'Dialog Title',
            subtitle: 'Dialog subtitle',
            headerTrailing: const Text('STATUS'),
            onClose: () => closeCount += 1,
            footer: const Text('Footer action'),
            child: const Text('Dialog body'),
          ),
        ),
      ),
    );

    expect(find.text('Dialog Title'), findsOneWidget);
    expect(find.text('Dialog subtitle'), findsOneWidget);
    expect(find.text('STATUS'), findsOneWidget);
    expect(find.text('Dialog body'), findsOneWidget);
    expect(find.text('Footer action'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pump();

    expect(closeCount, 1);
  });

  testWidgets(
    'supports headerless dialog content when only body and footer are needed',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppDialogScaffold(
              footer: Text('Done'),
              child: Text('Success content'),
            ),
          ),
        ),
      );

      expect(find.text('Success content'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.byTooltip('Close'), findsNothing);
    },
  );
}
