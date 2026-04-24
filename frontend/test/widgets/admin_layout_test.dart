import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/admin_ui_notification.dart';
import 'package:frontend/widgets/admin_layout.dart';

class _ThemeProbeCard extends StatelessWidget {
  const _ThemeProbeCard();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ColoredBox(
      key: const Key('theme-probe-card'),
      color: theme.colorScheme.surface,
      child: Text(
        theme.brightness == Brightness.dark ? 'dark' : 'light',
        textDirection: TextDirection.ltr,
      ),
    );
  }
}

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
          isDarkMode: false,
          onToggleDarkMode: () {},
          onNavigate: (String route) {
            navigatedRoute = route;
          },
          sidebarCounts: const <String, int>{'Patients': 3},
          child: const SizedBox.expand(),
        ),
      ),
    );

    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('CLINIC PERFORMANCE & LIVE STATS'), findsOneWidget);
    expect(find.text('Patient Accounts'), findsOneWidget);

    await tester.tap(find.text('Patient Accounts'));
    expect(navigatedRoute, 'Patients');

    await tester.tap(find.text('Alex Stone'));
    expect(navigatedRoute, 'Profile');
  });

  testWidgets('admin layout resets child theme when switching back to light', (
    WidgetTester tester,
  ) async {
    Widget buildLayout(bool isDarkMode) {
      return MaterialApp(
        home: AdminLayout(
          activeRoute: 'Dashboard',
          userInfo: const <String, dynamic>{'name': 'Alex Stone'},
          onLogout: () {},
          loggingOut: false,
          notifications: const <AdminUiNotification>[],
          isDarkMode: isDarkMode,
          onToggleDarkMode: () {},
          onNavigate: (_) {},
          child: const _ThemeProbeCard(),
        ),
      );
    }

    await tester.pumpWidget(buildLayout(true));
    await tester.pumpAndSettle();

    expect(find.text('dark'), findsOneWidget);

    await tester.pumpWidget(buildLayout(false));
    await tester.pumpAndSettle();

    expect(find.text('light'), findsOneWidget);
    final ColoredBox probe = tester.widget(
      find.byKey(const Key('theme-probe-card')),
    );
    expect(probe.color, Colors.white);
  });
}
