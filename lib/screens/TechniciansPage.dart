// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TechniciansPage extends StatefulWidget {
  const TechniciansPage({super.key});

  @override
  State<TechniciansPage> createState() => _TechniciansPageState();
}

class _TechniciansPageState extends State<TechniciansPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _clusterController = TextEditingController();

  List<dynamic> _technicians = [];
  bool _isLoading = true;

  @override
  void dispose() {
    _nameController.dispose();
    _clusterController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchTechnicians();
  }

  Future<void> _fetchTechnicians() async {
    final supabase = Supabase.instance.client;

    setState(() => _isLoading = true);

    try {
      final response = await supabase
          .from('technicians')
          .select()
          .order('created_at', ascending: false); // Newest first

      if (mounted) {
        setState(() {
          _technicians = response;
          _isLoading = false;
        });
      }
      //print('Fetched ${_technicians.length} technicians');
    } catch (e) {
      //print('Error fetching technicians: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching technicians: $e')),
        );
      }
    }
  }

  void _handleAddPress() {
    final List<String> clusters = ['Davao North', 'Davao South'];
    String? selectedCluster;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Add Technician'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedCluster,
                      hint: const Text('Choose cluster'),
                      isExpanded: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      items: clusters.map((String cluster) {
                        return DropdownMenuItem<String>(
                          value: cluster,
                          child: Text(cluster),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setStateDialog(() {
                          selectedCluster = newValue;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    String name = _nameController.text.trim();
                    String cluster = selectedCluster ?? '';

                    if (name.isEmpty || cluster.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill all fields')),
                      );
                      return;
                    }

                    try {
                      final supabase = Supabase.instance.client;
                      final userId = supabase.auth.currentUser?.id;

                      await supabase.from('technicians').insert({
                        'name': name,
                        'cluster': cluster,
                        'user_id': userId,
                      });

                      await _fetchTechnicians(); // Refresh list

                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Technician $name added successfully!',
                            ),
                          ),
                        );
                        _nameController.clear();
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'List of Technicians',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _handleAddPress,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
          ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_technicians.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'No technicians found',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _handleAddPress,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Technician'),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _technicians.length,
                itemBuilder: (context, index) {
                  final technician = _technicians[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text('${(index + 1).toString()[0]}'),
                      ),
                      title: Text(technician['name'] ?? 'Unknown'),
                      subtitle: Text(
                        'Cluster: ${technician['cluster'] ?? 'N/A'}',
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
