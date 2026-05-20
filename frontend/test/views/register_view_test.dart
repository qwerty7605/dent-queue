import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api_exception.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/views/register_view.dart';

class _FakeAuthService extends Fake implements AuthService {
  Future<void> Function(String identifier, String password)? onLogin;
  Future<void> Function(Map<String, dynamic> payload)? onRegister;

  @override
  Future<void> login(String identifier, String password) async {
    await onLogin?.call(identifier, password);
  }

  @override
  Future<void> validateRegistrationFields(Map<String, dynamic> payload) async {}

  @override
  Future<void> register(Map<String, dynamic> payload) async {
    await onRegister?.call(payload);
  }

  @override
  Future<void> logout() async {}

  @override
  Future<Map<String, dynamic>?> me() async => null;
}

void _drainExpectedExceptions(WidgetTester tester) {
  while (tester.takeException() != null) {}
}

void _setRegistrationTermsAccepted(WidgetTester tester, bool accepted) {
  final Checkbox checkbox = tester.widget<Checkbox>(
    find.byKey(const Key('registration-terms-checkbox')),
  );
  checkbox.onChanged!(accepted);
}

void _submitRegistration(WidgetTester tester) {
  final ElevatedButton submitButton = tester.widget<ElevatedButton>(
    find.widgetWithText(ElevatedButton, 'Sign Up'),
  );
  submitButton.onPressed!();
}

void main() {
  testWidgets(
    'returns to the affected register step and shows inline email errors',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final _FakeAuthService authService = _FakeAuthService()
        ..onRegister = (Map<String, dynamic> payload) async {
          throw ApiException(
            message: 'Validation failed.',
            errors: <String, dynamic>{
              'email': <String>['Email already taken'],
            },
          );
        };

      await tester.pumpWidget(
        MaterialApp(home: RegisterView(authService: authService)),
      );
      await tester.pump();
      _drainExpectedExceptions(tester);

      Finder fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Jamie');
      await tester.enterText(fields.at(1), 'M');
      await tester.enterText(fields.at(2), 'Stone');
      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Next'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
      await tester.pumpAndSettle();
      _drainExpectedExceptions(tester);

      fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '09123456789');
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Male').last);
      await tester.pumpAndSettle();
      await tester.enterText(fields.at(1), 'Manila City');
      await tester.enterText(fields.at(2), 'taken@example.com');
      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Next'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
      await tester.pumpAndSettle();
      _drainExpectedExceptions(tester);

      fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'queued-user');
      await tester.enterText(fields.at(1), 'password123');
      await tester.enterText(fields.at(2), 'password123');
      _setRegistrationTermsAccepted(tester, true);
      await tester.pumpAndSettle();
      _submitRegistration(tester);
      await tester.pump();
      _drainExpectedExceptions(tester);

      expect(find.text('Basic Information'), findsOneWidget);
      expect(find.text('Email already taken'), findsOneWidget);

      final List<TextFormField> stepOneFields = tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .toList();
      expect(stepOneFields[2].controller!.text, 'taken@example.com');
    },
  );

  testWidgets('requires terms acceptance before submitting registration', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Map<String, dynamic>? submittedPayload;
    final _FakeAuthService authService = _FakeAuthService()
      ..onRegister = (Map<String, dynamic> payload) async {
        submittedPayload = Map<String, dynamic>.from(payload);
      };

    await tester.pumpWidget(
      MaterialApp(home: RegisterView(authService: authService)),
    );
    await tester.pump();
    _drainExpectedExceptions(tester);

    Finder fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Jamie');
    await tester.enterText(fields.at(1), 'M');
    await tester.enterText(fields.at(2), 'Stone');
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Next'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
    await tester.pumpAndSettle();
    _drainExpectedExceptions(tester);

    fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '09123456789');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Male').last);
    await tester.pumpAndSettle();
    await tester.enterText(fields.at(1), 'Manila City');
    await tester.enterText(fields.at(2), 'jamie@example.com');
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Next'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
    await tester.pumpAndSettle();
    _drainExpectedExceptions(tester);

    fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'queued-user');
    await tester.enterText(fields.at(1), 'password123');
    await tester.enterText(fields.at(2), 'password123');

    _submitRegistration(tester);
    await tester.pump();

    expect(submittedPayload, isNull);
    expect(
      find.text('You must accept the Terms and Conditions to continue.'),
      findsOneWidget,
    );

    _setRegistrationTermsAccepted(tester, true);
    await tester.pumpAndSettle();
    _submitRegistration(tester);
    await tester.pump();

    expect(submittedPayload, isNotNull);
    expect(submittedPayload!['terms_accepted'], isTrue);
  });
}
