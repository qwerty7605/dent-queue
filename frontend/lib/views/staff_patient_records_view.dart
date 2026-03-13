import 'package:flutter/material.dart';

import '../widgets/staff_book_appointment_dialog.dart';
import 'staff_patient_detail_view.dart';

class StaffPatientRecordsView extends StatefulWidget {
  const StaffPatientRecordsView({super.key});

  @override
  State<StaffPatientRecordsView> createState() =>
      _StaffPatientRecordsViewState();
}

class _StaffPatientRecordsViewState extends State<StaffPatientRecordsView> {
  final TextEditingController _searchController = TextEditingController();

  final List<StaffPatientRecordData> _allPatients = const [
    StaffPatientRecordData(
      id: '1',
      patientId: 'SDQ-0003',
      name: 'kyle aldea',
      gender: 'Male',
      birthdate: '2026-03-05',
      address: '111',
      contactNumber: '09169014483',
      upcomingAppointments: [
        StaffPatientAppointmentItem(
          serviceType: 'Root Canal',
          date: 'Mar 10, 2026',
          time: '09:00',
          status: 'Approved',
        ),
      ],
      clinicalHistory: [
        StaffPatientAppointmentItem(
          serviceType: 'Dental Check-up',
          date: 'March 2, 2026',
          status: 'Completed',
        ),
      ],
    ),
    StaffPatientRecordData(
      id: '2',
      patientId: 'SDQ-0004',
      name: 'janine cruz',
      gender: 'Female',
      birthdate: '2000-11-16',
      address: '24 Mahogany Street',
      contactNumber: '09123456789',
      upcomingAppointments: [
        StaffPatientAppointmentItem(
          serviceType: 'Dental Panoramic X-ray',
          date: 'Mar 14, 2026',
          time: '08:30',
          status: 'Approved',
        ),
        StaffPatientAppointmentItem(
          serviceType: 'Teeth Cleaning',
          date: 'Mar 28, 2026',
          time: '10:00',
          status: 'Pending',
        ),
      ],
      clinicalHistory: [
        StaffPatientAppointmentItem(
          serviceType: 'Tooth Extraction',
          date: 'February 11, 2026',
          status: 'Completed',
        ),
      ],
    ),
    StaffPatientRecordData(
      id: '3',
      patientId: 'SDQ-0005',
      name: 'miguel ramos',
      gender: 'Male',
      birthdate: '1998-07-22',
      address: '88 Rizal Avenue',
      contactNumber: '09987654321',
      upcomingAppointments: [],
      clinicalHistory: [
        StaffPatientAppointmentItem(
          serviceType: 'Dental Check-up',
          date: 'January 20, 2026',
          status: 'Completed',
        ),
        StaffPatientAppointmentItem(
          serviceType: 'Teeth Whitening',
          date: 'December 8, 2025',
          status: 'Completed',
        ),
      ],
    ),
    StaffPatientRecordData(
      id: '4',
      patientId: 'SDQ-0006',
      name: 'bianca soriano',
      gender: 'Female',
      birthdate: '1996-04-09',
      address: '17 Sampaguita Street',
      contactNumber: '09181234567',
      upcomingAppointments: [
        StaffPatientAppointmentItem(
          serviceType: 'Dental Check-up',
          date: 'Mar 18, 2026',
          time: '11:30',
          status: 'Pending',
        ),
      ],
      clinicalHistory: [
        StaffPatientAppointmentItem(
          serviceType: 'Teeth Cleaning',
          date: 'February 3, 2026',
          status: 'Completed',
        ),
        StaffPatientAppointmentItem(
          serviceType: 'Dental Panoramic X-ray',
          date: 'December 15, 2025',
          status: 'Completed',
        ),
      ],
    ),
    StaffPatientRecordData(
      id: '5',
      patientId: 'SDQ-0007',
      name: 'carl dumagat',
      gender: 'Male',
      birthdate: '1989-09-27',
      address: '45 Mabini Extension',
      contactNumber: '09223334444',
      upcomingAppointments: [
        StaffPatientAppointmentItem(
          serviceType: 'Tooth Extraction',
          date: 'Mar 19, 2026',
          time: '08:00',
          status: 'Approved',
        ),
        StaffPatientAppointmentItem(
          serviceType: 'Follow-up Check-up',
          date: 'Mar 26, 2026',
          time: '09:30',
          status: 'Pending',
        ),
      ],
      clinicalHistory: [
        StaffPatientAppointmentItem(
          serviceType: 'Root Canal',
          date: 'January 9, 2026',
          status: 'Completed',
        ),
      ],
    ),
    StaffPatientRecordData(
      id: '6',
      patientId: 'SDQ-0008',
      name: 'diana flores',
      gender: 'Female',
      birthdate: '2002-06-14',
      address: '211 P. Gomez Street',
      contactNumber: '09335557777',
      upcomingAppointments: [],
      clinicalHistory: [
        StaffPatientAppointmentItem(
          serviceType: 'Dental Check-up',
          date: 'March 1, 2026',
          status: 'Completed',
        ),
      ],
    ),
    StaffPatientRecordData(
      id: '7',
      patientId: 'SDQ-0009',
      name: 'enzo valdez',
      gender: 'Male',
      birthdate: '1993-12-30',
      address: '89 Del Rosario Avenue',
      contactNumber: '09446668888',
      upcomingAppointments: [
        StaffPatientAppointmentItem(
          serviceType: 'Teeth Whitening',
          date: 'Mar 22, 2026',
          time: '01:30',
          status: 'Approved',
        ),
      ],
      clinicalHistory: [
        StaffPatientAppointmentItem(
          serviceType: 'Dental Check-up',
          date: 'January 12, 2026',
          status: 'Completed',
        ),
        StaffPatientAppointmentItem(
          serviceType: 'Teeth Cleaning',
          date: 'November 20, 2025',
          status: 'Completed',
        ),
      ],
    ),
    StaffPatientRecordData(
      id: '8',
      patientId: 'SDQ-0010',
      name: 'francesca lim',
      gender: 'Female',
      birthdate: '1999-01-21',
      address: '301 Orchid Homes',
      contactNumber: '09557779999',
      upcomingAppointments: [
        StaffPatientAppointmentItem(
          serviceType: 'Dental Panoramic X-ray',
          date: 'Mar 25, 2026',
          time: '03:00',
          status: 'Pending',
        ),
      ],
      clinicalHistory: [],
    ),
    StaffPatientRecordData(
      id: '9',
      patientId: 'SDQ-0011',
      name: 'gabriel mercado',
      gender: 'Male',
      birthdate: '1987-08-11',
      address: '72 Laurel Compound',
      contactNumber: '09668880000',
      upcomingAppointments: [
        StaffPatientAppointmentItem(
          serviceType: 'Root Canal',
          date: 'Mar 24, 2026',
          time: '10:30',
          status: 'Approved',
        ),
      ],
      clinicalHistory: [
        StaffPatientAppointmentItem(
          serviceType: 'Tooth Extraction',
          date: 'February 8, 2026',
          status: 'Completed',
        ),
        StaffPatientAppointmentItem(
          serviceType: 'Dental Check-up',
          date: 'September 6, 2025',
          status: 'Completed',
        ),
      ],
    ),
  ];

