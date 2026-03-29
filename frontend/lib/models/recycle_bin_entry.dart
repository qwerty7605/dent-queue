class RecycleBinEntry {
  const RecycleBinEntry({
    required this.id,
    required this.service,
    required this.appointmentAt,
    required this.deletedAt,
    required this.statusLabel,
    required this.isRestorable,
    this.expiresAt,
    this.patientName,
    this.notes,
  });

  final int id;
  final String service;
  final DateTime appointmentAt;
  final DateTime deletedAt;
  final String statusLabel;
  final bool isRestorable;
  final DateTime? expiresAt;
  final String? patientName;
  final String? notes;
}
