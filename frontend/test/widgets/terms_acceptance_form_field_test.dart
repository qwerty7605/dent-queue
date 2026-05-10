import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/terms_acceptance_form_field.dart';

void main() {
  testWidgets('validates acceptance and opens terms dialog', (
    WidgetTester tester,
  ) async {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    bool accepted = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Form(
                key: formKey,
                child: Column(
                  children: <Widget>[
                    TermsAcceptanceFormField(
                      value: accepted,
                      checkboxKey: const Key('terms-test-checkbox'),
                      linkKey: const Key('terms-test-link'),
                      textColor: Colors.black87,
                      linkColor: Colors.blue,
                      onChanged: (bool value) {
                        setState(() {
                          accepted = value;
                        });
                      },
                    ),
                    ElevatedButton(
                      onPressed: () => formKey.currentState!.validate(),
                      child: const Text('Submit'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Submit'));
    await tester.pump();

    expect(
      find.text('You must accept the Terms and Conditions to continue.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('terms-test-link')));
    await tester.pumpAndSettle();

    expect(find.text('Terms and Conditions'), findsWidgets);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('terms-test-checkbox')));
    await tester.pump();
    await tester.tap(find.text('Submit'));
    await tester.pump();

    expect(accepted, isTrue);
    expect(
      find.text('You must accept the Terms and Conditions to continue.'),
      findsNothing,
    );
  });
}
