class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.isRead,
    required this.type,
    this.relatedAppointmentId,
    this.actionType,
    this.actionLabel,
  });

  final int id;
  final String title;
  final String message;
  final DateTime? createdAt;
  final bool isRead;
  final String type;
  final int? relatedAppointmentId;
  final String? actionType;
  final String? actionLabel;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value is! String || value.isEmpty) {
        return null;
      }

      return DateTime.tryParse(value);
    }

    int parseInt(dynamic value) {
      if (value is int) {
        return value;
      }

      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    int? parseNullableInt(dynamic value) {
      if (value == null) {
        return null;
      }

      if (value is int) {
        return value;
      }

      return int.tryParse(value.toString());
    }

    return AppNotification(
      id: parseInt(json['notification_id'] ?? json['id']),
      title: json['title']?.toString() ?? 'Notification',
      message: json['message']?.toString() ?? '',
      createdAt: parseDate(json['created_at'] ?? json['timestamp_created']),
      isRead: json['is_read'] == true,
      type: json['type']?.toString() ?? 'general',
      relatedAppointmentId: parseNullableInt(
        json['related_appointment_id'] ?? json['appointment_id'],
      ),
      actionType: json['action_type']?.toString(),
      actionLabel: json['action_label']?.toString(),
    );
  }

  AppNotification copyWith({
    int? id,
    String? title,
    String? message,
    DateTime? createdAt,
    bool? isRead,
    String? type,
    int? relatedAppointmentId,
    String? actionType,
    String? actionLabel,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
      relatedAppointmentId: relatedAppointmentId ?? this.relatedAppointmentId,
      actionType: actionType ?? this.actionType,
      actionLabel: actionLabel ?? this.actionLabel,
    );
  }
}
