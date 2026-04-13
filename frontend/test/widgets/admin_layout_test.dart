import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/admin_ui_notification.dart';
import 'package:frontend/widgets/admin_layout.dart';

void main() {
  testWidgets('admin layout keeps header and sidebar navigation in sync', (
    WidgetTester tester,
  ) async {
    String? navigatedRoute;

    await tester.pumpWidget(
      MaterialApp(
        home: AdminLayout(
          activeRoute: 'Dashboard',
          userInfo: const <String, dynamic>{'name': 'Alex Stone'},
          onLogout: () {},
          loggingOut: false,
          notifications: const <AdminUiNotification>[],
          onNavigate: (String route) {
            navigatedRoute = route;
          },
          sidebarCounts: const <String, int>{'Patients': 3},
          child: const SizedBox.expand(),
        ),
      ),
    );

    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Admin module'), findsOneWidget);
    expect(find.text('Patients (3)'), findsOneWidget);

    await tester.tap(find.text('Patients (3)'));
    expect(navigatedRoute, 'Patients');

    await tester.tap(find.text('ALEX STONE'));
    expect(navigatedRoute, 'Profile');
  });
}
