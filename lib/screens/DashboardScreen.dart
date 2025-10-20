// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'TechniciansScreen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _pages = [const DashboardPage(), TechniciansScreen()];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _handleLogout(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();
      context.go('/');
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error logging out: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 2,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _handleLogout(context);
              } else if (value == 'add-tools') {
                context.go('/add-tools'); // navigate to AddNewToolPage
              } else if (value == 'technician-tools') {
                context.push('/technician-tools');
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'add-tools',
                child: Row(
                  children: [
                    Icon(Icons.add, size: 20),
                    SizedBox(width: 10),
                    Text('Add Tools'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 10),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
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

class _DashboardPageState extends State<DashboardPage> {
  int technicianCount = 0;
  int okToolsCount = 0;
  int missingToolsCount = 0;
  int defectiveToolsCount = 0;
  int totalToolsCount = 0;
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
      // Debug: Fetch all technicians to see raw data
      final allTechs = await supabase.from('technicians').select();
      print('All technicians data: $allTechs');
      print('Technicians count: ${allTechs.length}');

      // Debug: Fetch all tools to see raw data
      final totalTools = await supabase.from('tools').select();
      print('All tools data: $totalTools');
      print('Total tools: ${totalTools.length}');

      // Filter tools by status
      final okList = totalTools
          .where((tool) => tool['status'] == 'OK')
          .toList();
      final missingList = totalTools
          .where((tool) => tool['status'] == 'Missing')
          .toList();
      final defectiveList = totalTools
          .where((tool) => tool['status'] == 'Defective')
          .toList();

      print('OK tools: ${okList.length}');
      print('Missing tools: ${missingList.length}');
      print('Defective tools: ${defectiveList.length}');

      if (!mounted) return;

      setState(() {
        technicianCount = allTechs.length;
        okToolsCount = okList.length;
        missingToolsCount = missingList.length;
        defectiveToolsCount = defectiveList.length;
        totalToolsCount = totalTools.length;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching dashboard data: $e');
      print('Error type: ${e.runtimeType}');
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Dashboard',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      children: [
                        DashboardBox(
                          title: 'Technicians',
                          count: technicianCount.toString(),
                        ),
                        DashboardBox(
                          title: 'OK Tools',
                          count: okToolsCount.toString(),
                        ),
                        DashboardBox(
                          title: 'Missing Tools',
                          count: missingToolsCount.toString(),
                        ),
                        DashboardBox(
                          title: 'Defective Tools',
                          count: defectiveToolsCount.toString(),
                        ),
                        DashboardBox(
                          title: 'Total Tools',
                          count: (totalToolsCount).toString(),
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
}

// Reusable Dashboard Box Widget
class DashboardBox extends StatelessWidget {
  final String title;
  final String count;

  const DashboardBox({super.key, required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            count,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
