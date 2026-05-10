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
  testWidgets(
    'keeps account credentials hidden until edit actions are opened',
    (WidgetTester tester) async {
      final InMemoryTokenStorage tokenStorage = InMemoryTokenStorage();
      await tokenStorage.writeUserInfo(<String, dynamic>{
        'first_name': 'Admin',
        'last_name': 'User',
        'username': 'admin.user',
      });

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
              adminProfileService: _FakeAdminProfileService(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('admin.user'), findsNothing);
      expect(find.text('********'), findsNothing);
      expect(
        find.byKey(const Key('admin-profile-change-username-field')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('admin-profile-change-username-password-field')),
        findsNothing,
      );
      expect(find.text('Change Username'), findsOneWidget);
      expect(find.text('Change Password'), findsOneWidget);

      await tester.tap(find.text('Change Username'));
      await tester.pumpAndSettle();

      expect(find.text('Current username'), findsOneWidget);
      expect(find.text('admin.user'), findsOneWidget);
      expect(
        find.byKey(const Key('admin-profile-change-username-field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('admin-profile-change-username-password-field')),
        findsOneWidget,
      );
    },
  );

  testWidgets('obscures password text while changing password', (
    WidgetTester tester,
  ) async {
    final InMemoryTokenStorage tokenStorage = InMemoryTokenStorage();
    await tokenStorage.writeUserInfo(<String, dynamic>{
      'first_name': 'Admin',
      'last_name': 'User',
      'username': 'admin.user',
    });

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
            adminProfileService: _FakeAdminProfileService(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Change Password'));
    await tester.pump();

    final Finder passwordField = find.byKey(
      const Key('admin-profile-password-field'),
    );
    expect(passwordField, findsOneWidget);
    final EditableText editablePasswordField = tester.widget<EditableText>(
      find.descendant(of: passwordField, matching: find.byType(EditableText)),
    );
    expect(editablePasswordField.obscureText, isTrue);

    await tester.enterText(passwordField, 'new-password123');
    await tester.pump();
  });

  testWidgets('submits username change with password without profile fields', (
    WidgetTester tester,
  ) async {
    final InMemoryTokenStorage tokenStorage = InMemoryTokenStorage();
    await tokenStorage.writeUserInfo(<String, dynamic>{
      'first_name': 'Admin',
      'last_name': 'User',
      'username': 'admin.user',
    });

    Map<String, dynamic>? submittedPayload;
    Map<String, dynamic>? updatedProfile;
    final _FakeAdminProfileService adminProfileService =
        _FakeAdminProfileService()
          ..onUpdate = (Map<String, dynamic> data) async {
            submittedPayload = Map<String, dynamic>.from(data);
            return <String, dynamic>{
              'user': <String, dynamic>{
                'first_name': 'Admin',
                'last_name': 'User',
                'username': 'new.admin',
              },
            };
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
            onProfileUpdated: (Map<String, dynamic> user) {
              updatedProfile = user;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Change Username'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('admin-profile-change-username-field')),
      'new.admin',
    );
    await tester.enterText(
      find.byKey(const Key('admin-profile-change-username-password-field')),
      'password123',
    );
    await tester.tap(find.text('Save Username'));
    await tester.pumpAndSettle();

    expect(submittedPayload, isNotNull);
    expect(submittedPayload!['username'], 'new.admin');
    expect(submittedPayload!['current_password'], 'password123');
    expect(submittedPayload!.containsKey('first_name'), isFalse);
    expect(submittedPayload!.containsKey('last_name'), isFalse);
    expect(updatedProfile?['username'], 'new.admin');
    expect(find.text('Username updated successfully.'), findsOneWidget);
  });

  testWidgets('shows change username modal errors and keeps edits', (
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

    await tester.tap(find.text('Change Username'));
    await tester.pumpAndSettle();

    final Finder usernameField = find.byKey(
      const Key('admin-profile-change-username-field'),
    );
    await tester.enterText(usernameField, 'taken-name');
    await tester.enterText(
      find.byKey(const Key('admin-profile-change-username-password-field')),
      'password123',
    );
    await tester.tap(find.text('Save Username'));
    await tester.pump();

    expect(find.text('Username is already taken'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('admin-profile-change-username-field')),
          )
          .controller!
          .text,
      'taken-name',
    );
  });
}
