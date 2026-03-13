import 'package:flutter/material.dart';

import '../widgets/staff_book_appointment_dialog.dart';

class StaffPatientDetailView extends StatelessWidget {
  const StaffPatientDetailView({
    super.key,
    required this.patient,
  });

  final Map<String, String> patient;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5ED),
      appBar: AppBar(
        title: const Text('Patient Details'),
        backgroundColor: const Color(0xFF679B6A),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8ECE8),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF679B6A),
                    width: 3,
                  ),
                ),
                child: Center(
                  child: Text(
                    patient['name']!.isNotEmpty ? patient['name']![0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF679B6A),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                patient['name']!,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.phone,
                    color: Color(0xFF64748B),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    patient['phone']!,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),
              const Text(
                'Full patient details will be implemented soon.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF94A3B8),
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (_) => StaffBookAppointmentDialog(patient: patient),
                    );
                  },
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text(
                    'Book Appointment',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF679B6A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
