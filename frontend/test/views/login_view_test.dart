import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api_exception.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/views/login_view.dart';

class _FakeAuthService extends Fake implements AuthService {
  Future<void> Function(String identifier, String password)? onLogin;
  Future<void> Function(Map<String, dynamic> payload)? onRegister;

  @override
  Future<void> login(String identifier, String password) async {
    await onLogin?.call(identifier, password);
  }

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

void main() {
  testWidgets(
    'shows inline login field errors from API responses and keeps input',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final _FakeAuthService authService = _FakeAuthService()
        ..onLogin = (String identifier, String password) async {
          throw ApiException(
            message: 'Validation failed.',
            errors: <String, dynamic>{
              'username': <String>['Username is required'],
            },
          );
        };

      await tester.pumpWidget(
        MaterialApp(home: LoginView(authService: authService)),
      );
      await tester.pump();
      _drainExpectedExceptions(tester);

      final Finder fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'queued.user');
      await tester.enterText(fields.at(1), 'secret123');

      await tester.ensureVisible(find.text('Sign In'));
      await tester.tap(find.text('Sign In'));
      await tester.pump();
      _drainExpectedExceptions(tester);

      expect(find.text('Username is required'), findsOneWidget);

      final List<TextFormField> updatedFields = tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .toList();
      expect(updatedFields[0].controller!.text, 'queued.user');
      expect(updatedFields[1].controller!.text, 'secret123');
    },
  );
}
