import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api_exception.dart';
import 'package:frontend/core/token_storage.dart';
import 'package:frontend/services/admin_profile_service.dart';
import 'package:frontend/views/admin_profile_view.dart';

class _FakeAdminProfileService extends Fake implements AdminProfileService {
  Future<Map<String, dynamic>> Function(Map<String, dynamic> data)? onUpdate;

  @override
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    if (onUpdate != null) {
      return onUpdate!(data);
    }
    return <String, dynamic>{};
  }
}

void main() {
  testWidgets('shows inline admin profile username errors and keeps edits', (
    WidgetTester tester,
  ) async {
    final InMemoryTokenStorage tokenStorage = InMemoryTokenStorage();
    await tokenStorage.writeUserInfo(<String, dynamic>{
      'first_name': 'Admin',
      'last_name': 'User',
      'username': 'admin.user',
    });

    final _FakeAdminProfileService adminProfileService =
        _FakeAdminProfileService()
          ..onUpdate = (Map<String, dynamic> data) async {
            throw ApiException(
              message: 'Validation failed.',
              errors: <String, dynamic>{
                'username': <String>['Username is already taken'],
              },
            );
          };

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminProfileView(
            activeUser: <String, dynamic>{
              'first_name': 'Admin',
              'last_name': 'User',
              'username': 'admin.user',
            },
            tokenStorage: tokenStorage,
            adminProfileService: adminProfileService,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit Profile'));
    await tester.pump();
    await tester.tap(find.text('CHANGE USERNAME'));
    await tester.pump();

    final Finder usernameField = find.byType(TextFormField).at(2);
    await tester.enterText(usernameField, 'taken-name');
    await tester.tap(find.text('Save Changes'));
    await tester.pump();

    expect(find.text('Username is already taken'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(2))
          .controller!
          .text,
      'taken-name',
    );
  });
}
