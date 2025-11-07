// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'TechniciansScreen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  String? _loggedUserName;

  @override
  void initState() {
    super.initState();
    _fetchLoggedUser(); //
  }

  late final List<Widget> _pages = [const DashboardPage(), TechniciansScreen()];

  Future<void> _fetchLoggedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');

      if (userId == null) return;

      final user = await Supabase.instance.client
          .from('users')
          .select('full_name')
          .eq('id', userId)
          .limit(1)
          .maybeSingle();

      if (user != null && user['full_name'] != null) {
        setState(() {
          _loggedUserName = user['full_name'];
        });
      }
    } catch (e) {
      debugPrint("Error fetching user: $e");
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    try {
      // Clear saved credentials from shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('username');
      await prefs.remove('password');
      await prefs.setBool('rememberMe', false);

      // Sign out from Supabase (if using Supabase Auth)
      await Supabase.instance.client.auth.signOut();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logged out successfully'),
            backgroundColor: Color(0xFF001F3A),
          ),
        );
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error logging out: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 0, 62, 112),
        elevation: 2,
        title: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Text(
            _selectedIndex == 0 ? 'Dashboard' : 'List of Technicians',
            style: const TextStyle(color: Colors.white, fontSize: 20),
          ),
        ),

        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () {
                Scaffold.of(context).openEndDrawer();
              },
            ),
          ),
        ],
      ),

      // Side Drawer
      endDrawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color.fromARGB(255, 0, 62, 112),
              ),
              child: Text(
                "Hello, $_loggedUserName",
                style: const TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Manage Tools'),
              onTap: () {
                Navigator.pop(context); // close drawer
                context.push('/add-tools');
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Export File'),
              onTap: () {
                Navigator.pop(context); // close drawer
                context.push('/export-excel');
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _handleLogout(context);
              },
            ),
          ],
        ),
      ),

      body: _pages[_selectedIndex],

      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.white,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.engineering),
            label: 'Technicians',
          ),
        ],
      ),
    );
  }
}

// Dashboard Page
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

// Dashboard
class _DashboardPageState extends State<DashboardPage> {
  int checkedTodayCount = 0;

  int technicianCount = 0;
  int totalToolsCount = 0;
  int toolsOKCount = 0;
  int toolsdefectiveCount = 0;
  int toolsUnassignedCount = 0;
  int toolsCheckedToday = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    final supabase = Supabase.instance.client;
    setState(() => isLoading = true);

    try {
      // --- Fetch all data from tables ---
      final technicians = await supabase.from('technicians').select();
      final allTools = await supabase.from('tools').select();
      final technicianTools = await supabase
          .from('technician_tools')
          .select('checked_at, status');

      // --- Initialize counts ---
      int OKCount = 0;
      int defectiveCount = 0;
      int checkedToday = 0;

      final today = DateTime.now();

      for (final tool in technicianTools) {
        final checkedAt = tool['checked_at'] != null
            ? DateTime.parse(tool['checked_at'])
            : null;

        // Count based on status
        if (tool['status'] == 'None') {
          OKCount++;
        } else if (tool['status'] == 'Defective') {
          defectiveCount++;
        }

        // 📅 Count tools checked/updated today
        if (checkedAt != null &&
            checkedAt.year == today.year &&
            checkedAt.month == today.month &&
            checkedAt.day == today.day) {
          checkedToday++;
        }
      }

      final totalTools = allTools.length;

      if (!mounted) return;

      setState(() {
        technicianCount = technicians.length;
        totalToolsCount = totalTools;
        toolsOKCount = OKCount;
        toolsdefectiveCount = defectiveCount;
        toolsUnassignedCount = 0;
        checkedTodayCount = checkedToday;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error fetching dashboard data: $e');
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load dashboard: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _fetchDashboardData,
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: isLoading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        children: [
                          DashboardBox(
                            title: 'Total no. of Technicians',
                            count: technicianCount.toString(),
                            icon: Icons.engineering,
                            color: Colors.blue,
                          ),
                          DashboardBox(
                            title: 'Total no. of Tools',
                            count: totalToolsCount.toString(),
                            icon: Icons.build,
                            color: Colors.purple,
                          ),
                          DashboardBox(
                            title: 'OK Tools',
                            count: toolsOKCount.toString(),
                            icon: Icons.check_circle,
                            color: Colors.green,
                          ),
                          DashboardBox(
                            title: 'Defective Tools',
                            count: toolsdefectiveCount.toString(),
                            icon: Icons.cancel,
                            color: Colors.red,
                          ),
                          /*
                          DashboardBox(
                            title: 'Unassigned Tools',
                            count: toolsUnassignedCount.toString(),
                            icon: Icons.inventory_2,
                            color: Colors.grey,
                          ),
                          */
                        ],
                      ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// Reusable Dashboard Box Widget
class DashboardBox extends StatelessWidget {
  final String title;
  final String count;
  final IconData? icon;
  final Color color;

  const DashboardBox({
    super.key,
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(
            count,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
