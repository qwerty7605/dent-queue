import 'package:flutter/material.dart';

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

  String get initial => name.isEmpty ? '?' : name[0].toLowerCase();

  Map<String, String> toDialogPatient() {
    return <String, String>{
      'id': id,
      'patient_id': patientId,
      'name': name,
      'phone': contactNumber,
    };
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
        TextButton.icon(
          onPressed: onBack,
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF7BA47A),
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: const Icon(Icons.arrow_back_ios_new, size: 15),
          label: const Text(
            'Back to Search',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 14),
        _PatientInfoCard(
          patient: patient,
          onBookAppointment: onBookAppointment,
        ),
        const SizedBox(height: 18),
        _SectionHeader(
          title: 'Upcoming Appointments',
          counter: '${patient.upcomingAppointments.length} Scheduled',
        ),
        const SizedBox(height: 10),
        _AppointmentSection(
          items: patient.upcomingAppointments,
          emptyLabel: 'No upcoming appointments yet.',
          isHistory: false,
        ),
        const SizedBox(height: 18),
        _SectionHeader(
          title: 'Clinical History',
          counter:
              '${patient.clinicalHistory.length} Record${patient.clinicalHistory.length == 1 ? "" : "s"}',
        ),
        const SizedBox(height: 10),
        _AppointmentSection(
          items: patient.clinicalHistory,
          emptyLabel: 'No clinical history yet.',
          isHistory: true,
        ),
      ],
    );
  }
}

class _PatientInfoCard extends StatelessWidget {
  const _PatientInfoCard({
    required this.patient,
    required this.onBookAppointment,
  });

  final StaffPatientRecordData patient;
  final VoidCallback onBookAppointment;

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
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7EA87C),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Center(
                    child: Text(
                      patient.initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patient.name,
                          style: const TextStyle(
                            fontSize: 29,
                            height: 0.95,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF243244),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'PATIENT ID: ${patient.patientId}',
                          style: const TextStyle(
                            fontSize: 11,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF88A8A4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              runSpacing: 14,
              spacing: 18,
              children: [
                _DetailStat(label: 'Gender', value: patient.gender, width: 88),
                _DetailStat(
                  label: 'Birthdate',
                  value: patient.birthdate,
                  width: 116,
                ),
                _DetailStat(
                  label: 'Address',
                  value: patient.address,
                  width: 96,
                ),
                _DetailStat(
                  label: 'Contact Number',
                  value: patient.contactNumber,
                  width: 140,
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onBookAppointment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7BA47A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  'Book Appointment',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  const _DetailStat({
    required this.label,
    required this.value,
    required this.width,
  });

  final String label;
  final String value;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
              color: Color(0xFFB4BDC8),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF303C4E),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.counter});

  final String title;
  final String counter;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.75,
            color: Color(0xFFA7B5FF),
          ),
        ),
        const Spacer(),
        Text(
          counter,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: Color(0xFF6E8BFF),
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
    required this.isHistory,
  });

  final List<StaffPatientAppointmentItem> items;
  final String emptyLabel;
  final bool isHistory;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _EmptySection(label: emptyLabel);
    }

    return Column(
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _AppointmentCard(item: item, isHistory: isHistory),
            ),
          )
          .toList(),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.item, required this.isHistory});

  final StaffPatientAppointmentItem item;
  final bool isHistory;

  @override
  Widget build(BuildContext context) {
    final statusStyle = _statusStyle(item.status, isHistory: isHistory);

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
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF263548),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _MetaChip(icon: Icons.event_outlined, label: item.date),
                      if ((item.time ?? '').isNotEmpty)
                        _MetaChip(icon: Icons.access_time, label: item.time!),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: statusStyle.background,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                item.status.toUpperCase(),
                style: TextStyle(
                  color: statusStyle.foreground,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _StatusStyle _statusStyle(String status, {required bool isHistory}) {
    final normalized = status.toLowerCase();

    if (isHistory || normalized == 'completed') {
      return const _StatusStyle(
        background: Color(0xFFE5F8E7),
        foreground: Color(0xFF67B56B),
      );
    }

    if (normalized == 'approved' || normalized == 'confirmed') {
      return const _StatusStyle(
        background: Color(0xFFE6F0FF),
        foreground: Color(0xFF6F98F7),
      );
    }

    return const _StatusStyle(
      background: Color(0xFFF5F0DE),
      foreground: Color(0xFFB29033),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFFAEB9C8)),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF8796AA),
          ),
        ),
      ],
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF8B98AB),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatusStyle {
  const _StatusStyle({required this.background, required this.foreground});

  final Color background;
  final Color foreground;
}
