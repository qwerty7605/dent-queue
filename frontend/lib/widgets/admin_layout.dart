import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/config.dart';
import '../models/admin_ui_notification.dart';

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
  });

  final Widget child;
  final String activeRoute;
  final Map<String, dynamic>? userInfo;
  final VoidCallback onLogout;
  final bool loggingOut;
  final List<AdminUiNotification> notifications;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final name = userInfo?['name']?.toString() ?? 'ADMIN';
    final String? profilePic = userInfo?['profile_picture']?.toString();
    final bool hasProfilePic = profilePic != null && profilePic.isNotEmpty && profilePic != 'null' && profilePic != '/storage/';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Light off-white background
      body: Row(
        children: [
          // Left Sidebar
          Container(
            width: 250,
            color: const Color(0xFF679B6A), // Dark Green
            child: Column(
              children: [
                // Logo Header
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/images/logo.png',
                        width: 40,
                        height: 40,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'SMART',
                                style: TextStyle(
                                  color: Color(0xFFE8C355),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              TextSpan(
                                text: 'DentQueue',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white30, height: 1, thickness: 1),
                const SizedBox(height: 16),
                
                // Sidebar Navigation Items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    children: [
                      _buildSidebarItem(context, 'Dashboard', Icons.home),
                      _buildSidebarItem(context, 'Patients', Icons.badge_outlined),
                      _buildSidebarItem(context, 'Staff', Icons.medical_services_outlined),
                      _buildSidebarItem(context, 'Master List', Icons.list_alt),
                      _buildSidebarItem(context, 'Settings', Icons.settings),
                      _buildSidebarItem(context, 'Profile', Icons.person_outline),
                    ],
                  ),
                ),
                
                // Log out
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 24.0),
                  child: InkWell(
                    onTap: loggingOut ? null : onLogout,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                      child: Row(
                        children: [
                          if (loggingOut)
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          else
                            const Icon(Icons.logout, color: Colors.white, size: 24),
                          const SizedBox(width: 16),
                          const Text(
                            'Log out',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
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
          
          // Main Area
          Expanded(
            child: Column(
              children: [
                // Top Right App Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF679B6A),
                    border: const Border(
                      bottom: BorderSide(color: Color(0xFFE8C355), width: 4),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Notification Bell
                      IconButton(
                        onPressed: () => _showNotificationsDialog(context),
                        icon: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(Icons.notifications_none, color: Colors.white),
                            if (notifications.isNotEmpty)
                              Positioned(
                                right: -4,
                                top: -4,
                                child: Container(
                                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8C355),
                                    borderRadius: BorderRadius.circular(999),
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
                      const SizedBox(width: 16),
                      // Admin Account Chip
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'ADMIN',
                                  style: TextStyle(
                                    color: Color(0xFFE8C355),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  name.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.white,
                              backgroundImage: hasProfilePic 
                                  ? NetworkImage('${AppConfig.baseUrl}$profilePic') 
                                  : null,
                              child: !hasProfilePic 
                                  ? const Icon(Icons.person, color: Colors.grey, size: 24)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Page Content
                Expanded(
                  child: child,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(BuildContext context, String title, IconData icon) {
    final isActive = activeRoute == title;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Material(
        color: isActive ? Colors.white.withValues(alpha: 0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => onNavigate(title),
          borderRadius: BorderRadius.circular(8),
          hoverColor: Colors.white.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
                  ),
                ),
              ],
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
                    const Icon(Icons.notifications_active_outlined, color: Color(0xFF497A52)),
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
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F7F4),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'No notifications yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF607063),
                      ),
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
                              border: Border.all(color: const Color(0xFFD9E4DA)),
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