  List<StaffPatientRecordData> _searchResults = [];
  StaffPatientRecordData? _selectedPatient;
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch() {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      setState(() {
        _hasSearched = false;
        _selectedPatient = null;
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _hasSearched = true;
      _selectedPatient = null;
      _searchResults = _allPatients.where((patient) {
        return patient.name.toLowerCase().contains(query) ||
            patient.contactNumber.contains(query) ||
            patient.patientId.toLowerCase().contains(query);
      }).toList();
    });
  }

  void _selectPatient(StaffPatientRecordData patient) {
    setState(() {
      _selectedPatient = patient;
      _hasSearched = true;
      _searchController.text = patient.name;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedPatient = null;
    });
  }

  void _openBookAppointmentDialog(StaffPatientRecordData patient) {
    showDialog<void>(
      context: context,
      builder: (_) =>
          StaffBookAppointmentDialog(patient: patient.toDialogPatient()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 440 ? 14.0 : 22.0;
        final maxWidth = constraints.maxWidth > 1024 ? 920.0 : double.infinity;

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            16,
            horizontalPadding,
            18,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 10),
                  const Text(
                    'Patient Records',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Manage and review patient clinical history',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  _buildSearchBar(),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: _selectedPatient != null
                          ? StaffPatientDetailView(
                              key: ValueKey<String>(_selectedPatient!.id),
                              patient: _selectedPatient!,
                              onBack: _clearSelection,
                              onBookAppointment: () =>
                                  _openBookAppointmentDialog(_selectedPatient!),
                            )
                          : _buildSearchState(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onSubmitted: (_) => _performSearch(),
              decoration: InputDecoration(
                hintText: 'Search by name, patient ID, or phone...',
                hintStyle: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, color: Color(0xFFD1D5DB)),
                  onPressed: _performSearch,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF679B6A),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF679B6A).withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _performSearch,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Icon(Icons.search, color: Colors.white, size: 26),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchState() {
    if (!_hasSearched) {
      return Container(
        key: const ValueKey<String>('search-empty'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE7EBEE)),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.manage_search_rounded,
              size: 46,
              color: Color(0xFFCBD5E1),
            ),
            SizedBox(height: 14),
            Text(
              'Search a patient record to view full details.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
              ),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Container(
        key: const ValueKey<String>('search-no-results'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE7EBEE)),
        ),
        child: const Column(
          children: [
            Icon(Icons.search_off_rounded, size: 46, color: Color(0xFFCBD5E1)),
            SizedBox(height: 14),
            Text(
              'No patient records matched your search.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      key: const ValueKey<String>('search-results'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _searchResults.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final patient = _searchResults[index];
        return _buildPatientCard(patient);
      },
    );
  }

  Widget _buildPatientCard(StaffPatientRecordData patient) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _selectPatient(patient),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8ECE8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      patient.initial,
                      style: const TextStyle(
                        color: Color(0xFF679B6A),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        patient.patientId,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8CA0AF),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.phone_outlined,
                            size: 14,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            patient.contactNumber,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Color(0xFFCBD5E1),
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
