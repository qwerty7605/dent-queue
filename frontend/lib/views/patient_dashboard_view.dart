import 'package:flutter/material.dart';

class PatientDashboardView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final name = userInfo?['name']?.toString() ?? 'User';

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
              leading: loggingOut 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: loggingOut ? null : onLogout,
            ),
          ],
        ),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: const Color(0xFF679B6A),
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 36),
      ),
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
                  onTap: () {},
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_available, color: Color(0xFF679B6A)),
                      SizedBox(height: 4),
                      Text(
                        'Appointments',
                        style: TextStyle(color: Color(0xFF679B6A), fontSize: 10, fontWeight: FontWeight.bold),
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
                  onTap: () {},
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_outline, color: Colors.grey),
                      SizedBox(height: 4),
                      Text(
                        'Profile',
                        style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
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
