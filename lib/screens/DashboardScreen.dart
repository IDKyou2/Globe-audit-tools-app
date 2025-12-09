// ignore_for_file: file_names

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'TechniciansScreen.dart';
import '../main.dart';

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
///
///
///                                 BOXED DASHBOARD, WORKING SELECT DATE BUTTON
///
////////////////////////////////////////////////////////////////////////////////////////////////////////////

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
          const SnackBar(
            content: Text(
              'Logged out successfully.',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w400,
              ),
            ),
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
  int checkedTodayCount = 0;
  int technicianCount = 0;
  int totalToolsCount = 0;
  int toolsOnhandCount = 0;
  int toolsDefectiveCount = 0;
  int techniciansInspectedCount = 0;
  bool isLoading = true;
  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    final supabase = Supabase.instance.client;
    setState(() => isLoading = true);

    try {
      final today = DateTime.now();

      // Build local day range
      final startLocal = DateTime(today.year, today.month, today.day);
      final endLocal = startLocal.add(const Duration(days: 1));

      // Convert LOCAL → UTC for Supabase query
      final startUTC = startLocal.toUtc();
      final endUTC = endLocal.toUtc();

      final technicians = await supabase.from('technicians').select();
      final allTools = await supabase.from('tools').select();

      final technicianTools = await supabase
          .from('technician_tools')
          .select('checked_at, status, last_updated_at, technician_id')
          .gte('last_updated_at', startUTC.toIso8601String())
          .lt('last_updated_at', endUTC.toIso8601String());

      int onhandCount = 0;
      int defectiveCount = 0;
      int checkedCountForDate = 0;
      Set<String> inspectedTechnicianIds = {};

      for (final tool in technicianTools) {
        final checkedAt = tool['checked_at'] != null
            ? DateTime.parse(tool['checked_at']).toLocal()
            : null;

        if (tool['status'] == 'Onhand') onhandCount++;
        if (tool['status'] == 'Defective') defectiveCount++;

        if (checkedAt != null &&
            checkedAt.year == today.year &&
            checkedAt.month == today.month &&
            checkedAt.day == today.day) {
          checkedCountForDate++;
        }

        if (tool['technician_id'] != null) {
          inspectedTechnicianIds.add(tool['technician_id'].toString());
        }
      }

      if (!mounted) return;

      setState(() {
        technicianCount = technicians.length;
        totalToolsCount = allTools.length;
        toolsOnhandCount = onhandCount;
        toolsDefectiveCount = defectiveCount;
        checkedTodayCount = checkedCountForDate;
        techniciansInspectedCount = inspectedTechnicianIds.length;
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

  Future<void> filteredDate(DateTime pickedDate) async {
    final supabase = Supabase.instance.client;

    // Find the nearest audit date equal or before pickedDate
    final actualDate = await getNearestPreviousAuditDate(pickedDate);

    if (actualDate == null) {
      // No audit found at all
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("No Data Found"),
            content: Text(
              "There are no audit logs on or before "
              "${DateFormat('MMMM dd, yyyy').format(pickedDate)}.",
            ),
            actions: [
              TextButton(
                child: const Text("OK"),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
      return;
    }

    // Convert UTC from database → LOCAL time
    final localActualDate = actualDate.toLocal();

    // Update selected date in UI to reflect the actual audit date
    setState(() => selectedDate = localActualDate);

    // Build local day range
    final startDate = DateTime(
      localActualDate.year,
      localActualDate.month,
      localActualDate.day,
    );
    final endDate = startDate.add(const Duration(days: 1));

    // Convert LOCAL → UTC for Supabase query
    final utcStartDate = startDate.toUtc();
    final utcEndDate = endDate.toUtc();

    final logs = await supabase
        .from('technician_tools')
        .select('status, technician_id, checked_at')
        .gte('last_updated_at', utcStartDate.toIso8601String())
        .lt('last_updated_at', utcEndDate.toIso8601String());

    int onhand = 0;
    int defective = 0;
    int checked = 0;
    Set<String> inspectedTechnicianIds = {};

    for (final log in logs) {
      if (log['status'] == 'Onhand') onhand++;
      if (log['status'] == 'Defective') defective++;

      if (log['checked_at'] != null) {
        final checkedAt = DateTime.parse(log['checked_at']).toLocal();
        if (checkedAt.year == localActualDate.year &&
            checkedAt.month == localActualDate.month &&
            checkedAt.day == localActualDate.day) {
          checked++;
        }
      }

      if (log['technician_id'] != null) {
        inspectedTechnicianIds.add(log['technician_id'].toString());
      }
    }

    if (!mounted) return;

    setState(() {
      toolsOnhandCount = onhand;
      toolsDefectiveCount = defective;
      techniciansInspectedCount = inspectedTechnicianIds.length;
      checkedTodayCount = checked; // now correct for selected date
    });
  }

  Future<DateTime?> getNearestPreviousAuditDate(DateTime pickedDate) async {
    final supabase = Supabase.instance.client;

    // Convert pickedDate (LOCAL) → UTC for query
    final queryDateUTC = pickedDate.toUtc();

    final response = await supabase
        .from('technician_tools')
        .select('last_updated_at')
        .lte('last_updated_at', queryDateUTC.toIso8601String())
        .order('last_updated_at', ascending: false)
        .limit(1);

    if (response.isEmpty) return null;

    return DateTime.parse(response.first['last_updated_at']); // returns UTC
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: () async {
        final today = DateTime.now();
        setState(() => selectedDate = today);
        await filteredDate(today);
      },
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
                      const SizedBox(height: 10),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Last audit date text
        Row(
          children: [
            Text(
              "Last audit date: ${DateFormat('MMMM dd, yyyy').format(selectedDate)}",
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),

        const SizedBox(width: 5),

        ElevatedButton(
          onPressed: () async {
            final today = DateTime.now();

            final picked = await showDatePicker(
              context: context,
              initialDate: selectedDate.isAfter(today) ? today : selectedDate,
              firstDate: DateTime(2023),
              lastDate: today,
            );

            if (picked != null) {
              setState(() => selectedDate = picked);
              filteredDate(picked);
            }
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: const Size(85, 30),
            textStyle: const TextStyle(fontSize: 13),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text("Select Date"),
              SizedBox(width: 4),
              Icon(Icons.arrow_drop_down, size: 18),
            ],
          ),
        ),
        // const SizedBox(height: 10),
      ],
    );
  }

  Widget buildPieChart(bool isDark) {
    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.1,
      children: [
        _DashboardCard(
          title: 'Tools On-hand',
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
        _DashboardCard(
          title: 'Technicians Inspected',
          count: techniciansInspectedCount.toString(),
          icon: Icons.fact_check,
          color: Colors.blue,
        ),
        _DashboardCard(
          title: 'Total Technicians',
          count: technicianCount.toString(),
          icon: Icons.engineering,
          color: Colors.orange,
        ),
        _DashboardCard(
          title: 'Overall Tools Total',
          count: totalToolsCount.toString(),
          icon: Icons.build,
          color: Colors.grey,
        ),
      ],
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
