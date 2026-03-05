import 'package:flutter/material.dart';
import '../widgets/book_appointment_dialog.dart';
import '../widgets/edit_profile_dialog.dart';

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
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => const BookAppointmentDialog(),
          );
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
        Padding(
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
                count: '0',
                icon: Icons.access_time_filled,
                color: Colors.orange,
                backgroundColor: const Color(0xFFFFF7EF),
              ),
              _buildStatusCard(
                title: 'APPROVED',
                count: '0',
                icon: Icons.check_circle_outline,
                color: Colors.blue,
                backgroundColor: const Color(0xFFF1F7FF),
              ),
              _buildStatusCard(
                title: 'COMPLETED',
                count: '0',
                icon: Icons.medical_services_outlined, // Stethoscope like icon
                color: Colors.green,
                backgroundColor: const Color(0xFFF1FFF7),
              ),
              _buildStatusCard(
                title: 'CANCELLED',
                count: '0',
                icon: Icons.cancel_outlined,
                color: Colors.redAccent,
                backgroundColor: const Color(0xFFFFF1F1),
              ),
            ],
          ),
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
        
        const Spacer(),
        
        // Empty State
        const Center(
          child: Text(
            'No Appointment Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
        
        const Spacer(flex: 2),
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
}
