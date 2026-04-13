import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/config.dart';
import '../models/admin_ui_notification.dart';
import 'app_empty_state.dart';
import 'navigation_chrome.dart';

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
    this.sidebarCounts = const <String, int>{},
  });

  final Widget child;
  final String activeRoute;
  final Map<String, dynamic>? userInfo;
  final VoidCallback onLogout;
  final bool loggingOut;
  final List<AdminUiNotification> notifications;
  final ValueChanged<String> onNavigate;
  final Map<String, int> sidebarCounts;

  @override
  Widget build(BuildContext context) {
    final name = userInfo?['name']?.toString() ?? 'ADMIN';
    final String? profilePic = userInfo?['profile_picture']?.toString();
    final bool hasProfilePic =
        profilePic != null &&
        profilePic.isNotEmpty &&
        profilePic != 'null' &&
        profilePic != '/storage/';

    return Scaffold(
      backgroundColor: AppNavigationTheme.background,
      body: Row(
        children: [
          Container(
            width: 258,
            color: AppNavigationTheme.primary,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 18,
                  ),
                  child: const Align(
                    alignment: Alignment.centerLeft,
                    child: AppBrandLockup(
                      logoSize: 42,
                      smartFontSize: 16,
                      dentQueueFontSize: 16,
                      spacing: 10,
                    ),
                  ),
                ),
                const Divider(color: Colors.white24, height: 1, thickness: 1),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      _buildSidebarItem(context, 'Dashboard', Icons.home),
                      _buildSidebarItem(
                        context,
                        'Patients',
                        Icons.badge_outlined,
                        labelSuffix: _formatSidebarCount(
                          sidebarCounts['Patients'],
                        ),
                      ),
                      _buildSidebarItem(
                        context,
                        'Staff',
                        Icons.medical_services_outlined,
                        labelSuffix: _formatSidebarCount(
                          sidebarCounts['Staff'],
                        ),
                      ),
                      _buildSidebarItem(context, 'Master List', Icons.list_alt),
                      _buildSidebarItem(
                        context,
                        'Reports',
                        Icons.analytics_outlined,
                      ),
                      _buildSidebarItem(context, 'Settings', Icons.settings),
                      _buildSidebarItem(
                        context,
                        'Profile',
                        Icons.person_outline,
                      ),
                    ],
                  ),
                ),

                // Log out
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 24,
                  ),
                  child: InkWell(
                    onTap: loggingOut ? null : onLogout,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                      ),
                      child: Row(
                        children: [
                          if (loggingOut)
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          else
                            const Icon(
                              Icons.logout,
                              color: Colors.white,
                              size: 24,
                            ),
                          const SizedBox(width: 16),
                          const Text(
                            'Log out',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    color: AppNavigationTheme.primary,
                    border: const Border(
                      bottom: BorderSide(
                        color: AppNavigationTheme.accent,
                        width: 4,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activeRoute,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Admin module',
                              style: TextStyle(
                                color: AppNavigationTheme.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.55,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => _showNotificationsDialog(context),
                            icon: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                const Icon(
                                  Icons.notifications_none,
                                  color: Colors.white,
                                ),
                                if (notifications.isNotEmpty)
                                  Positioned(
                                    right: -4,
                                    top: -4,
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        minWidth: 18,
                                        minHeight: 18,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE8C355),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          notifications.length.toString(),
                                          style: const TextStyle(
                                            color: Color(0xFF1F2A22),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            tooltip: 'Notifications',
                          ),
                          const SizedBox(width: 12),
                          AppUserChip(
                            width: 188,
                            name: name.toUpperCase(),
                            roleLabel: 'ADMIN',
                            profileImage: hasProfilePic
                                ? NetworkImage(
                                    '${AppConfig.baseUrl}$profilePic',
                                  )
                                : null,
                            onTap: () => onNavigate('Profile'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Page Content
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatSidebarCount(int? count) {
    return count == null ? '' : ' ($count)';
  }

  Widget _buildSidebarItem(
    BuildContext context,
    String title,
    IconData icon, {
    String labelSuffix = '',
  }) {
    final isActive = activeRoute == title;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isActive
            ? Colors.white.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => onNavigate(title),
          borderRadius: BorderRadius.circular(16),
          hoverColor: Colors.white.withValues(alpha: 0.08),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isActive
                    ? AppNavigationTheme.accent.withValues(alpha: 0.55)
                    : Colors.transparent,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppNavigationTheme.accent
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Icon(
                    icon,
                    color: Colors.white.withValues(alpha: isActive ? 1 : 0.88),
                    size: 22,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      '$title$labelSuffix',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: isActive
                            ? FontWeight.w900
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showNotificationsDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        final formatter = DateFormat('MMM d, h:mm a');

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.notifications_active_outlined,
                      color: Color(0xFF497A52),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Notifications',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1F2A22),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (notifications.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 24,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F7F4),
                      borderRadius: BorderRadius.circular(14),
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
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: SingleChildScrollView(
                      child: Column(
                        children: notifications.map((notification) {
                          return Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F7F4),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFD9E4DA),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  notification.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1F2A22),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  notification.message,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF4E5A50),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  formatter.format(notification.createdAt),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF768279),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
