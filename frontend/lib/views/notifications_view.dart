import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/mobile_typography.dart';
import '../core/token_storage.dart';
import '../models/app_notification.dart';
import '../services/base_service.dart';
import '../services/notification_service.dart';
import '../widgets/app_empty_state.dart';

class NotificationsView extends StatefulWidget {
  const NotificationsView({
    super.key,
    this.notificationService,
    this.tokenStorage,
  });

  final NotificationService? notificationService;
  final TokenStorage? tokenStorage;

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  late final TokenStorage _tokenStorage;
  late final NotificationService _notificationService;

  List<AppNotification> _notifications = <AppNotification>[];
  bool _isLoading = true;
  bool _isMarkingAllAsRead = false;
  int _unreadCount = 0;
  String _role = 'patient';
  String? _loadError;
  bool _hasResolvedRole = false;

  @override
  void initState() {
    super.initState();
    _tokenStorage = widget.tokenStorage ?? SecureTokenStorage();
    _notificationService =
        widget.notificationService ??
        NotificationService(
          BaseService(ApiClient(tokenStorage: _tokenStorage)),
        );
    _fetchNotifications();
  }

  Future<void> _fetchNotifications({bool showLoader = true}) async {
    final bool hasVisibleContent = _notifications.isNotEmpty;
    final String resolvedRole = _hasResolvedRole ? _role : await _resolveRole();
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = showLoader || !hasVisibleContent;
      _loadError = null;
      _role = resolvedRole;
      _hasResolvedRole = true;
    });

    try {
      final NotificationListResult result = await _notificationService
          .getNotifications(resolvedRole);
      if (!mounted) {
        return;
      }

      setState(() {
        _notifications = result.notifications;
        _unreadCount = result.unreadCount;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      if (!showLoader && hasVisibleContent) {
        setState(() {
          _isLoading = false;
        });
        _showMessage(error.message);
        return;
      }

      setState(() {
        _isLoading = false;
        _loadError = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      if (!showLoader && hasVisibleContent) {
        setState(() {
          _isLoading = false;
        });
        _showMessage('Unable to refresh notifications right now.');
        return;
      }

      setState(() {
        _isLoading = false;
        _loadError = 'Unable to load notifications right now.';
      });
    }
  }

  Future<void> _refreshNotifications() {
    return _fetchNotifications(showLoader: false);
  }

  Future<void> _markAsRead(int id) async {
    final int index = _notifications.indexWhere(
      (AppNotification notification) => notification.id == id,
    );
    if (index == -1) {
      return;
    }

    final AppNotification notification = _notifications[index];
    if (notification.isRead) {
      return;
    }

    setState(() {
      _notifications[index] = notification.copyWith(isRead: true);
      _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
    });

    try {
      final AppNotification updatedNotification = await _notificationService
          .markAsRead(_role, id);
      if (!mounted) {
        return;
      }

      setState(() {
        _replaceNotification(updatedNotification);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _notifications[index] = notification;
        _unreadCount += 1;
      });

      _showMessage('Unable to mark notification as read.');
    }
  }

  Future<void> _markAllAsRead() async {
    if (_isMarkingAllAsRead || _unreadCount == 0) {
      return;
    }

    final List<AppNotification> previousNotifications =
        List<AppNotification>.from(_notifications);

    setState(() {
      _isMarkingAllAsRead = true;
      _notifications = _notifications.map((AppNotification notification) {
        return notification.copyWith(isRead: true);
      }).toList();
      _unreadCount = 0;
    });

    try {
      await _notificationService.markAllAsRead(_role);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _notifications = previousNotifications;
        _unreadCount = previousNotifications
            .where((AppNotification notification) => !notification.isRead)
            .length;
      });

      _showMessage('Unable to mark all notifications as read.');
    } finally {
      if (mounted) {
        setState(() {
          _isMarkingAllAsRead = false;
        });
      }
    }
  }

  Future<String> _resolveRole() async {
    final Map<String, dynamic>? userInfo = await _tokenStorage.readUserInfo();
    final String role =
        userInfo?['role']?.toString().trim().toLowerCase() ?? '';

    if (role == 'staff' || role == 'admin') {
      return 'staff';
    }

    return 'patient';
  }

  void _replaceNotification(AppNotification updatedNotification) {
    final int index = _notifications.indexWhere(
      (AppNotification notification) =>
          notification.id == updatedNotification.id,
    );
    if (index == -1) {
      return;
    }

    _notifications[index] = updatedNotification;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Unknown date';
    }

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
    final bool hasUnread = _unreadCount > 0;

    return Scaffold(
      backgroundColor: const Color(
        0xFFF4F5ED,
      ), // Faint greyish green for the background
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
              key: const Key('notification-mark-all-button'),
              onPressed: _isMarkingAllAsRead
                  ? null
                  : () {
                      _markAllAsRead();
                    },
              child: Text(
                _isMarkingAllAsRead ? 'Marking...' : 'Mark all as read',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: MobileTypography.caption(context),
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        key: const Key('notifications-refresh'),
        onRefresh: _refreshNotifications,
        color: const Color(0xFF679B6A),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF679B6A)),
                ),
              )
            : _loadError != null
            ? _buildErrorState()
            : _notifications.isEmpty
            ? _buildEmptyState()
            : _buildNotificationList(),
      ),
    );
  }

  Widget _buildErrorState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
      children: [
        Center(
          child: Column(
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Color(0xFFB45309),
              ),
              const SizedBox(height: 16),
              Text(
                _loadError ?? 'Unable to load notifications right now.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _fetchNotifications,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF679B6A),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      key: const Key('notifications-empty-state'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
      children: [
        AppEmptyState(
          icon: Icons.notifications_off_outlined,
          title: 'No notifications right now',
          message:
              'Updates, reminders, and appointment activity will appear here when they are available.',
          actionLabel: 'Refresh',
          actionIcon: Icons.refresh_rounded,
          onAction: () {
            _refreshNotifications();
          },
        ),
      ],
    );
  }

  Widget _buildNotificationList() {
    return ListView(
      key: const Key('notifications-list'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      children: [
        _buildUnreadSummary(),
        ..._notifications.map((AppNotification notification) {
          final bool isRead = notification.isRead;
          final String type = notification.type;
          final iconColor = _getColorForType(type);

          return Container(
            key: Key('notification-tile-${notification.id}'),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isRead
                  ? Colors.white
                  : const Color(0xFFE8F4EA), // Light green tint for unread
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(
                color: isRead
                    ? const Color(0xFFE2E8F0)
                    : const Color(0xFF679B6A).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  if (!isRead) {
                    await _markAsRead(notification.id);
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
                          color: isRead
                              ? const Color(0xFFF8FAFC)
                              : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isRead
                                ? const Color(0xFFE2E8F0)
                                : iconColor.withValues(alpha: 0.2),
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
                                    notification.title,
                                    style: TextStyle(
                                      fontSize: MobileTypography.body(context),
                                      fontWeight: isRead
                                          ? FontWeight.w700
                                          : FontWeight.w900,
                                      color: isRead
                                          ? const Color(0xFF334155)
                                          : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                if (!isRead)
                                  Container(
                                    key: Key(
                                      'notification-unread-dot-${notification.id}',
                                    ),
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
                              notification.message,
                              style: TextStyle(
                                fontSize: MobileTypography.bodySmall(context),
                                color: isRead
                                    ? const Color(0xFF64748B)
                                    : const Color(0xFF334155),
                                height: 1.4,
                                fontWeight: isRead
                                    ? FontWeight.w500
                                    : FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _formatDate(notification.createdAt),
                              style: TextStyle(
                                fontSize: MobileTypography.caption(context),
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
        }),
      ],
    );
  }

  Widget _buildUnreadSummary() {
    final String summary = _unreadCount == 0
        ? 'All caught up'
        : '$_unreadCount unread notification${_unreadCount == 1 ? '' : 's'}';

    return Container(
      key: const Key('notifications-unread-summary'),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFFE8F4EA),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_active_outlined,
              color: Color(0xFF679B6A),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              summary,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
