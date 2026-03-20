class AdminUiNotification {
  const AdminUiNotification({
    required this.title,
    required this.message,
    required this.createdAt,
  });

  final String title;
  final String message;
  final DateTime createdAt;
}
