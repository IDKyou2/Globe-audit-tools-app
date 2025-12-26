// ignore_for_file: file_names

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

          // --------------------------------------- DARK MODE TOGGLE -----------------------------------
          // ListTile(
          //   leading: Icon(
          //     isDark ? Icons.dark_mode : Icons.light_mode,
          //     color: colorScheme.primary,
          //   ),
          //   title: Text(
          //     'Dark Mode',
          //     style: TextStyle(color: colorScheme.onSurface),
          //   ),
          //   trailing: Switch(
          //     value: isDark,
          //     onChanged: (value) => MyApp.of(context)?.toggleTheme(value),
          //     activeColor: colorScheme.primary,
          //   ),
          // ),

          //const Divider(),
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

      final startLocal = DateTime(today.year, today.month, today.day);
      final endLocal = startLocal.add(const Duration(days: 1));

      final startUTC = startLocal.toUtc();
      final endUTC = endLocal.toUtc();

      final technicians = await supabase.from('technicians').select();
      final allTools = await supabase.from('tools').select();

      final logs = await supabase
          .from('technician_tools')
          .select('status, technician_id, last_updated_at')
          .gte('last_updated_at', startUTC.toIso8601String())
          .lt('last_updated_at', endUTC.toIso8601String());

      int onhand = 0;
      int defective = 0;
      int checked = 0;
      Set<String> inspectedTechs = {};

      for (final log in logs) {
        final status = log['status'];

        if (status == 'Onhand') onhand++;
        if (status == 'Defective') defective++;

        if (log['checked_at'] != null) {
          final checkedAt = DateTime.parse(log['checked_at']).toLocal();

          if (checkedAt.year == today.year &&
              checkedAt.month == today.month &&
              checkedAt.day == today.day) {
            checked++;
          }
        }

        if (log['technician_id'] != null) {
          inspectedTechs.add(log['technician_id'].toString());
        }
      }

      if (!mounted) return;

      setState(() {
        technicianCount = technicians.length;
        totalToolsCount = allTools.length;
        toolsOnhandCount = onhand;
        toolsDefectiveCount = defective;
        checkedTodayCount = checked;
        techniciansInspectedCount = inspectedTechs.length;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load dashboard: $e')));
      }
    }
  }

  Future<bool> filteredDate(DateTime pickedDate) async {
    final supabase = Supabase.instance.client;

    final utcDate = DateTime.utc(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
    );

    final exact = await supabase
        .from('dashboard_summary')
        .select()
        .eq('summary_date', utcDate.toIso8601String().substring(0, 10))
        .maybeSingle();

    Map<String, dynamic>? row = exact;

    if (row == null) {
      final previous = await supabase
          .from('dashboard_summary')
          .select()
          .lte('summary_date', utcDate.toIso8601String().substring(0, 10))
          .order('summary_date', ascending: false)
          .limit(1);

      if (previous.isEmpty) {
        if (!mounted) return false;

        // Try to find nearest previous audit date
        final nearestDate = await getNearestPreviousAuditDate(pickedDate);

        if (nearestDate == null) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("No Data Found"),
              content: Text(
                "There are no inspection records on or before "
                "${DateFormat('MMMM dd, yyyy').format(pickedDate)}.",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK"),
                ),
              ],
            ),
          );
          return false;
        }

        // Update to nearest previous audit date
        setState(() {
          selectedDate = nearestDate.toLocal();
        });

        return false;
      }
      row = previous.first;
    }

    final summaryDate = DateTime.parse(row['summary_date']).toLocal();

    if (!mounted) return true;

    setState(() {
      selectedDate = summaryDate;
      toolsOnhandCount = row!['tools_onhand'] ?? 0;
      toolsDefectiveCount = row['tools_defective'] ?? 0;
      techniciansInspectedCount = row['technicians_inspected'] ?? 0;
      checkedTodayCount = row['checked_today'] ?? 0;
    });

    return true;
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

  // Reusable function to fetch data based on selected date
  Future<bool> fetchDataForDate(DateTime date) async {
    final today = DateTime.now();

    if (_isSameDate(date, today)) {
      await _fetchDashboardData();
      return true;
    } else {
      return await filteredDate(date);
    }
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
            //
            final today = DateTime.now();
            final previousValidDate = selectedDate; // Store current date

            final picked = await showDatePicker(
              context: context,
              initialDate: selectedDate.isAfter(today) ? today : selectedDate,
              firstDate: DateTime(2023),
              lastDate: today,
            );

            if (picked != null) {
              setState(() => selectedDate = picked);

              final success = await fetchDataForDate(picked);

              if (!success && selectedDate == picked) {
                setState(() => selectedDate = previousValidDate);
              }
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

  Widget buildBoxes(bool isDark) {
    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.1,
      children: [
        _DashboardCard(
          title: 'Overall Tools On-hand',
          count: toolsOnhandCount.toString(),
          icon: Icons.check_circle,
          color: Colors.green,
        ),
        _DashboardCard(
          title: 'Overall Defective Tools ',
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
          title: 'Total Tools \n(Per technician)',
          count: totalToolsCount.toString(),
          icon: Icons.build,
          color: Colors.grey,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: () async {
        final today = DateTime.now();
        setState(() => selectedDate = today);
        await fetchDataForDate(today);
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
                      buildBoxes(isDark),
                      const SizedBox(height: 30),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ==================== Helper Widgets ====================\
// Helper function to check if two dates are the same day
bool _isSameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

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
