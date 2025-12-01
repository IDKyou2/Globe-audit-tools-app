import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'TechniciansScreen.dart';
import '../main.dart';

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
    _fetchLoggedUser();
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('username');
      await prefs.remove('password');
      await prefs.setBool('rememberMe', false);

      await Supabase.instance.client.auth.signOut();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Logged out successfully.',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w400,
              ),
            ),
            //backgroundColor: Theme.of(context).colorScheme.primary,
            backgroundColor: Colors.white,
            behavior: SnackBarBehavior.floating,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: isDark
            ? colorScheme.surfaceVariant
            : const Color(0xFF003E70),
        elevation: 2,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        title: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Text(
            _selectedIndex == 0 ? 'Dashboard' : 'Technicians',
            style: TextStyle(
              color: isDark ? colorScheme.onSurface : Colors.white,
              fontSize: 20,
            ),
          ),
        ),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: Icon(
                Icons.menu,
                color: isDark ? colorScheme.onSurface : Colors.white,
              ),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      endDrawer: _buildDrawer(context, isDark, colorScheme),
      body: _pages[_selectedIndex],
      bottomNavigationBar: _buildBottomNavBar(isDark, colorScheme),
    );
  }

  Widget _buildDrawer(
    BuildContext context,
    bool isDark,
    ColorScheme colorScheme,
  ) {
    return Drawer(
      backgroundColor: colorScheme.surface,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: isDark
                  ? colorScheme.primaryContainer
                  : const Color(0xFF003E70),
            ),
            child: Text(
              _loggedUserName ?? '',
              style: TextStyle(
                color: isDark ? colorScheme.onPrimaryContainer : Colors.white,
                fontSize: 20,
              ),
            ),
          ),
          ListTile(
            leading: Icon(
              isDark ? Icons.dark_mode : Icons.light_mode,
              color: colorScheme.primary,
            ),
            title: Text(
              'Dark Mode',
              style: TextStyle(color: colorScheme.onSurface),
            ),
            trailing: Switch(
              value: isDark,
              onChanged: (value) => MyApp.of(context)?.toggleTheme(value),
              activeColor: colorScheme.primary,
            ),
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.add, color: colorScheme.primary),
            title: Text(
              'Manage Tools',
              style: TextStyle(color: colorScheme.onSurface),
            ),
            onTap: () {
              Navigator.pop(context);
              context.push('/add-tools');
            },
          ),
          ListTile(
            leading: Icon(Icons.download, color: colorScheme.primary),
            title: Text(
              'Export File',
              style: TextStyle(color: colorScheme.onSurface),
            ),
            onTap: () {
              Navigator.pop(context);
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
    );
  }

  Widget _buildBottomNavBar(bool isDark, ColorScheme colorScheme) {
    return BottomNavigationBar(
      backgroundColor: isDark
          ? colorScheme.surfaceVariant
          : const Color(0xFF003E70),
      selectedItemColor: Colors.white,
      unselectedItemColor: isDark
          ? colorScheme.onSurfaceVariant
          : Colors.white70,
      currentIndex: _selectedIndex,
      onTap: (index) => setState(() => _selectedIndex = index),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.engineering),
          label: 'Manage Technicians',
        ),
      ],
    );
  }
}

