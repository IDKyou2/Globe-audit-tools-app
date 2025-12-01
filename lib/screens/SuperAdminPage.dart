import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SuperAdminPage extends StatelessWidget {
  const SuperAdminPage({super.key});

  // Logout function
  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    await prefs.remove('username');
    await prefs.remove('password');
    await prefs.setBool('rememberMe', false);

    const secureStorage = FlutterSecureStorage();
    await secureStorage.delete(key: 'password');

    if (context.mounted) {
      context.go('/'); // navigate to login page
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Superadmin Panel"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ElevatedButton(
            onPressed: () => context.push('/admin-approvals'),
            child: const Text("Manage User Approvals"),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.push('/manage-admins'),
            child: const Text("Manage Admin Accounts"),
          ),
        ],
      ),
    );
  }
}
