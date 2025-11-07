// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TechniciansScreen extends StatefulWidget {
  const TechniciansScreen({super.key});

  @override
  State<TechniciansScreen> createState() => _TechniciansScreenState();
}

class _TechniciansScreenState extends State<TechniciansScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _clusterController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  String formatDateTime(dynamic rawDate) {
    if (rawDate == null) return 'Never';

    final dt = DateTime.parse(rawDate.toString());
    return DateFormat('MM/dd/yyyy, hh:mm a').format(dt);
  }

  List<dynamic> _technicians = [];
  List<dynamic> _filteredTechnicians = [];
  bool _isLoading = true;
  bool _isSearching = false;

  @override
  void dispose() {
    _nameController.dispose();
    _clusterController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchTechnicians();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  Future<void> _fetchTechnicians() async {
    final supabase = Supabase.instance.client;

    setState(() => _isLoading = true);

    try {
      final response = await supabase
          .from('technicians')
          .select()
          .order(
            'last_checked_at',
            ascending: false,
          ); // Most recently checked first
      //.order('created_at', ascending: false); // Newest first

      if (mounted) {
        setState(() {
          _technicians = response;
          _filteredTechnicians = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching technicians: $e')),
        );
      }
    }
  }

  /// Search function
  void _filterTechnicians(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredTechnicians = _technicians;
      } else {
        _filteredTechnicians = _technicians.where((technician) {
          final name = technician['name']?.toString().toLowerCase() ?? '';
          final cluster = technician['cluster']?.toString().toLowerCase() ?? '';
          final searchLower = query.toLowerCase();

          return name.contains(searchLower) || cluster.contains(searchLower);
        }).toList();
      }
    });
  }

  // Add
  void _handleAddTechnician() {
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
                      items: clusters.map((cluster) {
                        return DropdownMenuItem<String>(
                          value: cluster,
                          child: Text(cluster),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setStateDialog(() => selectedCluster = newValue);
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
                    final name = _nameController.text.trim();
                    final cluster = selectedCluster;

                    if (name.isEmpty || cluster == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill all fields')),
                      );
                      return;
                    }

                    try {
                      final supabase = Supabase.instance.client;

                      // check if name already exists
                      final existing = await supabase
                          .from('technicians')
                          .select('id')
                          .eq('name', name)
                          .maybeSingle();

                      if (existing != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Technician "$name" already exists.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return; // stop — do not insert
                      }

                      // Insert technician
                      await supabase.from('technicians').insert({
                        'name': name,
                        'cluster': cluster,
                      });

                      await _fetchTechnicians();

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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error adding technician: $e')),
                      );
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

  void _showEditTechnicianDialog(Map<String, dynamic> technician) {
    final nameController = TextEditingController(text: technician['name']);
    final clusterController = TextEditingController(
      text: technician['cluster'],
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Technician'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Technician Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: clusterController,
              decoration: const InputDecoration(
                labelText: 'Cluster',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              nameController.dispose();
              clusterController.dispose();
              Navigator.pop(dialogContext);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final cluster = clusterController.text.trim();

              if (name.isEmpty || cluster.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill all fields'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              Navigator.pop(dialogContext); // Close dialog first

              try {
                await Supabase.instance.client
                    .from('technicians')
                    .update({'name': name, 'cluster': cluster})
                    .eq('id', technician['id']);

                await _fetchTechnicians();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Technician updated successfully!'),
                      // backgroundColor: Color(0xFF003E70),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error updating technician: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } finally {
                nameController.dispose();
                clusterController.dispose();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteTechnicianDialog(Map<String, dynamic> technician) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Technician'),
        content: Text(
          'Are you sure you want to remove "${technician['name']}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext); // Close dialog first

              try {
                await Supabase.instance.client
                    .from('technicians')
                    .delete()
                    .eq('id', technician['id']);

                await _fetchTechnicians();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Technician deleted successfully!'),
                      //backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting technician: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> updateLastChecked(String technicianId) async {
    try {
      final now = DateTime.now();
      final formatted = DateFormat('MM/dd/yyyy, h:mm a').format(now);

      await Supabase.instance.client
          .from('technicians')
          .update({'last_checked_at': formatted})
          .eq('id', technicianId); // uuid is string
    } catch (e) {
      debugPrint('Error updating last checked: $e');
    }
  }

  // Main build
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Search Icon/Field
                Expanded(
                  child: _isSearching
                      ? TextField(
                          controller: _searchController,
                          autofocus: true,
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'Search by name or cluster...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                setState(() {
                                  _isSearching = false;
                                  _searchController.clear();
                                  _filteredTechnicians = _technicians;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                          ),
                          onChanged: _filterTechnicians,
                        )
                      : Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.search, size: 28),
                              onPressed: () {
                                setState(() {
                                  _isSearching = true;
                                });
                              },
                            ),
                            const Spacer(),
                          ],
                        ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _handleAddTechnician,
                  icon: const Icon(Icons.add),
                  label: const Text('Add technician'),
                ),
              ],
            ),
          ),

          // Search results count
          if (_isSearching && _searchController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                'Found ${_filteredTechnicians.length} result(s)',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),

          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_filteredTechnicians.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _searchController.text.isNotEmpty
                          ? Icons.search_off
                          : Icons.people_outline,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _filteredTechnicians.length,
                itemBuilder: (context, index) {
                  final technician = _filteredTechnicians[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color.fromARGB(255, 0, 62, 112),
                        child: Text(
                          technician['name']?.toString()[0].toUpperCase() ??
                              '?',
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
                              overflow: TextOverflow.visible,
                              softWrap: true,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            technician['cluster'] ?? 'N/A',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Last Checked: ${formatDateTime(technician['last_checked_at'])}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color.fromARGB(255, 61, 57, 57),
                            ),
                          ),
                        ],
                      ),

                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton(
                            onPressed: () async {
                              await updateLastChecked(technician['id']);
                              await context.push(
                                '/view-tools',
                                extra: {
                                  'id': technician['id'],
                                  'name': technician['name'],
                                },
                              );

                              // refresh technicians card
                              if (!mounted) return;
                              //await _fetchTechnicians();
                            },

                            child: const Text('Tools'),
                          ),

                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.more_vert, size: 25),
                            onPressed: () async {
                              final selected = await showMenu<String>(
                                context: context,
                                position: const RelativeRect.fromLTRB(
                                  100,
                                  100,
                                  0,
                                  0,
                                ),
                                items: [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text(
                                      'Remove',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              );
                              if (selected == 'edit') {
                                _showEditTechnicianDialog(technician);
                              } else if (selected == 'delete') {
                                _showDeleteTechnicianDialog(technician);
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
