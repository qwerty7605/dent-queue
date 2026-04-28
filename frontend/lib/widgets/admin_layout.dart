import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_theme.dart';
import '../core/config.dart';
import '../models/admin_ui_notification.dart';
import 'app_dialog_scaffold.dart';
import 'app_empty_state.dart';

class AdminLayout extends StatelessWidget {
  const AdminLayout({
    super.key,
    required this.child,
    required this.activeRoute,
    required this.userInfo,
    required this.onLogout,
    required this.loggingOut,
    required this.notifications,
    required this.onNavigate,
    required this.isDarkMode,
    required this.onToggleDarkMode,
    this.sidebarCounts = const <String, int>{},
  });

  static const Color _sidebarColor = Color(0xFF20386F);
  static const Color _sidebarColorAlt = Color(0xFF263F79);
  static const Color _sidebarMuted = Color(0xFFA8B8DF);
  static const Color _sidebarActive = Color(0xFF3A4F87);
  static const Color _sidebarActiveBorder = Color(0xFF4C6299);
  static const Color _surfaceColor = Colors.white;
  static const Color _canvasColor = Color(0xFFF3F6FC);
  static const Color _outlineColor = Color(0xFFE1E8F4);
  static const Color _textColor = Color(0xFF1D3264);
  static const Color _mutedTextColor = Color(0xFF90A0BF);
  static const Color _badgeColor = Color(0xFFEC4F5B);

  final Widget child;
  final String activeRoute;
  final Map<String, dynamic>? userInfo;
  final VoidCallback onLogout;
  final bool loggingOut;
  final List<AdminUiNotification> notifications;
  final ValueChanged<String> onNavigate;
  final bool isDarkMode;
  final VoidCallback onToggleDarkMode;
  final Map<String, int> sidebarCounts;

  Color get _surfaceColorValue =>
      isDarkMode ? const Color(0xFF141C2E) : _surfaceColor;

  Color get _canvasColorValue =>
      isDarkMode ? const Color(0xFF0C1220) : _canvasColor;

  Color get _surfaceAltColorValue =>
      isDarkMode ? const Color(0xFF1A253A) : const Color(0xFFF8FAFE);

  Color get _outlineColorValue =>
      isDarkMode ? const Color(0xFF2B3956) : _outlineColor;

  Color get _textColorValue =>
      isDarkMode ? const Color(0xFFE8EEF9) : _textColor;

  Color get _mutedTextColorValue =>
      isDarkMode ? const Color(0xFF9DACCA) : _mutedTextColor;

  Color get _sidebarStartColor =>
      isDarkMode ? const Color(0xFF111827) : _sidebarColor;

  Color get _sidebarEndColor =>
      isDarkMode ? const Color(0xFF172235) : _sidebarColorAlt;

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.sizeOf(context);
    final bool compactSidebar = screenSize.width < 720;
    final ThemeData contentTheme =
        buildSmartDentTheme(
          brightness: isDarkMode ? Brightness.dark : Brightness.light,
        ).copyWith(
          scaffoldBackgroundColor: _canvasColorValue,
          canvasColor: _canvasColorValue,
          dialogTheme:
              buildSmartDentTheme(
                brightness: isDarkMode ? Brightness.dark : Brightness.light,
              ).dialogTheme.copyWith(
                backgroundColor: _surfaceColorValue,
                surfaceTintColor: _surfaceColorValue,
              ),
        );
    final String name = userInfo?['name']?.toString().trim().isNotEmpty == true
        ? userInfo!['name'].toString().trim()
        : 'Admin User';
    final String? profilePic = userInfo?['profile_picture']?.toString();
    final bool hasProfilePic =
        profilePic != null &&
        profilePic.isNotEmpty &&
        profilePic != 'null' &&
        profilePic != '/storage/';

