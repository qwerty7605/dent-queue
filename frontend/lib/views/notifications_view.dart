import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/mobile_typography.dart';
import '../core/token_storage.dart';
import '../models/app_notification.dart';
import '../services/appointment_service.dart';
import '../services/base_service.dart';
import '../services/notification_service.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/navigation_chrome.dart';
import '../widgets/reschedule_appointment_dialog.dart';

class NotificationsView extends StatefulWidget {
  const NotificationsView({
    super.key,
    this.notificationService,
    this.appointmentService,
    this.tokenStorage,
  });

  final NotificationService? notificationService;
  final AppointmentService? appointmentService;
  final TokenStorage? tokenStorage;

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  late final TokenStorage _tokenStorage;
  late final NotificationService _notificationService;
  late final AppointmentService _appointmentService;

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
          tokenStorage: _tokenStorage,
        );
    _appointmentService =
        widget.appointmentService ??
        AppointmentService(BaseService(ApiClient(tokenStorage: _tokenStorage)));
    _fetchNotifications();
  }

  Future<void> _fetchNotifications({
    bool showLoader = true,
    bool forceRefresh = false,
  }) async {
    bool hasVisibleContent = _notifications.isNotEmpty;
    final String resolvedRole = _hasResolvedRole ? _role : await _resolveRole();
    if (!mounted) {
      return;
    }

    if (showLoader && !forceRefresh && !hasVisibleContent) {
      final NotificationListResult? cachedResult = await _notificationService
          .getCachedNotifications(resolvedRole, allowStale: true);

      if (!mounted) {
        return;
      }

      if (cachedResult != null) {
        setState(() {
          _notifications = cachedResult.notifications;
          _unreadCount = cachedResult.unreadCount;
          _role = resolvedRole;
          _hasResolvedRole = true;
          _isLoading = false;
          _loadError = null;
        });
        hasVisibleContent = true;
        showLoader = false;
      }
    }

    setState(() {
      _isLoading = showLoader || !hasVisibleContent;
      _loadError = null;
      _role = resolvedRole;
      _hasResolvedRole = true;
    });

    try {
      final NotificationListResult result = await _notificationService
          .getNotifications(resolvedRole, forceRefresh: forceRefresh);
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
    return _fetchNotifications(showLoader: false, forceRefresh: true);
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

  Future<void> _openRescheduleFromNotification(
    AppNotification notification,
  ) async {
    final int? appointmentId = notification.relatedAppointmentId;
    if (appointmentId == null) {
      _showMessage('Unable to open this appointment right now.');
      return;
    }

    try {
      if (!notification.isRead) {
        await _markAsRead(notification.id);
      }

      final Map<String, dynamic> appointment = await _appointmentService
          .getPatientAppointment(appointmentId);
      if (!mounted) {
        return;
      }

      final bool? rescheduled = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (BuildContext routeContext) {
            return RescheduleAppointmentDialog(
              appointment: appointment,
              appointmentService: _appointmentService,
              asPage: true,
            );
          },
        ),
      );

      if (rescheduled == true && mounted) {
        await _refreshNotifications();
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage('Unable to open the reschedule form right now.');
    }
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
      case 'appointment_cancelled_by_doctor':
        return Icons.event_busy_outlined;
      case 'appointment_reschedule_required':
        return Icons.update_rounded;
      case 'doctor_unavailable':
        return Icons.event_busy_outlined;
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
      case 'appointment_cancelled_by_doctor':
        return const Color(0xFFB91C1C);
      case 'appointment_reschedule_required':
        return const Color(0xFFD97706);
      case 'doctor_unavailable':
        return const Color(0xFFB45309); // Amber brown
      case 'reminder':
        return const Color(0xFFF59E0B); // Amber
      case 'queue':
        return const Color(0xFF16A34A); // Green
      default:
        return const Color(0xFF4A769E); // Theme Green
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasUnread = _unreadCount > 0;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppNavigationTheme.background,
      appBar: AppHeaderBar(
        titleWidget: const AppBrandLockup(logoSize: 40, spacing: 4),
        titleSpacing: -8,
        showBottomAccent: false,
        actions: const <Widget>[SizedBox(width: 8)],
      ),
      body: RefreshIndicator(
        key: const Key('notifications-refresh'),
        onRefresh: _refreshNotifications,
        color: AppNavigationTheme.primary,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppNavigationTheme.primary,
                  ),
                ),
              )
            : _loadError != null
            ? _buildErrorState()
            : _notifications.isEmpty
            ? _buildEmptyState()
            : ListView(
                key: const Key('notifications-list'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 96),
                children: [
                  Row(
                    children: [
                      _buildBackButton(isDark),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Notifications',
                          style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1F3763),
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (hasUnread)
                        TextButton(
                          key: const Key('notification-mark-all-button'),
                          onPressed: _isMarkingAllAsRead
                              ? null
                              : _markAllAsRead,
                          child: Text(
                            _isMarkingAllAsRead
                                ? 'MARKING...'
                                : 'MARK ALL AS READ',
                            style: TextStyle(
                              color: const Color(0xFFC8D5F2),
                              fontWeight: FontWeight.bold,
                              fontSize: MobileTypography.caption(context),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  ..._buildNotificationTiles(),
                ],
              ),
      ),
    );
  }

  Widget _buildBackButton(bool isDark) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).maybePop(),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF17243A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(
          Icons.chevron_left_rounded,
          color: isDark ? Colors.white : const Color(0xFF1F3763),
        ),
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
                onPressed: () => _fetchNotifications(forceRefresh: true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4A769E),
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

  List<Widget> _buildNotificationTiles() {
    return _notifications.map((AppNotification notification) {
      final bool isRead = notification.isRead;
      final String type = notification.type;
      final iconColor = _getColorForType(type);
      final bool canReschedule =
          _role == 'patient' &&
          notification.actionType == 'reschedule' &&
          notification.relatedAppointmentId != null;

      return Container(
        key: Key('notification-tile-${notification.id}'),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isRead ? const Color(0xFFFDFDFE) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1A2F64).withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(
            color: isRead ? const Color(0xFFF3F4F8) : const Color(0xFFE7ECF8),
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
              padding: const EdgeInsets.all(18.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon Container
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isRead
                          ? const Color(0xFFF8F9FD)
                          : iconColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isRead
                            ? const Color(0xFFF0F2F7)
                            : iconColor.withValues(alpha: 0.18),
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
                                      ? const Color(0xFF67748A)
                                      : const Color(0xFF243B6B),
                                ),
                              ),
                            ),
                            Text(
                              _formatDate(notification.createdAt),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFB0B8C9),
                                fontWeight: FontWeight.w600,
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
                                ? const Color(0xFFBCC4D1)
                                : const Color(0xFF4E596F),
                            height: 1.4,
                            fontWeight: isRead
                                ? FontWeight.w500
                                : FontWeight.w600,
                          ),
                        ),
                        if (canReschedule) ...[
                          const SizedBox(height: 14),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              height: 38,
                              child: ElevatedButton.icon(
                                key: Key(
                                  'notification-action-button-${notification.id}',
                                ),
                                onPressed: () =>
                                    _openRescheduleFromNotification(
                                      notification,
                                    ),
                                style: ElevatedButton.styleFrom(
                                  elevation: 0,
                                  backgroundColor: const Color(0xFFEEF4FF),
                                  foregroundColor: const Color(0xFF1F4AA8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.schedule_rounded,
                                  size: 16,
                                ),
                                label: Text(
                                  notification.actionType == 'reschedule'
                                      ? 'Reschedule Now'
                                      : (notification.actionLabel ?? 'Open'),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }
}
