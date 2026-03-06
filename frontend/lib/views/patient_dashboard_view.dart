import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/token_storage.dart';
import '../services/base_service.dart';
import '../services/appointment_service.dart';

import '../widgets/book_appointment_dialog.dart';
import '../widgets/edit_profile_dialog.dart';
import '../widgets/appointment_details_dialog.dart';

class PatientDashboardView extends StatefulWidget {
  const PatientDashboardView({
    super.key,
    required this.userInfo,
    required this.onLogout,
    required this.loggingOut,
  });

  final Map<String, dynamic>? userInfo;
  final VoidCallback onLogout;
  final bool loggingOut;

  @override
  State<PatientDashboardView> createState() => _PatientDashboardViewState();
}

class _PatientDashboardViewState extends State<PatientDashboardView> {
  int _selectedIndex = 0; // 0 for Appointments, 1 for Profile

  late final AppointmentService _appointmentService;
  List<Map<String, dynamic>> _appointments = [];
  bool _isLoadingAppointments = true;

  @override
  void initState() {
    super.initState();
    _appointmentService = AppointmentService(
      BaseService(ApiClient(tokenStorage: SecureTokenStorage())),
    );
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    setState(() => _isLoadingAppointments = true);
    try {
      final list = await _appointmentService.getPatientAppointments();
      if (!mounted) return;
      setState(() {
        _appointments = list;
        _isLoadingAppointments = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingAppointments = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.userInfo?['name']?.toString() ?? 'User';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5ED), // Faint greyish green for the background
      appBar: _buildAppBar(name),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Color(0xFF679B6A),
              ),
              child: Text(
                'Menu',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: widget.loggingOut 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: widget.loggingOut ? null : widget.onLogout,
            ),
          ],
        ),
      ),
      body: _selectedIndex == 0 ? _buildBody() : _buildProfileView(),
      floatingActionButton: _selectedIndex == 0 ? FloatingActionButton(
        onPressed: () async {
          final result = await showDialog(
            context: context,
            builder: (context) => const BookAppointmentDialog(),
          );
          if (result == true) {
            _loadAppointments();
          }
        },
        backgroundColor: const Color(0xFF679B6A),
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 36),
      ) : null, // Hide FAB on profile page
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  PreferredSizeWidget _buildAppBar(String name) {
    return AppBar(
      backgroundColor: const Color(0xFF679B6A), // Green header
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.black, size: 24), // Hamburger menu
      titleSpacing: -15, // Reduces space between hamburger and title
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Placeholder for Logo
          Container(
            padding: const EdgeInsets.all(2),
            child: Image.asset(
              'assets/images/logo.png',
              width: 40, // slightly larger, logo looks a bit small
              height: 40,
            ),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'SMART',
                    style: TextStyle(
                      color: Color(0xFFE8C355), // Yellow from logo
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: -0.5,
                    ),
                  ),
                  TextSpan(
                    text: 'DentQueue',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        // Profile chip placeholder
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'PATIENT',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, color: Colors.grey, size: 20),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        const SizedBox(height: 24),
        // Title
        Center(
          child: Container(
            child: const Text(
              'PATIENT DASHBOARD',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: Colors.black87,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        
        // Status Cards Grid
        Builder(
          builder: (context) {
            final pendingCount = _appointments.where((a) => a['status']?.toString().toLowerCase() == 'pending').length;
            final approvedCount = _appointments.where((a) => a['status']?.toString().toLowerCase() == 'confirmed').length;
            final completedCount = _appointments.where((a) => a['status']?.toString().toLowerCase() == 'completed').length;
            final cancelledCount = _appointments.where((a) => a['status']?.toString().toLowerCase() == 'cancelled').length;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.35,
                children: [
                  _buildStatusCard(
                    title: 'PENDING',
                    count: pendingCount.toString(),
                    icon: Icons.access_time_filled,
                    color: Colors.orange,
                    backgroundColor: const Color(0xFFFFF7EF),
                  ),
                  _buildStatusCard(
                    title: 'APPROVED',
                    count: approvedCount.toString(),
                    icon: Icons.check_circle_outline,
                    color: Colors.blue,
                    backgroundColor: const Color(0xFFF1F7FF),
                  ),
                  _buildStatusCard(
                    title: 'COMPLETED',
                    count: completedCount.toString(),
                    icon: Icons.medical_services_outlined, 
                    color: Colors.green,
                    backgroundColor: const Color(0xFFF1FFF7),
                  ),
                  _buildStatusCard(
                    title: 'CANCELLED',
                    count: cancelledCount.toString(),
                    icon: Icons.cancel_outlined,
                    color: Colors.redAccent,
                    backgroundColor: const Color(0xFFFFF1F1),
                  ),
                ],
              ),
            );
          }
        ),
        
        const SizedBox(height: 24),
        
        // Horizontal Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Row(
            children: [
              _buildFilterChip('ALL', isSelected: true),
              const SizedBox(width: 8),
              _buildFilterChip('Pending', isSelected: false),
              const SizedBox(width: 8),
              _buildFilterChip('Approved', isSelected: false),
              const SizedBox(width: 8),
              _buildFilterChip('Completed', isSelected: false),
              const SizedBox(width: 8),
              _buildFilterChip('Cancelled', isSelected: false),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // The list or empty state
        if (_isLoadingAppointments)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_appointments.isEmpty)
          const Expanded(
            child: Center(
              child: Text(
                'No Appointment Yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              itemCount: _appointments.length,
              itemBuilder: (context, index) {
                return _buildAppointmentCard(_appointments[index]);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildProfileView() {
    final Map<String, dynamic> userInfo = widget.userInfo ?? {};
    
    // First try "name", if missing then try assembling from first_name, middle_name, last_name
    String fullName = userInfo['name']?.toString() ?? '';
    if (fullName.isEmpty) {
      fullName = '${userInfo['first_name'] ?? ''} ${userInfo['middle_name'] ?? ''} ${userInfo['last_name'] ?? ''}'.trim();
    }
    fullName = fullName.toUpperCase();

    final String address = (userInfo['location'] ?? userInfo['address'])?.toString() ?? 'N/A';
    final String gender = userInfo['gender']?.toString() ?? 'N/A';
    final String birthdate = userInfo['birthdate']?.toString() ?? 'N/A';
    final String contactNumber = (userInfo['phone_number'] ?? userInfo['contact_number'])?.toString() ?? 'N/A';

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 24),
            // Circular Avatar
            Center(
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF679B6A), width: 3),
                  color: const Color(0xFFF8FAFC),
                  image: const DecorationImage(
                    image: AssetImage('assets/images/placeholder_baby.png'), // Using a placeholder concept, since no real image is provided. But we can use an Icon
                    fit: BoxFit.cover,
                  ),
                ),
                child: const Icon(Icons.person, size: 80, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 16),
            
            // Name and Title
            Text(
              fullName.isNotEmpty ? fullName : 'User Name',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Patient Account\nID: SDQ-2',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            
            // Info Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileField(Icons.person_outline, 'FULL NAME', fullName),
                  const SizedBox(height: 20),
                  _buildProfileField(Icons.calendar_today_outlined, 'BIRTHDATE', birthdate),
                  const SizedBox(height: 20),
                  _buildProfileField(Icons.location_on_outlined, 'ADDRESS', address),
                  const SizedBox(height: 20),
                  _buildProfileField(Icons.people_outline, 'GENDER', gender),
                  const SizedBox(height: 20),
                  _buildProfileField(Icons.phone_outlined, 'CONTACT NUMBER', contactNumber),
                  const SizedBox(height: 32),
                  
                  // Edit Profile Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        // Show Edit Profile Dialog
                        showDialog(
                          context: context,
                          builder: (context) => EditProfileDialog(userInfo: widget.userInfo ?? {}),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF679B6A), // Green brand color
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Edit Profile',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileField(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF679B6A), size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF7E8CA0),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard({
    required String title,
    required String count,
    required IconData icon,
    required Color color,
    required Color backgroundColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            count,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, {required bool isSelected}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF679B6A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isSelected ? null : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.black54,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      color: Colors.white,
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Appointments Tab
            Expanded(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedIndex = 0;
                    });
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_available, color: _selectedIndex == 0 ? const Color(0xFF679B6A) : Colors.grey),
                      const SizedBox(height: 4),
                      Text(
                        'Appointments',
                        style: TextStyle(color: _selectedIndex == 0 ? const Color(0xFF679B6A) : Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(width: 48), // Space for FAB
            
            // Profile Tab
            Expanded(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedIndex = 1;
                    });
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_outline, color: _selectedIndex == 1 ? const Color(0xFF679B6A) : Colors.grey),
                      const SizedBox(height: 4),
                      Text(
                        'Profile',
                        style: TextStyle(color: _selectedIndex == 1 ? const Color(0xFF679B6A) : Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appt) {
    final serviceType = appt['service_type']?.toString() ?? 'Service';
    final date = appt['appointment_date']?.toString() ?? 'YYYY-MM-DD';
    String formattedTime = '--:--';
    final rawTime = appt['appointment_time']?.toString() ?? '--:--';
    if (rawTime != '--:--') {
      try {
        final parts = rawTime.split(':');
        final hour = int.parse(parts[0]);
        final minute = parts.length > 1 ? parts[1] : '00';
        final amPm = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        formattedTime = '$displayHour:$minute $amPm';
      } catch (e) {
        formattedTime = rawTime;
      }
    }
    final time = formattedTime;
    final queue = appt['queue_number']?.toString() ?? '--';
    final initial = serviceType.isNotEmpty ? serviceType[0].toUpperCase() : 'S';
    final status = appt['status']?.toString().toLowerCase() ?? 'pending';

    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AppointmentDetailsDialog(appointment: appt),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Icon wrapper
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F7FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        serviceType,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Text(date, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                          const SizedBox(width: 12),
                          const Icon(Icons.access_time_outlined, size: 14, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Text(time, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                // Queue Num
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'QUEUE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF7E8CA0),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      '#$queue',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF679B6A),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (status == 'pending')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFFFF1F1),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: const Center(
                child: Text(
                  'CANCEL APPOINTMENT',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
  }
}
