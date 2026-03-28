import 'package:flutter/material.dart';

class NotificationsView extends StatefulWidget {
  const NotificationsView({super.key});

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  // Mock data representing notifications from an API
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 600));

    // Mock data based on requirements
    if (mounted) {
      setState(() {
        _notifications = [
          {
            'id': 1,
            'title': 'Appointment Approved',
            'message': 'Your appointment for Dental Cleaning has been approved.',
            'type': 'approved',
            'date': DateTime.now().subtract(const Duration(minutes: 5)),
            'is_read': false,
          },
          {
            'id': 2,
            'title': 'Queue Update',
            'message': 'You are next in line. Please proceed to the clinic.',
            'type': 'queue',
            'date': DateTime.now().subtract(const Duration(hours: 1)),
            'is_read': false,
          },
          {
            'id': 3,
            'title': 'Appointment Reminder',
            'message': 'Reminder: You have an upcoming appointment tomorrow at 10:00 AM.',
            'type': 'reminder',
            'date': DateTime.now().subtract(const Duration(days: 1)),
            'is_read': true,
          },
          {
            'id': 4,
            'title': 'Appointment Cancelled',
            'message': 'Your appointment for Tooth Extraction was cancelled.',
            'type': 'cancelled',
            'date': DateTime.now().subtract(const Duration(days: 2)),
            'is_read': true,
          },
        ];
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(int id) async {
    setState(() {
      final index = _notifications.indexWhere((n) => n['id'] == id);
      if (index != -1) {
        _notifications[index]['is_read'] = true;
      }
    });

    // In a real app, this is where you'd call the API to mark as read
  }

  Future<void> _markAllAsRead() async {
    setState(() {
      for (var notification in _notifications) {
        notification['is_read'] = true;
      }
    });
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'approved':
        return Icons.check_circle_outline;
      case 'cancelled':
        return Icons.cancel_outlined;
      case 'reminder':
        return Icons.alarm;
      case 'queue':
        return Icons.people_outline;
      default:
        return Icons.notifications_none;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'approved':
        return const Color(0xFF1D4ED8); // Blue
      case 'cancelled':
        return const Color(0xFFDC2626); // Red
      case 'reminder':
        return const Color(0xFFF59E0B); // Amber
      case 'queue':
        return const Color(0xFF16A34A); // Green
      default:
        return const Color(0xFF679B6A); // Theme Green
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = _notifications.any((n) => n['is_read'] == false);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5ED), // Faint greyish green for the background
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: const Color(0xFF679B6A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text(
                'Mark all as read',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchNotifications,
        color: const Color(0xFF679B6A),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF679B6A)),
                ),
              )
            : _notifications.isEmpty
                ? _buildEmptyState()
                : _buildNotificationList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
      children: [
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.notifications_off_outlined,
                  size: 48,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'No notifications yet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'You currently have no updates or reminders. Check back later!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      itemCount: _notifications.length,
      itemBuilder: (context, index) {
        final notification = _notifications[index];
        final isRead = notification['is_read'] as bool;
        final type = notification['type'] as String;
        final iconColor = _getColorForType(type);
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isRead ? Colors.white : const Color(0xFFE8F4EA), // Light green tint for unread
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: isRead ? const Color(0xFFE2E8F0) : const Color(0xFF679B6A).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                if (!isRead) {
                  _markAsRead(notification['id']);
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon Container
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isRead ? const Color(0xFFF8FAFC) : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isRead ? const Color(0xFFE2E8F0) : iconColor.withOpacity(0.2),
                        ),
                      ),
                      child: Icon(
                        _getIconForType(type),
                        color: isRead ? const Color(0xFF94A3B8) : iconColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  notification['title'],
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isRead ? FontWeight.w700 : FontWeight.w900,
                                    color: isRead ? const Color(0xFF334155) : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              if (!isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(left: 8),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF679B6A),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            notification['message'],
                            style: TextStyle(
                              fontSize: 13,
                              color: isRead ? const Color(0xFF64748B) : const Color(0xFF334155),
                              height: 1.4,
                              fontWeight: isRead ? FontWeight.w500 : FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _formatDate(notification['date'] as DateTime),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
