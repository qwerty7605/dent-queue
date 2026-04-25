import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../widgets/app_empty_state.dart';
import '../widgets/appointment_status_badge.dart';

class StaffPatientSearchResult {
  const StaffPatientSearchResult({
    required this.patientId,
    required this.fullName,
    required this.contactNumber,
  });

  final String patientId;
  final String fullName;
  final String contactNumber;

  String get initial => fullName.isEmpty ? '?' : fullName[0].toUpperCase();

  factory StaffPatientSearchResult.fromApi(Map<String, dynamic> json) {
    return StaffPatientSearchResult(
      patientId: _readString(json['patient_id'], fallback: ''),
      fullName: _readString(json['full_name'], fallback: 'Unknown Patient'),
      contactNumber: _readString(
        json['contact_number'],
        fallback: 'Not provided',
      ),
    );
  }
}

class StaffPatientRecordData {
  const StaffPatientRecordData({
    required this.id,
    required this.patientId,
    required this.name,
    required this.gender,
    required this.birthdate,
    required this.address,
    required this.contactNumber,
    required this.upcomingAppointments,
    required this.clinicalHistory,
  });

  final String id;
  final String patientId;
  final String name;
  final String gender;
  final String birthdate;
  final String address;
  final String contactNumber;
  final List<StaffPatientAppointmentItem> upcomingAppointments;
  final List<StaffPatientAppointmentItem> clinicalHistory;

  String get initial => name.isEmpty ? '?' : name[0].toUpperCase();

  Map<String, String> toDialogPatient() {
    return <String, String>{
      'id': id,
      'patient_id': patientId,
      'name': name,
      'phone': contactNumber,
    };
  }

  factory StaffPatientRecordData.fromDetailResponse(Map<String, dynamic> json) {
    final patient = _readMap(json['patient']);

    return StaffPatientRecordData(
      id: _readString(patient['id'], fallback: ''),
      patientId: _readString(patient['patient_id'], fallback: ''),
      name: _readString(patient['full_name'], fallback: 'Unknown Patient'),
      gender: _readString(patient['gender'], fallback: 'Not provided'),
      birthdate: _formatBirthdate(patient['birthdate']),
      address: _readString(patient['address'], fallback: 'Not provided'),
      contactNumber: _readString(
        patient['contact_number'],
        fallback: 'Not provided',
      ),
      upcomingAppointments: _readList(json['upcoming_appointments'])
          .map(
            (item) =>
                StaffPatientAppointmentItem.fromApi(item, longMonth: false),
          )
          .toList(),
      clinicalHistory: _readList(json['clinical_history'])
          .map(
            (item) =>
                StaffPatientAppointmentItem.fromApi(item, longMonth: true),
          )
          .toList(),
    );
  }
}

class StaffPatientAppointmentItem {
  const StaffPatientAppointmentItem({
    required this.serviceType,
    required this.date,
    this.time,
    required this.status,
  });

  final String serviceType;
  final String date;
  final String? time;
  final String status;

  factory StaffPatientAppointmentItem.fromApi(
    Map<String, dynamic> json, {
    required bool longMonth,
  }) {
    final rawTime = _readString(json['appointment_time'], fallback: '');

    return StaffPatientAppointmentItem(
      serviceType: _readString(json['service_type'], fallback: 'Service'),
      date: _formatAppointmentDate(
        json['appointment_date'],
        longMonth: longMonth,
      ),
      time: rawTime.isEmpty ? null : _formatAppointmentTime(rawTime),
      status: _readString(json['status'], fallback: 'Pending'),
    );
  }
}

class StaffPatientDetailView extends StatelessWidget {
  const StaffPatientDetailView({
    super.key,
    required this.patient,
    required this.onBack,
    required this.onBookAppointment,
  });

