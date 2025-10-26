// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TechniciansScreen extends StatefulWidget {
  const TechniciansScreen({super.key});

  @override
  State<TechniciansScreen> createState() => _TechniciansScreenState();
}

class _TechniciansScreenState extends State<TechniciansScreen> {
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

  // Add
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
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: _handleAddPress,
                  icon: const Icon(Icons.add),
                  label: const Text('Add technician'),
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
                        backgroundColor: Color.fromARGB(255, 0, 62, 112),
                        child: Text(
                          (index + 1).toString()[0],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              technician['name'] ?? 'Unknown',
                              style: const TextStyle(fontSize: 14),
                              overflow: TextOverflow
                                  .visible, // default; allows wrapping
                              softWrap: true,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        '${technician['cluster'] ?? 'N/A'}',
                        softWrap: true,
                        style: const TextStyle(fontSize: 14),
                      ),

                      // 👇 Combine ElevatedButton + Icon inside trailing
                      trailing: Row(
                        mainAxisSize:
                            MainAxisSize.min, // Important to prevent full width
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              context.push(
                                '/view-tools',
                                extra: {
                                  'id': technician['id'],
                                  'name': technician['name'],
                                },
                              );
                              print('Button pressed for ${technician['name']}');
                            },
                            child: const Text('Tools'),
                          ),
                          const SizedBox(width: 8), // spacing before arrow
                          IconButton(
                            icon: const Icon(Icons.more_vert, size: 25),
                            onPressed: () async {
                              // Show dropdown menu first
                              final selected = await showMenu<String>(
                                context: context,
                                position: const RelativeRect.fromLTRB(
                                  100,
                                  100,
                                  0,
                                  0,
                                ), // adjust position if needed
                                items: [
                                  const PopupMenuItem<String>(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  const PopupMenuItem<String>(
                                    value: 'delete',
                                    child: Text(
                                      'Remove',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              );

                              if (selected == 'edit') {
                                showDialog(
                                  context: context,
                                  builder: (context) {
                                    final nameController =
                                        TextEditingController(
                                          text: technician['name'],
                                        );
                                    final clusterController =
                                        TextEditingController(
                                          text: technician['cluster'],
                                        );

                                    return AlertDialog(
                                      title: const Text('Edit Technician'),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          TextField(
                                            controller: nameController,
                                            decoration: const InputDecoration(
                                              labelText: 'Technician Name',
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          TextField(
                                            controller: clusterController,
                                            decoration: const InputDecoration(
                                              labelText: 'Cluster',
                                            ),
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () async {
                                            final supabase =
                                                Supabase.instance.client;
                                            Navigator.pop(context);

                                            try {
                                              // ✅ Update the record
                                              await supabase
                                                  .from('technicians')
                                                  .update({
                                                    'name': nameController.text
                                                        .trim(),
                                                    'cluster': clusterController
                                                        .text
                                                        .trim(),
                                                  })
                                                  .eq('id', technician['id']);

                                              // ✅ Refresh the list after update
                                              await _fetchTechnicians();

                                              // ✅ Show success message
                                              if (mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Technician updated successfully!',
                                                    ),
                                                  ),
                                                );
                                              }
                                            } catch (e) {
                                              if (mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Error updating technician: $e',
                                                    ),
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                          child: const Text('Save'),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              } else if (selected == 'delete') {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Remove Technician'),
                                    content: const Text(
                                      'Are you sure you want to remove this technician?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () async {
                                          Navigator.pop(context);
                                          final supabase =
                                              Supabase.instance.client;

                                          try {
                                            // ✅ Delete from Supabase
                                            await supabase
                                                .from('technicians')
                                                .delete()
                                                .eq('id', technician['id']);

                                            // ✅ Refresh the list
                                            await _fetchTechnicians();

                                            // ✅ Show confirmation
                                            if (mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Technician deleted successfully!',
                                                  ),
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            if (mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Error deleting technician: $e',
                                                  ),
                                                ),
                                              );
                                            }
                                          }
                                        },
                                        child: const Text(
                                          'Delete',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
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
