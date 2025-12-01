import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminApprovalPage extends StatefulWidget {
  const AdminApprovalPage({super.key});

  @override
  State<AdminApprovalPage> createState() => _AdminApprovalPageState();
}

class _AdminApprovalPageState extends State<AdminApprovalPage> {
  final supabase = Supabase.instance.client;

  Future<List<dynamic>> _fetchPendingUsers() async {
    return await supabase
        .from('users')
        .select()
        .eq('is_approved', false)
        .eq('role', 'user'); // only normal users waiting approval
  }

  Future<void> approveUser(String id) async {
    await supabase
        .from('users')
        .update({'is_approved': true})
        .eq('id', id);

    setState(() {});
  }

  Future<void> rejectUser(String id) async {
    await supabase.from('users').delete().eq('id', id);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("User Approvals"),
      ),
      body: FutureBuilder(
        future: _fetchPendingUsers(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data!;

          if (users.isEmpty) {
            return const Center(
              child: Text("No pending user approvals."),
            );
          }

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (_, i) {
              final u = users[i];

              return Card(
                child: ListTile(
                  title: Text(u['username']),
                  subtitle: Text("Status: Pending"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () => approveUser(u['id']),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => rejectUser(u['id']),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