  final StaffPatientRecordData patient;
  final VoidCallback onBack;
  final VoidCallback onBookAppointment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1A2F64).withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: onBack,
                icon: const Icon(
                  Icons.chevron_left_rounded,
                  color: Color(0xFF1A2F64),
                ),
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Patient Brief',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1A2F64),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'CLINICAL PROFILE',
                    style: TextStyle(
                      color: Color(0xFFA0AABF),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _PatientInfoCard(patient: patient),
        const SizedBox(height: 18),
        _SectionHeader(
          title: 'Upcoming Appointments',
          icon: Icons.access_time_rounded,
        ),
        const SizedBox(height: 10),
        _AppointmentSection(
          items: patient.upcomingAppointments,
          emptyLabel: 'No scheduled appointments',
          emptyMessage: '',
          emptyIcon: Icons.event_note_outlined,
        ),
        const SizedBox(height: 18),
        _SectionHeader(
          title: 'Clinical History',
          icon: Icons.assignment_outlined,
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onBookAppointment,
            icon: const Icon(Icons.event_available_outlined, size: 20),
            label: const Text(
              'BOOK APPOINTMENT',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF06D64F),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        _AppointmentSection(
          items: patient.clinicalHistory,
          emptyLabel: 'No clinical history yet',
          emptyMessage:
              'Records will appear here once appointment activity is available for this patient.',
          emptyIcon: Icons.folder_open_rounded,
        ),
      ],
    );
  }
}

class _PatientInfoCard extends StatelessWidget {
  const _PatientInfoCard({required this.patient});

  final StaffPatientRecordData patient;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: const Color(0xFFE6EEFF),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Center(
                child: Text(
                  patient.initial,
                  style: const TextStyle(
                    color: Color(0xFF1A2F64),
                    fontSize: 46,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              patient.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 29,
                height: 0.95,
                fontWeight: FontWeight.w900,
                color: Color(0xFF243244),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ID: ${patient.patientId}',
              style: const TextStyle(
                fontSize: 12,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w900,
                color: Color(0xFFA5B0C2),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _DetailStat(label: 'Gender', value: patient.gender),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: _DetailStat(
                    label: 'Birthdate',
                    value: patient.birthdate,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _DetailStat(label: 'Address', value: patient.address),
            const SizedBox(height: 18),
            _DetailStat(label: 'Contact Number', value: patient.contactNumber),
          ],
        ),
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  const _DetailStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: Color(0xFFA9B3C2),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF303C4E),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF4FF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: const Color(0xFF4A78D0), size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1A2F64),
          ),
        ),
      ],
    );
  }
}

class _AppointmentSection extends StatelessWidget {
  const _AppointmentSection({
    required this.items,
    required this.emptyLabel,
    required this.emptyMessage,
    required this.emptyIcon,
  });

  final List<StaffPatientAppointmentItem> items;
  final String emptyLabel;
  final String emptyMessage;
  final IconData emptyIcon;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _EmptySection(
        label: emptyLabel,
        message: emptyMessage,
        icon: emptyIcon,
      );
    }

    return Column(
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _AppointmentCard(item: item),
            ),
          )
          .toList(),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.item});

  final StaffPatientAppointmentItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.serviceType,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF263548),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.date,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF9CA6B5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AppointmentStatusBadge(status: item.status, compact: true),
          ],
        ),
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({
    required this.label,
    required this.message,
    required this.icon,
  });

  final String label;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: AppEmptyState(
        icon: icon,
        title: label,
        message: message,
        framed: false,
        compact: true,
      ),
    );
  }
}

Map<String, dynamic> _readMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map((key, data) => MapEntry(key.toString(), data));
  }

  return <String, dynamic>{};
}

List<Map<String, dynamic>> _readList(dynamic value) {
  if (value is! List) {
    return const <Map<String, dynamic>>[];
  }

  return value.map(_readMap).toList();
}

String _readString(dynamic value, {required String fallback}) {
  if (value == null) {
    return fallback;
  }

  final stringValue = value.toString().trim();
  return stringValue.isEmpty ? fallback : stringValue;
}

String _formatBirthdate(dynamic raw) {
  final value = _readString(raw, fallback: '');
  if (value.isEmpty) {
    return 'Not provided';
  }

  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    return value;
  }

  return DateFormat('yyyy-MM-dd').format(parsed);
}

String _formatAppointmentDate(dynamic raw, {required bool longMonth}) {
  final value = _readString(raw, fallback: '');
  if (value.isEmpty) {
    return 'Not scheduled';
  }

  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    return value;
  }

  return DateFormat(longMonth ? 'MMMM d, yyyy' : 'MMM d, yyyy').format(parsed);
}

String _formatAppointmentTime(String raw) {
  final formats = <String>['HH:mm', 'H:mm', 'HH:mm:ss'];

  for (final format in formats) {
    try {
      final parsed = DateFormat(format).parseStrict(raw);
      return DateFormat('HH:mm').format(parsed);
    } catch (_) {
      // Try next format.
    }
  }

  return raw;
}