    return Scaffold(
      backgroundColor: _canvasColorValue,
      body: SafeArea(
        child: Row(
          children: [
            _buildSidebar(context, compactSidebar),
            Expanded(
              child: Column(
                children: [
                  _buildHeader(
                    context,
                    name: name,
                    profilePic: profilePic,
                    hasProfilePic: hasProfilePic,
                  ),
                  Expanded(
                    child: Theme(
                      data: contentTheme,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: <Color>[
                              _canvasColorValue,
                              _surfaceAltColorValue,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: ClipRect(
                          child: KeyedSubtree(
                            key: ValueKey<String>(
                              '${activeRoute}_${isDarkMode ? 'dark' : 'light'}',
                            ),
                            child: child,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, bool compactSidebar) {
    final double width = compactSidebar ? 90 : 256;

    return Container(
      width: width,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[_sidebarStartColor, _sidebarEndColor],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              compactSidebar ? 10 : 16,
              18,
              compactSidebar ? 10 : 16,
              14,
            ),
            child: compactSidebar ? _buildCompactBrand() : _buildBrandLockup(),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                compactSidebar ? 8 : 10,
                10,
                compactSidebar ? 8 : 10,
                16,
              ),
              children: [
                _buildSidebarItem(
                  context,
                  route: 'Dashboard',
                  label: 'Dashboard',
                  icon: Icons.dashboard_outlined,
                  compactSidebar: compactSidebar,
                ),
                _buildSidebarItem(
                  context,
                  route: 'Patients',
                  label: 'Patient Accounts',
                  icon: Icons.groups_outlined,
                  compactSidebar: compactSidebar,
                ),
                _buildSidebarItem(
                  context,
                  route: 'Staff',
                  label: 'Staff Registry',
                  icon: Icons.person_outline_rounded,
                  compactSidebar: compactSidebar,
                ),
                _buildSidebarItem(
                  context,
                  route: 'Appointments',
                  label: 'Appointments',
                  icon: Icons.assignment_outlined,
                  compactSidebar: compactSidebar,
                ),
                _buildSidebarItem(
                  context,
                  route: 'Reports',
                  label: 'Reports',
                  icon: Icons.bar_chart_outlined,
                  compactSidebar: compactSidebar,
                ),
                _buildSidebarItem(
                  context,
                  route: 'Settings',
                  label: 'Settings',
                  icon: Icons.settings_outlined,
                  compactSidebar: compactSidebar,
                ),
                _buildSidebarItem(
                  context,
                  route: 'Profile',
                  label: 'Profile',
                  icon: Icons.account_circle_outlined,
                  compactSidebar: compactSidebar,
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              compactSidebar ? 8 : 12,
              18,
              compactSidebar ? 8 : 12,
              20,
            ),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: loggingOut ? null : onLogout,
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: compactSidebar ? 0 : 14,
                  ),
                  child: Row(
                    mainAxisAlignment: compactSidebar
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.start,
                    children: [
                      if (loggingOut)
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      else
                        const Icon(
                          Icons.logout_rounded,
                          color: Color(0xFFFF8C88),
                          size: 22,
                        ),
                      if (!compactSidebar) ...[
                        const SizedBox(width: 14),
                        const Text(
                          'Logout',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandLockup() {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1A253A) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: isDarkMode
                ? Border.all(color: Colors.white.withValues(alpha: 0.08))
                : null,
          ),
          child: Center(
            child: Image.asset(
              'assets/images/logo_blue.png',
              width: 30,
              height: 30,
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SmartDentQueue',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'ADMIN SYSTEM',
                style: TextStyle(
                  color: _sidebarMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactBrand() {
    return Center(
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1A253A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isDarkMode
              ? Border.all(color: Colors.white.withValues(alpha: 0.08))
              : null,
        ),
        child: Center(
          child: Image.asset(
            'assets/images/logo_blue.png',
            width: 28,
            height: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context, {
    required String name,
    required String? profilePic,
    required bool hasProfilePic,
  }) {
    final String title = activeRoute == 'Dashboard'
        ? 'Dashboard Overview'
        : _routeLabel(activeRoute);
    final String subtitle = switch (activeRoute) {
      'Dashboard' => 'CLINIC PERFORMANCE & LIVE STATS',
      'Patients' => 'PATIENT RECORD MANAGEMENT',
      'Staff' =>
        'PROVISION AND MANAGE CLINICAL PERSONNEL ACCESS AND ACCOUNT DISTRIBUTIONS.',
      'Appointments' => 'REAL-TIME CLINICAL SYNCHRONIZATION',
      'Reports' =>
        'COMPREHENSIVE ANALYTICS FOR YOUR CLINIC'
            'S GROWTH AND OPERATIONAL HEALTH.',
      'Settings' =>
        'GRANULAR CONTROL OVER OPERATIONAL LOGIC, SCHEDULING WINDOWS, AND PRACTICE-WIDE SECURITY RULES.',
      'Profile' => 'ACCOUNT DETAILS & PERSONALIZATION',
      _ => 'ADMIN PANEL',
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 16),
      decoration: BoxDecoration(
        color: _surfaceColorValue,
        border: Border(bottom: BorderSide(color: _outlineColorValue)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: _textColorValue,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: _mutedTextColorValue,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _buildThemeToggleButton(),
          const SizedBox(width: 12),
          _buildNotificationButton(context),
          const SizedBox(width: 16),
          _buildProfileCard(
            name: name,
            roleLabel: _resolveRoleLabel(),
            profilePic: profilePic,
            hasProfilePic: hasProfilePic,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showNotificationsDialog(context),
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isDarkMode
                ? const Color(0xFF1A253A)
                : const Color(0xFFF4F7FD),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _outlineColorValue),
            boxShadow: [
              BoxShadow(
                color: Color(0x080E1A3A),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Icon(
                  Icons.notifications_none_rounded,
                  color: _textColorValue,
                  size: 23,
                ),
              ),
              if (notifications.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 7,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: _badgeColor,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      notifications.length > 9
                          ? '9+'
                          : notifications.length.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeToggleButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggleDarkMode,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isDarkMode
                ? const Color(0xFF1A253A)
                : const Color(0xFFF4F7FD),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _outlineColorValue),
            boxShadow: const [
              BoxShadow(
                color: Color(0x080E1A3A),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: _textColorValue,
              size: 21,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard({
    required String name,
    required String roleLabel,
    required String? profilePic,
    required bool hasProfilePic,
  }) {
    final String initial = name.isNotEmpty ? name.characters.first : 'A';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onNavigate('Profile'),
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _surfaceColorValue,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _outlineColorValue),
            boxShadow: const [
              BoxShadow(
                color: Color(0x080E1A3A),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _textColorValue,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    roleLabel,
                    style: TextStyle(
                      color: _mutedTextColorValue,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.6,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              CircleAvatar(
                radius: 22,
                backgroundColor: isDarkMode
                    ? const Color(0xFF24324B)
                    : const Color(0xFFEAF0FF),
                backgroundImage: hasProfilePic
                    ? NetworkImage('${AppConfig.baseUrl}$profilePic')
                    : null,
                child: hasProfilePic
                    ? null
                    : Text(
                        initial.toUpperCase(),
                        style: TextStyle(
                          color: _textColorValue,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarItem(
    BuildContext context, {
    required String route,
    required String label,
    required IconData icon,
    required bool compactSidebar,
    String labelSuffix = '',
  }) {
    final bool isActive = activeRoute == route;
    final Widget content = Container(
      height: 50,
      decoration: BoxDecoration(
        color: isActive
            ? _sidebarActive.withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? _sidebarActiveBorder
              : Colors.white.withValues(alpha: 0.03),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: compactSidebar ? 0 : 14),
      child: Row(
        mainAxisAlignment: compactSidebar
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: [
          Icon(icon, color: isActive ? Colors.white : _sidebarMuted, size: 22),
          if (!compactSidebar) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$label$labelSuffix',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isActive ? Colors.white : _sidebarMuted,
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Tooltip(
        message: '$label$labelSuffix',
        waitDuration: const Duration(milliseconds: 400),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onNavigate(route),
            borderRadius: BorderRadius.circular(18),
            child: content,
          ),
        ),
      ),
    );
  }

  String _routeLabel(String route) {
    return switch (route) {
      'Patients' => 'Patient Accounts',
      'Staff' => 'Staff Management',
      'Reports' => 'Clinical Intelligence',
      'Settings' => 'Clinic Configuration',
      _ => route,
    };
  }

  String _resolveRoleLabel() {
    final String? directRole = userInfo?['role']?.toString().trim();
    final String? namedRole = userInfo?['role_name']?.toString().trim();
    final String resolved =
        (namedRole?.isNotEmpty == true ? namedRole : directRole) ?? 'Admin';
    return resolved.toUpperCase();
  }

  Future<void> _showNotificationsDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        final ThemeData dialogTheme = buildSmartDentTheme(
          brightness: isDarkMode ? Brightness.dark : Brightness.light,
        ).copyWith(
          dialogTheme: buildSmartDentTheme(
            brightness: isDarkMode ? Brightness.dark : Brightness.light,
          ).dialogTheme.copyWith(
            backgroundColor: _surfaceColorValue,
            surfaceTintColor: _surfaceColorValue,
          ),
        );
        final DateFormat formatter = DateFormat('MMM d, h:mm a');
        final ThemeData theme = dialogTheme;
        final bool isDark = isDarkMode;
        final Color dialogFill = isDark
            ? const Color(0xFF1A253A)
            : const Color(0xFFF5F7FC);
        final Color dialogBorder = isDark
            ? const Color(0xFF30415F)
            : const Color(0xFFE3E8F4);

        return Theme(
          data: dialogTheme,
          child: AppDialogScaffold(
            maxWidth: 460,
            bodyPadding: const EdgeInsets.only(top: 16),
            headerContent: Row(
              children: [
                Icon(
                  Icons.notifications_active_outlined,
                  color: theme.colorScheme.onSurface,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            onClose: () => Navigator.of(context).pop(),
            child: notifications.isEmpty
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 24,
                    ),
                    decoration: BoxDecoration(
                      color: dialogFill,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const AppEmptyState(
                      icon: Icons.notifications_off_outlined,
                      title: 'No notifications right now',
                      message:
                          'New admin updates and reminders will appear here.',
                      framed: false,
                      compact: true,
                    ),
                  )
                : Column(
                    children: notifications.map((
                      AdminUiNotification notification,
                    ) {
                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: dialogFill,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: dialogBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notification.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              notification.message,
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              formatter.format(notification.createdAt),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        );
      },
    );
  }
}