// ==================== Dashboard Page ====================
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, int> technicianDefectiveCounts = {}; // name -> defective count

  int checkedTodayCount = 0;
  int technicianCount = 0;
  int totalToolsCount = 0;
  int toolsOnhandCount = 0;
  int toolsDefectiveCount = 0;
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
      final technicians = await supabase.from('technicians').select();
      final allTools = await supabase.from('tools').select();
      final technicianTools = await supabase
          .from('technician_tools')
          .select('checked_at, status');

      int onhandCount = 0;
      int defectiveCount = 0;
      int checkedToday = 0;

      final today = DateTime.now();

      for (final tool in technicianTools) {
        final checkedAt = tool['checked_at'] != null
            ? DateTime.parse(tool['checked_at'])
            : null;

        if (tool['status'] == 'Onhand') {
          onhandCount++;
        } else if (tool['status'] == 'Defective') {
          defectiveCount++;
        }

        if (checkedAt != null &&
            checkedAt.year == today.year &&
            checkedAt.month == today.month &&
            checkedAt.day == today.day) {
          checkedToday++;
        }
      }

      if (!mounted) return;

      setState(() {
        technicianCount = technicians.length;
        totalToolsCount = allTools.length;
        toolsOnhandCount = onhandCount;
        toolsDefectiveCount = defectiveCount;
        checkedTodayCount = checkedToday;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching dashboard data: $e');
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
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: _fetchDashboardData,
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      buildDateHeader(isDark),
                      const SizedBox(height: 20),
                      //buildDashboardCards(isDark),
                      //const SizedBox(height: 40),
                      buildPieChart(isDark),
                      const SizedBox(height: 30),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget buildDateHeader(bool isDark) {
    return Row(
      children: [
        Text(
          "Date: ",
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        Text(
          DateFormat('MMMM dd, yyyy').format(DateTime.now()),
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ],
    );
  }

  /*
  Widget buildDashboardCards(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [Colors.grey.shade900, Colors.grey.shade800]
              : [Colors.white, Colors.grey.shade50],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _DashboardCard(
                title: 'Total Technicians',
                count: technicianCount.toString(),
                icon: Icons.engineering,
                color: Colors.orange,
              ),
              _DashboardCard(
                title: 'Tools Total',
                count: totalToolsCount.toString(),
                icon: Icons.build,
                color: Colors.blue,
              ),
              _DashboardCard(
                title: 'Tools Onhand',
                count: toolsOnhandCount.toString(),
                icon: Icons.check_circle,
                color: Colors.green,
              ),
              _DashboardCard(
                title: 'Defective Tools',
                count: toolsDefectiveCount.toString(),
                icon: Icons.warning,
                color: Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }
*/

  Widget buildPieChart(bool isDark) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.45,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [Colors.grey.shade900, Colors.grey.shade800]
              : [Colors.white, Colors.grey.shade50],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius:
                    MediaQuery.of(context).size.width * 0.15, // ⬅ responsive
                startDegreeOffset: -90,
                sections: [
                  _buildPieSection(
                    toolsOnhandCount.toDouble(),
                    Colors.green,
                    Icons.check_circle,
                  ),
                  _buildPieSection(
                    toolsDefectiveCount.toDouble(),
                    Colors.red,
                    Icons.warning,
                  ),
                  _buildPieSection(
                    technicianCount.toDouble(),
                    Colors.orange,
                    Icons.engineering,
                  ),
                  _buildPieSection(
                    totalToolsCount.toDouble(),
                    Colors.grey,
                    Icons.build,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16), // ⬅ spacing between chart and legend

          Wrap(
            spacing: 10,
            runSpacing: 5,
            alignment: WrapAlignment.center,
            children: [
              _LegendItem('Overall Tools On-hand', Colors.green),
              _LegendItem('Overall Defective Tools', Colors.red),
              _LegendItem('Total Technicians', Colors.orange),
              _LegendItem('Total Tools', Colors.grey),
            ],
          ),
        ],
      ),
    );
  }

  PieChartSectionData _buildPieSection(
    double value,
    Color color,
    IconData icon,
  ) {
    return PieChartSectionData(
      value: value,
      title: '${value.toInt()}',
      color: color,
      radius: 65,
      titleStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      badgeWidget: _ChartBadge(icon: icon, color: color),
      badgePositionPercentageOffset: 1.4,
    );
  }
}

// ==================== Helper Widgets ====================
class _DashboardCard extends StatelessWidget {
  final String title;
  final String count;
  final IconData icon;
  final Color color;

  const _DashboardCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32, color: Colors.white),
          const SizedBox(height: 8),
          Text(
            count,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartBadge extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _ChartBadge({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String label;
  final Color color;
  //final int count;

  const _LegendItem(
    this.label,
    this.color,
    // this.count
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 4),
        /*
        Text(
          '$count',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        */
      ],
    );
  }
}
